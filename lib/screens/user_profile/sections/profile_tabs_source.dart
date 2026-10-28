import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_history.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

/// Where the Friends, Clubs and History tabs of a profile get their data.
///
/// MyAnimeList's own profile pages answer where Jikan does not (it is unreachable on some
/// networks), so each tab reads the MAL page first and falls back to the mwl-api route. One
/// call never outlasts [budget]: the tab ends in data, an empty list or an error to retry.
/// Pages are parsed on a background isolate. Sources are fields so tests can replace them.
class ProfileTabsSource {
  ProfileTabsSource._();

  /// Longest wait for one tab, both sources included.
  static Duration budget = const Duration(seconds: 12);

  /// The MAL page gets this part of the [budget]; the fallback gets the rest.
  static Duration get _primaryShare =>
      Duration(milliseconds: budget.inMilliseconds * 7 ~/ 12);

  static const Duration _minFallback = Duration(milliseconds: 500);

  /// GET of one MAL page, body as text; throws on a non-200 status or after the timeout.
  static Future<String> Function(Uri url, Duration timeout) fetchPage = _fetchPage;

  /// mwl-api routes (Jikan for friends, MAL pages parsed by the backend for the others).
  static Future<Map<String, dynamic>?> Function(String username, int page) apiFriends =
      (username, page) =>
          MwlApi.i.getUserFriends(username, page: page, timeout: budget);
  static Future<Map<String, dynamic>?> Function(String username, String type) apiHistory =
      (username, type) => MwlApi.i.getUserHistory(username, type: type, timeout: budget);
  static Future<Map<String, dynamic>?> Function(String username) apiClubs =
      (username) => MwlApi.i.getUserClubs(username, timeout: budget);

  /// Tests parse on the calling isolate (`compute` needs a real event loop).
  @visibleForTesting
  static bool parseInline = false;

  /// Restores the real sources and timings (tests).
  @visibleForTesting
  static void reset() {
    budget = const Duration(seconds: 12);
    fetchPage = _fetchPage;
    apiFriends = (username, page) =>
        MwlApi.i.getUserFriends(username, page: page, timeout: budget);
    apiHistory = (username, type) =>
        MwlApi.i.getUserHistory(username, type: type, timeout: budget);
    apiClubs = (username) => MwlApi.i.getUserClubs(username, timeout: budget);
    parseInline = false;
  }

  // ---------------------------------------------------------------------------
  // The three tabs
  // ---------------------------------------------------------------------------

  /// One page (100) of friends. [page] starts at 1.
  static Future<ProfileFriendsPage> friends(String username, {int page = 1}) {
    return _withFallback<ProfileFriendsPage>(
      (timeout) async {
        final offset = (page - 1) * ProfileFriendsPage.pageSize;
        final body = await fetchPage(
          _profileUrl(username, 'friends', query: offset == 0 ? null : 'offset=$offset'),
          timeout,
        );
        return _parse(parseFriendsPage, body);
      },
      (timeout) async {
        final envelope = await apiFriends(username, page).timeout(timeout);
        if (envelope == null) throw StateError('No answer for the friends of $username');
        return parseFriendsEnvelope(envelope);
      },
    );
  }

  /// The recent activity of one kind (`anime` or `manga`).
  static Future<List<ProfileHistoryEntry>> history(String username, String type) {
    return _withFallback<List<ProfileHistoryEntry>>(
      (timeout) async {
        final body = await fetchPage(
          Uri.parse(
              '${Constants.maluserHistoryUrl}/${Uri.encodeComponent(username)}/$type'),
          timeout,
        );
        return _parse(parseHistoryPage, (body, type));
      },
      (timeout) async {
        final envelope = await apiHistory(username, type).timeout(timeout);
        if (envelope == null) throw StateError('No answer for the history of $username');
        return parseHistoryEnvelope(envelope, category: type);
      },
    );
  }

  /// Anime and manga activity together. One kind failing does not hide the other; both
  /// failing throws.
  static Future<List<ProfileHistoryEntry>> historyAll(String username) async {
    Future<List<ProfileHistoryEntry>?> one(String type) async {
      try {
        return await history(username, type);
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([one('anime'), one('manga')]);
    if (results.every((r) => r == null)) {
      throw TimeoutException('History unavailable for $username');
    }
    return [...?results[0], ...?results[1]];
  }

  /// The clubs a user belongs to.
  static Future<List<ClubHtml>> clubs(String username) {
    return _withFallback<List<ClubHtml>>(
      (timeout) async {
        final body = await fetchPage(_profileUrl(username, 'clubs'), timeout);
        return _parse(parseClubsPage, body);
      },
      (timeout) async {
        final envelope = await apiClubs(username).timeout(timeout);
        if (envelope == null) throw StateError('No answer for the clubs of $username');
        return clubsFromRows((envelope['data'] as Map?)?['clubs']);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Plumbing
  // ---------------------------------------------------------------------------

  static Uri _profileUrl(String username, String tab, {String? query}) => Uri.parse(
      '${Constants.maluserProfileUrl}/${Uri.encodeComponent(username)}/$tab'
      '${query == null ? '' : '?$query'}');

  /// Runs [primary], then [fallback] with what is left of the [budget]; the whole call is
  /// bounded by the budget. When both fail the fallback's error is thrown.
  static Future<T> _withFallback<T>(
    Future<T> Function(Duration timeout) primary,
    Future<T> Function(Duration timeout) fallback,
  ) {
    Future<T> run() async {
      final clock = Stopwatch()..start();
      try {
        return await primary(_primaryShare);
      } catch (_) {
        final left = budget - clock.elapsed;
        return fallback(left < _minFallback ? _minFallback : left);
      }
    }

    return run().timeout(budget + _minFallback);
  }

  static Future<R> _parse<M, R>(R Function(M) fn, M message) =>
      parseInline ? Future.value(fn(message)) : compute<M, R>(fn, message);

  static Future<String> _fetchPage(Uri url, Duration timeout) async {
    final response = await http.get(url, headers: const {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    return response.body;
  }
}

// -----------------------------------------------------------------------------
// Parsers (top level so `compute` can run them)
// -----------------------------------------------------------------------------

/// A MAL page always has `#contentWrapper`; a challenge or maintenance page does not, and
/// must not read as "no friends".
Document _malDocument(String body) {
  final doc = html.parse(body);
  if (doc.querySelector('#contentWrapper') == null) {
    throw const FormatException('Not a MyAnimeList profile page');
  }
  return doc;
}

/// The friends of `/profile/<name>/friends` (100 per page).
ProfileFriendsPage parseFriendsPage(String body) {
  final doc = _malDocument(body);
  final page = parseFriendsEnvelope({'data': HtmlParsers.parseUserFriends(doc).toJson()});
  return ProfileFriendsPage(
    page.friends,
    hasNextPage: page.friends.length >= ProfileFriendsPage.pageSize,
  );
}

/// The rows of `/history/<name>/<type>`; [args] = (page body, `anime` or `manga`).
List<ProfileHistoryEntry> parseHistoryPage((String, String) args) {
  final doc = _malDocument(args.$1);
  return parseHistoryEnvelope(
    {'data': HtmlParsers.parseUserHistory(doc).toJson()},
    category: args.$2,
  );
}

/// The clubs of `/profile/<name>/clubs`.
List<ClubHtml> parseClubsPage(String body) {
  final doc = _malDocument(body);
  return clubsFromRows(HtmlParsers.parseUserClubs(doc)['clubs']);
}

/// `[{id, name}]` rows to clubs, without rows lacking an id and without duplicates.
List<ClubHtml> clubsFromRows(Object? rows) {
  if (rows is! List) return const [];
  final seen = <int>{};
  return [
    for (final row in rows)
      if (row is Map && row['id'] is int && seen.add(row['id'] as int))
        ClubHtml(id: row['id'] as int, name: row['name'] as String?),
  ];
}
