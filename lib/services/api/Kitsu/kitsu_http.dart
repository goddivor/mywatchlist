import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';

/// Kitsu answered with an error status.
class KitsuHttpError implements Exception {
  final int statusCode;
  const KitsuHttpError(this.statusCode);

  @override
  String toString() => 'KitsuHttpError($statusCode)';
}

/// The Kitsu session is gone (never signed in, or the refresh was refused): the user must sign
/// in again.
class KitsuSessionExpired implements Exception {
  const KitsuSessionExpired();

  @override
  String toString() => 'KitsuSessionExpired';
}

/// Sends one authenticated request: `UserKitsuV2.sendAuthenticated` in the app, a fake in tests.
typedef KitsuAuthSender = Future<http.Response?> Function(
  Future<http.Response> Function(http.Client client, String token) send, {
  bool? idempotent,
});

/// The one place that talks to the Kitsu JSON:API.
///
/// Public reads (catalogue, trending, categories) go out without a token. Everything about the
/// signed-in user goes through `sendAuthenticated`, which refreshes an expiring token, replays
/// once after a 401 and retries transient network errors, so no call builds its own Bearer
/// header. Bodies of 32 KB or more are decoded off the UI isolate.
class KitsuHttp {
  KitsuHttp({KitsuAuthSender? auth, http.Client? publicClient})
      : _auth = auth ?? UserKitsuV2.instance.sendAuthenticated,
        _public = publicClient;

  /// Replaced by tests.
  static KitsuHttp instance = KitsuHttp();

  static const String base = Constants.kitsuApiUrl;
  static const String mime = 'application/vnd.api+json';
  static const Map<String, String> _headers = {'Accept': mime, 'Content-Type': mime};

  final KitsuAuthSender _auth;
  final http.Client? _public;

  Uri uri(String path, [Map<String, String>? query]) {
    final url = Uri.parse('$base$path');
    return query == null || query.isEmpty ? url : url.replace(queryParameters: query);
  }

  /// GET [path] and the decoded JSON:API document. [auth] sends the user's token.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    bool auth = false,
  }) async {
    final url = uri(path, query);
    final http.Response response;
    if (auth) {
      response = await _authed((client, token) =>
          client.get(url, headers: {..._headers, 'Authorization': 'Bearer $token'}));
    } else {
      final client = _public;
      response = await (client == null
              ? http.get(url, headers: _headers)
              : client.get(url, headers: _headers))
          .timeout(const Duration(seconds: 30));
    }
    return decode(response);
  }

  /// PATCH [path] with a JSON:API [body] as the signed-in user.
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) async {
    final url = uri(path);
    final response = await _authed(
      (client, token) => client.patch(url,
          headers: {..._headers, 'Authorization': 'Bearer $token'}, body: jsonEncode(body)),
      idempotent: true,
    );
    return decode(response);
  }

  /// POST [path] with a JSON:API [body] as the signed-in user. Not idempotent: a transient
  /// failure is not replayed, so a follow is never created twice.
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final url = uri(path);
    final response = await _authed(
      (client, token) => client.post(url,
          headers: {..._headers, 'Authorization': 'Bearer $token'}, body: jsonEncode(body)),
      idempotent: false,
    );
    return decode(response);
  }

  /// DELETE [path] as the signed-in user (Kitsu answers 204 with no body).
  Future<void> deleteJson(String path) async {
    final url = uri(path);
    final response = await _authed(
      (client, token) =>
          client.delete(url, headers: {..._headers, 'Authorization': 'Bearer $token'}),
      idempotent: true,
    );
    await decode(response);
  }

  Future<http.Response> _authed(
    Future<http.Response> Function(http.Client client, String token) send, {
    bool? idempotent,
  }) async {
    final response = await _auth(send, idempotent: idempotent);
    if (response == null) throw const KitsuSessionExpired();
    if (response.statusCode == 401) throw const KitsuSessionExpired();
    return response;
  }

  /// The JSON object of a 2xx answer; throws [KitsuHttpError] otherwise.
  @visibleForTesting
  Future<Map<String, dynamic>> decode(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KitsuHttpError(response.statusCode);
    }
    if (response.bodyBytes.isEmpty) return const {};
    // Kitsu sends `application/vnd.api+json` with no charset, which `response.body` reads as
    // Latin-1 ("KaiyÅ«"): the bytes are always UTF-8.
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final decoded = body.length > 32 * 1024 ? await compute(_decode, body) : _decode(body);
    return decoded;
  }
}

Map<String, dynamic> _decode(String body) {
  final value = json.decode(body);
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}
