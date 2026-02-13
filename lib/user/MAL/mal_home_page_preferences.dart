import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';



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
}

class HomeSectionPreference {
  SectionType type;
  bool enabled;
  int itemCount;
  String? customTitle;
  int cacheDurationHours;

  HomeSectionPreference({
    required this.type,
    this.enabled = true,
    this.itemCount = 15,
    this.customTitle,
    this.cacheDurationHours = 2,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'enabled': enabled,
      'itemCount': itemCount,
      'customTitle': customTitle,
      'cacheDurationHours': cacheDurationHours,
    };
  }

  // Create from JSON when loading
  factory HomeSectionPreference.fromJson(Map<String, dynamic> json) {
    return HomeSectionPreference(
      type: SectionType.values[json['type'] as int],
      enabled: json['enabled'] as bool,
      itemCount: json['itemCount'] as int,
      customTitle: json['customTitle'] as String?,
      cacheDurationHours: json['cacheDurationHours'] as int? ?? 2,
    );
  }

  String getDefaultTitle(String seasonName, int seasonYear) {
    switch (type) {
      case SectionType.news:
        return 'Anime News';
      case SectionType.seasonNow:
        return '$seasonName $seasonYear Anime';
      case SectionType.suggested:
        return 'Suggested For You';
      case SectionType.upcoming:
        return 'Top Upcoming Anime';
      case SectionType.topScore:
        return 'Top Anime by Score';
      case SectionType.topFavorites:
        return 'All-time Anime Favorites';
      case SectionType.topPopular:
        return 'Most Popular Anime';
      case SectionType.topAnimeAiring:
        return 'Top Airing Anime';
      case SectionType.topAnimeTV:
        return 'Top Anime TV Series';
      case SectionType.topAnimeMovie:
        return 'Top Anime Movies';
      case SectionType.topAnimeSpecial:
        return 'Top Anime Specials';
      case SectionType.topManga:
        return 'Top Manga';
      case SectionType.topMangaPopular:
        return 'Most Popular Manga';
      case SectionType.features:
        return 'Anime Features';
    }
  }

  String getDisplayTitle(String seasonName, int seasonYear) {
    if (customTitle != null && customTitle!.isNotEmpty) {
      return customTitle!;
    }
    return getDefaultTitle(seasonName, seasonYear);
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
      sections: (json['sections'] as List)
          .map((section) =>
              HomeSectionPreference.fromJson(section as Map<String, dynamic>))
          .toList(),
      tileSize: HomePageTileSize.values[json['tileSize'] as int],
    );
  }

  // Save preferences to SharedPreferences
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert to JSON string properly
      final jsonString = jsonEncode(toJson());
      await prefs.setString('mal_home_preferences', jsonString);
      debugPrint('Saved preferences: $jsonString');
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
        debugPrint('Loading preferences: $jsonString');
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
