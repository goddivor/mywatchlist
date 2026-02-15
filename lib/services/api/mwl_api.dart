import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mwl_api/handlers/environment.dart';
import 'package:mwl_commons/mwl_commons.dart' hide Constants;

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
      return jsonDecode(response.body);
    }
    return null;
  }

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
        return jsonDecode(response.body);
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

  /// Fetch reviews.
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

  /// Fetch user about/bio.
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

  /// Fetch anime schedules.
  Future<Map<String, dynamic>?> getSchedules({
    String? season,
    int? year,
    String type = 'all',
    bool fromCache = true,
  }) async {
    final params = <String, dynamic>{
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
        return jsonDecode(response.body) as Map<String, dynamic>;
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
