import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';

/// HTTP gateway of every Jikan call.
///
/// Jikan allows about 3 requests per second and 60 per minute, and answers
/// `429` beyond that. Rapid navigation fires many calls at once, so this
/// client:
/// - spaces the requests by [minInterval] (one shared queue);
/// - shares one network call between identical requests in flight;
/// - keeps successful answers for [cacheTtl] (revisiting a page costs nothing);
/// - on a `429`, waits (`Retry-After`, else an exponential backoff), pauses the
///   whole queue for that time and retries up to [maxRetries] times. When Jikan
///   keeps refusing, the last `429` response is returned for the caller to
///   report;
/// - gives up on a request after [requestTimeout] (Jikan is unreachable from
///   some networks and the socket can hang for minutes), throwing
///   [JikanUnavailable]; after such a failure every request fails at once for
///   [unreachableCooldown], so a detail page does not wait once per section.
///   [resetReachability] (a Retry button) ends that pause early.
///
/// With a [source] (the app's [instance] has [JikanSource.instance]), each
/// Jikan URL goes to ONE server, [JikanSource.active], never to both at once.
/// Requests first wait for the launch choice ([JikanSource.ready]). When the
/// active server fails at the network level (timeout, network error; for
/// Tenrai a 5xx too) the source switches ([JikanSource.jikanFailed] mutes
/// Jikan, [JikanSource.tenraiFailed] goes back to Jikan only when it is not
/// muted) and the same request is sent once to the new source, after the
/// failure. A Jikan 5xx is returned to the caller unchanged. Endpoints Tenrai
/// lacks fail at once ([JikanUnavailable]) while Tenrai is the source; the
/// client pauses ([isUnreachable]) only when no source could answer.
class JikanClient {
  JikanClient({
    http.Client? client,
    this.minInterval = const Duration(milliseconds: 350),
    this.cacheTtl = const Duration(minutes: 5),
    this.maxCacheEntries = 150,
    this.maxRetries = 3,
    this.baseBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 8),
    this.requestTimeout = const Duration(seconds: 12),
    this.unreachableCooldown = const Duration(seconds: 30),
    JikanSource? source,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  })  : _client = client,
        _source = source,
        _now = now ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed;

  /// The client used by the app (tests may replace it with one built on a
  /// fake `http.Client`).
  static JikanClient instance = JikanClient(source: JikanSource.instance);

  final http.Client? _client;
  final JikanSource? _source;

  /// The Jikan / Tenrai selector of this client (null: Jikan only).
  JikanSource? get source => _source;
  final Duration minInterval;
  final Duration cacheTtl;
  final int maxCacheEntries;
  final int maxRetries;
  final Duration baseBackoff;
  final Duration maxBackoff;

  /// Longest wait for one answer.
  final Duration requestTimeout;

  /// How long requests fail fast after a timeout or a network error.
  final Duration unreachableCooldown;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _unreachableUntil;
  final Map<String, Future<http.Response>> _inFlight = {};
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  /// GET [url]. [useCache] false skips both the cache and the in-flight
  /// sharing (the answer is still stored).
  Future<http.Response> get(Uri url, {bool useCache = true}) {
    final key = url.toString();
    if (useCache) {
      final cached = _cache[key];
      if (cached != null) {
        if (_now().isBefore(cached.expires)) {
          return Future.value(cached.response);
        }
        _cache.remove(key);
      }
      final pending = _inFlight[key];
      if (pending != null) return pending;
    }
    final future = _fetch(url, key);
    if (useCache) {
      _inFlight[key] = future;
      future.then<void>((_) {}, onError: (_) {}).whenComplete(() {
        if (identical(_inFlight[key], future)) _inFlight.remove(key);
      });
    }
    return future;
  }

  /// Forget every stored answer.
  void clearCache() => _cache.clear();

  /// True while requests fail fast after Jikan did not answer (with a
  /// [source]: after Jikan and Tenrai both failed).
  bool get isUnreachable {
    final until = _unreachableUntil;
    return until != null && _now().isBefore(until);
  }

  /// Let the next request reach the network again (used by Retry buttons).
  /// Also bumps [retryGeneration], so answers remembered by the fallback
  /// sources are asked again. A muted Jikan stays muted (only Settings > Data
  /// sources > Test again ends a mute).
  void resetReachability() {
    _unreachableUntil = null;
    _retryGeneration++;
    _source?.tenrai.resetReachability();
  }

  int _retryGeneration = 0;

  /// Number of [resetReachability] calls (a Retry button was pressed).
  int get retryGeneration => _retryGeneration;

  void _throwIfUnreachable(Uri url) {
    if (isUnreachable) throw JikanUnavailable(url, 'unreachable, skipped');
  }

  void _markUnreachable() =>
      _unreachableUntil = _now().add(unreachableCooldown);

  Future<http.Response> _fetch(Uri url, String key) async {
    final source = _source;
    if (source == null || !source.isJikan(url)) return _fetchJikan(url, key, null);
    _throwIfUnreachable(url);
    await source.ready;
    return source.active == DataSource.jikan
        ? _viaJikan(url, key, source)
        : _viaTenrai(url, key, source, jikanTried: false);
  }

  /// Jikan is the source: ask it; after a network failure Tenrai becomes the
  /// source and gets the request once.
  Future<http.Response> _viaJikan(Uri url, String key, JikanSource source) async {
    try {
      return await _fetchJikan(url, key, source);
    } on JikanUnavailable catch (e) {
      source.jikanFailed();
      if (!source.tenraiServes(url)) {
        throw JikanUnavailable(url, 'Jikan: ${e.reason}; Tenrai has no such endpoint');
      }
      return _viaTenrai(url, key, source, jikanTried: true);
    }
  }

  /// Tenrai is the source: an endpoint it lacks fails at once; after a
  /// network failure Jikan gets the request once, unless it is muted or was
  /// just asked.
  Future<http.Response> _viaTenrai(Uri url, String key, JikanSource source,
      {required bool jikanTried}) async {
    if (!source.tenraiServes(url)) {
      throw JikanUnavailable(url, 'Jikan is muted and Tenrai has no such endpoint');
    }
    try {
      return await _fromTenrai(url, key, source);
    } catch (e) {
      if (!jikanTried && source.tenraiFailed()) {
        try {
          return await _fetchJikan(url, key, source);
        } on JikanUnavailable catch (jikanError) {
          source.jikanFailed();
          _markUnreachable();
          throw JikanUnavailable(url, 'Tenrai: $e; Jikan: ${jikanError.reason}');
        }
      }
      _markUnreachable();
      throw JikanUnavailable(url, 'Tenrai: $e');
    }
  }

  /// The Tenrai answer to the Jikan URL [url]; a 5xx counts as a failure.
  Future<http.Response> _fromTenrai(Uri url, String key, JikanSource source) async {
    final tenraiUrl = source.toTenrai(url);
    final response = await source.tenrai.get(tenraiUrl);
    if (response.statusCode >= 500) {
      throw TenraiUnavailable(tenraiUrl, 'HTTP ${response.statusCode}');
    }
    _unreachableUntil = null;
    if (response.statusCode == 200) _store(key, response);
    return response;
  }

  /// One Jikan request (with the 429 retries). Without a [source] a failure
  /// pauses every request ([unreachableCooldown]); with one the caller
  /// switches the source instead.
  Future<http.Response> _fetchJikan(Uri url, String key, JikanSource? source) async {
    var attempt = 0;
    while (true) {
      if (source == null) _throwIfUnreachable(url);
      await _waitForSlot();
      if (source == null) _throwIfUnreachable(url);
      final http.Response response;
      final client = _client;
      try {
        final request = client != null ? client.get(url) : http.get(url);
        response = await request.timeout(requestTimeout);
      } on TimeoutException {
        if (source == null) _markUnreachable();
        throw JikanUnavailable(url, 'no answer after ${requestTimeout.inSeconds} s');
      } on http.ClientException catch (e) {
        if (source == null) _markUnreachable();
        throw JikanUnavailable(url, e.message);
      } on Exception catch (e) {
        // TLS handshake and other socket failures not wrapped by package:http.
        if (source == null) _markUnreachable();
        throw JikanUnavailable(url, '$e');
      }
      _unreachableUntil = null;
      if (response.statusCode == 429 && attempt < maxRetries) {
        final wait = retryDelay(response, attempt);
        debugPrint('Jikan 429 for $url, retrying in ${wait.inMilliseconds} ms');
        _pauseQueue(wait);
        attempt++;
        continue;
      }
      if (response.statusCode == 200) _store(key, response);
      return response;
    }
  }

  /// Waiting time before the retry number [attempt] (0 based): the
  /// `Retry-After` header in seconds when present, else an exponential
  /// backoff, never above [maxBackoff].
  Duration retryDelay(http.Response response, int attempt) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    final wait = seconds != null
        ? Duration(seconds: seconds)
        : baseBackoff * (1 << attempt);
    return wait > maxBackoff ? maxBackoff : wait;
  }

  Future<void> _waitForSlot() {
    final now = _now();
    final slot = _nextSlot.isAfter(now) ? _nextSlot : now;
    _nextSlot = slot.add(minInterval);
    final wait = slot.difference(now);
    return wait > Duration.zero ? _delay(wait) : Future<void>.value();
  }

  /// No request leaves before [wait] has elapsed.
  void _pauseQueue(Duration wait) {
    final until = _now().add(wait);
    if (until.isAfter(_nextSlot)) _nextSlot = until;
  }

  void _store(String key, http.Response response) {
    _cache.remove(key);
    _cache[key] = _CacheEntry(response, _now().add(cacheTtl));
    while (_cache.length > maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

/// Jikan did not answer in time, the network failed, or a recent failure
/// made the client skip the request.
class JikanUnavailable implements Exception {
  final Uri url;
  final String reason;
  const JikanUnavailable(this.url, this.reason);

  @override
  String toString() => 'JikanUnavailable($url): $reason';
}

class _CacheEntry {
  final http.Response response;
  final DateTime expires;
  _CacheEntry(this.response, this.expires);
}
