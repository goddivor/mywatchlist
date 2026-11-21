import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mwl_commons/mwl_commons.dart' show Paging;
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';

/// Reads the latest articles from MyAnimeList's own `/news` and `/featured` pages.
///
/// The pages use `news-unit` rows since November 2026 (and the four `featured-pickup-unit`
/// cards on top of `/featured`); the older `box-unit3` markup is still read. Only the first
/// `.news-list` is read: on `/news` the following lists repeat the same articles grouped by
/// tag. The next page is the `?p=` link one past the current one, or the old `btn-next`
/// button.
AnimeNewsOrFeaturedResult parseLatestArticles(String body) {
  final document = html_parser.parse(body);
  final list = document.querySelector('.news-list');
  final items = <AnimeNewsOrFeaturedItem>[];
  final seen = <int>{};

  int? idOf(String url) => int.tryParse(RegExp(r'/(?:news|featured)/(\d+)').firstMatch(url)?.group(1) ?? '');
  String imageOf(Element? image) =>
      image?.attributes['data-src'] ?? image?.attributes['src'] ?? image?.attributes['data-bg'] ?? '';
  String tagsOf(Element unit) => unit.querySelectorAll('.tags .tag').map((e) => e.text.trim()).join(', ');

  void add(int? id, String title, String text, String tags, String image, String url) {
    if (id == null || title.isEmpty || !seen.add(id)) return;
    items.add(AnimeNewsOrFeaturedItem(id: id, title: title, text: text, tags: tags, imageUrl: image, url: url));
  }

  for (final unit in document.querySelectorAll('.featured-pickup-unit')) {
    final link = unit.querySelector('a.title');
    final url = link?.attributes['href']?.trim() ?? '';
    add(idOf(url), _squash(link?.text ?? ''), _squash(unit.querySelector('.text')?.text ?? ''), tagsOf(unit),
        imageOf(unit.querySelector('a.image')), url);
  }
  for (final unit in list?.querySelectorAll('.news-unit') ?? const <Element>[]) {
    final link = unit.querySelector('.title a');
    final url = link?.attributes['href']?.trim() ?? '';
    add(idOf(url), _squash(link?.text ?? ''), _squash(unit.querySelector('.text')?.text ?? ''), tagsOf(unit),
        imageOf(unit.querySelector('img')), url);
  }
  for (final unit in list?.querySelectorAll('.box-unit3') ?? const <Element>[]) {
    final url = unit.querySelector('a.box-unit3-btn')?.attributes['href']?.trim() ?? '';
    add(idOf(url), unit.querySelector('.title')?.text.trim() ?? '', _squash(unit.querySelector('.update')?.text ?? ''),
        tagsOf(unit), imageOf(unit.querySelector('img')), url);
  }
  return AnimeNewsOrFeaturedResult(
    newsorfeatured: items,
    paging: Paging(previous: '', next: _nextPage(document)),
  );
}

/// The link to the next page of the list, or null on the last one.
String? _nextPage(Document document) {
  final old = document.querySelector('a.btn-next')?.attributes['href']?.trim();
  if (old != null && old.isNotEmpty) return old;
  int? pageOf(String? href) => int.tryParse(RegExp(r'[?&]p=(\d+)').firstMatch(href ?? '')?.group(1) ?? '');
  final links = <int, String>{};
  for (final a in document.querySelectorAll('a.link[href*="p="]')) {
    final href = a.attributes['href']!.trim();
    final page = pageOf(href);
    if (page != null && RegExp(r'/(?:news|featured)\?').hasMatch(href)) links[page] = href;
  }
  if (links.isEmpty) return null;
  // The current page is the `a.link.current` of the pagination ("1 - 20").
  final current = pageOf(document.querySelector('a.link.current')?.attributes['href']) ?? 1;
  return links[current + 1];
}

String _squash(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();
