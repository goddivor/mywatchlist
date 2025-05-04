import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mywatchlist/services/auth/kitsu_authresp.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:http/http.dart' as http;

class KitsuAuth {
  static const String _baseUrl = "https://kitsu.io/api";
  // static const String _baseUrledge = "https://kitsu.io/api/edge";
  static const String _tokenEndpoint = "/oauth/token";
  // static const String _userEndpoint = "/users?filter[self]=true";

  Future<void> signInWithKitsu(
      BuildContext context, String username, String password,
      {Function? onComplete}) async {
    UserKitsu.instance.setStatus(AuthStatus.INPROGRESS);
    final url = Uri.parse(_baseUrl + _tokenEndpoint);
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'grant_type': 'password',
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      // showStatusCodeToast(response.statusCode);
      final Map<String, dynamic> responseData = json.decode(response.body);
      KitsuAuthResponse authResponse = KitsuAuthResponse.fromJson(responseData);
      UserKitsu.instance.setKitsuAuthResponse(authResponse);
      if (onComplete != null) {
        onComplete();
      }
    } else {
      // showStatusCodeToast(response.statusCode);
      // throw 'Failed to get token access';
    }
  }

  Future<void> signout() async {
    UserKitsu.instance.clear();
    // showToast("Log out");
  }
}
