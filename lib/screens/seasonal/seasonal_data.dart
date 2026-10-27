import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplayType;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A MAL seasonal anime as a card entry, with the signed-in user's list status when MAL sent one.
ListEntryView entryFromAnime(Anime a) {
  final ls = a.myListStatus;
  final status = ListEntryStatus.fromMal(ls?.status);
  final broadcast = a.broadcast;
  return ListEntryView(
    id: a.id,
    malId: a.id,
    category: 'anime',
    title: a.title,
    imageUrl: a.imageUrl.isEmpty ? null : a.imageUrl,
    largeImageUrl: a.imageUrl.isEmpty ? null : a.imageUrl,
    mediaType: a.mediaType,
    releaseState: ReleaseState.fromMal(a.status),
    meanScore: a.score > 0 ? a.score : null,
    members: a.members > 0 ? a.members : null,
    popularity: a.popularity,
    total: a.numEpisodes ?? 0,
    genres: a.genres ?? const [],
    releaseStart: a.startDate,
    releaseEnd: a.endDate,
    broadcast: broadcast == null
        ? null
        : BroadcastSlot.fromMal(broadcast.dayOfTheWeek, broadcast.startTime),
    status: status,
    score: ls?.score ?? 0,
    progress: ls?.numEpisodesWatched ?? 0,
    repeating: ls?.isRewatching ?? false,
    priority: ls?.priority ?? 0,
    updatedAt: DateTime.tryParse(ls?.updatedAt ?? ''),
  );
}

/// Downloads whole seasons and keeps the sort / filter / display of the seasonal screen.
class SeasonalData {
  SeasonalData._();

  /// Fields asked for each anime: only what the cards, sorts and filters use (the default field
  /// list also carries synopses, relations and statistics, ten times the size for 500 titles).
  static const String fields = 'id,title,main_picture,start_date,end_date,mean,popularity,'
      'num_list_users,media_type,status,genres,num_episodes,broadcast,'
      'my_list_status{status,score,num_episodes_watched,is_rewatching,updated_at,priority}';

  /// MAL serves at most 500 anime per seasonal request.
  static const int pageSize = 500;

  /// Every anime of [season], all pages, cached for ten minutes.
  static Future<List<ListEntryView>> load(SeasonKey season, {bool force = false}) {
    final key = 'season:${season.storageKey}';
    if (force) ExploreCache.instance.forget(key);
    return ExploreCache.instance.load(key, () async {
      final all = <ListEntryView>[];
      var offset = 0;
      while (true) {
        final page = await MalApi.getAnimeSeasonalResult(
          season.season,
          season.year,
          sortType: SortType.AnimeNumListUsers,
          limit: pageSize,
          offset: offset,
          fields: const [fields],
        );
        all.addAll(page.data.map(entryFromAnime));
        if (!page.hasNextPage || page.data.isEmpty) break;
        offset += pageSize;
      }
      return all;
    });
  }

  /// Sort keys the seasonal screen offers, in this order.
  static const List<String> sortKeys = [
    ListSortKeys.mean,
    ListSortKeys.members,
    ListSortKeys.popularity,
    ListSortKeys.title,
    ListSortKeys.releaseStart,
    ListSortKeys.total,
  ];

  static List<ListSortOption> sortOptions() => [
        for (final key in sortKeys)
          standardSortOptions(isAnime: true).firstWhere((o) => o.key == key),
      ];

  /// Media type, airing state and genre facets of [entries]; the facets about the user's own
  /// list (score, priority…) mean nothing for a season and are left out.
  static List<ListFilterFacet> facets(Iterable<ListEntryView> entries) => [
        for (final f in facetsFor(entries, isAnime: true))
          if (f.key == ListFacetKeys.media ||
              f.key == ListFacetKeys.release ||
              f.key == ListFacetKeys.genre)
            f,
      ];

  /// Settings used before the user changes anything: best mean score first.
  static ListViewSettings defaults() {
    final grid = Preferences.general.defaultDisplayType == DisplayType.grid;
    return ListViewSettings(
      sortKey: ListSortKeys.mean,
      display: ListDisplay(type: grid ? DisplayType.grid : DisplayType.list_vert),
    );
  }

  /// Saved settings of [season], or the shared ones when the global seasonal filter is on.
  static String settingsKey(SeasonKey season, {required bool global}) =>
      'seasonal_view_v1:${global ? 'all' : season.storageKey}';

  static Future<ListViewSettings> readSettings(SeasonKey season) async {
    final fallback = defaults();
    try {
      final global = Preferences.content.globalSeasonalFilter;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(settingsKey(season, global: global));
      if (raw == null) return fallback;
      final saved = ListViewSettings.fromJson(jsonDecode(raw), fallback);
      return sortKeys.contains(saved.sortKey) ? saved : saved.copyWith(sortKey: fallback.sortKey);
    } catch (e) {
      debugPrint('SeasonalData.readSettings: $e');
      return fallback;
    }
  }

  static Future<void> writeSettings(SeasonKey season, ListViewSettings value) async {
    try {
      final global = Preferences.content.globalSeasonalFilter;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(settingsKey(season, global: global), jsonEncode(value.toJson()));
    } catch (e) {
      debugPrint('SeasonalData.writeSettings: $e');
    }
  }
}
