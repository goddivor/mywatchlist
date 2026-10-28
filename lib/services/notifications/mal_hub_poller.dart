import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mal_hub.dart';
import 'mal_hub_texts.dart';
import 'notification_backend.dart' show PluginNotificationBackend;

/// Payloads of the hub's system notifications: `malhub:<item id>|<target url>`; a friend
/// update has no item id, a group summary is `malhub:` alone (opens the screen).
abstract final class MalHubPayload {
  static const String prefix = 'malhub:';

  static String item(MalNotificationItem i) => '$prefix${i.id}|${i.targetUrl ?? ''}';
  static String friend(FriendActivity a) => '$prefix|${a.link}';
  static const String screen = prefix;

  static bool isHub(String? payload) => payload != null && payload.startsWith(prefix);

  /// The item id and the url of a hub payload (both may be null); null when not one.
  static ({String? id, String? url})? parse(String? payload) {
    if (!isHub(payload)) return null;
    final rest = payload!.substring(prefix.length);
    final bar = rest.indexOf('|');
    final id = bar < 0 ? rest : rest.substring(0, bar);
    final url = bar < 0 ? '' : rest.substring(bar + 1);
    return (id: id.isEmpty ? null : id, url: url.isEmpty ? null : url);
  }
}

/// Which Android channel a system notification goes to.
enum MalHubChannel {
  hub('mal_hub'),
  friends('mal_friends_activity');

  const MalHubChannel(this.id);
  final String id;
}

/// One system notification of the hub, text already translated.
@immutable
class HubSystemNotification {
  const HubSystemNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String payload;
}

/// Stable 28-bit hash (FNV-1a), so a notification id survives app restarts.
int _fnv(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x0FFFFFFF;
}

/// System notification ids: far above the airing reminders (`malId * 8 + slot`).
int hubNotificationId(String itemId) => 0x40000000 | _fnv('hub:$itemId');
int friendNotificationId(String key) => 0x50000000 | _fnv('friend:$key');
const int hubSummaryId = 0x3FFFFFF0;
const int friendsSummaryId = 0x3FFFFFF1;

/// The part of the notification plugin the poller uses (a fake in tests).
abstract class MalHubNotifier {
  bool get isSupported;

  /// The system lets the app show notifications.
  Future<bool> allowed();

  /// Shows [notifications] in one Android group of [channel], with a summary when there
  /// are several.
  Future<void> show(MalHubChannel channel, List<HubSystemNotification> notifications);

  Future<void> cancel(int id);
}

/// [MalHubNotifier] on `flutter_local_notifications` (Android). The plugin is initialised by
/// `NotificationService.init`, whose tap handler receives these payloads too.
class PluginMalHubNotifier implements MalHubNotifier {
  PluginMalHubNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String groupHub = 'com.teen.mywatchlist.MAL_HUB';
  static const String groupFriends = 'com.teen.mywatchlist.MAL_FRIENDS';

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> allowed() async {
    if (!isSupported) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> show(MalHubChannel channel, List<HubSystemNotification> notifications) async {
    if (!isSupported || notifications.isEmpty) return;
    final s = S.current;
    final hub = channel == MalHubChannel.hub;
    final name = hub ? s.Mn_Channel_Hub : s.Mn_Channel_Friends;
    final description = hub ? s.Mn_Channel_Hub_Desc : s.Mn_Channel_Friends_Desc;
    final group = hub ? groupHub : groupFriends;
    for (final n in notifications) {
      await _plugin.show(
        id: n.id,
        title: n.title,
        body: n.body,
        payload: n.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            name,
            channelDescription: description,
            icon: PluginNotificationBackend.smallIcon,
            groupKey: group,
            category: AndroidNotificationCategory.social,
            styleInformation: BigTextStyleInformation(n.body, contentTitle: n.title),
          ),
        ),
      );
    }
    if (notifications.length < 2) return;
    final summary = hub ? s.Mn_Summary(notifications.length) : s.Mn_Friends_Summary(notifications.length);
    await _plugin.show(
      id: hub ? hubSummaryId : friendsSummaryId,
      title: summary,
      body: notifications.first.title,
      payload: MalHubPayload.screen,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          name,
          channelDescription: description,
          icon: PluginNotificationBackend.smallIcon,
          groupKey: group,
          setAsGroupSummary: true,
          styleInformation: InboxStyleInformation(
            [for (final n in notifications.take(6)) n.title],
            contentTitle: summary,
          ),
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!isSupported) return;
    await _plugin.cancel(id: id);
  }
}

/// Polls MAL's notification hub (and, less often, the friends' activity) while the app runs,
/// and raises a system notification for each new unread item.
///
/// Battery: one page every [interval] (30 min) only while the app is in the foreground, a
/// check when it comes back if one is due, friends' feeds every [friendsInterval] (3 h). An
/// item is notified once (ids kept in SharedPreferences); the first run only notifies the
/// unread items of the last [firstRunWindow]. System notifications follow the master switch
/// of the notification settings, the system permission and the screen's own switches.
class MalHubPoller with WidgetsBindingObserver {
  MalHubPoller({
    MalNotificationsHub? hub,
    MalHubNotifier? notifier,
    NotificationPreferences Function()? readPrefs,
    Future<SharedPreferences> Function()? storage,
    DateTime Function()? clock,
    this.interval = const Duration(minutes: 30),
    this.friendsInterval = const Duration(hours: 3),
    this.firstDelay = const Duration(seconds: 30),
    this.firstRunWindow = const Duration(days: 3),
    this.friendsWindow = const Duration(days: 7),
    this.maxPerRun = 10,
  })  : _hub = hub,
        _notifier = notifier ?? PluginMalHubNotifier(),
        _readPrefs = readPrefs ?? (() => Preferences.current.notifications),
        _storage = storage ?? SharedPreferences.getInstance,
        _clock = clock ?? DateTime.now;

  static MalHubPoller instance = MalHubPoller();

  static const String seenKey = 'mal_hub_seen_v1';
  static const String shownKey = 'mal_hub_shown_v1';
  static const String lastPollKey = 'mal_hub_last_poll_v1';
  static const String friendsSeenKey = 'mal_friends_seen_v1';
  static const String friendsLastPollKey = 'mal_friends_last_poll_v1';
  static const String pushHubKey = 'mal_hub_push_v1';
  static const String pushFriendsKey = 'mal_friends_push_v1';

  final MalNotificationsHub? _hub;
  final MalHubNotifier _notifier;
  final NotificationPreferences Function() _readPrefs;
  final Future<SharedPreferences> Function() _storage;
  final DateTime Function() _clock;

  final Duration interval;
  final Duration friendsInterval;
  final Duration firstDelay;
  final Duration firstRunWindow;
  final Duration friendsWindow;
  final int maxPerRun;

  MalNotificationsHub get hub => _hub ?? MalNotificationsHub.instance;
  MalHubNotifier get notifier => _notifier;

  /// The screen's switches (both on by default).
  final ValueNotifier<bool> pushHub = ValueNotifier<bool>(true);
  final ValueNotifier<bool> pushFriends = ValueNotifier<bool>(true);

  Timer? _timer;
  bool _started = false;
  bool _foreground = true;
  Future<void>? _polling;

  bool get isStarted => _started;

  /// Starts polling (called once by `NotificationService.init`). Never throws.
  Future<void> start() async {
    if (_started || !_notifier.isSupported) return;
    _started = true;
    try {
      final prefs = await _storage();
      pushHub.value = prefs.getBool(pushHubKey) ?? true;
      pushFriends.value = prefs.getBool(pushFriendsKey) ?? true;
    } catch (_) {}
    hub.onItemsRead = _cancelShown;
    WidgetsBinding.instance.addObserver(this);
    _schedule(firstDelay);
  }

  Future<void> setPushHub(bool value) => _setSwitch(pushHub, pushHubKey, value);
  Future<void> setPushFriends(bool value) => _setSwitch(pushFriends, pushFriendsKey, value);

  Future<void> _setSwitch(ValueNotifier<bool> notifier, String key, bool value) async {
    notifier.value = value;
    try {
      await (await _storage()).setBool(key, value);
    } catch (_) {}
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_foreground) return;
    _timer = Timer(delay, () async {
      await poll();
      _schedule(interval);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
        unawaited(_resume());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _foreground = false;
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _resume() async {
    final last = await _readTime(lastPollKey);
    final since = last == null ? interval : _clock().difference(last);
    final wait = since >= interval ? const Duration(seconds: 5) : interval - since;
    _schedule(wait);
  }

  /// One polling round: the hub when due (or [force]), then the friends when due. Calls
  /// made during a round share it. Never throws.
  Future<void> poll({bool force = false}) =>
      _polling ??= _poll(force).whenComplete(() => _polling = null);

  Future<void> _poll(bool force) async {
    try {
      final now = _clock();
      final last = await _readTime(lastPollKey);
      if (force || last == null || now.difference(last) >= interval - const Duration(minutes: 1)) {
        await pollHub();
      }
      final lastFriends = await _readTime(friendsLastPollKey);
      if (force || lastFriends == null || now.difference(lastFriends) >= friendsInterval) {
        await pollFriends();
      }
    } catch (e) {
      debugPrint('MAL hub poll: $e');
    }
  }

  bool get _mayNotify => _readPrefs().enabled;

  /// Reads the hub and notifies its new unread items. Returns how many were notified.
  Future<int> pollHub() async {
    final prefs = await _storage();
    final feed = await hub.refresh(quiet: true);
    if (feed == null) return 0;
    await prefs.setInt(lastPollKey, _clock().millisecondsSinceEpoch);
    final all = feed.all;
    final stored = prefs.getStringList(seenKey);
    final seen = {...?stored};
    final first = stored == null;
    final now = _clock();

    // Items read elsewhere (MAL's website, another device): their system notification goes.
    final shown = {...?prefs.getStringList(shownKey)};
    final readNow = {for (final i in all) if (i.isRead && shown.contains(i.id)) i.id};
    if (readNow.isNotEmpty) await _cancelShown(readNow, prefs: prefs);

    final fresh = [
      for (final i in all)
        if (!i.isRead &&
            !seen.contains(i.id) &&
            (!first || (i.createdAt != null && now.difference(i.createdAt!) <= firstRunWindow)))
          i,
    ];
    await prefs.setStringList(seenKey, _capped([for (final i in all) i.id, ...seen], 400));
    if (fresh.isEmpty || !pushHub.value || !_mayNotify || !await _notifier.allowed()) return 0;
    final picked = fresh.take(maxPerRun).toList();
    final notifications = [
      for (final i in picked)
        () {
          final words = describeMalNotification(i);
          return HubSystemNotification(
            id: hubNotificationId(i.id),
            title: words.headline,
            body: words.detail ?? '',
            payload: MalHubPayload.item(i),
          );
        }(),
    ];
    await _notifier.show(MalHubChannel.hub, notifications);
    final nowShown = {...{for (final i in picked) i.id}, ...shown.difference(readNow)};
    await prefs.setStringList(shownKey, _capped(nowShown, 100));
    return notifications.length;
  }

  /// Reads the friends' feeds and notifies the titles they completed or dropped since the
  /// last check. The first check only remembers what is there. Returns how many were notified.
  Future<int> pollFriends() async {
    if (!pushFriends.value || !_mayNotify) return 0;
    final prefs = await _storage();
    final rows = await hub.loadActivity(force: true, quiet: true);
    if (rows == null) return 0;
    await prefs.setInt(friendsLastPollKey, _clock().millisecondsSinceEpoch);
    final stored = prefs.getStringList(friendsSeenKey);
    final seen = {...?stored};
    await prefs.setStringList(friendsSeenKey, _capped([for (final r in rows) r.key, ...seen], 1500));
    if (stored == null) return 0;
    final now = _clock();
    final fresh = [
      for (final r in rows)
        if ((r.isCompleted || r.isDropped) &&
            !seen.contains(r.key) &&
            r.date != null &&
            now.difference(r.date!) <= friendsWindow)
          r,
    ];
    if (fresh.isEmpty || !await _notifier.allowed()) return 0;
    final s = S.current;
    final notifications = [
      for (final r in fresh.take(maxPerRun))
        HubSystemNotification(
          id: friendNotificationId(r.key),
          title: r.isDropped ? s.Mn_Friend_Dropped(r.friend, r.title) : s.Mn_Friend_Completed(r.friend, r.title),
          body: friendProgressLabel(r, s) ?? '',
          payload: MalHubPayload.friend(r),
        ),
    ];
    await _notifier.show(MalHubChannel.friends, notifications);
    return notifications.length;
  }

  Future<void> _cancelShown(Iterable<String> ids, {SharedPreferences? prefs}) async {
    try {
      for (final id in ids) {
        await _notifier.cancel(hubNotificationId(id));
      }
      final store = prefs ?? await _storage();
      final shown = {...?store.getStringList(shownKey)}..removeAll(ids);
      await store.setStringList(shownKey, shown.toList());
      if (shown.isEmpty) await _notifier.cancel(hubSummaryId);
    } catch (e) {
      debugPrint('MAL hub cancel: $e');
    }
  }

  Future<DateTime?> _readTime(String key) async {
    try {
      final ms = (await _storage()).getInt(key);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  static List<String> _capped(Iterable<String> ids, int max) {
    final out = <String>[];
    final seen = <String>{};
    for (final id in ids) {
      if (seen.add(id)) out.add(id);
      if (out.length >= max) break;
    }
    return out;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
