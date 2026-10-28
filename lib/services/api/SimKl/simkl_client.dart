import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The Simkl session is gone (signed out, or a 401: Simkl has no refresh token, the
/// account must sign in again).
class SimklSessionExpired implements Exception {
  const SimklSessionExpired();

  @override
  String toString() => 'SimklSessionExpired';
}

/// Simkl answered with an error status.
///
/// Status codes: https://api.simkl.org/conventions/errors
class SimklHttpError implements Exception {
  final int statusCode;
  const SimklHttpError(this.statusCode);

  @override
  String toString() => 'SimklHttpError($statusCode)';
}

/// Simkl answered 429 (too many requests): back off for [retryAfter] before calling again.
/// While the back-off lasts the client throws this at once, without touching the network.
/// Rules: https://api.simkl.org/resources/rate-limits
class SimklRateLimited extends SimklHttpError {
  /// How long Simkl asked to wait (`Retry-After`, or the client's own exponential back-off).
  final Duration retryAfter;

  /// `X-RateLimit-Remaining` of the answer, when Simkl sent it.
  final int? remaining;

  const SimklRateLimited(this.retryAfter, {this.remaining}) : super(429);

  @override
  String toString() => 'SimklRateLimited(retry in ${retryAfter.inSeconds}s)';
}

/// Runs one authenticated request (`BaseUser.sendAuthenticated`); null = no usable session.
typedef SimklSender = Future<http.Response?> Function(
  Future<http.Response> Function(http.Client client, String token) send, {
  bool? idempotent,
});

/// Plain request without a session (public Simkl endpoints).
typedef SimklPublicGet = Future<http.Response> Function(Uri uri, Map<String, String> headers);

/// Every Simkl call of the app goes through here: the signed-in calls use
/// `UserSimklV2.sendAuthenticated`, the public ones carry the client id.
///
/// Every call identifies the app as https://api.simkl.org/conventions/headers asks: the
/// `app-name` and `app-version` query parameters (also sent as headers) and
/// `User-Agent: MyWatchList/<version>`. A 429 becomes a [SimklRateLimited] and pauses the client.
class SimklClient {
  SimklClient({
    SimklSender? auth,
    SimklPublicGet? publicGet,
    String Function()? clientId,
    Future<String> Function()? appVersion,
    DateTime Function()? now,
  })  : _auth = auth ?? UserSimklV2.instance.sendAuthenticated,
        _publicGet = publicGet ?? _defaultGet,
        _clientId = clientId ?? (() => Constants.simklClientId),
        _appVersion = appVersion ?? _packageVersion,
        _now = now ?? DateTime.now;

  /// Name sent as `app-name` and as the product of the `User-Agent`.
  static const String appName = 'MyWatchList';

  /// Longest back-off honoured, even when Simkl asks for more.
  static const Duration maxBackoff = Duration(minutes: 10);

  /// Back-off of a 429 that carries no usable `Retry-After`; doubles on each consecutive 429.
  static const Duration baseBackoff = Duration(seconds: 15);

  /// Shared instance; tests build their own with fakes.
  static SimklClient instance = SimklClient();

  final SimklSender _auth;
  final SimklPublicGet _publicGet;
  final String Function() _clientId;
  final Future<String> Function() _appVersion;
  final DateTime Function() _now;

  String? _version;
  DateTime? _blockedUntil;
  int _consecutive429 = 0;

  /// `X-RateLimit-Remaining` of the latest answer that carried it (null until one does).
  int? rateLimitRemaining;

  static Future<String> _packageVersion() async {
    try {
      return (await PackageInfo.fromPlatform().timeout(const Duration(seconds: 2))).version;
    } catch (_) {
      return '0.0.0'; // no platform channel (tests): still a valid version token
    }
  }

  static Future<http.Response> _defaultGet(Uri uri, Map<String, String> headers) =>
      http.get(uri, headers: headers).timeout(const Duration(seconds: 25));

  /// The URL of [path] with [query] plus `app-name` and `app-version`. The version is read from
  /// the package info on the first call of the client; before that it is `0.0.0`.
  Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('${Constants.simklApiBaseUrl}$path');
    return base.replace(queryParameters: {
      ...?query,
      'app-name': appName,
      'app-version': _version ?? '0.0.0',
    });
  }

  Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        'simkl-api-key': _clientId(),
        'app-name': appName,
        'app-version': _version ?? '0.0.0',
        'User-Agent': '$appName/${_version ?? '0.0.0'}',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<void> _prepare() async {
    _version ??= await _appVersion();
    final until = _blockedUntil;
    if (until != null) {
      final left = until.difference(_now());
      if (left > Duration.zero) throw SimklRateLimited(left, remaining: rateLimitRemaining);
    }
  }

  /// GET with the signed-in session; the decoded JSON body.
  Future<dynamic> getAuth(String path, {Map<String, String>? query}) async {
    await _prepare();
    final target = uri(path, query);
    final response = await _auth((c, t) => c.get(target, headers: _headers(t)), idempotent: true);
    return _decode(response);
  }

  /// POST with the signed-in session; the decoded JSON body (null for an empty one).
  /// Simkl writes are idempotent (add-to-list, history), so a lost answer may be replayed.
  Future<dynamic> postAuth(String path, Object body) async {
    await _prepare();
    final target = uri(path);
    final encoded = jsonEncode(body);
    final response = await _auth(
      (c, t) => c.post(target, headers: _headers(t), body: encoded),
      idempotent: true,
    );
    return _decode(response);
  }

  /// GET without a session (the client id is added as Simkl asks).
  Future<dynamic> getPublic(String path, {Map<String, String>? query}) async {
    await _prepare();
    final target = uri(path, {...?query, 'client_id': _clientId()});
    return _decode(await _publicGet(target, _headers()));
  }

  void _readRateLimit(http.Response response) {
    final remaining = int.tryParse(response.headers['x-ratelimit-remaining']?.trim() ?? '');
    if (remaining != null) rateLimitRemaining = remaining;
  }

  /// Starts the back-off of a 429: `Retry-After` (seconds) when Simkl sent one,
  /// else [baseBackoff] doubled per consecutive 429; never more than [maxBackoff].
  SimklRateLimited _backOff(http.Response response) {
    var wait = _parseRetryAfter(response.headers['retry-after']);
    wait ??= baseBackoff * (1 << _consecutive429.clamp(0, 6));
    _consecutive429++;
    if (wait > maxBackoff) wait = maxBackoff;
    _blockedUntil = _now().add(wait);
    return SimklRateLimited(wait, remaining: rateLimitRemaining);
  }

  Duration? _parseRetryAfter(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;
    final seconds = int.tryParse(raw); // an HTTP date is not used by Simkl: own back-off then
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  Future<dynamic> _decode(http.Response? response) async {
    if (response == null) throw const SimklSessionExpired();
    _readRateLimit(response);
    if (response.statusCode == 401) throw const SimklSessionExpired();
    if (response.statusCode == 429) throw _backOff(response);
    _consecutive429 = 0;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SimklHttpError(response.statusCode);
    }
    final body = response.body;
    if (body.trim().isEmpty) return null;
    // A whole anime list can be several MB: decode it off the UI isolate.
    return body.length > 32 * 1024 ? compute(_decodeJson, body) : _decodeJson(body);
  }
}

dynamic _decodeJson(String body) => json.decode(body);
