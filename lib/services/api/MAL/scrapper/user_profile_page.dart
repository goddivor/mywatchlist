import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// MyAnimeList answered 404 for this profile: the user does not exist.
class MalProfileNotFound implements Exception {
  final String username;
  const MalProfileNotFound(this.username);

  @override
  String toString() => 'MalProfileNotFound($username)';
}

/// The profile page of one user (`myanimelist.net/profile/<name>`), read on the device.
///
/// It answers where Jikan does not (Jikan is unreachable on some networks). The page is
/// requested with a desktop User-Agent: MAL serves another layout to Android browsers. It
/// is parsed off the UI isolate into the shape of a Jikan `users/{name}/full` payload, so
/// the profile code reads both sources the same way.
class MalProfilePage {
  MalProfilePage._();

  static const String _userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  /// Tests parse on the calling isolate (`compute` needs a real event loop).
  @visibleForTesting
  static bool parseInline = false;

  /// The Jikan-shaped profile of [username]. Throws [MalProfileNotFound] on a 404, an
  /// [http.ClientException] on another status, a [FormatException] when the page is not a
  /// profile (a challenge or maintenance page), a [TimeoutException] after [timeout].
  static Future<Map<String, dynamic>> fetch(
    String username, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final url = Uri.https('myanimelist.net', '/profile/${Uri.encodeComponent(username)}');
    final response = await http.get(url, headers: const {
      'User-Agent': _userAgent,
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(timeout);
    if (response.statusCode == 404) throw MalProfileNotFound(username);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    final body = response.body;
    final parsed = parseInline
        ? parseMalProfilePage(body)
        : await compute(parseMalProfilePage, body);
    if (parsed == null) throw FormatException('Not a MAL profile page for $username');
    return parsed;
  }
}

final DateFormat _fullDate = DateFormat('MMM d, yyyy', 'en_US');
final DateFormat _dayMonth = DateFormat('MMM d', 'en_US');

/// A date of the page ("Nov 26, 2021") as an ISO day ("2021-11-26"); a birthday shown
/// without its year ("Jan 1") as "--01-01". Null when unreadable.
@visibleForTesting
String? malProfileDate(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  try {
    final d = _fullDate.parseStrict(text);
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  } on FormatException {
    // Not a full date; try the day without its year.
  }
  try {
    final d = _dayMonth.parseStrict(text);
    return '--${two(d.month)}-${two(d.day)}';
  } on FormatException {
    return null;
  }
}

num? _number(String? raw) {
  final text = raw?.replaceAll(',', '').trim();
  if (text == null || text.isEmpty) return null;
  return num.tryParse(text);
}

String? _text(Element? e) {
  final t = e?.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return (t == null || t.isEmpty) ? null : t;
}

String? _image(Element? img) {
  if (img == null) return null;
  for (final key in const ['data-src', 'src']) {
    final v = img.attributes[key]?.trim();
    if (v != null && v.isNotEmpty && !v.endsWith('spacer.gif')) return v;
  }
  return null;
}

/// The stats block of one kind (`anime` or `manga`) in the Jikan `statistics` shape.
Map<String, dynamic>? _stats(Document doc, String kind) {
  final block = doc.querySelector('.user-statistics .stats.$kind');
  if (block == null) return null;
  final manga = kind == 'manga';
  final out = <String, dynamic>{};

  final scoreRow = block.querySelector('.stat-score');
  if (scoreRow != null) {
    for (final cell in scoreRow.children) {
      final label = _text(cell.querySelector('.fn-grey2'))?.toLowerCase() ?? '';
      if (label.startsWith('days')) {
        final value = cell.text.replaceFirst(RegExp(r'^\s*Days:\s*', caseSensitive: false), '');
        out[manga ? 'days_read' : 'days_watched'] = _number(value);
      } else if (label.startsWith('mean score')) {
        out['mean_score'] = _number(_text(cell.querySelector('.score-label')));
      }
    }
  }

  const statusKeys = {
    'watching': 'watching',
    'reading': 'reading',
    'completed': 'completed',
    'on_hold': 'on_hold',
    'dropped': 'dropped',
    'plan_to_watch': 'plan_to_watch',
    'plan_to_read': 'plan_to_read',
  };
  for (final li in block.querySelectorAll('ul.stats-status li')) {
    final link = li.querySelector('a');
    final value = _number(_text(li.querySelector('span')));
    if (link == null || value == null) continue;
    for (final cls in link.classes) {
      final key = statusKeys[cls];
      if (key != null) out[key] = value;
    }
  }

  for (final li in block.querySelectorAll('ul.stats-data li')) {
    final spans = li.querySelectorAll('span');
    if (spans.length < 2) continue;
    final label = _text(spans.first)?.toLowerCase();
    final value = _number(_text(spans.last));
    final key = switch (label) {
      'total entries' => 'total_entries',
      'rewatched' => 'rewatched',
      'reread' => 'reread',
      'episodes' => 'episodes_watched',
      'chapters' => 'chapters_read',
      'volumes' => 'volumes_read',
      _ => null,
    };
    if (key != null && value != null) out[key] = value;
  }
  return out;
}

/// One favorites slider (`anime_favorites`, `character_favorites`…) as Jikan rows.
List<Map<String, dynamic>> _favorites(Document doc, String blockId, String path, String key) {
  final rows = <Map<String, dynamic>>[];
  final block = doc.getElementById(blockId);
  if (block == null) return rows;
  final idPattern = RegExp('/$path/(\\d+)');
  for (final li in block.querySelectorAll('li.btn-fav')) {
    final a = li.querySelector('a');
    final id = int.tryParse(idPattern.firstMatch(a?.attributes['href'] ?? '')?.group(1) ?? '');
    final title = li.attributes['title']?.trim() ?? _text(li.querySelector('.title'));
    if (id == null || title == null || title.isEmpty) continue;
    rows.add({
      'mal_id': id,
      key: title,
      'images': {
        'jpg': {'image_url': _image(li.querySelector('img'))},
      },
    });
  }
  return rows;
}

/// The profile page parsed into the shape of a Jikan `users/{name}/full` payload, plus the
/// page's "about me" (`about`, HTML, and `about_modern`), the raw "Last Online" text and
/// `is_supporter` (the page shows the Supporter mark).
/// Null when [body] is not a profile page. Top level so `compute` can run it.
Map<String, dynamic>? parseMalProfilePage(String body) {
  final doc = html.parse(body);
  final side = doc.querySelector('.user-profile');
  if (side == null) return null;

  final status = <String, String>{};
  for (final li in side.querySelectorAll('ul.user-status li')) {
    final title = _text(li.querySelector('.user-status-title'));
    final data = _text(li.querySelector('.user-status-data'));
    if (title != null && data != null) status.putIfAbsent(title.toLowerCase(), () => data);
  }

  final report = doc.querySelector('a[href*="type=profile"][href*="id="]')?.attributes['href'];
  final id = int.tryParse(RegExp(r'[?&]id=(\d+)').firstMatch(report ?? '')?.group(1) ?? '');
  final pageUrl = doc.querySelector('meta[property="og:url"]')?.attributes['content'];
  final username = RegExp(r'/profile/([^/?#]+)').firstMatch(pageUrl ?? '')?.group(1);

  String? about;
  var modern = false;
  final classic = doc.querySelector('.user-profile-about .word-break')?.innerHtml.trim();
  if (classic != null && classic.isNotEmpty) {
    about = classic;
  } else {
    final m = doc.querySelector('#modern-about-me')?.innerHtml.trim();
    if (m != null && m.isNotEmpty) {
      about = m;
      modern = true;
    }
  }

  return {
    'mal_id': id,
    'username': username == null ? null : Uri.decodeComponent(username),
    'images': {
      'jpg': {'image_url': _image(side.querySelector('.user-image img'))},
    },
    // The Supporter mark of the profile's own status list (`.icon-supporter`); the same
    // class on commenters further down the page must not count.
    'is_supporter': side.querySelector('ul.user-status .icon-supporter') != null,
    'last_online': status['last online'],
    'gender': status['gender'],
    'birthday': malProfileDate(status['birthday']),
    'location': status['location'],
    'joined': malProfileDate(status['joined']),
    'statistics': {
      'anime': _stats(doc, 'anime'),
      'manga': _stats(doc, 'manga'),
    },
    'favorites': {
      'anime': _favorites(doc, 'anime_favorites', 'anime', 'title'),
      'manga': _favorites(doc, 'manga_favorites', 'manga', 'title'),
      'characters': _favorites(doc, 'character_favorites', 'character', 'name'),
      'people': _favorites(doc, 'person_favorites', 'people', 'name'),
    },
    'about': about,
    'about_modern': modern,
  };
}
