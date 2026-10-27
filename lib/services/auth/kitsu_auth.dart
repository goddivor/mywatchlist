import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mywatchlist/services/auth/kitsu_authresp.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_user.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:http/http.dart' as http;

class KitsuAuth {
  /// [client] replaces the default HTTP client (tests use a fake one).
  KitsuAuth({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const String _baseUrl = "https://kitsu.io/api";
  static const String _tokenEndpoint = "/oauth/token";

  /// Signs in to Kitsu with a username (or email) and a password.
  ///
  /// The status is "in progress" only while the request runs: it ends
  /// authenticated on success, unauthenticated on any failure (listeners are
  /// notified of the outcome). Returns true when signed in; a network or parsing
  /// failure is rethrown after the status is reset, so the caller can tell
  /// "wrong credentials" (false) from "could not reach Kitsu" (throws).
  /// [onComplete] runs after a successful sign in. [context] is unused.
  Future<bool> signInWithKitsu(
      BuildContext? context, String username, String password,
      {Function? onComplete}) async {
    final user = UserKitsuV2.instance;
    user.setStatus(AuthStatus.INPROGRESS);

    final KitsuAuthResponse authResponse;
    try {
      final body = jsonEncode({
        'grant_type': 'password',
        'username': username,
        'password': password,
      });
      const headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final url = Uri.parse(_baseUrl + _tokenEndpoint);
      final client = _client;
      final response = client != null
          ? await client.post(url, headers: headers, body: body)
          : await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        debugPrint('Kitsu sign in refused: HTTP ${response.statusCode}');
        _fail(user);
        return false;
      }
      final Map<String, dynamic> responseData = json.decode(response.body);
      authResponse = KitsuAuthResponse.fromJson(responseData);
    } catch (_) {
      _fail(user);
      rethrow;
    }

    user.setAuthResponse(authResponse);

    try {
      final userProfile = await KitsuUser().getUserInfo();
      user.setUserInfo(userProfile.name, userProfile.avatar);
    } catch (e) {
      debugPrint('Failed to fetch Kitsu user profile: $e');
    }

    if (onComplete != null) onComplete();
    return true;
  }

  static void _fail(UserKitsuV2 user) {
    user.setStatus(AuthStatus.UNAUTHENTICATED);
    user.notifyAccountChange();
  }

  /// Clears stored Kitsu credentials to sign out user
  Future<void> signout() async {
    UserKitsuV2.instance.clear();
  }
}
