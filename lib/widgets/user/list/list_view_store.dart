import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplayType;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the list was left: category and status tab per category.
@immutable
class ListPlace {
  final String category;

  /// Tab per category: `all` or a [ListEntryStatus] name.
  final Map<String, String> tabs;

  const ListPlace({this.category = 'anime', this.tabs = const {}});

  ListPlace copyWith({String? category, String? tabCategory, String? tab}) => ListPlace(
        category: category ?? this.category,
        tabs: tabCategory == null || tab == null ? tabs : {...tabs, tabCategory: tab},
      );

  Map<String, dynamic> toJson() => {'category': category, 'tabs': tabs};

  static ListPlace fromJson(Object? json) {
    if (json is! Map) return const ListPlace();
    final tabs = <String, String>{};
    if (json['tabs'] is Map) {
      (json['tabs'] as Map).forEach((k, v) {
        if (k is String && v is String) tabs[k] = v;
      });
    }
    final category = json['category'];
    return ListPlace(
      category: category == 'manga' ? 'manga' : 'anime',
      tabs: tabs,
    );
  }
}

/// Saved sort, filter and display of the user lists (DailyAL keeps the same
/// thing in its cache as `SortFilterDisplay`), and the last tab, per tracker.
///
/// SharedPreferences keys: `user_list_view_v1:<tracker>:<category>` and
/// `user_list_place_v1:<tracker>`. These are screen state, not preferences:
/// the defaults come from the preferences contract (`userListAnimeSort`,
/// `userListMangaSort`, `defaultDisplayType`).
class ListViewStore {
  const ListViewStore();

  static String _viewKey(AccountType tracker, String category) =>
      'user_list_view_v1:${tracker.name}:$category';
  static String _placeKey(AccountType tracker) => 'user_list_place_v1:${tracker.name}';

  /// Settings used before the user changes anything.
  static ListViewSettings defaults(String category) {
    final general = Preferences.general;
    final sort = category == 'anime' ? general.userListAnimeSort : general.userListMangaSort;
    final key = switch (sort) {
      'list_score' => ListSortKeys.score,
      'anime_title' || 'manga_title' || 'title' => ListSortKeys.title,
      'anime_start_date' || 'manga_start_date' => ListSortKeys.releaseStart,
      _ => ListSortKeys.updated,
    };
    final type = general.defaultDisplayType == DisplayType.grid
        ? DisplayType.grid
        : DisplayType.list_vert;
    return ListViewSettings(
      sortKey: key,
      direction: key == ListSortKeys.title ? SortDirection.ascending : SortDirection.descending,
      display: ListDisplay(type: type),
    );
  }

  Future<ListViewSettings> readView(AccountType tracker, String category) async {
    final fallback = defaults(category);
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_viewKey(tracker, category));
      if (raw == null) return fallback;
      return ListViewSettings.fromJson(jsonDecode(raw), fallback);
    } catch (e) {
      debugPrint('ListViewStore.readView: $e');
      return fallback;
    }
  }

  Future<void> writeView(AccountType tracker, String category, ListViewSettings value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewKey(tracker, category), jsonEncode(value.toJson()));
    } catch (e) {
      debugPrint('ListViewStore.writeView: $e');
    }
  }

  Future<ListPlace> readPlace(AccountType tracker) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_placeKey(tracker));
      return raw == null ? const ListPlace() : ListPlace.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('ListViewStore.readPlace: $e');
      return const ListPlace();
    }
  }

  Future<void> writePlace(AccountType tracker, ListPlace place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_placeKey(tracker), jsonEncode(place.toJson()));
    } catch (e) {
      debugPrint('ListViewStore.writePlace: $e');
    }
  }
}
