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
/// With a [source] (the app's [instance] has [JikanSource.instance]), Jikan
/// fails over to Tenrai: a timeout, a network error or a 5xx marks Jikan down
/// ([JikanSource.markJikanDown], re-probed after a few minutes) and the same
/// request is answered by Tenrai when Tenrai has the endpoint; a request Jikan
/// has not answered after [JikanSource.hedgeAfter] is also sent to Tenrai and
/// the first answer wins. Only when both fail does the client pause
/// ([isUnreachable]). Endpoints Tenrai lacks fail at once while Jikan is down.
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
  /// sources are asked again.
  void resetReachability() {
    _unreachableUntil = null;
    _retryGeneration++;
    final source = _source;
    if (source != null) {
      source.allowProbe();
      source.tenrai.resetReachability();
    }
  }

  int _retryGeneration = 0;

  /// Number of [resetReachability] calls (a Retry button was pressed).
  int get retryGeneration => _retryGeneration;

  void _throwIfUnreachable(Uri url) {
    if (isUnreachable) throw JikanUnavailable(url, 'unreachable, skipped');
  }

  void _markUnreachable() =>
      _unreachableUntil = _now().add(unreachableCooldown);

  Future<http.Response> _fetch(Uri url, String key) {
    final source = _source;
    if (source == null || !source.isJikan(url)) return _fetchJikan(url, key, null);
    _throwIfUnreachable(url);
    final served = source.tenraiServes(url);
    if (source.jikanDown) {
      if (!served) {
        return Future.error(JikanUnavailable(url, 'Jikan is down and Tenrai has no such endpoint'));
      }
      return _fromTenrai(url, key, source).catchError((Object e) {
        _markUnreachable();
        throw JikanUnavailable(url, 'Jikan is down; Tenrai: $e');
      });
    }
    if (!served) return _fetchJikan(url, key, source);
    return _hedged(url, key, source);
  }

  /// Jikan first, Tenrai after [JikanSource.hedgeAfter] (at once while Jikan
  /// is re-probed) or as soon as Jikan fails; the first usable answer wins.
  Future<http.Response> _hedged(Uri url, String key, JikanSource source) {
    final completer = Completer<http.Response>();
    Object? jikanError;
    Object? tenraiError;
    http.Response? jikanServerError;
    var jikanFailed = false;
    var tenraiStarted = false;
    var tenraiFailed = false;
    Timer? hedge;

    void failIfBoth() {
      if (!jikanFailed || !tenraiFailed || completer.isCompleted) return;
      final response = jikanServerError;
      if (response != null) {
        completer.complete(response);
        return;
      }
      _markUnreachable();
      completer.completeError(JikanUnavailable(url, 'Jikan: $jikanError; Tenrai: $tenraiError'));
    }

    void startTenrai() {
      if (tenraiStarted || completer.isCompleted) return;
      tenraiStarted = true;
      hedge?.cancel();
      _fromTenrai(url, key, source).then((response) {
        if (!completer.isCompleted) completer.complete(response);
      }, onError: (Object e) {
        tenraiFailed = true;
        tenraiError = e;
        failIfBoth();
      });
    }

    if (source.jikanSuspect) {
      startTenrai();
    } else {
      hedge = Timer(source.hedgeAfter, startTenrai);
    }
    _fetchJikan(url, key, source).then((response) {
      if (response.statusCode >= 500) {
        jikanFailed = true;
        jikanServerError = response;
        startTenrai();
        failIfBoth();
        return;
      }
      hedge?.cancel();
      if (!completer.isCompleted) completer.complete(response);
    }, onError: (Object e) {
      jikanFailed = true;
      jikanError = e;
      startTenrai();
      failIfBoth();
    });
    return completer.future;
  }

  /// The Tenrai answer to the Jikan URL [url]; a 5xx counts as a failure.
  Future<http.Response> _fromTenrai(Uri url, String key, JikanSource source) async {
    final response = await source.tenrai.get(source.toTenrai(url));
    if (response.statusCode >= 500) {
      throw TenraiUnavailable(source.toTenrai(url), 'HTTP ${response.statusCode}');
    }
    _unreachableUntil = null;
    if (response.statusCode == 200) _store(key, response);
    return response;
  }

  /// One Jikan request (with the 429 retries). Without a [source] a failure
  /// pauses every request ([unreachableCooldown]); with one it marks Jikan
  /// down in the [source] instead.
  Future<http.Response> _fetchJikan(Uri url, String key, JikanSource? source) async {
    var attempt = 0;
    while (true) {
      if (source == null) _throwIfUnreachable(url);
      await _waitForSlot();
      if (source == null) _throwIfUnreachable(url);
      final http.Response response;
      final client = _client;
      final timeout = source != null && source.jikanSuspect && source.probeTimeout < requestTimeout
          ? source.probeTimeout
          : requestTimeout;
      try {
        final request = client != null ? client.get(url) : http.get(url);
        response = await request.timeout(timeout);
      } on TimeoutException {
        source == null ? _markUnreachable() : source.markJikanDown();
        throw JikanUnavailable(url, 'no answer after ${timeout.inSeconds} s');
      } on http.ClientException catch (e) {
        source == null ? _markUnreachable() : source.markJikanDown();
        throw JikanUnavailable(url, e.message);
      }
      _unreachableUntil = null;
      if (source == null) {
        // Jikan only: nothing else to update.
      } else if (response.statusCode >= 500) {
        source.markJikanDown();
      } else {
        source.markJikanUp();
      }
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
