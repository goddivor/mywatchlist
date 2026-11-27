import 'package:equatable/equatable.dart';
import 'package:mywatchlist/user/preferences/json_read.dart';

/// Airing notification preferences (DAL `NotifPref`).
class NotificationPreferences extends Equatable {
  /// When the user turned airing notifications on; null = off.
  final DateTime? subscribedAt;

  /// Notify the episodes airing today (DAL `onDailyAnimeReleases`). Stored for parity but
  /// read by nothing and without a settings tile, as in DailyAL.
  final bool dailyReleases;

  /// Notify new episodes of the anime in the watching list (DAL `onWatchingListUpdated`).
  final bool watchingList;

  /// Notify when an anime of the plan-to-watch list starts airing (DAL `onPTWGoesToWatching`).
  final bool planToWatchList;

  /// Big picture style with the cover (DAL `preferLargeImage`).
  final bool largeImage;

  /// The trackers (`AccountType.name`) whose lists must not feed the episode reminders. Every
  /// connected tracker feeds them by default (#351: one switch per tracker).
  final Set<String> airingOff;

  const NotificationPreferences({
    this.subscribedAt,
    this.dailyReleases = true,
    this.watchingList = true,
    this.planToWatchList = true,
    this.largeImage = true,
    this.airingOff = const {},
  });

  bool get enabled => subscribedAt != null;

  /// Whether the lists of [tracker] (`AccountType.name`) feed the episode reminders.
  bool airingFrom(String tracker) => !airingOff.contains(tracker);

  /// The same preferences with [tracker]'s reminders on or off.
  NotificationPreferences withAiring(String tracker, bool on) =>
      copyWith(airingOff: on ? ({...airingOff}..remove(tracker)) : {...airingOff, tracker});

  /// [subscribedAt] cannot be cleared through a null argument: use [unsubscribed].
  NotificationPreferences copyWith({
    DateTime? subscribedAt,
    bool? dailyReleases,
    bool? watchingList,
    bool? planToWatchList,
    bool? largeImage,
    Set<String>? airingOff,
  }) =>
      NotificationPreferences(
        airingOff: airingOff ?? this.airingOff,
        subscribedAt: subscribedAt ?? this.subscribedAt,
        dailyReleases: dailyReleases ?? this.dailyReleases,
        watchingList: watchingList ?? this.watchingList,
        planToWatchList: planToWatchList ?? this.planToWatchList,
        largeImage: largeImage ?? this.largeImage,
      );

  /// Same lists, notifications off.
  NotificationPreferences unsubscribed() => NotificationPreferences(
        dailyReleases: dailyReleases,
        watchingList: watchingList,
        planToWatchList: planToWatchList,
        largeImage: largeImage,
        airingOff: airingOff,
      );

  Map<String, dynamic> toJson() => {
        'subscribedAt': subscribedAt?.toIso8601String(),
        'dailyReleases': dailyReleases,
        'watchingList': watchingList,
        'planToWatchList': planToWatchList,
        'largeImage': largeImage,
        'airingOff': airingOff.toList()..sort(),
      };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    const d = NotificationPreferences();
    final subscribed = json['subscribedAt'];
    return NotificationPreferences(
      subscribedAt: subscribed is String ? DateTime.tryParse(subscribed) : null,
      dailyReleases: readBool(json, 'dailyReleases', d.dailyReleases),
      watchingList: readBool(json, 'watchingList', d.watchingList),
      planToWatchList: readBool(json, 'planToWatchList', d.planToWatchList),
      largeImage: readBool(json, 'largeImage', d.largeImage),
      airingOff: {
        if (json['airingOff'] case final List list)
          for (final v in list)
            if (v is String) v,
      },
    );
  }

  @override
  List<Object?> get props =>
      [subscribedAt, dailyReleases, watchingList, planToWatchList, largeImage, [...airingOff]..sort()];
}
