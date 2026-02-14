import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Network utility class for MAL API calls.
/// Provides retry logic, connectivity checks, and maintenance detection.
class MalConnect {
  static const int _maxAttempts = 8;
  static const Duration _retryTimeout = Duration(seconds: 10);

  /// Perform an HTTP GET with automatic retry on transient failures.
  /// Retries up to [_maxAttempts] times on SocketException or TimeoutException.
  static Future<http.Response> retryGet(
    String url,
    Map<String, String> headers,
  ) async {
    Object? lastError;

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
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
