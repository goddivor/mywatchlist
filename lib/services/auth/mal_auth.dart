import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/auth_webview.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:http/http.dart' as http;

/// This class handles the authentication process with MyAnimeList (MAL).
/// It manages the OAuth flow, including generating a random code challenge,
/// redirecting the user to the authorization page, and exchanging the
/// authorization code for an access token.
class MalAuth {
  final String clientId = Constants.malclientId; // MyAnimeList client ID
  final String redirectUri =
      Constants.malredirectUri; // MyAnimeList redirect callback URI
  final String oauthEndPoint =
      Constants.maloauthEndPoint; // MyAnimeList OAuth endpoint
  final String tokenEndPoint =
      Constants.maltokenEndPoint; // MyAnimeList token endpoint

  final String _chars =
      Constants.chars; // Characters used for generating a random string
  final Random _rnd = Random.secure(); // Secure random number generator

  BuildContext? get context => null;

  /// Generates a random string of the specified [length] using the characters
  /// defined in [_chars]
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  /// Initiates the sign-in process with MyAnimeList. It generates a code
  /// challenge, constructs the authorization URL, and opens a web view for
  /// the user to authorize the app. Once the authorization code is received,
  /// it exchanges the code for an access token.
  ///
  /// [context] is the BuildContext used to navigate to the web view.
  /// [onComplete] is an optional callback function that is called after
  /// the authentication process is complete.
  Future<void> signInWithMAL(BuildContext context,
      {Function? onComplete}) async {
    UserMal.instance.setStatus(AuthStatus.INPROGRESS);
    String codeChallenge = getRandomString(127);
    String url =
        '$oauthEndPoint?response_type=code&client_id=$clientId&code_challenge=$codeChallenge&state=OAuthLogin&redirect_uri=$redirectUri';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AuthWebView(
          initialUrl: url,
          onAuthCodeReceived: (code) async {
            await _exchangeCodeForToken(code, codeChallenge);
            if (onComplete != null) {
              onComplete();
            }
          },
        ),
      ),
    );
  }

  /// Exchanges the authorization [code] for an access token using the
  /// [codeChallenge]. The access token is then stored in the [UserMal]
  /// instance.
  Future<void> _exchangeCodeForToken(String code, String codeChallenge) async {
    final response = await http.post(
      Uri.parse(tokenEndPoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': codeChallenge,
        'redirect_uri': redirectUri,
        'client_id': clientId,
      },
    );

    // showStatusCodeToast(response.statusCode);
    // Parse the response and store the authentication data
    final Map<String, dynamic> responseData = json.decode(response.body);
    AuthResponse authResponse = AuthResponse.fromJson(responseData);
    UserMal.instance.setAuthResponse(authResponse);
  }

  /// Signs out the user by clearing the authentication data stored in the
  /// [UserMal] instance.
  Future<void> signOut() async {
    UserMal.instance.clear();
    // showToast("Log out");
    // Optionally, show a toast message indicating the user has logged out
  }
}
