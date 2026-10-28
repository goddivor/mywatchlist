import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';

/// The Simkl session is gone (signed out, or a 401: Simkl has no refresh token, the
/// account must sign in again).
class SimklSessionExpired implements Exception {
  const SimklSessionExpired();

  @override
  String toString() => 'SimklSessionExpired';
}

/// Simkl answered with an error status.
class SimklHttpError implements Exception {
  final int statusCode;
  const SimklHttpError(this.statusCode);

  @override
  String toString() => 'SimklHttpError($statusCode)';
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
class SimklClient {
  SimklClient({SimklSender? auth, SimklPublicGet? publicGet, String Function()? clientId})
      : _auth = auth ?? UserSimklV2.instance.sendAuthenticated,
        _publicGet = publicGet ?? _defaultGet,
        _clientId = clientId ?? (() => Constants.simklClientId);

  /// Shared instance; tests build their own with fakes.
  static SimklClient instance = SimklClient();

  final SimklSender _auth;
  final SimklPublicGet _publicGet;
  final String Function() _clientId;

  static Future<http.Response> _defaultGet(Uri uri, Map<String, String> headers) =>
      http.get(uri, headers: headers).timeout(const Duration(seconds: 25));

  Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse('${Constants.simklApiBaseUrl}$path');
    return query == null || query.isEmpty ? base : base.replace(queryParameters: query);
  }

  Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        'simkl-api-key': _clientId(),
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// GET with the signed-in session; the decoded JSON body.
  Future<dynamic> getAuth(String path, {Map<String, String>? query}) async {
    final target = uri(path, query);
    final response = await _auth((c, t) => c.get(target, headers: _headers(t)), idempotent: true);
    return _decode(response);
  }

  /// POST with the signed-in session; the decoded JSON body (null for an empty one).
  /// Simkl writes are idempotent (add-to-list, history), so a lost answer may be replayed.
  Future<dynamic> postAuth(String path, Object body) async {
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
    final target = uri(path, {...?query, 'client_id': _clientId()});
    return _decode(await _publicGet(target, _headers()));
  }

  Future<dynamic> _decode(http.Response? response) async {
    if (response == null) throw const SimklSessionExpired();
    if (response.statusCode == 401) throw const SimklSessionExpired();
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
