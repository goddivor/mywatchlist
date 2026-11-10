import 'package:flutter/foundation.dart';

/// Payload of a notification opening the detail screen of anime [malId]
/// (`NotificationRoute` in `lib/utils/app_routes.dart` parses it; a test keeps both in step).
String animePayload(int malId) => 'anime:$malId';

/// Which list an airing notification comes from; one Android channel each.
enum NotificationKind {
  watching('airing_watching'),
  planToWatch('airing_plan_to_watch');

  const NotificationKind(this.channelId);

  final String channelId;
}

/// Everything a backend needs to show one notification (all text already
/// translated), produced by [NotificationPlanner].
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
    this.malId,
    this.episode,
    this.repeatsWeekly = false,
    this.imageUrl,
  });

  /// Stable id: `malId * 8 + slot`, so a reschedule replaces the same entry.
  final int id;
  final NotificationKind kind;

  /// When it fires (UTC instant).
  final DateTime at;
  final String title;
  final String body;

  /// `anime:<id>` (see `NotificationRoute` in `app_routes.dart`).
  final String payload;
  final int? malId;

  /// Episode number, null for the weekly broadcast fallback.
  final int? episode;

  /// True only for the weekly broadcast fallback (the episode is unknown).
  final bool repeatsWeekly;

  /// Cover shown as large icon / big picture.
  final String? imageUrl;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.payload == payload &&
      other.episode == episode &&
      other.repeatsWeekly == repeatsWeekly &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode =>
      Object.hash(id, kind, at, title, body, payload, episode, repeatsWeekly, imageUrl);

  @override
  String toString() => 'PlannedNotification($id, $title, $at)';
}

/// An airing anime of the current season with the user's list status.
@immutable
class AiringCandidate {
  const AiringCandidate({
    required this.malId,
    required this.title,
    required this.status,
    this.imageUrl,
    this.numEpisodes,
    this.airingStatus,
    this.broadcastDay,
    this.broadcastTime,
  });

  final int malId;
  final String title;

  /// MAL list status: `watching` or `plan_to_watch` (others are ignored).
  final String status;
  final String? imageUrl;

  /// Total episodes, 0 or null when unknown.
  final int? numEpisodes;

  /// MAL airing status (`currently_airing`, `finished_airing`, `not_yet_aired`).
  final String? airingStatus;

  /// MAL broadcast slot in JST (`sunday`, `23:30`).
  final String? broadcastDay;
  final String? broadcastTime;
}

/// The translated strings of the notifications (the service reads `S`, tests pass fakes).
abstract class NotificationTexts {
  String episodeTitle(String anime, int episode);
  String newEpisodeTitle(String anime);
  String get watchingBody;
  String get planToWatchBody;
  String get watchingChannel;
  String get watchingChannelDescription;
  String get planToWatchChannel;
  String get planToWatchChannelDescription;
  String get testBody;
}
