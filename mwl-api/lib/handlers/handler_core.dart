import 'dart:async';
import 'dart:convert';

import 'package:mwl_commons/mwl_commons.dart';
import 'package:shelf/shelf.dart';

import '../cache/cache_manager.dart';
import '../client/http_connect.dart';
import '../services/helpers.dart';
import 'environment.dart';

/// Core request router for the MWL backend.
///
/// Routes incoming requests to handler functions via [PathMatcher].
/// Supports both HTTP (Shelf) and in-process (Flutter) invocation.
class HandlerCore {
  late List<PathMatcher> _pathMatchers;

  HandlerCore() {
    _pathMatchers = [
      PathMatcher('anime/*id', _handleAnime, ['api']),
      PathMatcher('manga/*id', _handleManga, ['api']),
      PathMatcher('news', _handleNews, ['data']),
      PathMatcher('featured', _handleFeatured, ['data']),
      PathMatcher('reviews', _handleReviews),
      PathMatcher('character/*id', _handleCharacterInfo, ['data']),
      PathMatcher('people/*id', _handlePeopleInfo, ['data']),
      PathMatcher('genres', _handleGenres, ['data']),
      PathMatcher('users/search', _handleUserSearch, ['data']),
      PathMatcher('users/about', _handleUserAbout, ['data']),
      PathMatcher('users/friends', _handleUserFriends, ['data']),
      PathMatcher('users/history', _handleUserHistory, ['data']),
      PathMatcher('clubs', _handleClubs, ['data']),
      PathMatcher('schedules', _handleSchedules, ['data']),
      PathMatcher('stacks/*stackType', _handleContentStack),
      PathMatcher('content/featured', _handleContentFeatured, ['data']),
    ];
  }

  // ---------------------------------------------------------------------------
  // Entry points
  // ---------------------------------------------------------------------------

  /// In-process entry point — called from Flutter via MalConnect.
  ///
  /// Returns JSON string or null on error.
  Future<String?> handleRequestAsString(Uri uri) async {
    try {
      final result = await _handleUri(uri);
      if (result != null) {
        return jsonEncode(result);
      }
    } catch (e) {
      logMwl('handleRequestAsString error: $e');
    }
    return null;
  }

  /// Shelf HTTP entry point.
  Future<Response> handleRequest(Request request) async {
    try {
      final result = await _handleUri(request.requestedUri);
      if (result != null && (result['error'] ?? false) == true) {
        return errorResponse(result['message'] ?? 'Unknown error');
      }
      return okResponse(result ?? {'error': true});
    } catch (e) {
      logMwl('handleRequest error: $e');
      return errorResponse(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Internal routing
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _handleUri(Uri uri) async {
    final url = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;

    final PathMatcher matcher;
    try {
      matcher = _pathMatchers.firstWhere((m) => m.hasMatch(url));
    } catch (_) {
      logMwl('No route for: $url');
      return {'error': true, 'message': 'No route for: $url'};
    }

    final fromCache = queryParams<bool>(uri, 'fromCache', true)!;
    final ttlHours = queryParams<int>(uri, 'ttlHours', 1)!;

    return CacheManager.instance.getCachedResult(
      uri,
      matcher,
      fromCache: fromCache,
      ttlHours: ttlHours,
      orElse: () => matcher.handler(matcher, uri, uri.queryParameters),
    );
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Map<String, String> get _malHeaders =>
      {Constants.malClientHeader: Environment.i.malClientId ?? ''};

  /// Anime detail: MAL API v2 + HTML scraping in parallel.
  Future<Map<String, dynamic>> _handleAnime(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = path.pathParam<int>(uri.path.substring(1));
    final htmlOnly = queryParams<bool>(uri, 'htmlOnly', false)!;

    if (htmlOnly) {
      final html = await _getHtmlContent('anime', id);
      return {'url': uri.path, 'html': html, 'fromCache': false};
    }

    final results = await Future.wait([
      HttpConnect.retryGetChecked(
        '${Constants.malEndPoint}anime/$id${Constants.animeFields}',
        _malHeaders,
      ),
      _getHtmlContent('anime', id),
    ]);

    return {
      'url': uri.path,
      'api': results[0],
      'html': results[1],
      'fromCache': false,
    };
  }

  /// Manga detail: MAL API v2 + HTML scraping in parallel.
  Future<Map<String, dynamic>> _handleManga(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = path.pathParam<int>(uri.path.substring(1));
    final htmlOnly = queryParams<bool>(uri, 'htmlOnly', false)!;

    if (htmlOnly) {
      final html = await _getHtmlContent('manga', id);
      return {'url': uri.path, 'html': html, 'fromCache': false};
    }

    final results = await Future.wait([
      HttpConnect.retryGetChecked(
        '${Constants.malEndPoint}manga/$id${Constants.mangaFields}',
        _malHeaders,
      ),
      _getHtmlContent('manga', id),
    ]);

    return {
      'url': uri.path,
      'api': results[0],
      'html': results[1],
      'fromCache': false,
    };
  }

  /// News articles (HTML scraping).
  Future<Map<String, dynamic>> _handleNews(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final page = queryParams<int>(uri, 'page', 1)!;
    final tag = queryParams<String>(uri, 'tag');
    final query = queryParams<String>(uri, 'query');

    String url;
    if (tag != null && tag.isNotEmpty) {
      final formattedTag = tag.toLowerCase().replaceAll(' ', '_');
      url = '${Constants.malBaseUrl}/news/tag/$formattedTag?p=$page';
    } else if (query != null && query.isNotEmpty) {
      url = '${Constants.malBaseUrl}/news/search?q=${Uri.encodeComponent(query)}&cat=news&p=$page';
    } else {
      url = '${Constants.malBaseUrl}/news?p=$page';
    }

    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseAnimeNewsOrFeatured);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Featured articles (HTML scraping).
  Future<Map<String, dynamic>> _handleFeatured(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final page = queryParams<int>(uri, 'page', 1)!;
    final tag = queryParams<String>(uri, 'tag');
    final query = queryParams<String>(uri, 'query');

    String url;
    if (tag != null && tag.isNotEmpty) {
      final formattedTag = tag.toLowerCase().replaceAll(' ', '_');
      url = '${Constants.malBaseUrl}/featured/tag/$formattedTag?p=$page';
    } else if (query != null && query.isNotEmpty) {
      url = '${Constants.malBaseUrl}/featured/search?q=${Uri.encodeComponent(query)}&cat=featured&p=$page';
    } else {
      url = '${Constants.malBaseUrl}/featured?p=$page';
    }

    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseAnimeNewsOrFeatured);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Reviews (HTML scraping — kept as raw text since reviews use inline widget parser).
  Future<Map<String, dynamic>> _handleReviews(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = queryParams<int>(uri, 'id');
    final category = queryParams<String>(uri, 'category', 'anime')!;
    final page = queryParams<int>(uri, 'page', 1)!;

    String url;
    if (id != null) {
      url = '${Constants.malBaseUrl}/$category/$id/reviews?p=$page';
    } else {
      url = '${Constants.malBaseUrl}/reviews.php?t=$category&p=$page';
    }

    final result = await HttpConnect.htmlPage(url, (doc) => {'raw': doc.body?.text ?? ''});
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Character info from Jikan v4.
  Future<Map<String, dynamic>> _handleCharacterInfo(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = path.pathParam<int>(uri.path.substring(1));
    final result = await HttpConnect.retryGetChecked(
      '${Constants.jikanV4}characters/$id/full',
      {},
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Person/seiyuu info from Jikan v4.
  Future<Map<String, dynamic>> _handlePeopleInfo(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = path.pathParam<int>(uri.path.substring(1));
    final result = await HttpConnect.retryGetChecked(
      '${Constants.jikanV4}people/$id/full',
      {},
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Genre list (HTML scraping).
  Future<Map<String, dynamic>> _handleGenres(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final category = queryParams<String>(uri, 'category', 'anime')!;
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/$category.php',
      HtmlParsers.parseGenres,
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// User search (HTML scraping).
  Future<Map<String, dynamic>> _handleUserSearch(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final query = queryParams<String>(uri, 'q', '')!;
    final offset = queryParams<int>(uri, 'offset', 0)!;
    final url =
        '${Constants.malBaseUrl}/users.php?cat=user&q=${Uri.encodeComponent(query)}&show=$offset';
    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseUserSearch);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// User about/bio (HTML scraping — kept as raw, complex profile parsing).
  Future<Map<String, dynamic>> _handleUserAbout(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final username = queryParams<String>(uri, 'username', '')!;
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/profile/$username',
      (doc) => {'raw': doc.body?.text ?? ''},
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// User friends from Jikan v4.
  Future<Map<String, dynamic>> _handleUserFriends(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final username = queryParams<String>(uri, 'username', '')!;
    final page = queryParams<int>(uri, 'page', 1)!;
    final result = await HttpConnect.retryGetChecked(
      '${Constants.jikanV4}users/$username/friends?page=$page',
      {},
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// User history (HTML scraping).
  Future<Map<String, dynamic>> _handleUserHistory(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final username = queryParams<String>(uri, 'username', '')!;
    final type = queryParams<String>(uri, 'type', 'anime')!;
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/history/$username/$type',
      HtmlParsers.parseUserHistory,
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Clubs (HTML scraping).
  Future<Map<String, dynamic>> _handleClubs(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final query = queryParams<String>(uri, 'q');
    final page = queryParams<int>(uri, 'page', 1)!;

    String url;
    if (query != null && query.isNotEmpty) {
      url = '${Constants.malBaseUrl}/clubs.php?action=find&q=${Uri.encodeComponent(query)}&p=$page';
    } else {
      url = '${Constants.malBaseUrl}/clubs.php?p=$page';
    }

    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseClubList);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Anime schedules.
  Future<Map<String, dynamic>> _handleSchedules(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final season = queryParams<String>(uri, 'season');
    final year = queryParams<int>(uri, 'year');
    final type = queryParams<String>(uri, 'type');

    String url = '${Constants.jikanV4}schedules';
    if (type != null && type.isNotEmpty && type != 'all') {
      url += '?filter=$type';
    }
    if (season != null && year != null) {
      url += url.contains('?') ? '&sfw=true' : '?sfw=true';
    }

    final result = await HttpConnect.retryGetChecked(url, {});
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Interest stacks (HTML scraping).
  Future<Map<String, dynamic>> _handleContentStack(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final stackType = path.pathParam<String>(uri.path.substring(1));
    final query = queryParams<String>(uri, 'q');
    final page = queryParams<int>(uri, 'page', 1)!;

    String url;
    if (query != null && query.isNotEmpty) {
      url = '${Constants.malBaseUrl}/stacks/search?q=${Uri.encodeComponent(query)}&type=$stackType&p=$page';
    } else {
      url = '${Constants.malBaseUrl}/stacks?type=$stackType&p=$page';
    }

    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseInterestStackSearch);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Featured articles for a specific anime/manga (HTML scraping).
  ///
  /// Accepts optional `name` param for the slug (produces the canonical MAL URL
  /// with more results). Without it, falls back to the short URL.
  Future<Map<String, dynamic>> _handleContentFeatured(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = queryParams<int>(uri, 'id');
    final category = queryParams<String>(uri, 'category', 'anime')!;
    final name = queryParams<String>(uri, 'name');

    if (id == null) {
      return {'error': true, 'message': 'Missing id parameter'};
    }

    final slug = (name != null && name.isNotEmpty) ? '/$name' : '';
    final url = '${Constants.malBaseUrl}/$category/$id$slug/featured';
    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseAnimeFeaturedArticles);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  // ---------------------------------------------------------------------------
  // HTML scraping helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> _getHtmlContent(String category, int id) async {
    try {
      final type = category == 'manga' ? ContentType.manga : ContentType.anime;
      return await HttpConnect.htmlPage(
        '${Constants.malBaseUrl}/$category/$id',
        (doc) => HtmlParsers.parseAnimeDetailedHtml(doc, type: type),
      );
    } catch (e) {
      logMwl('_getHtmlContent error for $category/$id: $e');
      return null;
    }
  }
}
