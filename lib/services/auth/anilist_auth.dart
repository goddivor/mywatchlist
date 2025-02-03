import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/anilist_authresp.dart';
import 'package:mywatchlist/services/auth/auth_webview.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:http/http.dart' as http;

class AnilistAuth {
  final String clientId = Constants.anilistClientId;
  final String clientSecret = Constants.anilistClientSecret;
  final String redirectUri = Constants.anilistRedirectUri;
  final String oauthEndPoint = Constants.anilistOAuthEndPoint;
  final String tokenEndPoint = Constants.anilistTokenEndPoint;

  final String _chars = Constants.chars;
  final Random _rnd = Random.secure();
  
  BuildContext? get context => null;

  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
      length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  Future<void> signInWithAnilist(BuildContext context, {Function? onComplete}) async {
    UserAnilist.instance.setStatus(AuthStatus.INPROGRESS);
    // User.instance.setStatus(AuthStatus.INPROGRESS);
    String codeChallenge = getRandomString(127);
    String url = '$oauthEndPoint?client_id=$clientId&redirect_uri=$redirectUri&response_type=code';

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

    // showStatusCodeToast(response.statusCode);
    final Map<String, dynamic> responseData = json.decode(response.body);
    AnilistAuthResponse authResponse = AnilistAuthResponse.fromJson(responseData);
    UserAnilist.instance.setAnilistAuthResponse(authResponse);
  }

  Future<void> signOut() async {
    UserAnilist.instance.clear();
    // showToast("Log out");
  }
}