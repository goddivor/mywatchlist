import 'dart:convert';
import 'package:html/parser.dart' as htmlParser;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';

/// MAL Forum API client
/// Endpoints: GET /forum/boards, GET /forum/topics, GET /forum/topic/{topic_id}
class MalForumApi {
  static const String _forumEndPoint = Constants.malforumEndPoint;

  // Get forum boards list - GET /forum/boards
  Future<Map<String, dynamic>> getForumBoards() async {
    final url = '$_forumEndPoint/boards';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final headers = MalApi.getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load forum boards');
    }
  }

  // Get forum topics - GET /forum/topics
  Future<Map<String, dynamic>> getForumTopics({
    int? boardId,
    int? subboardId,
    int? animeId,
    int? mangaId,
    String? q,
    String? topicUserName,
    String? userName,
    int limit = 100,
    int offset = 0,
    String sort = 'recent',
    bool fromHtml = false,
  }) async {
    // HTML fallback path
    if (fromHtml) {
      final result = await _getForumTopicsHtml(
        boardId: boardId,
        subboardId: subboardId,
        animeId: animeId,
        mangaId: mangaId,
        offset: offset,
      );
      return result ?? {'data': []};
    }

    // API path
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

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final headers = MalApi.getHeadersForAccountType(selectedAcc);

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load forum topics');
    }
  }

  // Get forum topic detail - GET /forum/topic/{topic_id}
  Future<Map<String, dynamic>> getForumTopicDetail(
    int topicId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final url =
        '$_forumEndPoint/topic/$topicId?limit=$limit&offset=$offset';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final headers = MalApi.getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load forum topic detail');
    }
  }

  /// HTML fallback for forum topics when API is unavailable.
  Future<Map<String, dynamic>?> _getForumTopicsHtml({
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
        return HtmlParsers.parseForumTopicsHtml(document);
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Load forum topics from a direct URL (for pagination).
  Future<Map<String, dynamic>?> getForumTopicsPage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = htmlParser.parse(response.body);
        return HtmlParsers.parseForumTopicsHtml(document);
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }
}
