import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mwl_api/handlers/environment.dart';
import 'package:mwl_commons/mwl_commons.dart' hide Constants, ContentType;

import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';

/// Singleton API gateway for MyWatchList.
///
/// Manages remote server config, preferred server selection, and routes
/// requests either in-process (via [MalConnect] + [HandlerCore]) or to
/// a remote backend.
class MwlApi {
  static final MwlApi i = MwlApi._();

  late Future<Servers?> _configFuture;
  late Future<String> _preferredServer;

  Servers? _config;

  MwlApi._() {
    // Initialize the backend environment with MAL credentials.
    Environment.i.initFromValues(malClientId: Constants.malclientId);

    _configFuture = _loadConfig();
    _preferredServer = _getPreferredServer();
  }

  // ---------------------------------------------------------------------------
  // Config loading
  // ---------------------------------------------------------------------------

  Future<Servers?> _loadConfig() async {
    try {
      final configUrl = Constants.appConfigUrl;
      if (configUrl.isEmpty) return null;

      final variant = Constants.buildVariant;
      final url = '$configUrl/$variant/serverConfigV1.json';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _config = Servers.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        return _config;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MwlApi: config load error: $e');
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Server selection
  // ---------------------------------------------------------------------------

  Future<String> _getPreferredServer() async {
    const fallback = 'http://0.0.0.0:8080/';
    try {
      final config = await _configFuture;
      if (config == null) return fallback;

      final servers = config.preferredServers;
      if (servers == null || servers.isEmpty) return fallback;

      final strategy = config.strategy ?? 'load';

      switch (strategy) {
        case 'random':
          servers.shuffle();
          return servers.first.url ?? fallback;

        case 'max_load_random':
          final maxLoad = config.maxLoad ?? 100;
          final eligible =
              servers.where((s) => (s.load ?? 0) < maxLoad).toList();
          if (eligible.isEmpty) return fallback;
          eligible.shuffle();
          return eligible.first.url ?? fallback;

        case 'load':
        default:
          servers.sort((a, b) => (a.load ?? 0).compareTo(b.load ?? 0));
          return servers.first.url ?? fallback;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MwlApi: server selection error: $e');
      }
    }
    return fallback;
  }

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  /// GET request routed through the preferred backend server.
  Future<dynamic> httpGet(
    String endpoint, {
    bool fromCache = true,
    int ttlHours = 1,
  }) async {
    final server = await _preferredServer;
    final separator = endpoint.contains('?') ? '&' : '?';
    final url =
        '$server$endpoint${separator}fromCache=$fromCache&ttlHours=$ttlHours';

    final response = await MalConnect.retryGet(url, {});
    if (response.statusCode == 200 && response.body.isNotEmpty) {
      return decodeJson(response.body);
    }
    return null;
  }

  /// Bodies above this size are decoded on a background isolate.
  static const int isolateDecodeThreshold = 32 * 1024;

  /// Decode a JSON body, off the UI isolate when it is large
  /// (`compute` runs inline on web).
  static Future<dynamic> decodeJson(String body) {
    if (body.length < isolateDecodeThreshold) {
      return Future.value(jsonDecode(body));
    }
    return compute(jsonDecode, body);
  }

  /// `data` field of a backend envelope.
  Future<dynamic> _getData(String endpoint, {bool fromCache = true}) async {
    final result = await httpGet(endpoint, fromCache: fromCache);
    return result is Map ? result['data'] : null;
  }

  static List<T> _listOf<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is! List) return <T>[];
    return data
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Map<String, dynamic>? _mapOf(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : null;

  /// GET request to the Rust API (MWL API URL).
  Future<dynamic> _apiGet(String endpoint) async {
    final apiUrl = Constants.apiUrl;
    if (apiUrl.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('$apiUrl$endpoint'),
        headers: {
          'Authorization': 'Bearer ${Constants.apiSecret}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return await decodeJson(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MwlApi: Rust API error: $e');
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Content endpoints (Dart backend)
  // ---------------------------------------------------------------------------

  /// Fetch anime/manga detail (MAL API v2 + HTML scraping).
  Future<Map<String, dynamic>?> getContent(
    String category,
    int id, {
    bool fromCache = true,
    int ttlHours = 1,
  }) async {
    final result = await httpGet(
      '$category/$id',
      fromCache: fromCache,
      ttlHours: ttlHours,
    );
    return result as Map<String, dynamic>?;
  }

  /// Fetch only the HTML-scraped portion of content.
  Future<Map<String, dynamic>?> getContentHtml(
    String category,
    int id, {
    bool fromCache = true,
  }) async {
    final result = await httpGet(
      '$category/$id?htmlOnly=true',
      fromCache: fromCache,
    );
    return result as Map<String, dynamic>?;
  }

  /// Fetch news articles.
  Future<Map<String, dynamic>?> getNews({
    int page = 1,
    String? tag,
    String? query,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      if (tag != null) 'tag': tag,
      if (query != null) 'query': query,
    };
    final qs = _buildQuery(params);
    final result = await httpGet('news?$qs', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch featured articles.
  Future<Map<String, dynamic>?> getFeatured({
    int page = 1,
    String? tag,
    String? query,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      if (tag != null) 'tag': tag,
      if (query != null) 'query': query,
    };
    final qs = _buildQuery(params);
    final result = await httpGet('featured?$qs', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch reviews (raw envelope; `data` is a list of [ReviewHtml] JSON).
  /// Prefer the typed [getReviewList].
  Future<Map<String, dynamic>?> getReviews({
    int? id,
    String category = 'anime',
    int page = 1,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'category': category,
      'page': page,
      if (id != null) 'id': id,
    };
    final qs = _buildQuery(params);
    final result = await httpGet('reviews?$qs', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch character info.
  Future<Map<String, dynamic>?> getCharacterInfo(
    int id, {
    bool fromCache = true,
  }) async {
    final result = await httpGet('character/$id', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch people/seiyuu info.
  Future<Map<String, dynamic>?> getPeopleInfo(
    int id, {
    bool fromCache = true,
  }) async {
    final result = await httpGet('people/$id', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch genres.
  Future<Map<String, dynamic>?> getGenres({
    String category = 'anime',
    bool fromCache = true,
  }) async {
    final result =
        await httpGet('genres?category=$category', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch user about/bio (raw envelope; `data` is [UserAboutHtml] JSON).
  /// Prefer the typed [getUserAboutHtml].
  Future<Map<String, dynamic>?> getUserAbout(
    String username, {
    bool fromCache = true,
  }) async {
    final result = await httpGet(
      'users/about?username=$username',
      fromCache: fromCache,
    );
    return result as Map<String, dynamic>?;
  }

  /// Fetch user friends.
  Future<Map<String, dynamic>?> getUserFriends(
    String username, {
    int page = 1,
    bool fromCache = true,
  }) async {
    final result = await httpGet(
      'users/friends?username=$username&page=$page',
      fromCache: fromCache,
    );
    return result as Map<String, dynamic>?;
  }

  /// Fetch user history.
  Future<Map<String, dynamic>?> getUserHistory(
    String username, {
    String type = 'anime',
    bool fromCache = true,
  }) async {
    final result = await httpGet(
      'users/history?username=$username&type=$type',
      fromCache: fromCache,
    );
    return result as Map<String, dynamic>?;
  }

  /// Fetch clubs.
  Future<Map<String, dynamic>?> getClubs({
    String? query,
    int page = 1,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      if (query != null) 'q': query,
    };
    final qs = _buildQuery(params);
    final result = await httpGet('clubs?$qs', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch anime schedules from Jikan (raw envelope).
  ///
  /// The backend's default source is now LiveChart: use
  /// [getLiveChartSchedule] for DailyAL's episode countdowns.
  Future<Map<String, dynamic>?> getSchedules({
    String? season,
    int? year,
    String type = 'all',
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'source': 'jikan',
      'type': type,
      if (season != null) 'season': season,
      if (year != null) 'year': year,
    };
    final qs = _buildQuery(params);
    final result = await httpGet('schedules?$qs', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch interest stacks.
  Future<Map<String, dynamic>?> getInterestStacks({
    required String stackType,
    String? query,
    int page = 1,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      if (query != null) 'q': query,
    };
    final qs = _buildQuery(params);
    final result =
        await httpGet('stacks/$stackType?$qs', fromCache: fromCache);
    return result as Map<String, dynamic>?;
  }

  /// Fetch interest stack detail.
  Future<Map<String, dynamic>?> getInterestStackDetail(int id, {bool fromCache = true}) async {
    final result = await httpGet('stacks/detail?id=$id', fromCache: fromCache);
    return (result as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?;
  }

  /// Fetch interest stacks for a specific anime/manga.
  Future<List<InterestStack>> getInterestStacksForContent({
    required String category,
    required int categoryId,
    int page = 1,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'category': category,
      'categoryId': categoryId,
      'page': page,
    };
    final qs = _buildQuery(params);
    final result = await httpGet('stacks/content?$qs', fromCache: fromCache);
    final data = (result as Map<String, dynamic>?)?['data'];
    if (data is List) {
      return data
          .map((e) => InterestStack.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Typed convenience methods (unwrap handler_core envelope)
  // ---------------------------------------------------------------------------

  /// Fetch anime/manga detailed HTML data (parsed).
  Future<Map<String, dynamic>?> getAnimeDetailedHtml(
    String category,
    int id, {
    bool fromCache = true,
  }) async {
    final result = await getContentHtml(category, id, fromCache: fromCache);
    return result?['html'] as Map<String, dynamic>?;
  }

  /// Search MAL users.
  Future<MalUserSearchResult?> searchUsers(
    String query, {
    int offset = 0,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'q': query,
      'offset': offset,
    };
    final qs = _buildQuery(params);
    final result = await httpGet('users/search?$qs', fromCache: fromCache);
    final data = (result as Map<String, dynamic>?)?['data'];
    if (data is Map<String, dynamic>) {
      return MalUserSearchResult.fromJson(data);
    }
    return null;
  }

  /// Search news articles (typed).
  Future<AnimeNewsOrFeaturedResult?> searchNews(
    String query, {
    String? tag,
    int page = 1,
    bool fromCache = true,
  }) async {
    final result =
        await getNews(query: query, tag: tag, page: page, fromCache: fromCache);
    final data = result?['data'];
    if (data is Map<String, dynamic>) {
      return AnimeNewsOrFeaturedResult.fromJson(data);
    }
    return null;
  }

  /// Search featured articles (typed).
  Future<AnimeNewsOrFeaturedResult?> searchFeatured(
    String query, {
    String? tag,
    int page = 1,
    bool fromCache = true,
  }) async {
    final result = await getFeatured(
        query: query, tag: tag, page: page, fromCache: fromCache);
    final data = result?['data'];
    if (data is Map<String, dynamic>) {
      return AnimeNewsOrFeaturedResult.fromJson(data);
    }
    return null;
  }

  /// Search clubs (typed).
  Future<Map<String, dynamic>?> searchClubs(
    String query, {
    int page = 1,
    bool fromCache = true,
  }) async {
    final result =
        await getClubs(query: query, page: page, fromCache: fromCache);
    return result?['data'] as Map<String, dynamic>?;
  }

  /// Search interest stacks (typed).
  Future<List<Map<String, dynamic>>> searchInterestStacks(
    String query, {
    String? type,
    int page = 1,
    bool fromCache = true,
  }) async {
    final result = await getInterestStacks(
      stackType: type ?? 'anime',
      query: query,
      page: page,
      fromCache: fromCache,
    );
    final data = result?['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  /// Get featured articles for a specific content (anime/manga).
  ///
  /// Pass [name] (the anime/manga title) to get the full featured page
  /// from MAL (canonical URL with slug).
  Future<Map<String, dynamic>?> getContentFeaturedArticles(
    int id,
    String category, {
    String? name,
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
      'id': id,
      'category': category,
      if (name != null) 'name': name,
    };
    final qs = _buildQuery(params);
    final result = await httpGet(
      'content/featured?$qs',
      fromCache: fromCache,
    );
    return (result as Map<String, dynamic>?)?['data'] as Map<String, dynamic>?;
  }

  /// Fetch full recommendation data (with user comments) for a specific content.
  Future<List<Map<String, dynamic>>> getRecommendationData({
    required int id,
    required String category,
    bool fromCache = true,
  }) async {
    final result = await httpGet(
      'recommendations?id=$id&category=$category',
      fromCache: fromCache,
    );
    final data = (result as Map<String, dynamic>?)?['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  // ---------------------------------------------------------------------------
  // DailyAL page routes (typed)
  // ---------------------------------------------------------------------------

  /// Every character (with voice actors) and the staff of an anime or manga
  /// (`category` is `anime` or `manga`). Null when the page failed.
  Future<ContentCharactersHtml?> getContentCharacters(
    int id, {
    String category = 'anime',
    bool fromCache = true,
  }) async {
    final data = _mapOf(await _getData(
      'content/characters?${_buildQuery({'id': id, 'category': category})}',
      fromCache: fromCache,
    ));
    return data == null ? null : ContentCharactersHtml.fromJson(data);
  }

  /// Longest wait for [getContentStats] before it gives up (null).
  static const contentStatsTimeout = Duration(seconds: 15);

  /// Score distribution and status counts of an anime or manga from MAL's
  /// stats page (`category` is `anime` or `manga`), so the score stats
  /// work without Jikan. The page is parsed and the JSON decoded off the UI
  /// isolate. Null when the page failed, the parameters were refused or no
  /// answer came within [contentStatsTimeout]; never throws.
  Future<ContentStatsHtml?> getContentStats(
    int id,
    String category, {
    bool fromCache = true,
  }) =>
      fetchContentStats(
        () => _getData(
          'content/stats?${_buildQuery({'id': id, 'category': category})}',
          fromCache: fromCache,
        ),
      );

  /// [getContentStats] around any [getData] source of the `data` field
  /// (exposed so the timeout and failure paths are tested offline).
  @visibleForTesting
  static Future<ContentStatsHtml?> fetchContentStats(
    Future<dynamic> Function() getData, {
    Duration timeout = contentStatsTimeout,
  }) async {
    try {
      final data = _mapOf(await getData().timeout(timeout));
      if (data == null) return null;
      return ContentStatsHtml.fromJson(data);
    } catch (e) {
      if (kDebugMode) debugPrint('MwlApi: content stats error: $e');
      return null;
    }
  }

  /// Full-size picture URLs of a character.
  Future<List<String>> getCharacterPictures(int id,
          {bool fromCache = true}) =>
      _pictures('character/$id/pics', fromCache);

  /// Full-size picture URLs of a person.
  Future<List<String>> getPeoplePictures(int id, {bool fromCache = true}) =>
      _pictures('people/$id/pics', fromCache);

  Future<List<String>> _pictures(String endpoint, bool fromCache) async {
    final data = await _getData(endpoint, fromCache: fromCache);
    return data is List ? data.whereType<String>().toList() : <String>[];
  }

  /// Top characters by favorites, 50 per page (page starts at 1).
  Future<List<RankedPersonHtml>> getTopCharacters({
    int page = 1,
    bool fromCache = true,
  }) async =>
      _listOf(await _getData('characters?page=$page', fromCache: fromCache),
          RankedPersonHtml.fromJson);

  /// Top people by favorites, 50 per page (page starts at 1).
  Future<List<RankedPersonHtml>> getTopPeople({
    int page = 1,
    bool fromCache = true,
  }) async =>
      _listOf(await _getData('people?page=$page', fromCache: fromCache),
          RankedPersonHtml.fromJson);

  /// Manga magazines: MAL id to name, most entries first.
  Future<Map<int, String>> getMagazines({bool fromCache = true}) =>
      _producers('magazines', fromCache);

  /// Anime studios and producers: MAL id to name, most entries first.
  Future<Map<int, String>> getStudios({bool fromCache = true}) =>
      _producers('studios', fromCache);

  Future<Map<int, String>> _producers(String endpoint, bool fromCache) async {
    final data = await _getData(endpoint, fromCache: fromCache);
    final result = <int, String>{};
    if (data is Map) {
      data.forEach((key, value) {
        final id = int.tryParse('$key');
        if (id != null && value is String) result[id] = value;
      });
    }
    return result;
  }

  /// A club page (information, members, pictures, topics, comments, staff,
  /// relations). Null when the page failed.
  Future<ClubPageHtml?> getClubPage(int id, {bool fromCache = true}) async {
    final data = _mapOf(await _getData('clubs?id=$id', fromCache: fromCache));
    return data == null ? null : ClubPageHtml.fromJson(data);
  }

  /// Club members, 36 per page ([offset] is MAL's `show` offset).
  Future<List<MalUserRef>> getClubMembers(
    int id, {
    int offset = 0,
    bool fromCache = true,
  }) async =>
      _listOf(await _clubViewAll(id, 'members', offset, fromCache),
          MalUserRef.fromJson);

  /// Club forum topics, 50 per page ([offset] is MAL's `show` offset).
  Future<List<ForumTopicHtml>> getClubForumTopics(
    int id, {
    int offset = 0,
    bool fromCache = true,
  }) async =>
      _listOf(await _clubViewAll(id, 'forum', offset, fromCache),
          ForumTopicHtml.fromJson);

  /// Club comments, newest first, 20 per page ([offset] is MAL's `show`
  /// offset).
  Future<List<ClubCommentHtml>> getClubComments(
    int id, {
    int offset = 0,
    bool fromCache = true,
  }) async =>
      _listOf(await _clubViewAll(id, 'comments', offset, fromCache),
          ClubCommentHtml.fromJson);

  Future<dynamic> _clubViewAll(
          int id, String type, int offset, bool fromCache) =>
      _getData(
        'clubs/type?${_buildQuery({'id': id, 'type': type, 'offset': offset})}',
        fromCache: fromCache,
      );

  /// Reviews: of one anime/manga when [id] is given (most voted first),
  /// else MAL's latest reviews of [category].
  Future<List<ReviewHtml>> getReviewList({
    int? id,
    String category = 'anime',
    int page = 1,
    bool fromCache = true,
  }) async {
    final result = await getReviews(
        id: id, category: category, page: page, fromCache: fromCache);
    return _listOf(result?['data'], ReviewHtml.fromJson);
  }

  /// "About me" of a MAL profile. Null when the page failed.
  Future<UserAboutHtml?> getUserAboutHtml(
    String username, {
    bool fromCache = true,
  }) async {
    final result = await getUserAbout(
      Uri.encodeQueryComponent(username),
      fromCache: fromCache,
    );
    final data = _mapOf(result?['data']);
    return data == null ? null : UserAboutHtml.fromJson(data);
  }

  /// Upcoming episodes of a season from LiveChart.me.
  ///
  /// [season] is `winter`, `spring`, `summer` or `fall`; [season] and
  /// [year] default to the current season; [type] is LiveChart's filter
  /// (`all`, `tv`, `movies`, `ovas`, …).
  Future<List<LiveChartEpisode>> getLiveChartSchedule({
    String? season,
    int? year,
    String type = 'all',
    bool fromCache = true,
  }) async {
    final qs = _buildQuery({'season': season, 'year': year, 'type': type});
    return _listOf(await _getData('schedules?$qs', fromCache: fromCache),
        LiveChartEpisode.fromJson);
  }

  /// MAL "all" search, grouped by category (every category key present).
  /// Null when the page failed.
  Future<SearchAllResult?> searchAll(
    String query, {
    bool fromCache = true,
  }) async {
    final data = _mapOf(await _getData(
      'search/all?${_buildQuery({'q': query})}',
      fromCache: fromCache,
    ));
    return data == null ? null : SearchAllResult.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Rust API endpoints
  // ---------------------------------------------------------------------------

  /// Fetch anime relation graph from Rust API.
  Future<Map<String, dynamic>?> getAnimeGraph(int id) async {
    final result = await _apiGet('/anime/$id/related');
    return result as Map<String, dynamic>?;
  }

  /// Get AI-generated review summary from Rust API.
  Future<Map<String, dynamic>?> getReviewsSummary(
    int id,
    String category,
    List<String> reviews,
  ) async {
    final apiUrl = Constants.apiUrl;
    if (apiUrl.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/reviews'),
        headers: {
          'Authorization': 'Bearer ${Constants.apiSecret}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'category': category,
          'reviews': reviews,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return await decodeJson(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MwlApi: review summary error: $e');
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Feature flags
  // ---------------------------------------------------------------------------

  /// Check if a feature flag is enabled in the remote config.
  bool isFeatureEnabled(FeatureFlag flag) {
    return _config?.featureFlags?[flag.name] ?? false;
  }

  /// Check if a platform is under maintenance per remote config.
  bool isPlatformUnderMaintenance(PlatformType platform) {
    final maintenances = _config?.platformMaintenances;
    if (maintenances == null) return false;
    return maintenances
            .where((m) => m.platform == platform)
            .firstOrNull
            ?.maintenance ??
        false;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _buildQuery(Map<String, dynamic> params) {
    final entries = params.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}');
    return entries.join('&');
  }
}
