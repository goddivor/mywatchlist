import 'package:flutter/material.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';

/// A season of a year ("Fall 2026").
@immutable
class SeasonKey {
  final SeasonType season;
  final int year;

  const SeasonKey(this.season, this.year);

  /// The season airing today (MAL's calendar: a season starts a few days before its first month).
  factory SeasonKey.current() => SeasonKey(MalApi.getSeasonType(), MalApi.getCurrentSeasonYear());

  /// The season [delta] seasons away (negative = earlier), crossing years.
  SeasonKey shifted(int delta) {
    final index = year * 4 + season.index + delta;
    return SeasonKey(SeasonType.values[index % 4], index ~/ 4);
  }

  String get storageKey => '$year-${season.name.toLowerCase()}';

  String get label => '${seasonLabel(season)} $year';

  @override
  bool operator ==(Object other) => other is SeasonKey && other.season == season && other.year == year;

  @override
  int get hashCode => Object.hash(season, year);
}

/// Oldest year the season picker offers.
const int kFirstSeasonYear = 1960;

/// Newest year the season picker offers (MAL lists next year's announcements).
int lastSeasonYear([DateTime? now]) => (now ?? DateTime.now()).year + 1;

/// Translated season name.
String seasonLabel(SeasonType season) => switch (season) {
      SeasonType.WINTER => S.current.Explore_Season_Winter,
      SeasonType.SPRING => S.current.Explore_Season_Spring,
      SeasonType.SUMMER => S.current.Explore_Season_Summer,
      SeasonType.FALL => S.current.Explore_Season_Fall,
    };

/// Header picture of a season.
String seasonImage(SeasonType season) => switch (season) {
      SeasonType.WINTER => 'assets/images/winter.jpg',
      SeasonType.SPRING => 'assets/images/spring.jpg',
      SeasonType.SUMMER => 'assets/images/summer.jpg',
      SeasonType.FALL => 'assets/images/fall.jpg',
    };

IconData seasonIcon(SeasonType season) => switch (season) {
      SeasonType.WINTER => Icons.ac_unit_rounded,
      SeasonType.SPRING => Icons.local_florist_rounded,
      SeasonType.SUMMER => Icons.wb_sunny_rounded,
      SeasonType.FALL => Icons.eco_rounded,
    };
