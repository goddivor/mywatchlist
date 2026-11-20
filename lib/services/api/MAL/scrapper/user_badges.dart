import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// One badge of a MyAnimeList profile (`/profile/<name>/badges`).
@immutable
class MalBadge {
  final String name;

  /// The badge picture on MAL's CDN (`cdn.myanimelist.net/images/badge/…png`).
  final String imageUrl;

  /// What the badge links to on MAL (an event page, a forum topic), when it has a link.
  final String? url;

  /// When it was earned: MAL gives the month only ("Nov 2024"); the first day of it.
  final DateTime? earnedAt;

  const MalBadge({required this.name, required this.imageUrl, this.url, this.earnedAt});
}

final DateFormat _monthYear = DateFormat('MMM yyyy', 'en_US');

/// The badges of a `/profile/<name>/badges` page, in MAL's order (newest first). A user
/// without badges gives an empty list.
List<MalBadge> parseMalBadgesPage(String body) {
  final doc = html.parse(body);
  final badges = <MalBadge>[];
  for (final box in doc.querySelectorAll('.boxlist-container.badge .boxlist')) {
    final img = box.querySelector('img');
    final image = img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
    if (image.isEmpty || image.endsWith('spacer.gif')) continue;
    final title = box.querySelector('.title a') ?? box.querySelector('.title');
    final name = (title?.text ?? img?.attributes['alt'] ?? '').trim();
    if (name.isEmpty) continue;
    final href = box.querySelector('a')?.attributes['href'];
    DateTime? earned;
    final date = box.querySelector('.fn-grey2')?.text.trim();
    if (date != null && date.isNotEmpty) {
      try {
        earned = _monthYear.parseStrict(date);
      } on FormatException {
        earned = null;
      }
    }
    badges.add(MalBadge(
      name: name,
      imageUrl: image.startsWith('http') ? image : 'https://myanimelist.net$image',
      url: href == null || href.isEmpty
          ? null
          : (href.startsWith('http') ? href : 'https://myanimelist.net$href'),
      earnedAt: earned,
    ));
  }
  return badges;
}

/// Reads the badges of a profile on the device (MAL page, desktop layout), parsed off the UI
/// isolate. Each user is read once per session; a failure is asked again next time.
class MalBadges {
  MalBadges._();

  static const String _userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  /// The page source; tests replace it.
  @visibleForTesting
  static Future<List<MalBadge>> Function(String username) source = _fetch;

  static final Map<String, Future<List<MalBadge>>> _session = {};

  /// The badges of [username] (empty when none).
  static Future<List<MalBadge>> of(String username) {
    final key = username.toLowerCase();
    final known = _session[key];
    if (known != null) return known;
    final future = source(username);
    _session[key] = future;
    future.then<void>((_) {}, onError: (_) => _session.remove(key));
    return future;
  }

  @visibleForTesting
  static void reset() {
    _session.clear();
    source = _fetch;
  }

  static Future<List<MalBadge>> _fetch(String username) async {
    final url = Uri.https('myanimelist.net', '/profile/${Uri.encodeComponent(username)}/badges');
    final response = await http.get(url, headers: const {
      'User-Agent': _userAgent,
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    return compute(parseMalBadgesPage, response.body);
  }
}
