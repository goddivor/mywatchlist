import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';

/// News of one title read from MyAnimeList's own page
/// (`https://myanimelist.net/<anime|manga>/<id>/_/news`), the fallback of the
/// detail page's News section when Jikan does not answer. The page lists
/// every article of the title at once (no pagination).
class MalNewsPage {
  MalNewsPage._();

  /// Longest wait for the page (the race caps the whole load at 12 s anyway).
  static const Duration timeout = Duration(seconds: 12);

  /// Page URL of the news of [id] in [category] (`anime` or `manga`).
  static Uri url(int id, String category) =>
      Uri.parse('$_base/${category == 'manga' ? 'manga' : 'anime'}/$id/_/news');

  /// Downloads and parses the page; the parsing runs off the UI isolate.
  /// Throws on a network error or a non-200 answer.
  static Future<List<AnimeNews>> fetch(int id, String category, {http.Client? client}) async {
    final uri = url(id, category);
    final request = client != null ? client.get(uri) : http.get(uri);
    final response = await request.timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL news page answered ${response.statusCode}', uri);
    }
    final items = await compute(parseMalNewsPage, response.body);
    return items.map(AnimeNews.fromJson).toList();
  }
}

final RegExp _newsId = RegExp(r'/news/(\d+)');
final RegExp _comments = RegExp(r'\(([\d,]+) comments?\)');
final DateFormat _malDate = DateFormat('MMM d, yyyy h:mm a', 'en_US');

/// The articles of a MAL news page in Jikan's `news` JSON shape (so the
/// cards are the same whatever the source). Top-level so `compute` can run it
/// on a background isolate. Unreadable entries are skipped.
List<Map<String, dynamic>> parseMalNewsPage(String body) {
  final document = html_parser.parse(body);
  final result = <Map<String, dynamic>>[];
  final seen = <int>{};
  for (final pic in document.querySelectorAll('div.picSurround')) {
    final link = pic.querySelector('a[href*="/news/"]');
    final id = int.tryParse(_newsId.firstMatch(link?.attributes['href'] ?? '')?.group(1) ?? '');
    final item = pic.parent;
    if (id == null || item == null || !seen.add(id)) continue;
    final title = _text(item.querySelector('p.spaceit strong'));
    if (title.isEmpty) continue;
    final meta = item.querySelector('p.lightLink');
    final author = meta?.querySelector('a[href^="/profile/"]');
    final forum = meta?.querySelector('a[href*="topicid="]');
    final authorName = _text(author);
    result.add({
      'mal_id': id,
      'url': '$_base/news/$id',
      'title': title,
      'date': _date(meta),
      'author_username': authorName.isEmpty ? null : authorName,
      'author_url': authorName.isEmpty ? null : '$_base/profile/$authorName',
      'forum_url': forum == null ? null : _absolute(forum.attributes['href']),
      'images': {
        'jpg': {'image_url': _image(pic.querySelector('img'))},
      },
      'comments': _commentCount(forum),
      'excerpt': _excerpt(item),
    });
  }
  return result;
}

const String _base = 'https://myanimelist.net';

String _text(Element? element) => element?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';

String? _absolute(String? href) {
  if (href == null || href.isEmpty) return null;
  return href.startsWith('http') ? href : '$_base$href';
}

/// The 2x picture of the lazy-loaded thumbnail (100 x 156), else the 1x one.
String? _image(Element? img) {
  if (img == null) return null;
  final srcset = img.attributes['data-srcset'];
  if (srcset != null) {
    for (final part in srcset.split(',')) {
      final pieces = part.trim().split(RegExp(r'\s+'));
      if (pieces.length == 2 && pieces[1] == '2x') return pieces[0];
    }
  }
  final src = img.attributes['data-src'] ?? img.attributes['src'];
  if (src == null || src.contains('spacer.gif')) return null;
  return src;
}

/// The text of the excerpt without its "read more" link.
String? _excerpt(Element item) {
  // A direct child block: a descendant selector would also match the item's
  // own `clearfix` class and return the title paragraph.
  Element? paragraph;
  for (final child in item.children) {
    if (child.localName == 'div' && child.classes.contains('clearfix')) {
      paragraph = child.querySelector('p');
      break;
    }
  }
  if (paragraph == null) return null;
  final copy = paragraph.clone(true);
  for (final a in copy.querySelectorAll('a')) {
    a.remove();
  }
  final text = _text(copy);
  return text.isEmpty ? null : text;
}

/// "Oct 10, 2023 6:34 AM by …" as an ISO date (MAL's server time), or null.
String? _date(Element? meta) {
  final text = _text(meta);
  final index = text.indexOf(' by ');
  final raw = index > 0 ? text.substring(0, index) : text;
  if (raw.isEmpty) return null;
  try {
    return _malDate.parseLoose(raw).toIso8601String();
  } catch (_) {
    return null;
  }
}

int? _commentCount(Element? forum) {
  final match = _comments.firstMatch(_text(forum));
  return match == null ? null : int.tryParse(match.group(1)!.replaceAll(',', ''));
}
