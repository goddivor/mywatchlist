import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:http/http.dart' as http;

class SimklUser {
  final String userInfoEndpoint = 'https://api.simkl.com/users/settings';
  final String clientid = Constants.simklClientId;

  Future<UserProfSimkl> getUserInfo() async {
    final authToken = UserSimklV2.instance.accessToken;


    final response = await http.get(
      Uri.parse(userInfoEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        'simkl-api-key': clientid,
      },
    );

    debugPrint('Simkl getUserInfo response: ${response.statusCode}');
    debugPrint('Simkl access token: ${authToken != null ? "present" : "null"}');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      debugPrint('Simkl user data: $data');
      return UserProfSimkl.fromJson(data);
    } else {
      debugPrint('Simkl getUserInfo error: ${response.body}');
      throw Exception('Failed to load user info');
    }
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${UserSimklV2.instance.accessToken}',
    'simkl-api-key': Constants.simklClientId,
  };

  // Sync all items - GET /sync/all-items/{type}
  Future<Map<String, dynamic>> syncAllItems({String type = 'anime'}) async {
    final uri = Uri.parse('${Constants.simklApiBaseUrl}/sync/all-items/$type');
    final response = await http.get(uri, headers: _authHeaders);

    debugPrint('Simkl syncAllItems response: ${response.statusCode}');
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Simkl syncAllItems error: ${response.body}');
      throw Exception('Failed to sync all items from Simkl');
    }
  }

  // Add to list - POST /sync/add-to-list
  // Body should be: {"anime": [...], "shows": [...], "movies": [...]}
  Future<Map<String, dynamic>> addToList(Map<String, dynamic> body) async {
    final uri = Uri.parse('${Constants.simklApiBaseUrl}/sync/add-to-list');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode(body),
    );

    debugPrint('Simkl addToList response: ${response.statusCode}');
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Simkl addToList error: ${response.body}');
      throw Exception('Failed to add items to Simkl list');
    }
  }

  // Remove from list - POST /sync/remove-from-list
  // Body should be: {"anime": [...], "shows": [...], "movies": [...]}
  Future<Map<String, dynamic>> removeFromList(Map<String, dynamic> body) async {
    final uri = Uri.parse('${Constants.simklApiBaseUrl}/sync/remove-from-list');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode(body),
    );

    debugPrint('Simkl removeFromList response: ${response.statusCode}');
    if (response.statusCode == 200 || response.statusCode == 204) {
      if (response.body.isEmpty) return {};
      final decoded = json.decode(response.body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } else {
      debugPrint('Simkl removeFromList error: ${response.body}');
      throw Exception('Failed to remove items from Simkl list');
    }
  }

  // Get watchlist - GET /sync/watchlist/{type}
  Future<Map<String, dynamic>> getWatchlist({String type = 'anime'}) async {
    final uri = Uri.parse('${Constants.simklApiBaseUrl}/sync/watchlist/$type');
    final response = await http.get(uri, headers: _authHeaders);

    debugPrint('Simkl getWatchlist response: ${response.statusCode}');
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Simkl getWatchlist error: ${response.body}');
      throw Exception('Failed to get watchlist from Simkl');
    }
  }

  // Get watch history - GET /sync/history/{type}
  Future<Map<String, dynamic>> getWatchHistory({String type = 'anime'}) async {
    final uri = Uri.parse('${Constants.simklApiBaseUrl}/sync/history/$type');
    final response = await http.get(uri, headers: _authHeaders);

    debugPrint('Simkl getWatchHistory response: ${response.statusCode}');
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Simkl getWatchHistory error: ${response.body}');
      throw Exception('Failed to get watch history from Simkl');
    }
  }
}
