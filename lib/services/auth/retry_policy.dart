import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Retries an HTTP call on transient network failures only.
///
/// Transient means: no connection, a timeout or a transport level client
/// error. An HTTP response is never an error here, so a 4xx or 5xx status is
/// returned to the caller untouched and never retried by this policy.
///
/// Timeouts never bound the whole transfer: a slow but healthy large
/// response keeps going as long as bytes keep arriving. Three limits apply:
/// [connectTimeout] (TCP + TLS, set on the client by [BaseUser]),
/// [responseTimeout] (until the status line and headers arrive) and
/// [idleTimeout] (silence between two body chunks). An overall deadline is
/// opt-in, per call, through `send(timeout: ...)`.
///
/// Only idempotent calls are replayed after a failure that may have reached
/// the server (timeout, connection reset). A write (POST, PUT, PATCH,
/// DELETE) is replayed only when the error proves it was never delivered
/// (DNS failure, connection refused, unreachable, connect or TLS failure),
/// unless the caller marks it `idempotent: true`.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 8,
    this.connectTimeout = const Duration(seconds: 15),
    this.responseTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 30),
    this.baseDelay = const Duration(milliseconds: 250),
    this.maxDelay = const Duration(seconds: 4),
    this.sleep = _defaultSleep,
  });

  /// Total number of tries, the first one included (DailyAL uses 8).
  final int maxAttempts;

  /// Limit to open the connection (DNS, TCP, TLS). Applied by the client
  /// factory; a connect timeout means the request was never sent.
  final Duration connectTimeout;

  /// Limit between sending the request and receiving the response headers.
  final Duration responseTimeout;

  /// Limit of silence between two chunks of the response body.
  final Duration idleTimeout;

  /// Delay before the second attempt, doubled after each failure.
  final Duration baseDelay;

  /// Upper bound of the backoff delay.
  final Duration maxDelay;

  /// Waits between two attempts. Tests inject a fake to run instantly.
  final Future<void> Function(Duration) sleep;

  static Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);

  /// Methods a server must treat as free of side effects (RFC 9110, 9.2.1).
  static const Set<String> safeMethods = {'GET', 'HEAD', 'OPTIONS'};

  /// Whether [error] is a transient network failure worth another attempt.
  static bool isTransient(Object error) =>
      error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is HandshakeException;

  // errno values, Linux/Android then Darwin.
  static const Set<int> _notDeliveredErrno = {
    111, 61, // ECONNREFUSED
    101, 51, // ENETUNREACH
    113, 65, // EHOSTUNREACH
  };

  static const List<String> _notDeliveredMessages = [
    'failed host lookup',
    'connection refused',
    'network is unreachable',
    'no route to host',
    'http connection timed out', // HttpClient.connectionTimeout
  ];

  /// Whether [error] proves the request never reached the server, so even a
  /// write can be sent again safely.
  static bool isNotDelivered(Object error) {
    if (error is HandshakeException) return true;
    if (error is! SocketException) return false;
    final code = error.osError?.errorCode;
    if (code != null && _notDeliveredErrno.contains(code)) return true;
    final text = '${error.message} ${error.osError?.message ?? ''}'
        .toLowerCase();
    return _notDeliveredMessages.any(text.contains);
  }

  /// Backoff before attempt number [attempt] + 1 (attempt starts at 1).
  Duration delayAfter(int attempt) {
    final factor = pow(2, attempt - 1).toInt();
    final delay = baseDelay * factor;
    return delay > maxDelay ? maxDelay : delay;
  }

  /// Runs [request] with a fresh client from [newClient] per attempt, until
  /// it completes, a non transient or non replayable error is thrown, the
  /// optional overall [timeout] expires or [maxAttempts] tries are used.
  ///
  /// The client of a failed attempt is closed before the next one starts,
  /// which aborts its pending connection. [idempotent] overrides the method
  /// based replay rule: null decides from the methods [request] sent.
  Future<http.Response> send(
    http.Client Function() newClient,
    Future<http.Response> Function(http.Client client) request, {
    bool? idempotent,
    Duration? timeout,
  }) async {
    final deadline = timeout == null ? null : DateTime.now().add(timeout);
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = GuardedClient(
        newClient(),
        responseTimeout: responseTimeout,
        idleTimeout: idleTimeout,
      );
      try {
        var call = request(client);
        if (deadline != null) {
          final left = deadline.difference(DateTime.now());
          call = call.timeout(left.isNegative ? Duration.zero : left);
        }
        return await call;
      } catch (e, st) {
        if (!isTransient(e)) rethrow;
        final replayable =
            idempotent ?? client.methods.every(safeMethods.contains);
        if (!replayable && !isNotDelivered(e)) rethrow;
        if (deadline != null && !DateTime.now().isBefore(deadline)) rethrow;
        lastError = e;
        lastStack = st;
      } finally {
        client.close();
      }
      if (attempt == maxAttempts) break;
      var wait = delayAfter(attempt);
      if (deadline != null) {
        final left = deadline.difference(DateTime.now());
        // The next attempt would start at or after the deadline.
        if (left <= wait) break;
      }
      await sleep(wait);
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('Failed after $maxAttempts attempts'),
      lastStack ?? StackTrace.current,
    );
  }
}

/// Client wrapper that enforces the response and idle timeouts, records the
/// methods it sent, and closes (aborts) the inner client on a timeout.
class GuardedClient extends http.BaseClient {
  GuardedClient(
    this._inner, {
    required this.responseTimeout,
    required this.idleTimeout,
  });

  final http.Client _inner;
  final Duration responseTimeout;
  final Duration idleTimeout;

  /// Upper case methods of every request sent through this client.
  final Set<String> methods = {};

  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    methods.add(request.method.toUpperCase());
    final http.StreamedResponse response;
    try {
      response = await _inner.send(request).timeout(responseTimeout);
    } on TimeoutException {
      close();
      rethrow;
    }
    final body = response.stream.timeout(idleTimeout, onTimeout: (sink) {
      sink.addError(
          TimeoutException('No response data for $idleTimeout', idleTimeout));
      sink.close();
      close();
    });
    return http.StreamedResponse(
      body,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _inner.close();
  }
}
