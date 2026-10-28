import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/SimKl/scrapper/simkl_page_parser.dart';
import 'package:mywatchlist/services/api/SimKl/scrapper/simkl_web_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';

/// Simkl has no title with this id (`GET /anime/{id}` answered `[]`).
class SimklTitleNotFound implements Exception {
  final int simklId;
  const SimklTitleNotFound(this.simklId);

  @override
  String toString() => 'SimklTitleNotFound($simklId)';
}

/// Runs [parse] on [input] off the UI isolate (`compute` by default; tests may run inline).
typedef SimklParseRunner = Future<R> Function<Q, R>(R Function(Q input) parse, Q input);

Future<R> _computeRunner<Q, R>(R Function(Q input) parse, Q input) => compute(parse, input);

/// Everything the native Simkl title page reads, read-only:
/// - the record (`GET /anime/{id}`) and the episodes (`GET /anime/episodes/{id}`) through
///   [SimklClient] (Cloudflare-cached by Simkl, not counted against the quota);
/// - the title page and its `reviews/`, `comments/`, `memos/` sub-pages from simkl.com through
///   [SimklWebClient] (desktop User-Agent, one request per second), parsed off the UI isolate.
///
/// Answers are kept in memory for [ttl] (the last [maxEntries] of each kind) and concurrent
/// asks for the same thing share one request.
class SimklDetailService {
  SimklDetailService({
    SimklClient? client,
    SimklWebClient? web,
    SimklParseRunner? runner,
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 30),
    this.maxEntries = 24,
  })  : _client = client ?? SimklClient.instance,
        _web = web ?? SimklWebClient.instance,
        _run = runner ?? _computeRunner,
        _now = now ?? DateTime.now;

  static SimklDetailService instance = SimklDetailService();

  final SimklClient _client;
  final SimklWebClient _web;
  final SimklParseRunner _run;
  final DateTime Function() _now;
  final Duration ttl;
  final int maxEntries;

  final LinkedHashMap<String, _Kept> _kept = LinkedHashMap();
  final Map<String, Future<Object?>> _inflight = {};

  /// The kept answer of [key] while fresh, without asking (null when absent or stale).
  T? peek<T>(String key) {
    final k = _kept[key];
    if (k == null || _now().difference(k.at) > ttl) return null;
    final v = k.value;
    return v is T ? v : null;
  }

  Future<T> _cached<T>(String key, Future<T> Function() load, {bool force = false}) {
    if (!force) {
      final k = _kept[key];
      if (k != null && _now().difference(k.at) <= ttl && k.value is T) {
        _kept.remove(key);
        _kept[key] = k; // most recent last
        return Future.value(k.value as T);
      }
      final running = _inflight[key];
      if (running != null) return running.then((v) => v as T);
    }
    final future = load().then((value) {
      _kept.remove(key);
      _kept[key] = _Kept(value, _now());
      while (_kept.length > maxEntries * 6) {
        _kept.remove(_kept.keys.first);
      }
      return value;
    });
    _inflight[key] = future;
    future.whenComplete(() {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    }).ignore();
    return future;
  }

  /// Drops everything kept for [simklId] (pull to refresh).
  void invalidate(int simklId) {
    _kept.removeWhere((k, _) => k.endsWith(':$simklId'));
  }

  static String titleKey(int id) => 'title:$id';
  static String episodesKey(int id) => 'episodes:$id';
  static String pageKey(int id) => 'page:$id';
  static String reviewsKey(int id) => 'reviews:$id';
  static String commentsKey(int id) => 'comments:$id';
  static String memosKey(int id) => 'memos:$id';

  /// `https://simkl.com/anime/{id}/{slug}` (no trailing slash: that form redirects).
  static String pageUrl(int id, String? slug) =>
      '$simklSite/anime/$id${slug == null || slug.isEmpty ? '' : '/$slug'}';

  static String subPageUrl(int id, String? slug, String sub) => '${pageUrl(id, slug)}/$sub/';

  /// The full record. Throws [SimklTitleNotFound] for an unknown id.
  Future<SimklTitle> title(int id, {bool force = false}) => _cached(titleKey(id), () async {
        final data = await _client.getPublic('/anime/$id');
        final title = SimklTitle.fromJson(data, fallbackId: id);
        if (title == null) throw SimklTitleNotFound(id);
        return title;
      }, force: force);

  /// The episodes and specials, in Simkl's order.
  Future<List<SimklEpisode>> episodes(int id, {bool force = false}) => _cached(episodesKey(id), () async {
        final data = await _client.getPublic('/anime/episodes/$id');
        return SimklEpisode.listFrom(data);
      }, force: force);

  /// Watchers, counters, first reviews, tags and links of the title page.
  Future<SimklTitlePage> page(int id, String? slug, {bool force = false}) => _cached(pageKey(id), () async {
        final html = await _web.page(pageUrl(id, slug));
        return _run(parseSimklTitlePage, html);
      }, force: force);

  /// Every review (null when the page no longer has the review markup).
  Future<SimklReviews?> reviews(int id, String? slug, {bool force = false}) =>
      _cached(reviewsKey(id), () async {
        final html = await _web.page(subPageUrl(id, slug, 'reviews'));
        return _run(parseSimklReviews, html);
      }, force: force);

  /// Comments with their replies (null when the markup is not recognised).
  Future<List<SimklComment>?> comments(int id, String? slug, {bool force = false}) =>
      _cached(commentsKey(id), () async {
        final html = await _web.page(subPageUrl(id, slug, 'comments'));
        return _run(parseSimklComments, html);
      }, force: force);

  /// Members' memos (null when the markup is not recognised).
  Future<List<SimklMemo>?> memos(int id, String? slug, {bool force = false}) => _cached(memosKey(id), () async {
        final html = await _web.page(subPageUrl(id, slug, 'memos'));
        return _run(parseSimklMemos, html);
      }, force: force);
}

class _Kept {
  final Object? value;
  final DateTime at;
  const _Kept(this.value, this.at);
}
