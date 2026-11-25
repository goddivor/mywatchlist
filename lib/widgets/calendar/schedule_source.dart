import 'package:flutter/foundation.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/user/preferences/preferences_bloc.dart';

/// Reads one page of AniList's public GraphQL API.
typedef AnilistQuery = Future<Map<String, dynamic>> Function(String query, Map<String, dynamic> variables);

/// The airing schedule of the coming days, for the calendar and the countdown of a title.
///
/// LiveChart (through the backend) comes first. When the backend fails or gives nothing, the
/// episodes airing from yesterday to a week ahead are read from AniList's public API (episode
/// number, air time and MyAnimeList id), so the calendar does not need the backend. Throws when
/// both fail: the caller then shows its failure state.
class AiringScheduleSource {
  AiringScheduleSource({
    Future<List<LiveChartEpisode>> Function({required bool fromCache})? backend,
    AnilistQuery? anilist,
    bool Function()? adultAllowed,
    DateTime Function()? clock,
    this.backendTimeout = const Duration(seconds: 10),
  })  : _backend = backend ?? _liveChart,
        _anilist = anilist ?? _anilistQuery,
        _adult = adultAllowed ?? (() => Preferences.general.nsfw),
        _clock = clock ?? DateTime.now;

  static AiringScheduleSource instance = AiringScheduleSource();

  /// AniList pages read at most (50 episodes each).
  static const int maxPages = 12;

  final Future<List<LiveChartEpisode>> Function({required bool fromCache}) _backend;
  final AnilistQuery _anilist;
  final bool Function() _adult;
  final DateTime Function() _clock;
  final Duration backendTimeout;

  static Future<List<LiveChartEpisode>> _liveChart({required bool fromCache}) =>
      MwlApi.i.getLiveChartSchedule(fromCache: fromCache);

  static Future<Map<String, dynamic>> _anilistQuery(String query, Map<String, dynamic> variables) =>
      AnilistGraphql.instance.query(query, variables: variables);

  Future<List<LiveChartEpisode>> fetch({bool fromCache = true}) async {
    Object? backendError;
    try {
      final episodes = await _backend(fromCache: fromCache).timeout(backendTimeout);
      if (episodes.isNotEmpty) return episodes;
    } catch (e) {
      backendError = e;
    }
    try {
      return await _fromAnilist();
    } catch (e) {
      debugPrint('Airing schedule unavailable (backend: $backendError, AniList: $e)');
      rethrow;
    }
  }

  static const String _query = r'''
    query ($page: Int, $from: Int, $to: Int) {
      Page(page: $page, perPage: 50) {
        pageInfo { hasNextPage }
        airingSchedules(airingAt_greater: $from, airingAt_lesser: $to, sort: TIME) {
          episode airingAt
          media { idMal isAdult siteUrl title { romaji } }
        }
      }
    }''';

  Future<List<LiveChartEpisode>> _fromAnilist() async {
    final now = _clock().toUtc();
    final from = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
    final to = now.add(const Duration(days: 8)).millisecondsSinceEpoch ~/ 1000;
    final adult = _adult();
    final episodes = <LiveChartEpisode>[];
    for (var page = 1; page <= maxPages; page++) {
      final data = await _anilist(_query, {'page': page, 'from': from, 'to': to});
      final pageData = data['Page'];
      if (pageData is! Map) break;
      final rows = pageData['airingSchedules'];
      if (rows is List) {
        for (final row in rows) {
          if (row is! Map) continue;
          final media = row['media'];
          if (media is! Map) continue;
          final malId = (media['idMal'] as num?)?.toInt();
          final at = (row['airingAt'] as num?)?.toInt();
          if (malId == null || at == null) continue;
          if (!adult && media['isAdult'] == true) continue;
          final site = media['siteUrl'];
          episodes.add(LiveChartEpisode(
            timestamp: at,
            episode: (row['episode'] as num?)?.toInt() ?? 0,
            title: (media['title'] as Map?)?['romaji'] as String?,
            malId: malId,
            relatedLinks: {
              'mal': 'https://myanimelist.net/anime/$malId',
              if (site is String && site.isNotEmpty) 'anilist': site,
            },
          ));
        }
      }
      final info = pageData['pageInfo'];
      if (info is! Map || info['hasNextPage'] != true) break;
    }
    return episodes;
  }
}
