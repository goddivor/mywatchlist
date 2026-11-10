import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplayType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One MAL `node` of a seasonal answer as a card entry, with the user's list status when MAL
/// sent one.
ListEntryView weeklyEntryFromNode(Map<String, dynamic> node) {
  int toInt(Object? v) => v is num ? v.toInt() : 0;
  int? toIntOrNull(Object? v) => v is num ? v.toInt() : null;
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  final picture = node['main_picture'];
  final broadcast = node['broadcast'];
  final ls = node['my_list_status'] is Map ? node['my_list_status'] as Map : const {};
  return ListEntryView(
    id: toInt(node['id']),
    malId: toInt(node['id']),
    category: 'anime',
    title: text(node['title']) ?? '',
    imageUrl: picture is Map ? text(picture['medium']) ?? text(picture['large']) : null,
    largeImageUrl: picture is Map ? text(picture['large']) ?? text(picture['medium']) : null,
    mediaType: text(node['media_type']),
    releaseState: ReleaseState.fromMal(text(node['status'])),
    meanScore: node['mean'] is num ? (node['mean'] as num).toDouble() : null,
    members: toIntOrNull(node['num_list_users']),
    scoringUsers: toIntOrNull(node['num_scoring_users']),
    popularity: toIntOrNull(node['popularity']),
    total: toInt(node['num_episodes']),
    genres: [
      if (node['genres'] is List)
        for (final g in node['genres'] as List)
          if (g is Map && text(g['name']) != null) text(g['name'])!,
    ],
    releaseStart: text(node['start_date']),
    releaseEnd: text(node['end_date']),
    broadcast: broadcast is Map
        ? BroadcastSlot.fromMal(text(broadcast['day_of_the_week']), text(broadcast['start_time']))
        : null,
    status: ListEntryStatus.fromMal(text(ls['status'])),
    score: toInt(ls['score']),
    progress: toInt(ls['num_episodes_watched']),
    repeating: ls['is_rewatching'] == true,
    priority: toInt(ls['priority']),
    updatedAt: DateTime.tryParse(text(ls['updated_at']) ?? ''),
  );
}

List<List<ListEntryView>> _toEntries(List<List<Map<String, dynamic>>> days) => [
      for (final day in days) [for (final node in day) weeklyEntryFromNode(node)],
    ];

/// Data and saved view of the weekly anime screen (DailyAL `WeeklySchedulePage`).
class WeeklyData {
  WeeklyData._();

  /// Tabs: Monday to Sunday, then the titles without a broadcast slot.
  static const int dayCount = 8;

  /// Filter facet of the user's list status (`not_in_list` or a MAL status word).
  static const String statusFacet = 'weekly_list_status';
  static const String notInList = 'not_in_list';

  /// Every anime of [season] grouped by broadcast day in the time zone [pref], cached ten
  /// minutes per season and zone.
  static Future<List<List<ListEntryView>>> load(SeasonKey season,
      {required TimezonePref pref, bool force = false}) {
    final key = 'weekly:${season.storageKey}:${pref.name}';
    if (force) ExploreCache.instance.forget(key);
    return ExploreCache.instance.load(key, () async {
      final days = await MalApi.getSchedule(
        seasonType: season.season,
        currentYear: season.year,
        pref: pref,
      );
      return days.fold<int>(0, (n, d) => n + d.length) > 150
          ? compute(_toEntries, days)
          : _toEntries(days);
    });
  }

  /// Translated day names of the tabs (Monday… in the app locale, then "Others").
  static List<String> dayNames(String locale) => [
        for (var i = 0; i < 7; i++)
          // 2024-01-01 is a Monday.
          _capitalized(DateFormat('EEEE', locale).format(DateTime.utc(2024, 1, 1 + i))),
        S.current.Others,
      ];

  static String _capitalized(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Index of the tab of today in the time zone [pref].
  static int todayIndex(TimezonePref pref, [DateTime? now]) {
    final utc = (now ?? DateTime.now()).toUtc();
    final day = switch (pref) {
      TimezonePref.utc => utc.weekday,
      TimezonePref.jst => utc.add(const Duration(hours: 9)).weekday,
      TimezonePref.local => utc.toLocal().weekday,
    };
    return day - 1;
  }

  /// DailyAL's sorts: score, members, scorers.
  static const List<String> sortKeys = [
    ListSortKeys.mean,
    ListSortKeys.members,
    ListSortKeys.scorers,
  ];

  static List<ListSortOption> sortOptions() => [
        for (final key in sortKeys)
          standardSortOptions(isAnime: true).firstWhere((o) => o.key == key),
      ];

  /// True when the season comes with the user's list statuses (the MAL API sends them to
  /// the signed-in MyAnimeList account only).
  static bool get listKnown => AccountManagerSingleton().selectedAcc == AccountType.myanimelist;

  /// The list status facet (DailyAL's three-state "Not in list" included), then media types.
  static List<ListFilterFacet> facets(Iterable<ListEntryView> entries, {required bool listKnown}) =>
      [
        if (listKnown)
          ListFilterFacet(
            key: statusFacet,
            label: S.current.Wk_List_Status,
            allowExclude: true,
            options: [
              SelectOption(notInList, S.current.Wk_Not_In_List),
              for (final s in ListEntryStatus.values)
                SelectOption(s.malValue(isAnime: true), s.label(isAnime: true)),
            ],
          ),
        for (final f in facetsFor(entries, isAnime: true))
          if (f.key == ListFacetKeys.media) f,
      ];

  /// Value of [statusFacet] of [e].
  static String statusValue(ListEntryView e) => e.status?.malValue(isAnime: true) ?? notInList;

  /// [entries] filtered by [settings] (list status first, then the shared facets) and sorted.
  static List<ListEntryView> apply(List<ListEntryView> entries, ListViewSettings settings) {
    final filter = settings.filter;
    final included = filter.includedOf(statusFacet);
    final excluded = filter.excludedOf(statusFacet);
    final byStatus = included.isEmpty && excluded.isEmpty
        ? entries
        : [
            for (final e in entries)
              if ((included.isEmpty || included.contains(statusValue(e))) &&
                  !excluded.contains(statusValue(e)))
                e,
          ];
    final rest = filterEntries(byStatus, filter.clearFacet(statusFacet));
    return sortEntries(rest, settings.sortKey, settings.direction);
  }

  /// Settings used before the user changes anything: best mean score first.
  static ListViewSettings defaults() {
    final grid = Preferences.general.defaultDisplayType == DisplayType.grid;
    return ListViewSettings(
      sortKey: ListSortKeys.mean,
      display: ListDisplay(type: grid ? DisplayType.grid : DisplayType.list_vert),
    );
  }

  /// One saved view for every season, like DailyAL's `weekly_schedule` cache.
  static const String settingsKey = 'weekly_view_v1';

  static Future<ListViewSettings> readSettings() async {
    final fallback = defaults();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(settingsKey);
      if (raw == null) return fallback;
      final saved = ListViewSettings.fromJson(jsonDecode(raw), fallback);
      return sortKeys.contains(saved.sortKey) ? saved : saved.copyWith(sortKey: fallback.sortKey);
    } catch (e) {
      debugPrint('WeeklyData.readSettings: $e');
      return fallback;
    }
  }

  static Future<void> writeSettings(ListViewSettings value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(settingsKey, jsonEncode(value.toJson()));
    } catch (e) {
      debugPrint('WeeklyData.writeSettings: $e');
    }
  }
}
