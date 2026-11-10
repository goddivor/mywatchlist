import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';
import 'package:mywatchlist/services/api/MAL/models/search_result.dart';
import 'package:mywatchlist/services/api/MAL/models/mal_user_search.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:html/parser.dart' as htmlParser;

class MalUser {
  static const String userBaseEndPoint = Constants.maluserBaseEndPoint;

  Future<MalUserProf> getUserInfo({List<String>? fields, String username = "@me"}) async {
    // For other users, try Jikan first (MAL API only works for @me with auth)
    if (username != '@me') {
      final jikanResult = await _adaptFromJikan(username);
      if (jikanResult != null) return jikanResult;
    }

    // For own user (@me), use MAL API
    String url = '$userBaseEndPoint/$username';
    if (fields != null && fields.isNotEmpty) {
      url += '?fields=${fields.join(",")}';
    }
    final response = await MalApi.signedGet(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to load user info (${response.statusCode})');
    }

    final profileData = json.decode(response.body);
    return MalUserProf.fromJson(profileData);
  }

  /// Fallback to Jikan API for public user profiles.
  /// MAL's official API only supports @me for user info.
  static Future<MalUserProf?> _adaptFromJikan(String username) async {
    try {
      final jikanApi = JikanApi();
      final data = await jikanApi.getUserFullProfile(username);
      return MalUserProf.fromJson({
        'id': data['mal_id'] ?? 0,
        'name': data['username'] ?? username,
        'location': data['location'] ?? '',
        'gender': data['gender'],
        'birthday': data['birthday'],
        'time_zone': '',
        'joined_at': data['joined'] ?? '',
        'picture': data['images']?['jpg']?['image_url'] ?? '',
        'anime_statistics': data['statistics']?['anime'] ?? {},
      });
    } catch (e) {
      debugPrint('Jikan fallback failed for $username: $e');
    }
    return null;
  }

  /// Get user's content list as SearchResult with pagination support.
  static Future<SearchResult> getMyContentListResult({
    int limit = 100,
    int offset = 0,
    String category = "anime",
    String? status = "all",
    String? sortType,
    List<String>? fields,
    String username = "@me",
  }) async {

    String fieldsString = (fields != null && fields.isNotEmpty)
        ? fields.join(",")
        : 'id,title,main_picture,mean,num_list_users,status,media_type,num_episodes,start_date,end_date,list_status{is_rewatching,is_rereading,num_times_rewatched,num_times_reread,priority,rewatch_value,reread_value,start_date,finish_date,tags,comments}';

    String url = '$userBaseEndPoint/$username/${category}list?fields=$fieldsString&limit=$limit&offset=$offset';

    if (status != null) url += "&status=$status";
    if (sortType != null) url += "&sort=$sortType";

    final response = await MalApi.signedGet(url);

    if (response.statusCode == 200) {
      return SearchResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get user content list');
    }
  }

  static Future<List<Anime>> getMyContentList({
    int limit = 100,
    int offset = 0,
    String category = "anime",
    String? status = "all",
    String? sortType,
    List<String>? fields,
    String username = "@me",
  }) async {
    final result = await getMyContentListResult(
      limit: limit,
      offset: offset,
      category: category,
      status: status,
      sortType: sortType,
      fields: fields,
      username: username,
    );
    return result.data;
  }

  /// Fetch ALL items from a user's list with automatic pagination.
  /// Uses limit=1000 and follows paging.next until exhausted.
  static Future<SearchResult> getAllUserList(
    String username,
    String category, {
    String? status,
    String? sortType,
    List<String>? fields,
  }) async {
    const limit = 1000;

    String fieldsString = (fields != null && fields.isNotEmpty)
        ? fields.join(",")
        : 'id,title,main_picture,mean,num_list_users,status,media_type,num_episodes,start_date,end_date,list_status{is_rewatching,is_rereading,num_times_rewatched,num_times_reread,priority,rewatch_value,reread_value,start_date,finish_date,tags,comments}';

    String url = '$userBaseEndPoint/$username/${category}list?fields=$fieldsString&limit=$limit';
    if (status != null) url += "&status=$status";
    if (sortType != null) url += "&sort=$sortType";

    List<Anime> allItems = [];

    String? currentUrl = url;
    while (currentUrl != null) {
      final response = await MalApi.signedGet(currentUrl);

      if (response.statusCode != 200) {
        break;
      }

      final result = SearchResult.fromJson(json.decode(response.body));
      allItems.addAll(result.data);

      // Stop if we got fewer items than the limit (last page)
      if (result.data.length < limit || !result.hasNextPage) {
        break;
      }
      currentUrl = result.paging?.next;
    }

    return SearchResult(data: allItems);
  }

  /// Search for MAL users by username (HTML scraping).
  static Future<MalUserSearchResult?> searchUser(String query, {int offset = 0}) async {
    try {
      final url = 'https://myanimelist.net/users.php?cat=user&q=${Uri.encodeComponent(query)}&show=$offset';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);
        return HtmlParsers.parseUserSearch(document);
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
    return null;
  }
}
