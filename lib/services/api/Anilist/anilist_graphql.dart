import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/user/user_anilist_v2.dart';

/// The AniList session is dead (signed out, or the token could not be renewed).
class AnilistSessionExpired implements Exception {
  const AnilistSessionExpired();

  @override
  String toString() => 'AnilistSessionExpired';
}

/// AniList answered with an error status or a GraphQL error.
class AnilistError implements Exception {
  final int statusCode;
  final String? message;
  const AnilistError(this.statusCode, [this.message]);

  /// 429: too many requests.
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'AnilistError($statusCode${message == null ? '' : ', $message'})';
}

/// Sends one JSON body to AniList's GraphQL endpoint. [auth] true must use the signed-in
/// account (and return null when there is none). Replaceable in tests.
typedef GraphqlSender = Future<http.Response?> Function(String body, {required bool auth});

/// AniList's GraphQL endpoint. Public reads go out plain, the signed-in user's reads and
/// writes through `UserAnilistV2.sendAuthenticated` (token renewed, one replay on 401).
class AnilistGraphql {
  AnilistGraphql({GraphqlSender? sender}) : _sender = sender ?? _send;

  /// The client every AniList page uses; tests replace it.
  static AnilistGraphql instance = AnilistGraphql();

  static const String endpoint = 'https://graphql.anilist.co';

  final GraphqlSender _sender;

  static Future<http.Response?> _send(String body, {required bool auth}) {
    const headers = {'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (!auth) {
      return http
          .post(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(const Duration(seconds: 20));
    }
    return UserAnilistV2.instance.sendAuthenticated(
      (client, token) => client.post(
        Uri.parse(endpoint),
        headers: {...headers, 'Authorization': 'Bearer $token'},
        body: body,
      ),
      // Reads only: replaying one is harmless.
      idempotent: true,
    );
  }

  /// Runs [query] and returns its `data` object. Throws [AnilistSessionExpired] without a
  /// usable session ([auth] true) and [AnilistError] on any failure.
  Future<Map<String, dynamic>> query(
    String query, {
    Map<String, dynamic> variables = const {},
    bool auth = false,
  }) async {
    final body = jsonEncode({'query': query, 'variables': variables});
    final response = await _sender(body, auth: auth);
    if (response == null) throw const AnilistSessionExpired();
    if (response.statusCode == 401 && auth) throw const AnilistSessionExpired();
    final decoded = await _decode(response);
    final data = decoded['data'];
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      final errors = decoded['errors'];
      final message = errors is List && errors.isNotEmpty && errors.first is Map
          ? (errors.first as Map)['message']?.toString()
          : null;
      throw AnilistError(response.statusCode, message);
    }
    return data;
  }

  static Future<Map<String, dynamic>> _decode(http.Response response) async {
    try {
      // A whole list is a few hundred KB: decode it off the UI isolate.
      final decoded = response.body.length > 32 * 1024
          ? await compute(_decodeMap, response.body)
          : _decodeMap(response.body);
      return decoded;
    } catch (_) {
      return const {};
    }
  }
}

Map<String, dynamic> _decodeMap(String body) {
  final decoded = json.decode(body);
  return decoded is Map<String, dynamic> ? decoded : const {};
}
