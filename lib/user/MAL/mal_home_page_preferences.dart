import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' hide myAnimeStatusMap;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:shared_preferences/shared_preferences.dart';



/// Kinds of home section. New kinds are only ever appended: the saved JSON stores the index.
enum SectionType {
  news,
  seasonNow,
  suggested,
  upcoming,
  topScore,
  topFavorites,
  topPopular,
  topAnimeAiring,
  topAnimeTV,
  topAnimeMovie,
  topAnimeSpecial,
  topManga,
  topMangaPopular,
  features,
  userList,
  forum,
}

/// Bounds of the per-section item count (the slider of the home settings). MAL's ranking,
/// seasonal and suggestion endpoints all accept that many in one call.
const int kHomeRowMinItems = 5;
const int kHomeRowMaxItems = 30;

/// The order of the kinds in the "section type" picker: anime rows, then manga rows, then the
/// others (the enum order is the storage order and cannot be regrouped).
const List<SectionType> kSectionPickerOrder = [
  SectionType.seasonNow,
  SectionType.suggested,
  SectionType.upcoming,
  SectionType.topScore,
  SectionType.topAnimeAiring,
  SectionType.topPopular,
  SectionType.topFavorites,
  SectionType.topAnimeTV,
  SectionType.topAnimeMovie,
  SectionType.topAnimeSpecial,
  SectionType.topManga,
  SectionType.topMangaPopular,
  SectionType.userList,
  SectionType.forum,
  SectionType.news,
  SectionType.features,
];

extension SectionTypeRanking on SectionType {
  /// The MAL anime ranking behind the row, null when it is not an anime ranking.
  RankingType? get animeRanking => switch (this) {
        SectionType.upcoming => RankingType.UPCOMING,
        SectionType.topScore => RankingType.ALL,
        SectionType.topFavorites => RankingType.FAVOURITE,
        SectionType.topPopular => RankingType.BYPOPULARITY,
        SectionType.topAnimeAiring => RankingType.AIRING,
        SectionType.topAnimeTV => RankingType.TV,
        SectionType.topAnimeMovie => RankingType.MOVIE,
        SectionType.topAnimeSpecial => RankingType.SPECIAL,
        _ => null,
      };

  /// The MAL manga ranking behind the row, null when it is not a manga ranking.
  MangaRanking? get mangaRanking => switch (this) {
        SectionType.topManga => MangaRanking.all,
        SectionType.topMangaPopular => MangaRanking.bypopularity,
        _ => null,
      };

  /// A row of anime or manga cards filled by the shared home requests (RequestsBloc).
  bool get isContentRow =>
      this == SectionType.seasonNow ||
      this == SectionType.suggested ||
      animeRanking != null ||
      mangaRanking != null;
}

class HomeSectionPreference {
  SectionType type;
  bool enabled;
  int itemCount;
  String? customTitle;
  int cacheDurationHours;

  /// [SectionType.userList]: `anime` or `manga`.
  String userCategory;

  /// [SectionType.userList]: the MAL status key (`watching`, `completed`…), null for all.
  String? userStatus;

  /// [SectionType.forum]: board and sub-board ids (MAL), null for the recent topics of the forum.
  int? boardId;
  int? subboardId;

  /// [SectionType.seasonNow]: a fixed season, null for the current one.
  SeasonType? season;
  int? year;

  HomeSectionPreference({
    required this.type,
    this.enabled = true,
    this.itemCount = 15,
    this.customTitle,
    this.cacheDurationHours = 2,
    this.userCategory = 'anime',
    this.userStatus,
    this.boardId,
    this.subboardId,
    this.season,
    this.year,
  });

  HomeSectionPreference copy() => HomeSectionPreference(
        type: type,
        enabled: enabled,
        itemCount: itemCount,
        customTitle: customTitle,
        cacheDurationHours: cacheDurationHours,
        userCategory: userCategory,
        userStatus: userStatus,
        boardId: boardId,
        subboardId: subboardId,
        season: season,
        year: year,
      );

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'enabled': enabled,
      'itemCount': itemCount,
      'customTitle': customTitle,
      'cacheDurationHours': cacheDurationHours,
      'userCategory': userCategory,
      'userStatus': userStatus,
      'boardId': boardId,
      'subboardId': subboardId,
      'season': season?.name,
      'year': year,
    };
  }

  // Create from JSON when loading (tolerant: a missing or odd field takes its default)
  static HomeSectionPreference? tryFromJson(Map<String, dynamic> json) {
    final typeIndex = json['type'];
    if (typeIndex is! int || typeIndex < 0 || typeIndex >= SectionType.values.length) {
      return null;
    }
    final seasonName = json['season'];
    return HomeSectionPreference(
      type: SectionType.values[typeIndex],
      enabled: json['enabled'] as bool? ?? true,
      itemCount: ((json['itemCount'] as num?)?.toInt() ?? 15)
          .clamp(kHomeRowMinItems, kHomeRowMaxItems),
      customTitle: json['customTitle'] as String?,
      cacheDurationHours: json['cacheDurationHours'] as int? ?? 2,
      userCategory: json['userCategory'] == 'manga' ? 'manga' : 'anime',
      userStatus: json['userStatus'] as String?,
      boardId: json['boardId'] as int?,
      subboardId: json['subboardId'] as int?,
      season: SeasonType.values.where((s) => s.name == seasonName).firstOrNull,
      year: json['year'] as int?,
    );
  }

  /// The season a [SectionType.seasonNow] section shows.
  SeasonType get effectiveSeason => season ?? MalApi.getSeasonType();
  int get effectiveYear => year ?? MalApi.getCurrentSeasonYear();

  /// The title of the section in the app language (read at each build, so a language change
  /// applies at once).
  String getDefaultTitle() {
    final s = S.current;
    switch (type) {
      case SectionType.news:
        return s.Hw_Sec_News;
      case SectionType.seasonNow:
        return s.Hw_Sec_Season(seasonLabel(effectiveSeason), '$effectiveYear');
      case SectionType.suggested:
        return s.Hw_Sec_Suggested;
      case SectionType.upcoming:
        return s.Hw_Sec_Upcoming;
      case SectionType.topScore:
        return s.Hw_Sec_Top_Score;
      case SectionType.topFavorites:
        return s.Hw_Sec_Favorites;
      case SectionType.topPopular:
        return s.Hw_Sec_Popular;
      case SectionType.topAnimeAiring:
        return s.Hw_Sec_Airing;
      case SectionType.topAnimeTV:
        return s.Hw_Sec_Tv;
      case SectionType.topAnimeMovie:
        return s.Hw_Sec_Movie;
      case SectionType.topAnimeSpecial:
        return s.Hw_Sec_Special;
      case SectionType.topManga:
        return s.Hw_Sec_Top_Manga;
      case SectionType.topMangaPopular:
        return s.Hw_Sec_Popular_Manga;
      case SectionType.features:
        return s.Hw_Sec_Features;
      case SectionType.userList:
        final list = userCategory == 'manga' ? s.Hw_Sec_List_Manga : s.Hw_Sec_List_Anime;
        final labels = userCategory == 'manga' ? myMangaStatusMap : myAnimeStatusMap;
        final status = userStatus == null ? null : labels[userStatus];
        return status == null ? list : s.Hw_Sec_List_Status(list, status);
      case SectionType.forum:
        final board = boardId == null ? null : ForumConstants.boards[boardId];
        return board == null ? s.Hw_Sec_Forum : s.Hw_Sec_Forum_Board(board);
    }
  }

  String getDisplayTitle() {
    if (customTitle != null && customTitle!.isNotEmpty) {
      return customTitle!;
    }
    return getDefaultTitle();
  }

  IconData getIcon() {
    switch (type) {
      case SectionType.news:
        return Icons.newspaper;
      case SectionType.seasonNow:
        return Icons.tv;
      case SectionType.suggested:
        return Icons.recommend;
      case SectionType.upcoming:
        return Icons.upcoming;
      case SectionType.topScore:
        return Icons.star;
      case SectionType.topFavorites:
        return Icons.favorite;
      case SectionType.topPopular:
        return Icons.trending_up;
      case SectionType.topAnimeAiring:
        return Icons.live_tv;
      case SectionType.topAnimeTV:
        return Icons.connected_tv;
      case SectionType.topAnimeMovie:
        return Icons.movie;
      case SectionType.topAnimeSpecial:
        return Icons.auto_awesome;
      case SectionType.topManga:
        return Icons.menu_book;
      case SectionType.topMangaPopular:
        return Icons.auto_stories;
      case SectionType.features:
        return Icons.featured_play_list;
      case SectionType.userList:
        return Icons.video_library_outlined;
      case SectionType.forum:
        return Icons.forum_outlined;
    }
  }
}

class MalHomePreferences {
  List<HomeSectionPreference> sections;
  HomePageTileSize tileSize;

  // Constructor with default values
  MalHomePreferences({
    List<HomeSectionPreference>? sections,
    this.tileSize = HomePageTileSize.l,
  }) : sections = sections ?? _getDefaultSections();

  // Default section order and settings
  static List<HomeSectionPreference> _getDefaultSections() {
    return [
      HomeSectionPreference(type: SectionType.news, itemCount: 10, cacheDurationHours: 8),
      HomeSectionPreference(type: SectionType.seasonNow, itemCount: 15),
      HomeSectionPreference(type: SectionType.suggested, itemCount: 15),
      HomeSectionPreference(type: SectionType.upcoming, itemCount: 15),
      HomeSectionPreference(type: SectionType.topScore, itemCount: 15),
      HomeSectionPreference(type: SectionType.topFavorites, itemCount: 15),
      HomeSectionPreference(type: SectionType.topPopular, itemCount: 15),
    ];
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'sections': sections.map((section) => section.toJson()).toList(),
      'tileSize': tileSize.index,
    };
  }

  // Create from JSON when loading
  factory MalHomePreferences.fromJson(Map<String, dynamic> json) {
    return MalHomePreferences(
      sections: [
        for (final section in json['sections'] as List)
          if (section is Map<String, dynamic>)
            if (HomeSectionPreference.tryFromJson(section) case final parsed?) parsed,
      ],
      tileSize: HomePageTileSize.values
              .elementAtOrNull(json['tileSize'] as int? ?? -1) ??
          HomePageTileSize.l,
    );
  }

  // Save preferences to SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert to JSON string properly
      final jsonString = jsonEncode(toJson());
      await prefs.setString('mal_home_preferences', jsonString);
    } catch (e) {
      debugPrint('Error saving MAL home preferences: $e');
      // Rethrow to handle in UI
      rethrow;
    }
  }

// Load preferences from SharedPreferences
  static Future<MalHomePreferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('mal_home_preferences');

      if (jsonString != null) {
        // Parse JSON string to Map
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
        return MalHomePreferences.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('Error loading MAL home preferences: $e');
      // Don't rethrow, just return default
    }

    // Return default preferences if there was an error or no saved preferences
    return MalHomePreferences();
  }

  // Reset to default preferences
  void reset() {
    sections = _getDefaultSections();
    tileSize = HomePageTileSize.l;
  }
}
