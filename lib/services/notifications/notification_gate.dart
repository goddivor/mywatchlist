import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_backend.dart';

/// The app-wide "Allow notifications" gate: the system permission plus the app's own kill
/// switch. Every notification of every tracker (airing reminders, MAL hub, friends, private
/// messages, AniList inbox, Kitsu, Simkl) is shown only when [mayNotify] is true, and then
/// only if its own per-tracker switch is on.
///
/// It is separate from airing reminders: the old "Airing reminders" master
/// (`NotificationPreferences.subscribedAt`) no longer gates inbox or message notifications;
/// the notifications units turn it into one airing switch per tracker.
///
/// ## Storage (frozen)
///
/// Kill switch: bool [switchKey], default [defaultSwitch] (on), so notifications flow as soon
/// as the system allows them. A background isolate builds its own gate over
/// `await SharedPreferences.getInstance()` after `prefs.reload()` (the worker already
/// reloads), with the default backend.
class NotificationGate {
  NotificationGate(this._prefs, {NotificationBackend? backend})
      : _backend = backend ?? PluginNotificationBackend(),
        _switch = ValueNotifier<bool>(_prefs.getBool(switchKey) ?? defaultSwitch);

  static const String switchKey = 'notifications_allowed_v1';
  static const bool defaultSwitch = true;

  final SharedPreferences _prefs;
  final NotificationBackend _backend;
  final ValueNotifier<bool> _switch;

  static NotificationGate? _shared;

  /// The gate of this isolate (built once over the default prefs and backend), so the
  /// settings page and the pollers see the same [switchListenable].
  static Future<NotificationGate> shared() async =>
      _shared ??= NotificationGate(await SharedPreferences.getInstance());

  @visibleForTesting
  static set debugShared(NotificationGate? gate) => _shared = gate;

  /// The app's kill switch (true = the app may notify), without the system permission.
  bool get switchOn => _switch.value;

  /// [switchOn] for the settings tile; changes when [setAllowed] runs on this gate.
  ValueListenable<bool> get switchListenable => _switch;

  /// True when the kill switch is on and the system shows the app's notifications (Android
  /// 13+ permission, not blocked in the system settings). False off Android.
  Future<bool> mayNotify() async {
    if (!_switch.value || !_backend.isSupported) return false;
    return (await _backend.permissions()).notifications;
  }

  /// Turns the kill switch [on] or off and saves it. Turning it on asks the system for the
  /// permission when it is missing (unless [requestPermission] is false, e.g. from a
  /// background isolate, which cannot show the prompt). Returns [mayNotify] afterwards.
  Future<bool> setAllowed(bool on, {bool requestPermission = true}) async {
    _switch.value = on;
    await _prefs.setBool(switchKey, on);
    if (!on || !_backend.isSupported) return false;
    final now = await _backend.permissions();
    if (now.notifications || !requestPermission) return now.notifications;
    return (await _backend.requestPermissions()).notifications;
  }
}

/// What a notification channel is for; with the tracker it gives the Android channel.
enum NotificationPurpose {
  /// New episode of an anime of the tracker's Watching list.
  airingWatching,

  /// An anime of the tracker's Plan to Watch list starts airing.
  airingPlanToWatch,

  /// The tracker's own notifications (MAL hub, AniList inbox, Kitsu feed).
  inbox,

  /// Friends' activity (MAL).
  friends,

  /// Private messages (MAL), high importance.
  messages,
}

/// One Android notification channel of one tracker: the user can mute each tracker's
/// channels on their own in the system settings.
@immutable
class TrackerChannel {
  const TrackerChannel._(this.tracker, this.purpose, this.id);

  final AccountType tracker;
  final NotificationPurpose purpose;

  /// The Android channel id (frozen: renaming one drops the user's system settings of it).
  final String id;

  /// Heads-up channel (`Importance.high`): private messages only.
  bool get isHighImportance => purpose == NotificationPurpose.messages;

  /// Channel name shown in the Android settings, e.g. "AniList · New episodes (Watching)".
  String get name {
    final t = _brand(tracker);
    switch (purpose) {
      case NotificationPurpose.airingWatching:
        return S.current.Tc_Channel_Watching(t);
      case NotificationPurpose.airingPlanToWatch:
        return S.current.Tc_Channel_Plan(t);
      case NotificationPurpose.inbox:
        return S.current.Tc_Channel_Inbox(t);
      case NotificationPurpose.friends:
        return S.current.Tc_Channel_Friends(t);
      case NotificationPurpose.messages:
        return S.current.Tc_Channel_Messages(t);
    }
  }

  /// Channel description shown in the Android settings.
  String get description {
    final t = _brand(tracker);
    switch (purpose) {
      case NotificationPurpose.airingWatching:
        return S.current.Tc_Channel_Watching_Desc(t);
      case NotificationPurpose.airingPlanToWatch:
        return S.current.Tc_Channel_Plan_Desc(t);
      case NotificationPurpose.inbox:
        return S.current.Tc_Channel_Inbox_Desc(t);
      case NotificationPurpose.friends:
        return S.current.Tc_Channel_Friends_Desc(t);
      case NotificationPurpose.messages:
        return S.current.Tc_Channel_Messages_Desc(t);
    }
  }

  /// The channel of [tracker] for [purpose]; null when the tracker has none (see [of]).
  static TrackerChannel? find(AccountType tracker, NotificationPurpose purpose) {
    for (final c in of(tracker)) {
      if (c.purpose == purpose) return c;
    }
    return null;
  }

  /// Every channel of [tracker] (frozen ids):
  ///
  /// * MAL keeps the ids already on users' phones: `airing_watching`,
  ///   `airing_plan_to_watch`, `mal_hub`, `mal_friends_activity`, plus `mal_messages`;
  /// * AniList: `anilist_airing_watching`, `anilist_airing_plan_to_watch`, and its inbox
  ///   keeps `anilist_notifications`;
  /// * Kitsu: `kitsu_airing_watching`, `kitsu_airing_plan_to_watch`, `kitsu_notifications`;
  /// * Simkl (no inbox API): `simkl_airing_watching`, `simkl_airing_plan_to_watch`.
  static List<TrackerChannel> of(AccountType tracker) => _all[tracker] ?? const [];

  /// Every channel of every tracker.
  static List<TrackerChannel> get all => [for (final l in _all.values) ...l];

  static const Map<AccountType, List<TrackerChannel>> _all = {
    AccountType.myanimelist: [
      TrackerChannel._(AccountType.myanimelist, NotificationPurpose.airingWatching, 'airing_watching'),
      TrackerChannel._(
          AccountType.myanimelist, NotificationPurpose.airingPlanToWatch, 'airing_plan_to_watch'),
      TrackerChannel._(AccountType.myanimelist, NotificationPurpose.inbox, 'mal_hub'),
      TrackerChannel._(AccountType.myanimelist, NotificationPurpose.friends, 'mal_friends_activity'),
      TrackerChannel._(AccountType.myanimelist, NotificationPurpose.messages, 'mal_messages'),
    ],
    AccountType.anilist: [
      TrackerChannel._(
          AccountType.anilist, NotificationPurpose.airingWatching, 'anilist_airing_watching'),
      TrackerChannel._(AccountType.anilist, NotificationPurpose.airingPlanToWatch,
          'anilist_airing_plan_to_watch'),
      TrackerChannel._(AccountType.anilist, NotificationPurpose.inbox, 'anilist_notifications'),
    ],
    AccountType.kitsu: [
      TrackerChannel._(AccountType.kitsu, NotificationPurpose.airingWatching, 'kitsu_airing_watching'),
      TrackerChannel._(
          AccountType.kitsu, NotificationPurpose.airingPlanToWatch, 'kitsu_airing_plan_to_watch'),
      TrackerChannel._(AccountType.kitsu, NotificationPurpose.inbox, 'kitsu_notifications'),
    ],
    AccountType.simkl: [
      TrackerChannel._(AccountType.simkl, NotificationPurpose.airingWatching, 'simkl_airing_watching'),
      TrackerChannel._(
          AccountType.simkl, NotificationPurpose.airingPlanToWatch, 'simkl_airing_plan_to_watch'),
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is TrackerChannel && other.tracker == tracker && other.purpose == purpose;

  @override
  int get hashCode => Object.hash(tracker, purpose);

  @override
  String toString() => 'TrackerChannel($id)';
}

/// Brand name of a tracker (never translated), for channel names.
String _brand(AccountType tracker) {
  switch (tracker) {
    case AccountType.myanimelist:
      return 'MyAnimeList';
    case AccountType.anilist:
      return 'AniList';
    case AccountType.kitsu:
      return 'Kitsu';
    case AccountType.simkl:
      return 'Simkl';
    case AccountType.none:
      return '';
  }
}
