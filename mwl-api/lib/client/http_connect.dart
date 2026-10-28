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
