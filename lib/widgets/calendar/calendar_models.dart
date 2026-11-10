import 'package:flutter/foundation.dart';

/// One episode of the calendar: an airing time joined with what is known about
/// the anime (cover, number of episodes, the user's list status).
@immutable
class CalendarEntry {
  final int malId;
  final String title;

  /// Cover URL, empty when the anime is not in the MAL season list.
  final String imageUrl;

  /// Number of the episode that airs at [airingAt].
  final int episode;

  /// Air time (UTC).
  final DateTime airingAt;

  /// Total number of episodes, null when MAL does not know it.
  final int? numEpisodes;

  /// The user's MAL list status (`watching`, `plan_to_watch`...), null when the
  /// anime is not on the list or the list is unknown.
  final String? listStatus;

  /// Link kind (`website`, `twitter`, `anilist`, `mal`...) to URL.
  final Map<String, String> relatedLinks;

  const CalendarEntry({
    required this.malId,
    required this.title,
    required this.imageUrl,
    required this.episode,
    required this.airingAt,
    this.numEpisodes,
    this.listStatus,
    this.relatedLinks = const {},
  });

  /// Watching or planned: the entries the calendar highlights.
  bool get isHighlighted => listStatus == 'watching' || listStatus == 'plan_to_watch';
}
