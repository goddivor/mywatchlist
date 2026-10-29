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
    imageUrl: a.imageUrl.isEmpty ? null : mediumCover(a.imageUrl),
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

final RegExp _malLargeCover = RegExp(r'^(https://cdn\.myanimelist\.net/images/.*\d)l(\.(?:jpe?g|webp))$');

/// The medium picture of a MyAnimeList cover from its large one (`…/138006l.jpg` gives
/// `…/138006.jpg`, MAL's `main_picture.medium`). `Anime` keeps only the large picture, which list
/// rows would download and decode at about four times the pixels they show; other URLs are kept.
String mediumCover(String url) {
  final m = _malLargeCover.firstMatch(url);
  return m == null ? url : '${m[1]}${m[2]}';
}

/// Which part of a season the screen shows: everything, the shows that start in it, or the
/// leftovers of earlier seasons that still air (MAL's "TV (New)" and "TV (Continuing)").
enum SeasonGroup { all, fresh, continuing }

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

  static final Map<String, Set<int>> _continuing = {};

  /// Ids of the anime of [season] that started in an earlier season and still air (MAL's
  /// "Continuing"). Empty until [load] has read the season, and when MAL sent no `start_season`.
  static Set<int> continuingIds(SeasonKey season) => _continuing[season.storageKey] ?? const {};

  /// True when an anime that began on [startDate] (`2026-07-05`, `2026-07` or `2026`) began before
  /// [season]. `Anime` does not carry MAL's `start_season`, so the season is read from the date
  /// (winter 1-3, spring 4-6, summer 7-9, fall 10-12); an unknown or partial date counts as new.
  static bool isContinuing(String? startDate, SeasonKey season) {
    if (startDate == null) return false;
    final parts = startDate.split('-');
    final year = int.tryParse(parts.first);
    if (year == null) return false;
    if (year != season.year) return year < season.year;
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (month == null) return false;
    return (month - 1) ~/ 3 < season.season.index;
  }

  /// Every anime of [season], all pages, cached for ten minutes.
  static Future<List<ListEntryView>> load(SeasonKey season, {bool force = false}) {
    final key = 'season:${season.storageKey}';
    if (force) ExploreCache.instance.forget(key);
    return ExploreCache.instance.load(key, () async {
      final all = <ListEntryView>[];
      final continuing = <int>{};
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
        for (final a in page.data) {
          if (isContinuing(a.startDate, season)) continuing.add(a.id);
        }
        if (!page.hasNextPage || page.data.isEmpty) break;
        offset += pageSize;
      }
      _continuing[season.storageKey] = continuing;
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

  /// Settings used before the user changes anything: best mean score first, in DailyAL's list
  /// rows (the user's progress and quick +1 / -1). The grid stays a choice of the display sheet,
  /// whatever the default display of My List.
  static ListViewSettings defaults() => const ListViewSettings(
        sortKey: ListSortKeys.mean,
        display: ListDisplay(type: DisplayType.list_vert),
      );

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

  static const String _groupKey = 'seasonal_group_v1';

  static Future<SeasonGroup> readGroup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_groupKey);
      return SeasonGroup.values.firstWhere((g) => g.name == name, orElse: () => SeasonGroup.all);
    } catch (e) {
      debugPrint('SeasonalData.readGroup: $e');
      return SeasonGroup.all;
    }
  }

  static Future<void> writeGroup(SeasonGroup value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_groupKey, value.name);
    } catch (e) {
      debugPrint('SeasonalData.writeGroup: $e');
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
