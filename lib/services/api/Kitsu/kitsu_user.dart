import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Kitsu/kitsu_user_prof.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';

class KitsuUser {
  static const String _userBaseEndPoint = "https://kitsu.io/api/edge";

  static const String _userEndpoint = "/users?filter[self]=true";

  static const Map<String, String> _jsonApiHeaders = {
    'Content-Type': 'application/vnd.api+json',
    'Accept': 'application/vnd.api+json',
  };

  Map<String, String> get _authHeaders => {
        ..._jsonApiHeaders,
        'Authorization': 'Bearer ${UserKitsuV2.instance.accessToken}',
      };

  /// Ensure the Kitsu access token is valid, refreshing if expired.
  Future<void> _ensureValidToken() async {
    final user = UserKitsuV2.instance;
    if (user.isTokenExpired) {
      debugPrint('Kitsu token expired, refreshing...');
      final refreshed = await user.refreshAccessToken();
      debugPrint('Kitsu token refresh: ${refreshed ? "success" : "failed"}');
    }
  }

  String? _cachedUserId;

  /// Get the authenticated user's Kitsu user ID.
  Future<String?> getSelfUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    await _ensureValidToken();
    final accessToken = UserKitsuV2.instance.accessToken;
    if (accessToken == null) return null;

    final url = Uri.parse(_userBaseEndPoint + _userEndpoint);
    final response = await http.get(url, headers: _authHeaders);

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'] as List;
      if (data.isNotEmpty) {
        _cachedUserId = data[0]['id'] as String;
        return _cachedUserId;
      }
    }
    return null;
  }

  Future<KitsuUserProf> getUserInfo() async {
    final accessToken = UserKitsuV2.instance.accessToken;

    // Constructing the URL
    // String url = '$userBaseEndPoint/users?filter[self]=true';

    final url = Uri.parse(_userBaseEndPoint + _userEndpoint);
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    );

    print('Kitsu getUserInfo response: ${response.statusCode}');
    print('Kitsu access token: ${accessToken != null ? "present" : "null"}');
    if (response.statusCode == 200) {
      final profileData = json.decode(response.body)['data'][0]['attributes'];
      print('Kitsu user data: $profileData');
      return KitsuUserProf.fromJson(profileData);
    } else {
      print('Kitsu getUserInfo error: ${response.body}');
      throw Exception('Failed to fetch user profile');
    }
  }

  /// Get library entries for a user.
  ///
  /// [userId] - The Kitsu user ID.
  /// [kind] - Filter by media kind: 'anime' or 'manga'. Defaults to 'anime'.
  /// [status] - Optional status filter (e.g. 'current', 'planned', 'completed', 'on_hold', 'dropped').
  /// [limit] - Number of results per page. Defaults to 20.
  /// [offset] - Pagination offset. Defaults to 0.
  Future<Map<String, dynamic>> getLibraryEntries({
    required String userId,
    String kind = 'anime',
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'filter[userId]': userId,
      'filter[kind]': kind,
      'page[limit]': limit.toString(),
      'page[offset]': offset.toString(),
    };
    if (status != null) {
      params['filter[status]'] = status;
    }

    final uri = Uri.parse('$_userBaseEndPoint/library-entries')
        .replace(queryParameters: params);
    final response = await http.get(uri, headers: _authHeaders);

    debugPrint('Kitsu getLibraryEntries response: ${response.statusCode}');
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Kitsu getLibraryEntries error: ${response.body}');
      throw Exception('Failed to get library entries from Kitsu');
    }
  }

  /// Find a library entry for a specific media (anime/manga) by its ID.
  /// Returns the raw JSON:API resource data or null if not found.
  Future<Map<String, dynamic>?> getLibraryEntryForMedia({
    required String mediaId,
    required String mediaType,
  }) async {
    final userId = await getSelfUserId();
    if (userId == null) return null;
    final filterKey = mediaType == 'anime' ? 'animeId' : 'mangaId';
    final params = <String, String>{
      'filter[userId]': userId,
      'filter[$filterKey]': mediaId,
      'page[limit]': '1',
    };

    final uri = Uri.parse('$_userBaseEndPoint/library-entries')
        .replace(queryParameters: params);
    debugPrint('Kitsu getLibraryEntryForMedia: userId=$userId, $filterKey=$mediaId');
    final response = await http.get(uri, headers: _authHeaders);
    debugPrint('Kitsu getLibraryEntryForMedia response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final body = json.decode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>?;
      debugPrint('Kitsu getLibraryEntryForMedia entries found: ${data?.length ?? 0}');
      if (data != null && data.isNotEmpty) {
        return data.first as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Create a new library entry.
  ///
  /// [mediaId] - The ID of the anime or manga.
  /// [mediaType] - The media type: 'anime' or 'manga'.
  /// [status] - The library status (e.g. 'current', 'planned', 'completed', 'on_hold', 'dropped').
  Future<Map<String, dynamic>> createLibraryEntry({
    required int mediaId,
    required String mediaType,
    required String status,
  }) async {
    await _ensureValidToken();
    final userId = await getSelfUserId();
    final bodyMap = {
      'data': {
        'type': 'libraryEntries',
        'attributes': {
          'status': status,
        },
        'relationships': {
          mediaType: {
            'data': {
              'type': mediaType,
              'id': mediaId.toString(),
            },
          },
          if (userId != null)
            'user': {
              'data': {
                'type': 'users',
                'id': userId,
              },
            },
        },
      },
    };
    final body = json.encode(bodyMap);
    debugPrint('Kitsu createLibraryEntry body: $body');

    final response = await http.post(
      Uri.parse('$_userBaseEndPoint/library-entries'),
      headers: _authHeaders,
      body: body,
    );

    debugPrint('Kitsu createLibraryEntry response: ${response.statusCode}');
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Kitsu createLibraryEntry error: ${response.body}');
      throw Exception('Failed to create library entry on Kitsu');
    }
  }

  /// Update an existing library entry.
  ///
  /// [entryId] - The library entry ID to update.
  /// [status] - Optional new status.
  /// [progress] - Optional progress (episodes watched or chapters read).
  /// [ratingTwenty] - Optional rating on a 0-20 scale (Kitsu's native rating scale).
  Future<Map<String, dynamic>> updateLibraryEntry({
    required String entryId,
    String? status,
    int? progress,
    double? ratingTwenty,
  }) async {
    await _ensureValidToken();
    final attributes = <String, dynamic>{};
    if (status != null) attributes['status'] = status;
    if (progress != null) attributes['progress'] = progress;
    if (ratingTwenty != null) attributes['ratingTwenty'] = ratingTwenty;

    final body = json.encode({
      'data': {
        'id': entryId,
        'type': 'libraryEntries',
        'attributes': attributes,
      },
    });

    final response = await http.patch(
      Uri.parse('$_userBaseEndPoint/library-entries/$entryId'),
      headers: _authHeaders,
      body: body,
    );

    debugPrint('Kitsu updateLibraryEntry response: ${response.statusCode}');
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('Kitsu updateLibraryEntry error: ${response.body}');
      throw Exception('Failed to update library entry on Kitsu');
    }
  }

  /// Delete a library entry.
  ///
  /// [entryId] - The library entry ID to delete.
  Future<void> deleteLibraryEntry(String entryId) async {
    await _ensureValidToken();
    final response = await http.delete(
      Uri.parse('$_userBaseEndPoint/library-entries/$entryId'),
      headers: _authHeaders,
    );

    debugPrint('Kitsu deleteLibraryEntry response: ${response.statusCode}');
    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint('Kitsu deleteLibraryEntry error: ${response.body}');
      throw Exception('Failed to delete library entry on Kitsu');
    }
  }
}
