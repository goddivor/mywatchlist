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
}

class HomeSectionPreference {
  SectionType type;
  bool enabled;
  int itemCount;

  HomeSectionPreference({
    required this.type,
    this.enabled = true,
    this.itemCount = 15,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'enabled': enabled,
      'itemCount': itemCount,
    };
  }

  // Create from JSON when loading
  factory HomeSectionPreference.fromJson(Map<String, dynamic> json) {
    return HomeSectionPreference(
      type: SectionType.values[json['type'] as int],
      enabled: json['enabled'] as bool,
      itemCount: json['itemCount'] as int,
    );
  }

  String getTitle(String seasonName, int seasonYear) {
    switch (type) {
      case SectionType.news:
        return 'Anime News & Features';
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
    }
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
    }
  }
}

class MalHomePreferences {
  List<HomeSectionPreference> sections;
  HomePageTileSize tileSize;

  // Constructor with default values
  MalHomePreferences({
    List<HomeSectionPreference>? sections,
    this.tileSize = HomePageTileSize.m,
  }) : sections = sections ?? _getDefaultSections();

  // Default section order and settings
  static List<HomeSectionPreference> _getDefaultSections() {
    return [
      HomeSectionPreference(type: SectionType.news, itemCount: 10),
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
    tileSize = HomePageTileSize.m;
  }
}
