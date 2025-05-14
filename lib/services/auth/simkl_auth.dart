import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/simkl_authresp.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

// This class handles the authentication process with Simkl
class SimklAuth {
  // Simkl API credentials and endpoints
  final String clientId = Constants.simklClientId;
  final String clientSecret = Constants.simklClientSecret;
  final String redirectUri = Constants.simklRedirectUri;
  final String oauthEndPoint = Constants.simklOAuthEndPoint;
  final String tokenEndPoint = Constants.simklTokenEndPoint;

  // Callback function to be executed after authentication is complete
  static Function? onCompleteCallback;

  // Initiates the sign-in process with Simkl
  Future<void> signInWithSimkl(BuildContext context, {Function? onComplete}) async {
    // Set the user's authentication status to "in progress"
    UserSimkl.instance.setStatus(AuthStatus.INPROGRESS);

    // Construct the OAuth URL
    String url =
        '$oauthEndPoint?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&state=OAuthLogin';

    // Store the onComplete callback for later use
    onCompleteCallback = onComplete;

    try {
      // Launch the OAuth URL in the browser
      // ignore: deprecated_member_use
      await launch(url.toString());
    } catch (e) {
      // Throw an error if the URL cannot be launched
      throw 'Could not launch $url';
    }
  }

  // Handles the redirect URI after the user authorizes the app
  Future<void> handleSimklAuthRedirect(Uri uri) async {
    // Extract the authorization code from the redirect URI
    final code = uri.queryParameters['code'];

    if (code != null) {
      // Exchange the authorization code for an access token
      await _exchangeCodeForToken(code);

      // Execute the onComplete callback if it is defined
      if (onCompleteCallback != null) {
        onCompleteCallback!();
      }
    }
  }

  // Exchanges the authorization code for an access token
  Future<void> _exchangeCodeForToken(String code) async {
    // Make a POST request to the token endpoint
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

    // If the request is successful, parse the response and update the user's authentication data
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      SimklAuthResponse authResponse = SimklAuthResponse.fromJson(responseData);
      UserSimkl.instance.setSimklAuthResponse(authResponse);
    } else {
      // Handle the error case (e.g., log the error or show a message to the user)
    }
  }

  // Signs the user out by clearing their authentication data
  Future<void> signOut() async {
    UserSimkl.instance.clear();
    // Optionally, show a toast message to indicate the user has logged out
  }
}
