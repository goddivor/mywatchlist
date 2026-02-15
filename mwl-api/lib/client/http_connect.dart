import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static const _retryDuration = Duration(seconds: 10);

  /// GET with automatic retry on transient failures.
  static Future<http.Response> retryGet(
    String url,
    Map<String, String> headers,
  ) async {
    logMwl('hitting -> $url');
    final response = await _options.retry(
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
  static Future<T?> htmlPage<T>(
    String url,
    dynamic Function(Document) fromHtml, {
    Map<String, String>? headers,
  }) async {
    final response = await retryGet(url, headers ?? {});
    if (response.statusCode != 200) {
      logMwl('HTML error ${response.statusCode} for $url');
      return null;
    }
    final parsed = fromHtml(parser.parse(response.body));
    if (parsed is Map) {
      return parsed as T;
    } else if (parsed is List) {
      return parsed as T;
    }
    return _toJson(parsed) as T?;
  }

  static Map<String, dynamic>? _toJson(dynamic data) {
    try {
      return data?.toJson();
    } catch (e) {
      if (e is NoSuchMethodError) {
        return data;
      }
      return null;
    }
  }
}
