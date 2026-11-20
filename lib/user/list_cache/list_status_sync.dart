import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fills [ListStatusCache] with the whole MyAnimeList lists (anime and manga) of the signed-in
/// user, in the background: the status, the score and the progress of every entry, so any
/// card or row of the app can show "it is in my list" without the list pages having been
/// opened. Runs at most every [every]; edits keep the cache current in between.
class ListStatusSync {
  ListStatusSync({
    ListStatusCache? cache,
    Future<String?> Function(String url)? get,
    bool Function()? signedIn,
    String? Function()? owner,
    DateTime Function()? clock,
    this.every = const Duration(hours: 12),
  })  : _cache = cache,
        _get = get ?? _signedGet,
        _signedIn = signedIn ?? (() => UserManager.instance.isAuthenticated(AccountType.myanimelist)),
        _owner = owner ?? (() => UserMalV2.instance.username),
        _clock = clock ?? DateTime.now;

  static ListStatusSync instance = ListStatusSync();

  static const String lastSyncKey = 'list_status_sync_last_v1';

  /// The account the last full read was for: another account is always read at once.
  static const String lastOwnerKey = 'list_status_sync_owner_v1';

  /// Entries asked per page (MAL's maximum).
  static const int pageSize = 1000;

  final ListStatusCache? _cache;
  final Future<String?> Function(String url) _get;
  final bool Function() _signedIn;
  final String? Function() _owner;
  final DateTime Function() _clock;
  final Duration every;

  Future<void>? _running;

  ListStatusCache get _target => _cache ?? ListStatusCache.instance;

  static Future<String?> _signedGet(String url) async {
    final http.Response response = await MalApi.signedGet(url);
    return response.statusCode == 200 ? response.body : null;
  }

  /// Reads both lists when the last full read is older than [every] (or [force]). Concurrent
  /// calls share one run. Never throws; a failed kind keeps what the cache had.
  Future<void> syncIfDue({bool force = false}) => _running ??= _run(force).whenComplete(() {
        _running = null;
      });

  Future<void> _run(bool force) async {
    try {
      if (!_signedIn()) return;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(lastSyncKey);
      final owner = _owner();
      final sameOwner = prefs.getString(lastOwnerKey) == owner;
      final now = _clock();
      if (!force &&
          sameOwner &&
          last != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < every) {
        return;
      }
      await _target.ensureLoaded();
      _target.bindOwner(AccountType.myanimelist, owner);
      var complete = true;
      for (final category in const ['anime', 'manga']) {
        final values = await _readList(category);
        if (values == null) {
          complete = false;
          continue;
        }
        // The whole list: entries gone from it (removed on another device) are dropped.
        _target.replaceStatuses(values,
            statuses: null, category: category, tracker: AccountType.myanimelist);
      }
      if (complete) {
        await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
        if (owner != null) await prefs.setString(lastOwnerKey, owner);
      }
    } catch (e) {
      debugPrint('List status sync: $e');
    }
  }

  /// Every entry of the signed-in user's [category] list, or null when a page failed.
  Future<Map<int, CachedListStatus>?> _readList(String category) async {
    final progressField = category == 'manga' ? 'num_chapters_read' : 'num_episodes_watched';
    String? url = '${MalApi.userBaseEndPoint}/@me/${category}list'
        '?fields=list_status{status,score,$progressField}&limit=$pageSize&nsfw=1';
    final values = <int, CachedListStatus>{};
    while (url != null) {
      final body = await _get(url);
      if (body == null) return null;
      final page = parseListStatusPage(body, category);
      values.addAll(page.values);
      url = page.next;
    }
    return values;
  }
}

/// One page of `/users/@me/<category>list`: id to status, score and progress, and the next
/// page's URL.
@visibleForTesting
({Map<int, CachedListStatus> values, String? next}) parseListStatusPage(
    String body, String category) {
  final json = jsonDecode(body);
  final values = <int, CachedListStatus>{};
  if (json is! Map) return (values: values, next: null);
  final rows = json['data'];
  if (rows is List) {
    for (final row in rows) {
      if (row is! Map) continue;
      final node = row['node'];
      final status = row['list_status'];
      final id = node is Map ? node['id'] : null;
      if (id is! int || status is! Map) continue;
      final word = status['status'];
      if (word is! String || word.isEmpty) continue;
      final progress =
          status[category == 'manga' ? 'num_chapters_read' : 'num_episodes_watched'];
      final score = status['score'];
      values[id] = CachedListStatus(
        status: word,
        score: score is int ? score : 0,
        progress: progress is int && progress > 0 ? progress : 0,
      );
    }
  }
  final paging = json['paging'];
  final next = paging is Map ? paging['next'] : null;
  return (values: values, next: next is String && next.isNotEmpty ? next : null);
}
