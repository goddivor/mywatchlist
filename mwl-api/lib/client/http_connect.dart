import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:mwl_commons/mwl_commons.dart';
import 'package:retry/retry.dart';

/// HTTP client with retry logic for the backend.
///
/// Pure Dart — no Flutter dependency.
class HttpConnect {
  static const _options = RetryOptions(maxAttempts: 8);

  /// Two quick attempts: the search routes must fail fast, the app bounds
  /// the whole call anyway.
  static const quickRetry = RetryOptions(maxAttempts: 2, delayFactor: Duration(milliseconds: 400));
  static const _retryDuration = Duration(seconds: 10);

  /// GET with automatic retry on transient failures.
  static Future<http.Response> retryGet(
    String url,
    Map<String, String> headers, {
    RetryOptions options = _options,
  }) async {
    logMwl('hitting -> $url');
    final response = await options.retry(
      () => http.get(Uri.parse(url), headers: headers).timeout(_retryDuration),
      retryIf: (e) {
        logMwl('retrying... on $e');
        return e is SocketException || e is TimeoutException;
      },
    );
    return response;
  }

  /// GET with status check and JSON parsing.
  static Future<Map<String, dynamic>?> retryGetChecked(
    String url,
    Map<String, String> headers,
  ) async {
    final response = await retryGet(url, headers);
    if (response.statusCode != 200) {
      logMwl('Error ${response.statusCode}: ${response.body.substring(0, 200)}');
      return null;
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// When Jikan failed, it is skipped until then (circuit breaker).
  static DateTime? _jikanDownUntil;

  /// How long Jikan stays skipped after a failure before it is tried again.
  static Duration jikanReprobe = const Duration(minutes: 5);

  /// Longest wait for one Jikan answer before Tenrai is asked.
  static Duration jikanTimeout = const Duration(seconds: 8);

  static DateTime _nextTenraiSlot = DateTime.fromMillisecondsSinceEpoch(0);

  /// True while Jikan is skipped after a failure.
  static bool get jikanDown {
    final until = _jikanDownUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static void _markJikanDown() {
    logMwl('Jikan marked down for ${jikanReprobe.inMinutes} min');
    _jikanDownUntil = DateTime.now().add(jikanReprobe);
  }

  /// Jikan v4 [path] (`characters/1/full`, no leading slash), decoded; null on
  /// a non-200 answer. Jikan is asked first; on a timeout, a network error or
  /// a 5xx it is marked down for [jikanReprobe] and, when [tenrai] is true
  /// (Tenrai has the endpoint), the same path is asked from Tenrai, which
  /// follows Jikan's schema. Endpoints Tenrai lacks (`users/*`, `clubs/*`)
  /// pass `tenrai: false`: they keep Jikan with its retries, and return null at
  /// once while Jikan is down.
  static Future<Map<String, dynamic>?> jikanGetChecked(String path, {bool tenrai = true}) async {
    final jikanUrl = '${Constants.jikanV4}$path';
    if (!tenrai) {
      if (jikanDown) return null;
      try {
        return await retryGetChecked(jikanUrl, {});
      } on Exception {
        _markJikanDown();
        rethrow;
      }
    }
    if (!jikanDown) {
      try {
        logMwl('hitting -> $jikanUrl');
        final response = await http.get(Uri.parse(jikanUrl)).timeout(jikanTimeout);
        if (response.statusCode < 500) {
          _jikanDownUntil = null;
          if (response.statusCode == 200) {
            return jsonDecode(response.body) as Map<String, dynamic>;
          }
          logMwl('Jikan error ${response.statusCode} for $jikanUrl');
          return null;
        }
        _markJikanDown();
      } on TimeoutException {
        _markJikanDown();
      } on SocketException {
        _markJikanDown();
      } on http.ClientException {
        _markJikanDown();
      }
    }
    return tenraiGetChecked(path);
  }

  /// Tenrai [path] (no leading slash), decoded; null on a non-200 answer.
  /// Requests are spaced by 250 ms (Tenrai allows 4 per second) and a 429 is
  /// retried once after its `Retry-After` (at most 5 s).
  static Future<Map<String, dynamic>?> tenraiGetChecked(String path) async {
    final url = '${Constants.tenraiV1}$path';
    for (var attempt = 0;; attempt++) {
      final now = DateTime.now();
      final slot = _nextTenraiSlot.isAfter(now) ? _nextTenraiSlot : now;
      _nextTenraiSlot = slot.add(const Duration(milliseconds: 250));
      if (slot.isAfter(now)) await Future<void>.delayed(slot.difference(now));
      final response = await retryGet(url, {}, options: quickRetry);
      if (response.statusCode == 429 && attempt == 0) {
        final seconds = int.tryParse(response.headers['retry-after'] ?? '') ?? 1;
        await Future<void>.delayed(Duration(seconds: seconds.clamp(1, 5)));
        continue;
      }
      if (response.statusCode != 200) {
        logMwl('Tenrai error ${response.statusCode} for $url');
        return null;
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
  }

  /// Fetch an HTML page and parse it with a custom parser function.
  ///
  /// Parsing (DOM build + [fromHtml] + `toJson`) runs on a short-lived
  /// background isolate so the in-process backend never parses a large MAL
  /// page on the Flutter UI isolate. Where isolates are unavailable (web) or
  /// the parser cannot be sent, it falls back to parsing inline.
  ///
  /// [okStatuses] are the statuses whose body is parsed (MAL's search pages
  /// answer "no titles matched" with a 404 page); [options] bounds the
  /// retries (default: 8 attempts).
  static Future<T?> htmlPage<T>(
    String url,
    dynamic Function(Document) fromHtml, {
    Map<String, String>? headers,
    Set<int> okStatuses = const {200},
    RetryOptions options = _options,
  }) async {
    final response = await retryGet(url, headers ?? {}, options: options);
    if (!okStatuses.contains(response.statusCode)) {
      logMwl('HTML error ${response.statusCode} for $url');
      return null;
    }
    final body = response.body;
    dynamic parsed;
    try {
      parsed = await Isolate.run(() => parseHtml(body, fromHtml));
    } catch (_) {
      // No isolate support, an unsendable parser, or a parser error: parse
      // inline (a genuine parser error then surfaces with its own stack).
      parsed = parseHtml(body, fromHtml);
    }
    return parsed as T?;
  }

  /// Parse [body] with [fromHtml] and turn the result into JSON-ready data
  /// (maps, lists and primitives), so it can cross isolates and be cached.
  static dynamic parseHtml(String body, dynamic Function(Document) fromHtml) {
    return toJsonReady(fromHtml(parser.parse(body)));
  }

  /// Recursively convert models (anything with `toJson`) to plain JSON data.
  static dynamic toJsonReady(dynamic value) {
    if (value == null || value is num || value is String || value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry('$k', toJsonReady(v)));
    }
    if (value is Iterable) return value.map(toJsonReady).toList();
    try {
      return toJsonReady((value as dynamic).toJson());
    } on NoSuchMethodError {
      return value.toString();
    }
  }
}
