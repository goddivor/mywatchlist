import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Retries an operation on transient network failures only.
///
/// Transient means: no connection, a timeout or a transport level client
/// error. An HTTP response is never an error here, so a 4xx or 5xx status is
/// returned to the caller untouched and never retried by this policy.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 8,
    this.timeout = const Duration(seconds: 10),
    this.baseDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 4),
    this.sleep = _defaultSleep,
  });

  /// Total number of tries, the first one included (DailyAL uses 8).
  final int maxAttempts;

  /// Per attempt timeout.
  final Duration timeout;

  /// Delay before the second attempt, doubled after each failure.
  final Duration baseDelay;

  /// Upper bound of the backoff delay.
  final Duration maxDelay;

  /// Waits between two attempts. Tests inject a fake to run instantly.
  final Future<void> Function(Duration) sleep;

  static Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

  /// Whether [error] is a transient network failure worth another attempt.
  static bool isTransient(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is HandshakeException;

  /// Backoff before attempt number [attempt] + 1 (attempt starts at 1).
  Duration delayAfter(int attempt) {
    final factor = pow(2, attempt - 1).toInt();
    final delay = baseDelay * factor;
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Runs [operation] until it completes, a non transient error is thrown or
  /// [maxAttempts] tries are used. The last transient error is rethrown.
  Future<T> run<T>(Future<T> Function() operation) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation().timeout(timeout);
      } catch (e, st) {
        if (!isTransient(e)) rethrow;
        lastError = e;
        lastStack = st;
      }
      if (attempt < maxAttempts) await sleep(delayAfter(attempt));
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('Failed after $maxAttempts attempts'),
      lastStack ?? StackTrace.current,
    );
  }
}
