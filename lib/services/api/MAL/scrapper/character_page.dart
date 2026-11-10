import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// A character or person page read from MyAnimeList itself
/// (`https://myanimelist.net/character/<id>` or `/people/<id>`), the fallback
/// of the character screen when Jikan does not answer.
///
/// The page is parsed off the UI isolate into Jikan's `characters/{id}/full`
/// or `people/{id}/full` `data` shape, so the screen builds the same profile
/// whatever the source.
class MalCharacterPage {
  MalCharacterPage._();

  /// Longest wait for the page (the race caps the whole load at 12 s anyway).
  static const Duration timeout = Duration(seconds: 12);

  /// MAL serves its mobile layout (other markup) to an Android user agent:
  /// the parser reads the desktop one.
  static const Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  /// Page URL of the character (or person when [isCharacter] is false) [id].
  static Uri url(int id, {required bool isCharacter}) => Uri.parse(
      '$_base/${isCharacter ? 'character' : 'people'}/$id');

  /// GET of one page, body as text; throws on a non-200 status or after
  /// [timeout]. Replaceable in tests.
  static Future<String> Function(Uri url) fetch = _fetch;

  /// Tests parse on the calling isolate.
  @visibleForTesting
  static bool parseInline = false;

  /// Restores the real network access (tests).
  @visibleForTesting
  static void reset() {
    fetch = _fetch;
    parseInline = false;
  }

  /// Downloads and parses the page of [id]. Throws on a network error, a
  /// non-200 answer or a page without a name (not a profile page).
  static Future<Map<String, dynamic>> load(int id,
      {required bool isCharacter}) async {
    final body = await fetch(url(id, isCharacter: isCharacter));
    final parser = isCharacter ? parseMalCharacterPage : parseMalPersonPage;
    final data =
        parseInline ? parser(body) : await compute(parser, body);
    final name = data['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('Not a MAL profile page');
    }
    return data;
  }

  static Future<String> _fetch(Uri url) async {
    final response = await http.get(url, headers: headers).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    return response.body;
  }
}

const String _base = 'https://myanimelist.net';

final RegExp _favorites = RegExp(r'Member Favorites:\s*([\d,]+)');
final RegExp _resized = RegExp(r'/r/\d+x\d+/');

// =============================================================================
// Character page
// =============================================================================

/// A MAL character page in Jikan's `characters/{id}/full` `data` shape.
/// Top-level so `compute` can run it on a background isolate.
Map<String, dynamic> parseMalCharacterPage(String body) {
  final document = html_parser.parse(body);
  final content = document.querySelector('#content') ?? document.body;
  final header = content?.querySelector('h2.normal_header');
  final kanji = _text(header?.querySelector('small'));
  return {
    'name': _name(document, header),
    'name_kanji': _stripParens(kanji),
    'about': _aboutAfter(header),
    'favorites': _favoriteCount(content),
    'images': _images(_portrait(content)),
    'anime': [
      for (final work in _works(_header(content, 'character-anime'), 'anime'))
        {'role': work.subtitle, 'anime': work.node},
    ],
    'manga': [
      for (final work in _works(_header(content, 'character-manga'), 'manga'))
        {'role': work.subtitle, 'manga': work.node},
    ],
    'voices': _voiceActors(content),
  };
}

/// The name as Jikan gives it ("Lelouch Lamperouge"): the page's `og:title`,
/// else the profile header without its Japanese part.
String _name(Document document, Element? header) {
  final og = document
      .querySelector('meta[property="og:title"]')
      ?.attributes['content']
      ?.trim();
  if (og != null && og.isNotEmpty) return og;
  if (header == null) return _text(document.querySelector('h1'));
  final copy = header.clone(true);
  for (final small in copy.querySelectorAll('span, small')) {
    small.remove();
  }
  return _text(copy);
}

String _stripParens(String text) {
  var t = text.trim();
  if (t.startsWith('(') && t.endsWith(')')) t = t.substring(1, t.length - 1);
  return t.trim();
}

/// The text after the profile header up to the next section header (the
/// voice actors), with line breaks kept.
String _aboutAfter(Element? header) {
  final parent = header?.parent;
  if (header == null || parent == null) return '';
  final buffer = StringBuffer();
  var started = false;
  for (final node in parent.nodes) {
    if (!started) {
      started = identical(node, header);
      continue;
    }
    if (node is Element &&
        node.localName == 'div' &&
        node.classes.contains('normal_header')) {
      break;
    }
    _writeText(node, buffer);
  }
  return _cleanBlock(buffer.toString());
}

/// The `div.normal_header` with [cls] (e.g. `character-anime`).
Element? _header(Element? content, String cls) =>
    content?.querySelector('div.normal_header.$cls');

class _Work {
  final Map<String, dynamic> node;
  final String? subtitle;

  const _Work(this.node, this.subtitle);
}

/// Rows of the table right after a character page's section [header]:
/// a work of [category] with the character's role.
List<_Work> _works(Element? header, String category) {
  var table = header?.nextElementSibling;
  if (table?.localName != 'table') return const [];
  final out = <_Work>[];
  for (final row in table!.querySelectorAll('tr')) {
    final cells = row.querySelectorAll('td');
    if (cells.length < 2) continue;
    final link = _directLink(cells[1], '/$category/');
    final id = _idIn(link, category);
    if (link == null || id == null) continue;
    final role = _text(cells[1].querySelector('small'));
    out.add(_Work({
      'mal_id': id,
      'url': '$_base/$category/$id',
      'images': _images(cells[0].querySelector('img')),
      'title': _text(link),
    }, role.isEmpty ? null : role));
  }
  return out;
}

/// The voice actors of a character page: one small table each after the
/// "Voice Actors" header.
List<Map<String, dynamic>> _voiceActors(Element? content) {
  Element? header;
  for (final div in content?.querySelectorAll('div.normal_header') ??
      const <Element>[]) {
    if (_text(div) == 'Voice Actors') {
      header = div;
      break;
    }
  }
  final out = <Map<String, dynamic>>[];
  var table = header?.nextElementSibling;
  while (table != null && table.localName == 'table') {
    for (final row in table.querySelectorAll('tr')) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 2) continue;
      final link = _directLink(cells[1], '/people/');
      final id = _idIn(link, 'people');
      if (link == null || id == null) continue;
      final language = _text(cells[1].querySelector('small'));
      out.add({
        'language': language.isEmpty ? null : language,
        'person': {
          'mal_id': id,
          'url': '$_base/people/$id',
          'images': _images(cells[0].querySelector('img')),
          'name': _text(link),
        },
      });
    }
    table = table.nextElementSibling;
  }
  return out;
}

// =============================================================================
// Person page
// =============================================================================

/// A MAL person page in Jikan's `people/{id}/full` `data` shape. Top-level
/// so `compute` can run it on a background isolate. The voice roles also
/// carry the character's favorites (`favorites`), which Jikan leaves out.
Map<String, dynamic> parseMalPersonPage(String body) {
  final document = html_parser.parse(body);
  final content = document.querySelector('#content') ?? document.body;
  final buffer = StringBuffer();
  final more = content?.querySelector('div.people-informantion-more');
  if (more != null) _writeText(more, buffer);
  return {
    'name': _name(document, null),
    'given_name': _labelled(content, 'Given name:'),
    'family_name': _labelled(content, 'Family name:'),
    'about': _cleanBlock(buffer.toString()),
    'favorites': _favoriteCount(content),
    'images': _images(_portrait(content)),
    'voices': _voiceRoles(content),
    'anime': [
      for (final work in _positions(content, 'staff', 'anime'))
        {'position': work.subtitle, 'anime': work.node},
    ],
    'manga': [
      for (final work in _positions(content, 'manga', 'manga'))
        {'position': work.subtitle, 'manga': work.node},
    ],
  };
}

/// The value after a `span.dark_text` label of the person's side column.
String? _labelled(Element? content, String label) {
  for (final span in content?.querySelectorAll('span.dark_text') ??
      const <Element>[]) {
    if (_text(span) != label) continue;
    final buffer = StringBuffer();
    final siblings = span.parent?.nodes ?? const <Node>[];
    for (var i = siblings.indexOf(span) + 1; i > 0 && i < siblings.length; i++) {
      final node = siblings[i];
      if (node is Element &&
          (node.localName == 'div' || node.classes.contains('dark_text'))) {
        break;
      }
      buffer.write(node.text);
    }
    final value = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty ? null : value;
  }
  return null;
}

/// Rows of `table.js-table-people-character`: the anime, the character and
/// its role, plus the character's favorites.
List<Map<String, dynamic>> _voiceRoles(Element? content) {
  final out = <Map<String, dynamic>>[];
  for (final row in content?.querySelectorAll(
          'table.js-table-people-character tr.js-people-character') ??
      const <Element>[]) {
    final cells = row.querySelectorAll('td');
    if (cells.length < 4) continue;
    final title = cells[1].querySelector('a.js-people-title');
    final animeId = _idIn(title, 'anime');
    final link = cells[2].querySelector('a[href*="/character/"]');
    final id = _idIn(link, 'character');
    if (link == null || id == null) continue;
    final pads = cells[2].querySelectorAll('div.spaceit_pad');
    final role = pads.length > 1 ? _text(pads[1]) : '';
    final favorites = int.tryParse(
        _text(cells[2].querySelector('small.js-people-favorites')));
    out.add({
      'role': role.isEmpty ? null : role,
      'favorites': favorites,
      'anime': animeId == null
          ? null
          : {
              'mal_id': animeId,
              'url': '$_base/anime/$animeId',
              'images': _images(cells[0].querySelector('img')),
              'title': _text(title),
            },
      'character': {
        'mal_id': id,
        'url': '$_base/character/$id',
        'images': _images(cells[3].querySelector('img')),
        'name': _text(link),
      },
    });
  }
  return out;
}

/// Rows of `table.js-table-people-<kind>` (`staff` or `manga`): a work of
/// [category] with the person's position.
List<_Work> _positions(Element? content, String kind, String category) {
  final out = <_Work>[];
  for (final row in content?.querySelectorAll(
          'table.js-table-people-$kind tr.js-people-$kind') ??
      const <Element>[]) {
    final cells = row.querySelectorAll('td');
    if (cells.length < 2) continue;
    final title = cells[1].querySelector('a.js-people-title');
    final id = _idIn(title, category);
    if (title == null || id == null) continue;
    String? position;
    for (final small in cells[1].querySelectorAll('div.spaceit_pad small')) {
      final text = _text(small);
      if (text.isNotEmpty) {
        position = text;
        break;
      }
    }
    out.add(_Work({
      'mal_id': id,
      'url': '$_base/$category/$id',
      'images': _images(cells[0].querySelector('img')),
      'title': _text(title),
    }, position));
  }
  return out;
}

// =============================================================================
// Shared helpers
// =============================================================================

String _text(Element? element) =>
    element?.text.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim() ??
    '';

int? _favoriteCount(Element? content) {
  final match = _favorites.firstMatch(content?.text ?? '');
  return match == null ? null : int.tryParse(match.group(1)!.replaceAll(',', ''));
}

/// The main picture: the image linking to the `pics` page.
Element? _portrait(Element? content) =>
    content?.querySelector('a[href*="/pics"] img') ??
    content?.querySelector('img.portrait-225x350');

/// The first `a` child of [cell] whose link contains [path] (the add-to-list
/// buttons sit deeper and are skipped).
Element? _directLink(Element cell, String path) {
  for (final child in cell.children) {
    if (child.localName == 'a' && (child.attributes['href'] ?? '').contains(path)) {
      return child;
    }
  }
  final pad = cell.querySelector('div.spaceit_pad > a.js-people-title');
  return pad;
}

int? _idIn(Element? link, String category) {
  final href = link?.attributes['href'];
  if (href == null) return null;
  final match = RegExp('/$category/(\\d+)').firstMatch(href);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// Jikan's `images` object for a lazy-loaded thumbnail, at full size
/// (MAL's `/r/<w>x<h>/` resized copy and its signature dropped).
Map<String, dynamic> _images(Element? img) => {
      'jpg': {'image_url': _imageUrl(img)},
    };

String? _imageUrl(Element? img) {
  if (img == null) return null;
  var src = img.attributes['data-src'] ?? img.attributes['src'];
  if (src == null || src.isEmpty || src.contains('spacer.gif')) return null;
  if (src.contains('questionmark')) return null;
  if (src.startsWith('//')) src = 'https:$src';
  if (src.startsWith('/')) src = '$_base$src';
  src = src.replaceFirst(_resized, '/');
  final query = src.indexOf('?');
  return query < 0 ? src : src.substring(0, query);
}

/// Text of [node] with `br` and list items as line breaks; scripts, styles
/// and buttons (the spoiler toggle) skipped.
void _writeText(Node node, StringBuffer out) {
  if (node is Text) {
    out.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
    return;
  }
  if (node is! Element) return;
  switch (node.localName) {
    case 'script' || 'style' || 'noscript' || 'input' || 'button':
      return;
    case 'br':
      out.write('\n');
      return;
    case 'li':
      out.write('\n');
  }
  for (final child in node.nodes) {
    _writeText(child, out);
  }
}

/// Trims every line, keeps at most one empty line in a row.
String _cleanBlock(String raw) {
  final lines = raw
      .replaceAll(' ', ' ')
      .split('\n')
      .map((l) => l.trim())
      .toList();
  final out = <String>[];
  for (final line in lines) {
    if (line.isEmpty && (out.isEmpty || out.last.isEmpty)) continue;
    out.add(line);
  }
  while (out.isNotEmpty && out.last.isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}
