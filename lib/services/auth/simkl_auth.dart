import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/simkl_authresp.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class SimklAuth {
  final String clientId = Constants.simklClientId;
  final String clientSecret = Constants.simklClientSecret;
  final String redirectUri = Constants.simklRedirectUri;
  final String oauthEndPoint = Constants.simklOAuthEndPoint;
  final String tokenEndPoint = Constants.simklTokenEndPoint;
  static Function? onCompleteCallback;

  Future<void> signInWithSimkl(BuildContext context,
      {Function? onComplete}) async {
    UserSimkl.instance.setStatus(AuthStatus.INPROGRESS);
    String url =
        '$oauthEndPoint?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&state=OAuthLogin';
      onCompleteCallback = onComplete;
    
    try {
      // ignore: deprecated_member_use
      await launch(url.toString()); // launh the url with the navigator
    } catch (e) {
      throw 'Could not launch $url';
    }
  }

  //this function is called only when our app receive a callback link by a listner defined on main.dart
  Future<void> handleSimklAuthRedirect(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code != null) {
      await _exchangeCodeForToken(code);
      if(onCompleteCallback != null) {
        onCompleteCallback!();
      }
      //we need to apply the onComplete callback here
    }
  }

  Future<void> _exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse(tokenEndPoint),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'code': code,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
      }),
    );

    if (response.statusCode == 200) {
      // showStatusCodeToast(response.statusCode);
      final Map<String, dynamic> responseData = json.decode(response.body);
      SimklAuthResponse authResponse = SimklAuthResponse.fromJson(responseData);
      UserSimkl.instance.setSimklAuthResponse(authResponse); 
    } else {
      // showStatusCodeToast(response.statusCode);
      // throw 'Failed to exchange code for token';
    }
  }

  Future<void> signOut() async {
    UserSimkl.instance.clear();
    // showToast("Log out");
  }
}
