import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as htmlParser;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';

/// MAL Forum API client.
/// Endpoints: GET /forum/boards, GET /forum/topics, GET /forum/topic/{topic_id}
class MalForumApi {
  static const String _forumEndPoint = Constants.malforumEndPoint;

  Map<String, String> get _headers {
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    return MalApi.getHeadersForAccountType(selectedAcc);
  }

  /// Get forum boards/categories list.
  Future<Categories?> getForumBoards() async {
    try {
      final response = await http.get(
        Uri.parse('$_forumEndPoint/boards'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return Categories.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalForumApi: getForumBoards error: $e');
    }
    return null;
  }

  /// Get forum topics list with filtering/pagination.
  Future<ForumTopics?> getForumTopics({
    int? boardId,
    int? subboardId,
    int? animeId,
    int? mangaId,
    String? q,
    String? topicUserName,
    String? userName,
    int limit = 40,
    int offset = 0,
    String sort = 'recent',
    bool fromHtml = false,
  }) async {
    // HTML fallback path
    if (fromHtml) {
      return _getForumTopicsHtml(
        boardId: boardId,
        subboardId: subboardId,
        animeId: animeId,
        mangaId: mangaId,
        offset: offset,
      );
    }

    try {
      final queryParams = <String, String>{
        if (boardId != null) 'board_id': boardId.toString(),
        if (subboardId != null) 'subboard_id': subboardId.toString(),
        if (animeId != null) 'anime_id': animeId.toString(),
        if (mangaId != null) 'manga_id': mangaId.toString(),
        if (q != null) 'q': q,
        if (topicUserName != null) 'topic_user_name': topicUserName,
        if (userName != null) 'user_name': userName,
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sort': sort,
      };

      final uri = Uri.parse('$_forumEndPoint/topics')
          .replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ForumTopics.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalForumApi: getForumTopics error: $e');
    }
    return null;
  }

  /// Get forum topic detail with posts.
  Future<ForumTopicData?> getForumTopicDetail(
    int topicId, {
    int limit = 14,
    int offset = 0,
  }) async {
    try {
      final url =
          '$_forumEndPoint/topic/$topicId?limit=$limit&offset=$offset';

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ForumTopicData.fromJson(data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalForumApi: getForumTopicDetail error: $e');
    }
    return null;
  }

  /// HTML fallback for forum topics when API is unavailable.
  Future<ForumTopics?> _getForumTopicsHtml({
    int? boardId,
    int? subboardId,
    int? animeId,
    int? mangaId,
    int offset = 0,
  }) async {
    try {
      String url = 'https://myanimelist.net/forum/?';
      if (boardId != null) url += 'board=$boardId&';
      if (subboardId != null) url += 'subboard=$subboardId&';
      if (animeId != null) url += 'animeid=$animeId&';
      if (mangaId != null) url += 'mangaid=$mangaId&';
      url += 'show=$offset';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);
        final result = HtmlParsers.parseForumTopicsHtml(document);
        return ForumTopics.fromJson(result);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MalForumApi: HTML fallback error: $e');
    }
    return null;
  }
}
