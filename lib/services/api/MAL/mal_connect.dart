import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mwl_api/handlers/handler_core.dart';

/// Network utility class for MAL API calls.
/// Provides retry logic, connectivity checks, and maintenance detection.
/// Supports in-process backend calls for local server URLs.
class MalConnect {
  static const int _maxAttempts = 8;
  static const Duration _retryTimeout = Duration(seconds: 10);

  static HandlerCore? _handlerCore;

  /// Whether the URL targets the local in-process backend.
  static bool _isLocalBackend(String url) {
    return url.startsWith('http://0.0.0.0:8080') ||
        url.startsWith('http://localhost:8080') ||
        url.startsWith('http://127.0.0.1:8080');
  }

  /// Get or create the shared HandlerCore instance.
  static HandlerCore get _handler {
    _handlerCore ??= HandlerCore();
    return _handlerCore!;
  }

  /// Perform an HTTP GET with automatic retry on transient failures.
  /// Retries up to [_maxAttempts] times on SocketException or TimeoutException.
  /// For local backend URLs, routes requests in-process via HandlerCore.
  static Future<http.Response> retryGet(
    String url,
    Map<String, String> headers,
  ) async {
    final isLocal = _isLocalBackend(url);
    Object? lastError;

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        if (isLocal) {
          final value = await _handler
              .handleRequestAsString(Uri.parse(url))
              .timeout(_retryTimeout);
          return http.Response.bytes(
            utf8.encode(value ?? ''),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final response = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(_retryTimeout);
        return response;
      } on SocketException catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('MalConnect: retry $attempt/$_maxAttempts (SocketException)');
        }
      } on TimeoutException catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('MalConnect: retry $attempt/$_maxAttempts (Timeout)');
        }
      }
      // Brief delay before next attempt (exponential-ish: 500ms, 1s, 2s, ...)
      if (attempt < _maxAttempts) {
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    throw lastError ?? Exception('Failed after $_maxAttempts attempts');
  }

  /// Perform an HTTP PUT with automatic retry on transient failures.
  static Future<http.Response> retryPut(
    String url,
    Map<String, String> headers, {
    Object? body,
  }) async {
    Object? lastError;

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await http
            .put(Uri.parse(url), headers: headers, body: body)
            .timeout(_retryTimeout);
        return response;
      } on SocketException catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('MalConnect: PUT retry $attempt/$_maxAttempts (SocketException)');
        }
      } on TimeoutException catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('MalConnect: PUT retry $attempt/$_maxAttempts (Timeout)');
        }
      }
      if (attempt < _maxAttempts) {
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    throw lastError ?? Exception('PUT failed after $_maxAttempts attempts');
  }

  /// Check if the device has network connectivity.
  static Future<bool> hasConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Check if the device can actually reach the internet.
  /// Performs a lightweight HEAD request to MAL's CDN.
  static Future<bool> hasInternetAccess() async {
    if (!await hasConnection()) return false;
    try {
      final response = await http
          .head(Uri.parse('https://myanimelist.net'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// Check if MAL API is under maintenance.
  /// Returns true if the API returns 503 or is unreachable.
  static Future<bool> isUnderMaintenance() async {
    if (!await hasConnection()) return false;
    try {
      final response = await http
          .get(Uri.parse('https://api.myanimelist.net/v2/anime/1?fields=id'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 503;
    } catch (e) {
      return false;
    }
  }
}
