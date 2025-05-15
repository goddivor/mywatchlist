import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/anilist_authresp.dart';
import 'package:mywatchlist/services/auth/auth_webview.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:http/http.dart' as http;

/// Handles OAuth authentication flow with AniList
class AnilistAuth {
  // OAuth configuration values
  final String clientId = Constants.anilistClientId;
  final String clientSecret = Constants.anilistClientSecret;
  final String redirectUri = Constants.anilistRedirectUri;
  final String oauthEndPoint = Constants.anilistOAuthEndPoint;
  final String tokenEndPoint = Constants.anilistTokenEndPoint;

  // Characters for generating random strings (PKCE state or code verifier)
  final String _chars = Constants.chars;
  final Random _rnd = Random.secure();

  BuildContext? get context => null; // placeholder getter

  /// Generate a random string of [length] using allowed chars
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  /// Initiates AniList sign-in by opening a WebView for user login
  /// Calls [onComplete] after successful token exchange
  Future<void> signInWithAnilist(BuildContext context,
      {Function? onComplete}) async {
    // update user status to show in-progress
    UserAnilist.instance.setStatus(AuthStatus.INPROGRESS);
    // Generate a random string for PKCE state or code verifier
    String codeChallenge = getRandomString(127);
    // Generate the authorization URL with required parameters
    String url =
        '$oauthEndPoint?client_id=$clientId&redirect_uri=$redirectUri&response_type=code';

    // navigate to WebView for OAuth login
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthWebView(
          initialUrl: url,
          onAuthCodeReceived: (code) async {
            // exchange auth code for access token
            await _exchangeCodeForToken(code, codeChallenge);
            // notify completion
            if (onComplete != null) {
              onComplete();
            }
          },
        ),
      ),
    );
  }

  /// Exchange the authorization [code] for an access token
  Future<void> _exchangeCodeForToken(String code, String codeChallenge) async {
    final response = await http.post(
      Uri.parse(tokenEndPoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'client_secret': clientSecret,
      }),
    );

    // parse JSON response into model
    final Map<String, dynamic> responseData = json.decode(response.body);
    AnilistAuthResponse authResponse =
        AnilistAuthResponse.fromJson(responseData);
    // store authentication info
    UserAnilist.instance.setAnilistAuthResponse(authResponse);
  }

  /// Clears stored AniList credentials to sign out user
  Future<void> signOut() async {
    UserAnilist.instance.clear();
    // showToast("Log out");
  }
}
