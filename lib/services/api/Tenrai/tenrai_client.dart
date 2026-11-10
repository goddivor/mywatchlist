import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP gateway of every Tenrai call (`https://api.tenrai.org/v1`).
///
/// Tenrai's public tier (no key; the app never ships one) allows 4 requests per
/// second and 120 per minute, and answers `429` with `Retry-After` beyond that.
/// This client:
/// - spaces the requests by [minInterval] and never sends more than
///   [maxPerMinute] in any 60 s window (one shared queue);
/// - shares one network call between identical requests in flight;
/// - keeps successful answers for [cacheTtl];
/// - on a `429`, pauses the whole queue for `Retry-After` (else an exponential
///   backoff, capped by [maxBackoff]) and retries up to [maxRetries] times;
/// - gives up after [requestTimeout] with [TenraiUnavailable]; then requests
///   fail at once for [unreachableCooldown] ([resetReachability] ends it).
class TenraiClient {
  TenraiClient({
    http.Client? client,
    this.minInterval = const Duration(milliseconds: 250),
    this.maxPerMinute = 120,
    this.cacheTtl = const Duration(minutes: 5),
    this.maxCacheEntries = 150,
    this.maxRetries = 2,
    this.baseBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 10),
    this.requestTimeout = const Duration(seconds: 12),
    this.unreachableCooldown = const Duration(seconds: 30),
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  })  : _client = client,
        _now = now ?? DateTime.now,
        _delay = delay ?? Future<void>.delayed;

  /// Base URL of the API (no trailing slash).
  static const String baseUrl = 'https://api.tenrai.org/v1';

  /// The client used by the app (tests replace it).
  static TenraiClient instance = TenraiClient();

  final http.Client? _client;
  final Duration minInterval;
  final int maxPerMinute;
  final Duration cacheTtl;
  final int maxCacheEntries;
  final int maxRetries;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final Duration requestTimeout;
  final Duration unreachableCooldown;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _unreachableUntil;
  final Queue<DateTime> _window = Queue();
  final Map<String, Future<http.Response>> _inFlight = {};
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  /// Tenrai URL of [path] (`/anime/1`) with [query].
  static Uri uri(String path, [Map<String, String> query = const {}]) {
    final url = Uri.parse('$baseUrl$path');
    return query.isEmpty ? url : url.replace(queryParameters: query);
  }

  /// GET [path] and decode it; throws [TenraiHttpError] on any status but 200,
  /// [TenraiUnavailable] when Tenrai cannot be reached.
  Future<Map<String, dynamic>> getJson(String path,
      [Map<String, String> query = const {}]) async {
    final url = uri(path, query);
    final response = await get(url);
    if (response.statusCode != 200) {
      throw TenraiHttpError(url, response.statusCode, response.body);
    }
    final body = response.body.length < 32 * 1024
        ? jsonDecode(response.body)
        : await compute(jsonDecode, response.body);
    if (body is! Map) throw FormatException('Tenrai answer is not an object: $url');
    return Map<String, dynamic>.from(body);
  }

  /// GET [url] (a Tenrai URL). [useCache] false skips the cache and the
  /// in-flight sharing (the answer is still stored).
  Future<http.Response> get(Uri url, {bool useCache = true}) {
    final key = url.toString();
    if (useCache) {
      final cached = _cache[key];
      if (cached != null) {
        if (_now().isBefore(cached.expires)) return Future.value(cached.response);
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

  void clearCache() => _cache.clear();

  /// True while requests fail fast after Tenrai did not answer.
  bool get isUnreachable {
    final until = _unreachableUntil;
    return until != null && _now().isBefore(until);
  }

  void resetReachability() => _unreachableUntil = null;

  Future<http.Response> _fetch(Uri url, String key) async {
    var attempt = 0;
    while (true) {
      if (isUnreachable) throw TenraiUnavailable(url, 'unreachable, skipped');
      await _waitForSlot();
      if (isUnreachable) throw TenraiUnavailable(url, 'unreachable, skipped');
      final http.Response response;
      try {
        final client = _client;
        final request = client != null ? client.get(url) : http.get(url);
        response = await request.timeout(requestTimeout);
      } on TimeoutException {
        _unreachableUntil = _now().add(unreachableCooldown);
        throw TenraiUnavailable(url, 'no answer after ${requestTimeout.inSeconds} s');
      } on http.ClientException catch (e) {
        _unreachableUntil = _now().add(unreachableCooldown);
        throw TenraiUnavailable(url, e.message);
      }
      _unreachableUntil = null;
      if (response.statusCode == 429 && attempt < maxRetries) {
        final wait = retryDelay(response, attempt);
        debugPrint('Tenrai 429 for $url, retrying in ${wait.inMilliseconds} ms');
        _pauseQueue(wait);
        attempt++;
        continue;
      }
      if (response.statusCode == 200) _store(key, response);
      return response;
    }
  }

  /// Wait before retry number [attempt] (0 based): `Retry-After` seconds when
  /// present, else an exponential backoff; never above [maxBackoff].
  Duration retryDelay(http.Response response, int attempt) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    final wait = seconds != null ? Duration(seconds: seconds) : baseBackoff * (1 << attempt);
    return wait > maxBackoff ? maxBackoff : wait;
  }

  Future<void> _waitForSlot() {
    final now = _now();
    var slot = _nextSlot.isAfter(now) ? _nextSlot : now;
    const minute = Duration(minutes: 1);
    while (_window.isNotEmpty && !_window.first.add(minute).isAfter(slot)) {
      _window.removeFirst();
    }
    if (_window.length >= maxPerMinute) {
      final free = _window.elementAt(_window.length - maxPerMinute).add(minute);
      if (free.isAfter(slot)) slot = free;
    }
    _window.addLast(slot);
    _nextSlot = slot.add(minInterval);
    final wait = slot.difference(now);
    return wait > Duration.zero ? _delay(wait) : Future<void>.value();
  }

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

/// Tenrai did not answer in time, the network failed, or a recent failure made
/// the client skip the request.
class TenraiUnavailable implements Exception {
  final Uri url;
  final String reason;
  const TenraiUnavailable(this.url, this.reason);

  @override
  String toString() => 'TenraiUnavailable($url): $reason';
}

/// Tenrai answered with a status other than 200.
class TenraiHttpError implements Exception {
  final Uri url;
  final int statusCode;
  final String body;
  const TenraiHttpError(this.url, this.statusCode, this.body);

  @override
  String toString() => 'TenraiHttpError($url): HTTP $statusCode';
}

class _CacheEntry {
  final http.Response response;
  final DateTime expires;
  _CacheEntry(this.response, this.expires);
}
