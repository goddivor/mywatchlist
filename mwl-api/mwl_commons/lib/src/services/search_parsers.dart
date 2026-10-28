import 'package:html/dom.dart';
import 'package:html_unescape/html_unescape.dart';

import '../model/html/pages/content_search.dart';

/// Parsers of MyAnimeList's own search pages and company directory, the
/// sources used when Jikan is unreachable.
///
/// Pure (Document in, model out) so they run on a background isolate. A page
/// without MAL's `#contentWrapper` (a challenge or maintenance page) throws a
/// [FormatException]: it must read as a failure, never as "no results".
class SearchParsers {
  SearchParsers._();

  static final _unescape = HtmlUnescape();
  static final _spaces = RegExp(r'\s+');

  static String _clean(String? text) =>
      _unescape.convert((text ?? '').replaceAll(_spaces, ' ').trim());

  static String? _cleanOrNull(String? text) {
    final cleaned = _clean(text);
    return cleaned.isEmpty ? null : cleaned;
  }

  static void _requireMalPage(Document doc) {
    if (doc.querySelector('#contentWrapper') == null) {
      throw const FormatException('Not a MyAnimeList page');
    }
  }

  // ---------------------------------------------------------------------------
  // anime.php, manga.php, character.php, people.php
  // ---------------------------------------------------------------------------

  /// One page of results of `<category>.php` (`anime`, `manga`, `character`,
  /// `person`). MAL answers "no titles matched" with a 404 page that still has
  /// `#contentWrapper`: that is an empty page, not a failure.
  static MalSearchPageHtml parseSearchPage(Document doc, String category) {
    _requireMalPage(doc);
    final bad = _clean(doc.querySelector('.badresult')?.text).toLowerCase();
    if (bad.contains('at least 3')) {
      return const MalSearchPageHtml(tooShort: true);
    }
    final items = category == 'character' || category == 'person'
        ? _peopleRows(doc, category)
        : _contentRows(doc, category);
    return MalSearchPageHtml(items: items, hasNext: _hasNextOffset(doc));
  }

  /// A paging link with a `show` offset beyond the current one.
  static bool _hasNextOffset(Document doc) {
    var current = 0;
    final pager = doc.querySelectorAll('.normal_header span.bgColor1');
    if (pager.isEmpty) return false;
    final span = pager.first;
    // The current page is the bracketed number, e.g. "[2]".
    final match = RegExp(r'\[(\d+)\]').firstMatch(span.text);
    final currentPage = int.tryParse(match?.group(1) ?? '') ?? 1;
    current = (currentPage - 1) * 50;
    for (final a in span.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final show = RegExp(r'[?&;]show=(\d+)').firstMatch(href);
      final offset = int.tryParse(show?.group(1) ?? '');
      if (offset != null && offset > current) return true;
    }
    return false;
  }

  static List<MalSearchItemHtml> _contentRows(Document doc, String category) {
    final prefix = category == 'manga' ? '/manga/' : '/anime/';
    final table = doc
        .querySelectorAll('table')
        .where((t) => t.querySelector('a.hoverinfo_trigger strong') != null)
        .firstOrNull;
    if (table == null) return const [];
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return const [];

    // Column names from the header row: "Type", "Eps.", "Vol.", "Chap.",
    // "Score", "Start Date", "End Date", "Members", "Rated".
    final header =
        rows.first.children.map((td) => _clean(td.text).toLowerCase()).toList();
    int col(String name) => header.indexWhere((h) => h.startsWith(name));
    final typeAt = col('type');
    final epsAt = category == 'manga' ? col('chap') : col('eps');
    final volAt = col('vol');
    final scoreAt = col('score');
    final startAt = col('start');
    final endAt = col('end');
    final membersAt = col('members');
    final ratedAt = col('rated');

    final items = <MalSearchItemHtml>[];
    final seen = <int>{};
    for (final row in rows.skip(1)) {
      final cells = row.children;
      final link = row.querySelector('a.hoverinfo_trigger strong')?.parent;
      final href = link?.attributes['href'] ?? '';
      final at = href.indexOf(prefix);
      if (at < 0) continue;
      final id = int.tryParse(href.substring(at + prefix.length).split('/').first);
      if (id == null || !seen.add(id)) continue;
      final title = _clean(link!.querySelector('strong')?.text);
      if (title.isEmpty) continue;
      String? cell(int index) =>
          index >= 0 && index < cells.length ? _cleanOrNull(cells[index].text) : null;

      final synopsis = row.querySelector('.pt4');
      synopsis?.querySelectorAll('a').forEach((a) => a.remove());
      items.add(MalSearchItemHtml(
        id: id,
        category: category,
        title: title,
        image: _fullImage(row.querySelector('img')),
        synopsis: _cleanOrNull(synopsis?.text),
        type: _dash(cell(typeAt)),
        episodes: _number(cell(epsAt)),
        volumes: _number(cell(volAt)),
        score: double.tryParse(cell(scoreAt) ?? ''),
        startDate: malDate(cell(startAt)),
        endDate: malDate(cell(endAt)),
        members: _number(cell(membersAt)),
        rated: _dash(cell(ratedAt)),
      ));
    }
    return items;
  }

  static List<MalSearchItemHtml> _peopleRows(Document doc, String category) {
    final prefix = category == 'character' ? '/character/' : '/people/';
    final items = <MalSearchItemHtml>[];
    final seen = <int>{};
    for (final row in doc.querySelectorAll('#content table tr')) {
      final links = row
          .querySelectorAll('a')
          .where((a) => (a.attributes['href'] ?? '').contains(prefix))
          .toList();
      if (links.isEmpty) continue;
      final href = links.first.attributes['href']!;
      final at = href.indexOf(prefix);
      final id = int.tryParse(href.substring(at + prefix.length).split('/').first);
      if (id == null || !seen.add(id)) continue;
      final named = links.where((a) => _clean(a.text).isNotEmpty).firstOrNull;
      final name = _clean(named?.text);
      if (name.isEmpty) continue;
      final small = named?.parent?.querySelector('small');
      final other = _cleanOrNull(small?.text)?.replaceAll(RegExp(r'^\(|\)$'), '');
      items.add(MalSearchItemHtml(
        id: id,
        category: category,
        title: name,
        image: _fullImage(row.querySelector('img')),
        alternative: other == null || other.isEmpty ? null : other,
      ));
    }
    return items;
  }

  /// `https://cdn.myanimelist.net/r/50x70/images/anime/1234/1.jpg?s=…` →
  /// `https://cdn.myanimelist.net/images/anime/1234/1.jpg`; MAL's question
  /// mark placeholder → null.
  static String? _fullImage(Element? img) {
    if (img == null) return null;
    var src = img.attributes['data-src'] ?? img.attributes['src'] ?? '';
    if (src.isEmpty || src.contains('spacer.gif')) {
      src = img.attributes['data-src'] ?? '';
    }
    if (src.isEmpty || src.contains('questionmark') || src.contains('na_series')) {
      return null;
    }
    src = src.replaceFirst(RegExp(r'/r/\d+x\d+/'), '/');
    final query = src.indexOf('?');
    return query < 0 ? src : src.substring(0, query);
  }

  static String? _dash(String? text) =>
      text == null || text == '-' || text == 'N/A' ? null : text;

  static int? _number(String? text) {
    final digits = (text ?? '').replaceAll(RegExp(r'[^\d]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// MAL's `MM-DD-YY` (unknown parts `??`) → `yyyy-mm-dd`, `yyyy-mm` or
  /// `yyyy`; two-digit years up to three years ahead are 20xx, others 19xx.
  static String? malDate(String? text, {DateTime? now}) {
    final value = (text ?? '').trim();
    final match = RegExp(r'^(\?\?|\d{2})-(\?\?|\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final yy = int.parse(match.group(3)!);
    final limit = ((now ?? DateTime.now()).year + 3) % 100;
    final year = yy <= limit ? 2000 + yy : 1900 + yy;
    final month = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    if (month == null) return '$year';
    final mm = month.toString().padLeft(2, '0');
    if (day == null) return '$year-$mm';
    return '$year-$mm-${day.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // /company
  // ---------------------------------------------------------------------------

  /// The company directory (`/company?limit=`, most favorited first, with the
  /// number of anime and favorites) or a company search (`/company?q=&p=`).
  /// Both list 50 companies with their logo.
  static CompanyPageHtml parseCompanies(Document doc) {
    _requireMalPage(doc);
    final items = <CompanyHtml>[];
    final seen = <int>{};
    for (final row in doc.querySelectorAll('#content table tr')) {
      final links = row
          .querySelectorAll('a')
          .where((a) => (a.attributes['href'] ?? '').contains('/anime/producer/'))
          .toList();
      if (links.isEmpty) continue;
      final href = links.first.attributes['href']!;
      final rest = href.substring(href.indexOf('/anime/producer/') + 16);
      final id = int.tryParse(rest.split('/').first);
      if (id == null || !seen.add(id)) continue;
      final named = links.where((a) => _clean(a.text).isNotEmpty).firstOrNull;
      final img = row.querySelector('img');
      var name = _clean(named?.text);
      if (name.isEmpty) name = _clean(img?.attributes['alt']);
      if (name.isEmpty) continue;
      final small = named?.parent?.querySelector('small');
      final japanese = _clean(small?.text).replaceAll(RegExp(r'^\(|\)$'), '').trim();
      final logo = img?.attributes['data-src'] ?? img?.attributes['src'];
      items.add(CompanyHtml(
        id: id,
        name: name,
        japaneseName: japanese.isEmpty ? null : japanese,
        logo: logo == null || logo.contains('company_no_picture') || logo.contains('spacer.gif')
            ? null
            : logo,
        animeCount: _number(row.querySelector('td.numofanime')?.text),
        favorites: _number(row.querySelector('td.favorites')?.text),
      ));
    }
    final listingNext = doc.querySelector('a.link-blue-box.next') != null;
    final current = doc.querySelector('.pagination .current');
    final searchNext = current?.nextElementSibling?.localName == 'a';
    return CompanyPageHtml(items: items, hasNext: listingNext || searchNext);
  }
}
