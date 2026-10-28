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
      PathMatcher('reviews', _handleReviews, ['data']),
      PathMatcher('content/characters', _handleAllCharacters, ['data']),
      PathMatcher('content/stats', _handleContentStats, ['data']),
      PathMatcher('character/*id', _handleCharacterInfo, ['data']),
      PathMatcher('character/*id/pics', _handleCharacterPics, ['data']),
      PathMatcher('characters', _handleCharacterHome, ['data']),
      PathMatcher('people/*id', _handlePeopleInfo, ['data']),
      PathMatcher('people/*id/pics', _handlePeoplePics, ['data']),
      PathMatcher('people', _handlePeopleHome, ['data']),
      PathMatcher('magazines', _handleMagazines, ['data']),
      PathMatcher('studios', _handleStudios, ['data']),
      PathMatcher('search/all', _handleSearchAll, ['data']),
      PathMatcher('genres', _handleGenres, ['data']),
      PathMatcher('users/search', _handleUserSearch, ['data']),
      PathMatcher('users/about', _handleUserAbout, ['data']),
      PathMatcher('users/friends', _handleUserFriends, ['data']),
      PathMatcher('users/history', _handleUserHistory, ['data']),
      PathMatcher('users/clubs', _handleUserClubs, ['data']),
      PathMatcher('clubs', _handleClubs, ['data']),
      PathMatcher('clubs/type', _handleClubViewAll, ['data']),
      PathMatcher('schedules', _handleSchedules, ['data']),
      PathMatcher('stacks/detail', _handleStackDetail, ['data']),
      PathMatcher('stacks/content', _handleStackContent, ['data']),
      PathMatcher('stacks/*stackType', _handleContentStack),
      PathMatcher('content/featured', _handleContentFeatured, ['data']),
      PathMatcher('recommendations/recent', _handleRecentRecommendations, ['data']),
      PathMatcher('recommendations', _handleRecommendations),
    ];
  }

  // ---------------------------------------------------------------------------
  // Entry points
  // ---------------------------------------------------------------------------

  /// In-process entry point — called from Flutter via MalConnect.
  ///
  /// Returns JSON string, the error body of a refused request, or null on
  /// any other error.
  Future<String?> handleRequestAsString(Uri uri) async {
    try {
      final result = await _handleUri(uri);
      if (result != null) {
        return jsonEncode(result);
      }
    } on BadRequest catch (e) {
      return jsonEncode(badRequestBody(e.message));
    } catch (e) {
      logMwl('handleRequestAsString error: $e');
    }
    return null;
  }

  /// Shelf HTTP entry point.
  Future<Response> handleRequest(Request request) =>
      respond(request.requestedUri);

  /// Answers [uri]: 200 with the result, 400 when a parameter is missing or
  /// invalid ([BadRequest]), 500 on any other error.
  Future<Response> respond(Uri uri) async {
    try {
      final result = await _handleUri(uri);
      if (result != null && (result['error'] ?? false) == true) {
        return errorResponse(result['message'] ?? 'Unknown error');
      }
      return okResponse(result ?? {'error': true});
    } on BadRequest catch (e) {
      return badRequestResponse(e.message);
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
    final id = path.intPathParam(uri.path.substring(1));
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
    final id = path.intPathParam(uri.path.substring(1));
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

  /// Reviews (HTML scraping), parsed into `ReviewHtml` items.
  ///
  /// With `id`: reviews of that anime/manga, most voted first; without:
  /// MAL's latest reviews of the `category`.
  Future<Map<String, dynamic>> _handleReviews(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = queryParams<int>(uri, 'id');
    final category = _category(uri);
    final page = queryParams<int>(uri, 'page', 1)!;

    final url = id != null
        ? '${Constants.malBaseUrl}/$category/$id/_/reviews?sort=mostvoted&p=$page'
        : '${Constants.malBaseUrl}/reviews.php?t=$category&p=$page';

    final result = await HttpConnect.htmlPage(url, PageParsers.getReviews);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Every character (with voice actors) and staff member of a content.
  Future<Map<String, dynamic>> _handleAllCharacters(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = queryParams<int>(uri, 'id');
    if (id == null) throw _missing('id');
    final category = _category(uri);
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/$category/$id/_/characters',
      (doc) => PageParsers.parseCharacterAllPage(doc, category),
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Score distribution and status counts of an anime or manga, from
  /// MAL's stats page: `{scores: [{score, votes, percentage}], statuses:
  /// {watching, completed, on_hold, dropped, plan_to_watch, total}}`
  /// (`ContentStatsHtml`). `id` is required and numeric; `category` is
  /// `anime` (default) or `manga`, anything else answers 400.
  Future<Map<String, dynamic>> _handleContentStats(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = queryParams<int>(uri, 'id');
    if (id == null || id <= 0) throw _missing('id');
    final category = queryParams<String>(uri, 'category', 'anime')!;
    if (category != 'anime' && category != 'manga') {
      throw _missing('category');
    }
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/$category/$id/x/stats',
      PageParsers.parseContentStats,
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  Future<Map<String, dynamic>> _handleCharacterPics(
          PathMatcher path, Uri uri, Map<String, String> params) =>
      _handlePics('character', path, uri);

  Future<Map<String, dynamic>> _handlePeoplePics(
          PathMatcher path, Uri uri, Map<String, String> params) =>
      _handlePics('people', path, uri);

  /// Full-size picture URLs of a character or a person.
  Future<Map<String, dynamic>> _handlePics(
      String type, PathMatcher path, Uri uri) async {
    final id = path.intPathParam(uri.path.substring(1));
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/$type/$id/_/pics',
      PageParsers.parsePicturesPage,
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  Future<Map<String, dynamic>> _handleCharacterHome(
          PathMatcher path, Uri uri, Map<String, String> params) =>
      _handleRanking('character', uri);

  Future<Map<String, dynamic>> _handlePeopleHome(
          PathMatcher path, Uri uri, Map<String, String> params) =>
      _handleRanking('people', uri);

  /// Top characters / top people by favorites, 50 per page.
  Future<Map<String, dynamic>> _handleRanking(String type, Uri uri) async {
    final page = queryParams<int>(uri, 'page', 1)!;
    final offset = (page < 1 ? 0 : page - 1) * 50;
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/$type.php?limit=$offset',
      (doc) => PageParsers.parseCharacterPeopleHome(doc, type),
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  Future<Map<String, dynamic>> _handleMagazines(
          PathMatcher path, Uri uri, Map<String, String> params) =>
      _handleProducers('manga', uri);

  Future<Map<String, dynamic>> _handleStudios(
          PathMatcher path, Uri uri, Map<String, String> params) =>
      _handleProducers('anime', uri);

  /// Studios (anime) or magazines (manga): `{ "<id>": "<name>" }`.
  Future<Map<String, dynamic>> _handleProducers(
      String category, Uri uri) async {
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/$category.php',
      (doc) => PageParsers.parseMagazines(doc, category),
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// MAL "all" search, grouped by category.
  Future<Map<String, dynamic>> _handleSearchAll(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final query = queryParams<String>(uri, 'q', '')!;
    if (query.trim().isEmpty) throw _missing('q');
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/search/all?q=${Uri.encodeQueryComponent(query)}&cat=all',
      PageParsers.allSearchResultFromHtml,
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Character info from Jikan v4.
  Future<Map<String, dynamic>> _handleCharacterInfo(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = path.intPathParam(uri.path.substring(1));
    final result = await HttpConnect.retryGetChecked(
      '${Constants.jikanV4}characters/$id/full',
      {},
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Person/seiyuu info from Jikan v4.
  Future<Map<String, dynamic>> _handlePeopleInfo(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = path.intPathParam(uri.path.substring(1));
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

  /// User "about me" (HTML scraping), parsed into `UserAboutHtml`.
  Future<Map<String, dynamic>> _handleUserAbout(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final username = queryParams<String>(uri, 'username', '')!;
    if (username.isEmpty) throw _missing('username');
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/profile/${Uri.encodeComponent(username)}',
      PageParsers.parseUserAboutPage,
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

  /// The clubs a user belongs to (HTML scraping of `/profile/<name>/clubs`).
  Future<Map<String, dynamic>> _handleUserClubs(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final username = queryParams<String>(uri, 'username', '')!;
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/profile/${Uri.encodeComponent(username)}/clubs',
      HtmlParsers.parseUserClubs,
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Clubs (HTML scraping).
  ///
  /// With `id`: that club's page (`ClubPageHtml`). Without: the club list,
  /// or a club search when `q` is given (MWL behaviour, kept).
  Future<Map<String, dynamic>> _handleClubs(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = queryParams<int>(uri, 'id');
    if (id != null) {
      final result = await HttpConnect.htmlPage(
        '${Constants.malBaseUrl}/clubs.php?cid=$id',
        PageParsers.parseClubPage,
      );
      return {'url': uri.path, 'data': result, 'fromCache': false};
    }

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

  /// "See all" pages of a club: `type` is `members`, `forum` or `comments`,
  /// `offset` the MAL `show` offset (36, 50 and 20 items per page).
  Future<Map<String, dynamic>> _handleClubViewAll(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final type = queryParams<String>(uri, 'type');
    final id = queryParams<int>(uri, 'id');
    if (id == null) throw _missing('id');
    if (!const ['members', 'forum', 'comments'].contains(type)) {
      throw _missing('type');
    }
    final offset = queryParams<int>(uri, 'offset', 0)!;
    final url = type == 'forum'
        ? '${Constants.malBaseUrl}/forum/?clubid=$id&show=$offset'
        : '${Constants.malBaseUrl}/clubs.php?action=view&t=$type&id=$id&show=$offset';
    final result = await HttpConnect.htmlPage(
      url,
      (doc) => PageParsers.parseClubPageViewAll(doc, type!),
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Anime schedules.
  ///
  /// Default source is LiveChart.me (DailyAL behaviour): `season`
  /// (`winter|spring|summer|fall`, current one by default), `year` and
  /// `type` (`all`, `tv`, …) give a list of `LiveChartEpisode`.
  /// `source=jikan` keeps the former Jikan `/schedules` proxy.
  Future<Map<String, dynamic>> _handleSchedules(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final source = queryParams<String>(uri, 'source', 'livechart')!;
    final type = queryParams<String>(uri, 'type');

    if (source == 'jikan') {
      String url = '${Constants.jikanV4}schedules';
      if (type != null && type.isNotEmpty && type != 'all') {
        url += '?filter=$type';
      }
      final result = await HttpConnect.retryGetChecked(url, {});
      return {'url': uri.path, 'data': result, 'fromCache': false};
    }

    final current = currentSeason(DateTime.now());
    final rawYear = uri.queryParameters['year'];
    final year = rawYear == null ? current.year : int.tryParse(rawYear);
    if (year == null) throw _missing('year');
    final season = queryParams<String>(uri, 'season', current.season)!;
    if (!seasons.contains(season)) throw _missing('season');
    final result = await HttpConnect.htmlPage(
      'https://www.livechart.me/$season-$year/${type ?? 'all'}',
      PageParsers.parseLiveChartSchedule,
    );
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
      // `/stacks?type=` is the hub page (no list); the paged listing is `/stacks/search`.
      url = '${Constants.malBaseUrl}/stacks/search?type=$stackType&p=$page';
    }

    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseInterestStackSearch);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Interest stack detail (HTML scraping).
  Future<Map<String, dynamic>> _handleStackDetail(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final id = queryParams<int>(uri, 'id');
    if (id == null) {
      throw _missing('id');
    }

    final url = '${Constants.malBaseUrl}/stacks/$id?view_style=seasonal';
    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseInterestStackDetail);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// Interest stacks for a specific anime/manga (HTML scraping).
  ///
  /// URL: `/{category}/{id}/_/stacks?offset=N`
  Future<Map<String, dynamic>> _handleStackContent(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final category = queryParams<String>(uri, 'category', 'anime')!;
    final categoryId = queryParams<int>(uri, 'categoryId');
    final page = queryParams<int>(uri, 'page', 1)!;

    if (categoryId == null) {
      throw _missing('categoryId');
    }

    final offset = (page - 1) * 20;
    final url =
        '${Constants.malBaseUrl}/$category/$categoryId/_/stacks?offset=$offset';
    final result = await HttpConnect.htmlPage(
        url, HtmlParsers.parseInterestStackContent);
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
      throw _missing('id');
    }

    final slug = (name != null && name.isNotEmpty) ? '/$name' : '';
    final url = '${Constants.malBaseUrl}/$category/$id$slug/featured';
    final result = await HttpConnect.htmlPage(url, HtmlParsers.parseAnimeFeaturedArticles);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// User recommendations for a specific anime/manga (HTML scraping).
  ///
  /// URL: `/{category}/{id}/_/userrecs`
  Future<Map<String, dynamic>> _handleRecommendations(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final category = queryParams<String>(uri, 'category', 'anime')!;
    final categoryId = queryParams<int>(uri, 'id');

    if (categoryId == null) {
      throw _missing('id');
    }

    final url = '${Constants.malBaseUrl}/$category/$categoryId/_/userrecs';
    final result =
        await HttpConnect.htmlPage(url, HtmlParsers.getRecommendations);
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  /// MAL's global feed of recommendations
  /// (`recommendations.php?s=recentrecs&t=<category>&show=<offset>`, 100 per page).
  Future<Map<String, dynamic>> _handleRecentRecommendations(
      PathMatcher path, Uri uri, Map<String, String> params) async {
    final category = _category(uri);
    final show = queryParams<int>(uri, 'show', 0)!;
    if (show < 0) throw _missing('show');
    final result = await HttpConnect.htmlPage(
      '${Constants.malBaseUrl}/recommendations.php?s=recentrecs&t=$category&show=$show',
      (doc) => PageParsers.parseRecentRecommendations(doc, category),
    );
    return {'url': uri.path, 'data': result, 'fromCache': false};
  }

  // ---------------------------------------------------------------------------
  // HTML scraping helpers
  // ---------------------------------------------------------------------------

  /// `category` query parameter restricted to `anime` or `manga`.
  String _category(Uri uri) =>
      queryParams<String>(uri, 'category', 'anime') == 'manga'
          ? 'manga'
          : 'anime';

  /// Refusal of a missing or invalid [param]: thrown, it answers 400.
  BadRequest _missing(String param) =>
      BadRequest('Missing or invalid $param parameter');

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

/// LiveChart season names, in calendar order.
const seasons = ['winter', 'spring', 'summer', 'fall'];

/// Current anime season of [date], LiveChart style: a season starts on the
/// 28th of the month before its first month (so 28 Dec is next year's
/// winter). Ported from DailyAL `_getSeason`.
({String season, int year}) currentSeason(DateTime date) {
  final month = date.month;
  final day = date.day;
  if (month == 12 && day >= 28) return (season: 'winter', year: date.year + 1);
  final shifted = day >= 28 && month % 3 == 0 ? month + 1 : month;
  final index = ((shifted - 1) ~/ 3) % 4;
  return (season: seasons[index], year: date.year);
}
