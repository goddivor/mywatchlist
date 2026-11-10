import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/MAL/web/mal_notifications_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/user/user_manager.dart';

export 'package:mywatchlist/services/api/MAL/web/mal_notifications_api.dart';

/// Where a list of the hub stands.
enum MalHubStatus {
  /// Never loaded.
  idle,
  loading,
  ready,

  /// No MyAnimeList account is signed in.
  noAccount,

  /// A MyAnimeList account without a website session (or a platform that cannot have one).
  noSession,

  /// MAL refused the stored website session.
  expired,

  /// Network or page failure; the previous items (if any) stay shown.
  error,
}

/// MAL's notification hub and the friends' activity, shared by the notifications screen, the
/// header bell (unread badge) and the background poller.
///
/// A `ChangeNotifier` singleton like `MalWebSession` (project convention: no other state
/// library); screens listen to it, the badge listens to [unread] only.
class MalNotificationsHub extends ChangeNotifier {
  MalNotificationsHub({
    MalNotificationsApi? api,
    FriendsActivityApi? friends,
    MalWebSession? session,
    bool Function()? malSignedIn,
    String? Function()? malUsername,
    DateTime Function()? clock,
    this.activityMaxAge = const Duration(minutes: 15),
  })  : _api = api,
        _friends = friends,
        _sessionOverride = session,
        _malSignedIn = malSignedIn ?? _defaultSignedIn,
        _malUsername = malUsername ?? _defaultUsername,
        _clock = clock ?? DateTime.now;

  static MalNotificationsHub instance = MalNotificationsHub();

  final MalNotificationsApi? _api;
  final FriendsActivityApi? _friends;
  final MalWebSession? _sessionOverride;
  final bool Function() _malSignedIn;
  final String? Function() _malUsername;
  final DateTime Function() _clock;

  /// The friends' activity is read again only after this long (or on a pull to refresh).
  final Duration activityMaxAge;

  MalNotificationsApi get api => _api ?? MalNotificationsApi.instance;
  FriendsActivityApi get friendsApi => _friends ?? FriendsActivityApi.instance;
  MalWebSession get session => _sessionOverride ?? MalWebSession.instance;

  static bool _defaultSignedIn() => UserManager.instance.isAuthenticated(AccountType.myanimelist);
  static String? _defaultUsername() => UserMalV2.instance.username ?? MalWebSession.instance.username;

  /// Unread items of the hub (the bell badge).
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  /// Called with the ids of items that became read (the poller removes their system
  /// notifications).
  void Function(Iterable<String> ids)? onItemsRead;

  MalHubStatus _status = MalHubStatus.idle;
  List<MalNotificationItem> _items = const [];
  DateTime? _loadedAt;
  Future<MalNotificationFeed?>? _refreshing;

  MalHubStatus _activityStatus = MalHubStatus.idle;
  List<FriendActivity> _activity = const [];
  DateTime? _activityAt;
  String? _activityUser;
  Future<List<FriendActivity>?>? _activityLoading;

  bool _bound = false;
  MalWebSessionState? _lastSessionState;

  MalHubStatus get status => _status;
  List<MalNotificationItem> get items => _items;
  DateTime? get loadedAt => _loadedAt;
  MalHubStatus get activityStatus => _activityStatus;
  List<FriendActivity> get activity => _activity;

  /// Whether the hub can be read now: [MalHubStatus.ready] when it can, else the reason.
  MalHubStatus get access {
    if (!_malSignedIn()) return MalHubStatus.noAccount;
    switch (session.state) {
      case MalWebSessionState.connected:
        return MalHubStatus.ready;
      case MalWebSessionState.expired:
        return MalHubStatus.expired;
      case MalWebSessionState.loading:
      case MalWebSessionState.none:
      case MalWebSessionState.unsupported:
        return MalHubStatus.noSession;
    }
  }

  /// Follows the website session: a new session reloads, a lost one clears the items.
  void bindSession() {
    if (_bound) return;
    _bound = true;
    _lastSessionState = session.state;
    session.addListener(_onSession);
  }

  void _onSession() {
    final state = session.state;
    if (state == _lastSessionState) return;
    final was = _lastSessionState;
    _lastSessionState = state;
    if (state == MalWebSessionState.connected) {
      if (was != MalWebSessionState.loading) unawaited(refresh(quiet: true));
      return;
    }
    if (state == MalWebSessionState.none || state == MalWebSessionState.expired) {
      _items = const [];
      _loadedAt = null;
      _status = state == MalWebSessionState.expired ? MalHubStatus.expired : MalHubStatus.noSession;
      _syncUnread();
      notifyListeners();
    }
  }

  void _syncUnread() => unread.value = _items.where((i) => !i.isRead).length;

  /// Reads the hub again. Calls made while one runs share it. [quiet] keeps the current
  /// items on screen without a loading state (background refresh). Returns the feed, or null
  /// when it could not be read. Never throws.
  Future<MalNotificationFeed?> refresh({bool quiet = false}) =>
      _refreshing ??= _refresh(quiet).whenComplete(() => _refreshing = null);

  Future<MalNotificationFeed?> _refresh(bool quiet) async {
    bindSession();
    await session.ensureLoaded();
    final access = this.access;
    if (access != MalHubStatus.ready) {
      _status = access;
      _items = const [];
      _syncUnread();
      notifyListeners();
      return null;
    }
    if (!quiet || _status != MalHubStatus.ready) {
      _status = MalHubStatus.loading;
      notifyListeners();
    }
    try {
      final feed = await api.fetch();
      _items = feed.all;
      _loadedAt = _clock();
      _status = MalHubStatus.ready;
      _syncUnread();
      notifyListeners();
      return feed;
    } on MalWebNoSession {
      _status = MalHubStatus.noSession;
    } on MalWebSessionExpired {
      _status = MalHubStatus.expired;
      _items = const [];
      _syncUnread();
    } catch (e) {
      debugPrint('MAL notifications: $e');
      _status = MalHubStatus.error;
    }
    notifyListeners();
    return null;
  }

  /// Marks [items] read: shown read at once, put back when MAL refuses. True on success.
  Future<bool> markRead(Iterable<MalNotificationItem> items) async {
    final ids = {for (final i in items) if (!i.isRead) i.id};
    if (ids.isEmpty) return true;
    final before = _items;
    final targets = [for (final i in before) if (ids.contains(i.id)) i];
    _items = [for (final i in before) ids.contains(i.id) ? i.copyWith(isRead: true) : i];
    _syncUnread();
    notifyListeners();
    var ok = false;
    try {
      ok = await api.markRead(targets.isEmpty ? items : targets);
    } on MalWebSessionExpired {
      _status = MalHubStatus.expired;
    } catch (e) {
      debugPrint('MAL notifications mark read: $e');
    }
    if (!ok) {
      _items = [
        for (final i in _items)
          ids.contains(i.id) ? i.copyWith(isRead: before.firstWhere((b) => b.id == i.id, orElse: () => i).isRead) : i
      ];
      _syncUnread();
      notifyListeners();
      return false;
    }
    _confirmedRead.addAll(ids);
    onItemsRead?.call(ids);
    return true;
  }

  /// Marks every unread notification read. MAL's page lists at most 25 unread at a time, so
  /// after each batch the hub is read again and the next unread ones are marked, until none
  /// is left (at most [_markAllRounds] batches).
  Future<bool> markAllRead() async {
    var ok = await markRead(_items);
    for (var round = 0; ok && round < _markAllRounds; round++) {
      final feed = await refresh(quiet: true);
      if (feed == null) break;
      // What MAL accepted stays read even if a stale page still lists it as unread.
      _items = [for (final i in _items) _confirmedRead.contains(i.id) ? i.copyWith(isRead: true) : i];
      _syncUnread();
      notifyListeners();
      final pending = [for (final i in _items) if (!i.isRead) i];
      if (pending.isEmpty) break;
      ok = await markRead(pending);
    }
    return ok;
  }

  static const int _markAllRounds = 20;

  /// Ids MAL confirmed read in this session (a page fetched just after can still list them).
  final Set<String> _confirmedRead = {};

  /// Accepts or declines a friend request, then marks it read.
  Future<bool> answerFriendRequest(MalNotificationItem item, {required bool accept}) async {
    var ok = false;
    try {
      ok = accept ? await api.acceptFriendRequests([item]) : await api.denyFriendRequests([item]);
    } on MalWebSessionExpired {
      _status = MalHubStatus.expired;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('MAL friend request: $e');
    }
    if (!ok) return false;
    if (accept) {
      _items = [for (final i in _items) i.id == item.id ? i.copyWith(isApproved: true, isRead: true) : i];
    } else {
      // MAL's own page removes a declined request from the list.
      _items = [for (final i in _items) if (i.id != item.id) i];
    }
    _syncUnread();
    notifyListeners();
    onItemsRead?.call([item.id]);
    return true;
  }

  // ---- friends' activity ----

  /// Reads the friends' list updates of the signed-in MAL user, at most every
  /// [activityMaxAge] unless [force]. Rows arrive friend by friend. Never throws.
  Future<List<FriendActivity>?> loadActivity({bool force = false, bool quiet = false}) {
    final running = _activityLoading;
    if (running != null) return running;
    return _activityLoading = _loadActivity(force, quiet).whenComplete(() => _activityLoading = null);
  }

  Future<List<FriendActivity>?> _loadActivity(bool force, bool quiet) async {
    final user = _malUsername();
    if (!_malSignedIn() || user == null || user.isEmpty) {
      _activityStatus = MalHubStatus.noAccount;
      _activity = const [];
      notifyListeners();
      return null;
    }
    final at = _activityAt;
    if (!force &&
        user == _activityUser &&
        at != null &&
        _activityStatus == MalHubStatus.ready &&
        _clock().difference(at) < activityMaxAge) {
      return _activity;
    }
    if (user != _activityUser) _activity = const [];
    _activityUser = user;
    if (!quiet || _activity.isEmpty) {
      _activityStatus = MalHubStatus.loading;
      notifyListeners();
    }
    try {
      final rows = await friendsApi.load(user, onProgress: (partial) {
        if (quiet && _activity.isNotEmpty) return;
        _activity = partial;
        notifyListeners();
      });
      _activity = rows;
      _activityAt = _clock();
      _activityStatus = MalHubStatus.ready;
      notifyListeners();
      return rows;
    } catch (e) {
      debugPrint('Friends activity: $e');
      _activityStatus = MalHubStatus.error;
      notifyListeners();
      return null;
    }
  }

  /// Forgets everything (tests, account change).
  @visibleForTesting
  void reset() {
    _items = const [];
    _activity = const [];
    _status = MalHubStatus.idle;
    _activityStatus = MalHubStatus.idle;
    _loadedAt = null;
    _activityAt = null;
    _activityUser = null;
    _syncUnread();
  }

  @override
  void dispose() {
    if (_bound) session.removeListener(_onSession);
    unread.dispose();
    super.dispose();
  }
}
