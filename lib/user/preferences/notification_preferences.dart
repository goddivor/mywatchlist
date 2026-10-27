import 'package:equatable/equatable.dart';
import 'package:mywatchlist/user/preferences/json_read.dart';

/// Airing notification preferences (DAL `NotifPref`).
class NotificationPreferences extends Equatable {
  /// When the user turned airing notifications on; null = off.
  final DateTime? subscribedAt;

  /// Notify the episodes airing today (DAL `onDailyAnimeReleases`).
  final bool dailyReleases;

  /// Notify new episodes of the anime in the watching list (DAL `onWatchingListUpdated`).
  final bool watchingList;

  /// Notify when an anime of the plan-to-watch list starts airing (DAL `onPTWGoesToWatching`).
  final bool planToWatchList;

  /// Big picture style with the cover (DAL `preferLargeImage`).
  final bool largeImage;

  const NotificationPreferences({
    this.subscribedAt,
    this.dailyReleases = true,
    this.watchingList = true,
    this.planToWatchList = true,
    this.largeImage = true,
  });

  bool get enabled => subscribedAt != null;

  /// [subscribedAt] cannot be cleared through a null argument: use [unsubscribed].
  NotificationPreferences copyWith({
    DateTime? subscribedAt,
    bool? dailyReleases,
    bool? watchingList,
    bool? planToWatchList,
    bool? largeImage,
  }) =>
      NotificationPreferences(
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
      );

  Map<String, dynamic> toJson() => {
        'subscribedAt': subscribedAt?.toIso8601String(),
        'dailyReleases': dailyReleases,
        'watchingList': watchingList,
        'planToWatchList': planToWatchList,
        'largeImage': largeImage,
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
    );
  }

  @override
  List<Object?> get props => [subscribedAt, dailyReleases, watchingList, planToWatchList, largeImage];
}
