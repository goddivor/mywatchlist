import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mywatchlist/services/auth/kitsu_authresp.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:http/http.dart' as http;

class KitsuAuth {
  static const String _baseUrl = "https://kitsu.io/api";
  // static const String _baseUrledge = "https://kitsu.io/api/edge"; // Old base URL for edge API, might be useful later
  static const String _tokenEndpoint = "/oauth/token";
  // static const String _userEndpoint = "/users?filter[self]=true"; // Endpoint for fetching user details, commented for now

  /// Initiates Kitsu sign-in for user login
  /// Calls [onComplete] after successful login
  Future<void> signInWithKitsu(
      BuildContext context, String username, String password,
      {Function? onComplete}) async {
    UserKitsu.instance.setStatus(AuthStatus
        .INPROGRESS); // Set user status to in-progress during authentication
    final url = Uri.parse(
        _baseUrl + _tokenEndpoint); // Construct the token endpoint URL
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json', // Specify content type as JSON
        'Accept': 'application/json', // Accept JSON response
      },
      body: jsonEncode({
        'grant_type': 'password', // OAuth2 grant type
        'username': username, // User's username
        'password': password, // User's password
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData =
          json.decode(response.body); // Decode JSON response
      KitsuAuthResponse authResponse = KitsuAuthResponse.fromJson(
          responseData); // Parse response into KitsuAuthResponse
      UserKitsu.instance.setKitsuAuthResponse(
          authResponse); // Save authentication response to user instance
      if (onComplete != null) {
        onComplete(); // Call onComplete callback if provided
      }
    } else {
      // showStatusCodeToast(response.statusCode); // Uncomment to show status code toast for debugging
      // throw 'Failed to get token access'; // Uncomment to throw an error for failed authentication
    }
  }

  /// Clears stored Kitsu credentials to sign out user
  Future<void> signout() async {
    UserKitsu.instance.clear(); // Clear user data on sign out
    // showToast("Log out"); // Uncomment to show a toast message on logout
  }
}
