import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/notifications_screen.dart' show openMalHubPayload;
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mal_hub_poller.dart';
import 'notification_backend.dart';
import 'notification_models.dart';
import 'notification_planner.dart';

export 'notification_backend.dart' show NotificationPermissions;
export 'notification_models.dart';

/// Loads the airing anime of the user's lists (watching and plan to watch).
typedef CandidateLoader = Future<List<AiringCandidate>> Function();

/// Downloads a cover and returns its local path, or null.
typedef CoverFetcher = Future<String?> Function(String url, int malId);

/// Airing times, loaded on demand.
typedef EpisodeSource = Future<List<AiringEpisode>> Function();

/// What the last scheduling run did, for the settings page.
@immutable
class NotificationSummary {
  const NotificationSummary({
    this.running = false,
    this.scheduled = 0,
    this.next,
    this.updatedAt,
    this.failed = false,
    this.needsMal = false,
  });

  final bool running;

  /// Notifications handed to Android by the last run.
  final int scheduled;

  /// The earliest scheduled notification.
  final DateTime? next;
  final DateTime? updatedAt;

  /// The last run could not read the lists or the schedule (the previous alarms stay).
  final bool failed;

  /// No connected account feeds the reminders (MyAnimeList is the fallback and is not
  /// connected either): the lists the notifications read are not available.
  final bool needsMal;

  NotificationSummary copyWith({bool? running}) => NotificationSummary(
        running: running ?? this.running,
        scheduled: scheduled,
        next: next,
        updatedAt: updatedAt,
        failed: failed,
        needsMal: needsMal,
      );

  @override
  bool operator ==(Object other) =>
      other is NotificationSummary &&
      other.running == running &&
      other.scheduled == scheduled &&
      other.next == next &&
      other.updatedAt == updatedAt &&
      other.failed == failed &&
      other.needsMal == needsMal;

  @override
  int get hashCode => Object.hash(running, scheduled, next, updatedAt, failed, needsMal);
}

/// Airing notifications: which episodes of the watching and plan-to-watch lists to remind,
/// scheduled with the system alarm so they fire while the app is closed.
///
/// The plugin keeps and restores the alarms itself (boot and app update receivers in the
/// manifest); the app refreshes them at most once a day when it starts, and right away when
/// the notification preferences change.
class NotificationService {
  NotificationService({
    NotificationBackend? backend,
    CandidateLoader? loadCandidates,
    EpisodeSource? loadEpisodes,
    CoverFetcher? fetchCover,
    NotificationTexts? texts,
    NotificationPreferences Function()? readPrefs,
    DateTime Function()? clock,
    Listenable? trackerChanges,
    AccountType Function()? readFeedTracker,
    this.refreshEvery = const Duration(days: 1),
    this.debounce = const Duration(seconds: 2),
    this.pollMalHub = false,
    void Function(String payload)? openHubPayload,
  })  : _backend = backend ?? PluginNotificationBackend(),
        _loadCandidates = loadCandidates ?? _loadMalCandidates,
        _loadEpisodes = loadEpisodes ?? _loadScheduleEpisodes,
        _fetchCover = fetchCover ?? _downloadCover,
        _texts = texts ?? const _SNotificationTexts(),
        _readPrefs = readPrefs ?? (() => Preferences.current.notifications),
        _clock = clock ?? DateTime.now,
        _trackerChanges = trackerChanges,
        _readFeedTracker = readFeedTracker ?? _userFeedTracker,
        _openHubPayload = openHubPayload ?? openMalHubPayload;

  /// The app's service; it also polls MAL's notification hub ([MalHubPoller]).
  static NotificationService instance = NotificationService(pollMalHub: true);

  /// Start [MalHubPoller.instance] from [init] (the app's instance only, not tests').
  final bool pollMalHub;

  /// Opens a tapped MAL hub notification (`malhub:` payloads, see [MalHubPayload]); the
  /// other payloads, private messages included, go to [onOpen].
  final void Function(String payload) _openHubPayload;

  /// Last scheduling run (shared pref, milliseconds since epoch).
  static const String lastRunKey = 'notifications_last_run_v1';

  /// The account whose lists the last run planned from (shared pref, the tracker's name).
  static const String feedKey = 'notifications_feed_tracker_v1';

  /// Pause between a preference change and the reschedule it triggers.
  final Duration debounce;

  /// Minimum time between two automatic runs.
  final Duration refreshEvery;

  final NotificationBackend _backend;
  final CandidateLoader _loadCandidates;
  final EpisodeSource _loadEpisodes;
  final CoverFetcher _fetchCover;
  final NotificationTexts _texts;
  final NotificationPreferences Function() _readPrefs;
  final DateTime Function() _clock;
  final Listenable? _trackerChanges;
  final AccountType Function() _readFeedTracker;

  final ValueNotifier<NotificationSummary> summary =
      ValueNotifier(const NotificationSummary());

  /// Opens a tapped notification (set by the app once its navigator exists).
  void Function(String payload)? onOpen;

  bool _initialized = false;
  String? _launchPayload;
  String? _pendingTap;
  Future<void>? _running;
  bool _runAgain = false;
  bool _runAgainForced = false;
  Timer? _debounceTimer;
  StreamSubscription<AppPreferences>? _prefsSub;
  Listenable? _boundTrackers;
  AccountType? _lastFeedTracker;

  bool get isInitialized => _initialized;

  /// True where scheduled notifications exist (Android).
  bool get isSupported => _backend.isSupported;

  /// Called once by `main` before `runApp`. Must stay cheap and must never throw: a
  /// notification failure cannot block the app start.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    bindTracker(_trackerChanges ?? UserManager.instance);
    try {
      await _backend.init(_handleTap);
      final launch = await _backend.launchPayload();
      if (MalHubPayload.isHub(launch)) {
        // Not a route of the home shell: opened once the navigator exists (flushPendingTap).
        _pendingTap = launch;
      } else {
        _launchPayload = launch;
      }
    } catch (e) {
      debugPrint('Notifications init: $e');
    }
    if (pollMalHub) unawaited(MalHubPoller.instance.start());
  }

  /// The payload of the notification that launched the app, once: a Phoenix restart or a
  /// rebuilt root must not open it a second time.
  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  /// A MAL hub payload opened by [_openHubPayload]; a private message's payload (thread,
  /// inbox) is an app route instead and goes to [onOpen] (`AppRoutes.openFromNotification`).
  static bool _isHubOnly(String payload) =>
      MalHubPayload.isHub(payload) && MalHubPayload.messageLink(payload) == null;

  void _handleTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (_isHubOnly(payload)) {
      if (onOpen == null) {
        _pendingTap = payload;
      } else {
        _openHubPayload(payload);
      }
      return;
    }
    final open = onOpen;
    if (open == null) {
      _pendingTap = payload;
      return;
    }
    open(payload);
  }

  /// Delivers a tap that arrived before [onOpen] was set.
  void flushPendingTap() {
    final payload = _pendingTap;
    final open = onOpen;
    if (payload == null || open == null) return;
    _pendingTap = null;
    if (_isHubOnly(payload)) {
      _openHubPayload(payload);
      return;
    }
    open(payload);
  }

  /// Follows the preference store: any change of the notification group reschedules
  /// (debounced) or cancels everything when turned off.
  void bindPreferences(Stream<AppPreferences> changes) {
    _prefsSub?.cancel();
    AppPreferences? last;
    _prefsSub = changes.listen((state) {
      final before = last?.notifications;
      last = state;
      if (before == null || before == state.notifications) return;
      requestReschedule();
    });
  }

  /// Follows the active tracker: when the account that feeds the reminders changes (the user
  /// switches tracker, or connects / disconnects the one in use), the lists of the new account
  /// replace the old ones (debounced forced run). [source] notifies on every account change;
  /// `UserManager`, which `AccountBloc` keeps in step with the selected account, in the app.
  void bindTracker(Listenable source) {
    _boundTrackers?.removeListener(_onTrackerChanged);
    _boundTrackers = source;
    _lastFeedTracker = _readFeedTracker();
    source.addListener(_onTrackerChanged);
  }

  void _onTrackerChanged() {
    final feed = _readFeedTracker();
    if (feed == _lastFeedTracker) return;
    _lastFeedTracker = feed;
    if (!_readPrefs().enabled) return;
    unawaited(_rescheduleIfFeedDiffers(feed));
  }

  /// The alarms in place were planned from another account than [feed]. Startup loads the
  /// saved tracker after `init`, which looks like a switch: the account of the last run
  /// tells the two apart, and a never-run schedule is left to the startup refresh.
  Future<void> _rescheduleIfFeedDiffers(AccountType feed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(feedKey);
      if (saved == null || saved == feed.name) return;
    } catch (_) {
      // Unreadable store: reschedule, a spare run is harmless.
    }
    requestReschedule();
  }

  /// Schedules a forced run shortly, merging bursts of changes.
  void requestReschedule() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => scheduleAll(force: true));
  }

  /// Startup refresh: runs when notifications are on and the last run is old enough.
  Future<void> refreshIfDue() => scheduleAll();

  Future<NotificationPermissions> permissions() async {
    try {
      return await _backend.permissions();
    } catch (e) {
      debugPrint('Notifications permissions: $e');
      return const NotificationPermissions();
    }
  }

  /// Asks Android for the permissions (the system dialog / settings screen).
  Future<NotificationPermissions> requestPermissions() async {
    try {
      return await _backend.requestPermissions();
    } catch (e) {
      debugPrint('Notifications request: $e');
      return const NotificationPermissions();
    }
  }

  /// Cancels everything and schedules again from the current lists and schedule.
  /// [force] skips the once-a-day limit. Calls made while a run is going share it and queue
  /// one more run, so the last preference change always wins. Never throws.
  Future<void> scheduleAll({bool force = false}) {
    final running = _running;
    if (running != null) {
      _runAgain = true;
      _runAgainForced = _runAgainForced || force;
      return running;
    }
    return _running = _run(force).whenComplete(() {
      _running = null;
      if (_runAgain) {
        final forced = _runAgainForced;
        _runAgain = false;
        _runAgainForced = false;
        scheduleAll(force: forced);
      }
    });
  }

  Future<void> _run(bool force) async {
    if (!isSupported) return;
    try {
      final prefs = _readPrefs();
      if (!prefs.enabled) {
        await _backend.cancelAll();
        summary.value = const NotificationSummary();
        return;
      }
      final now = _clock();
      if (!force && !await _isDue(now)) {
        if (summary.value.updatedAt == null) await _refreshPending();
        return;
      }
      summary.value = summary.value.copyWith(running: true);
      final allowed = await _backend.permissions();
      if (!allowed.notifications) {
        summary.value = const NotificationSummary();
        return;
      }

      final List<AiringCandidate> candidates;
      final List<AiringEpisode> episodes;
      final feed = _readFeedTracker();
      try {
        candidates = await _loadCandidates();
        episodes = await _loadEpisodes();
      } on _NeedsMal {
        summary.value = const NotificationSummary(needsMal: true);
        return;
      } catch (e) {
        debugPrint('Notifications: lists unavailable ($e)');
        summary.value = NotificationSummary(
          scheduled: summary.value.scheduled,
          next: summary.value.next,
          updatedAt: summary.value.updatedAt,
          failed: true,
        );
        return;
      }

      final planned = NotificationPlanner.plan(
        candidates: candidates,
        schedule: episodes,
        prefs: prefs,
        texts: _texts,
        now: now,
      );
      final covers = await _covers(planned);
      await _backend.cancelAll();
      var count = 0;
      for (final n in planned) {
        try {
          await _backend.schedule(n, _lookOf(n, covers[n.malId], prefs.largeImage));
          count++;
        } catch (e) {
          debugPrint('Notifications: could not schedule ${n.id} ($e)');
        }
      }
      await _saveLastRun(now, feed);
      summary.value = NotificationSummary(
        scheduled: count,
        next: planned.isEmpty ? null : planned.first.at,
        updatedAt: now,
      );
    } catch (e) {
      debugPrint('Notifications: $e');
      summary.value = summary.value.copyWith(running: false);
    }
  }

  Future<void> _refreshPending() async {
    try {
      summary.value = NotificationSummary(scheduled: await _backend.pendingCount());
    } catch (_) {}
  }

  Future<bool> _isDue(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(lastRunKey);
      if (last == null) return true;
      return now.difference(DateTime.fromMillisecondsSinceEpoch(last)) >= refreshEvery;
    } catch (_) {
      return true;
    }
  }

  Future<void> _saveLastRun(DateTime now, AccountType feed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(lastRunKey, now.millisecondsSinceEpoch);
      await prefs.setString(feedKey, feed.name);
    } catch (_) {}
  }

  NotificationLook _lookOf(PlannedNotification n, String? cover, bool bigPicture) {
    final watching = n.kind == NotificationKind.watching;
    return NotificationLook(
      channelName: watching ? _texts.watchingChannel : _texts.planToWatchChannel,
      channelDescription:
          watching ? _texts.watchingChannelDescription : _texts.planToWatchChannelDescription,
      imagePath: cover,
      bigPicture: bigPicture,
    );
  }

  /// Covers of the planned anime, four downloads at a time; an anime without a cover just
  /// gets a plain notification.
  Future<Map<int?, String?>> _covers(List<PlannedNotification> planned) async {
    final urls = <int, String>{};
    for (final n in planned) {
      final id = n.malId;
      if (id != null && n.imageUrl != null && n.imageUrl!.isNotEmpty) urls[id] = n.imageUrl!;
    }
    final result = <int?, String?>{};
    final queue = urls.entries.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final entry = queue.removeLast();
        try {
          result[entry.key] = await _fetchCover(entry.value, entry.key);
        } catch (_) {}
      }
    }

    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    return result;
  }

  /// Removes every scheduled notification and schedules them again.
  Future<void> clearAndReschedule() => scheduleAll(force: true);

  /// Shows a notification in two seconds (the settings "test" button). [candidate] is the
  /// anime it opens; the default is a well known series so the tap can be checked anywhere.
  Future<bool> sendTest({AiringCandidate? candidate, Duration delay = const Duration(seconds: 2)}) async {
    if (!isSupported) return false;
    try {
      final allowed = await _backend.permissions();
      if (!allowed.notifications) return false;
      final anime = candidate ?? _sampleCandidate;
      final prefs = _readPrefs();
      final at = _clock().toUtc().add(delay);
      final n = PlannedNotification(
        id: testId,
        kind: NotificationKind.watching,
        at: at,
        title: _texts.episodeTitle(anime.title, 1),
        body: _texts.testBody,
        payload: animePayload(anime.malId),
        malId: anime.malId,
        episode: 1,
        imageUrl: anime.imageUrl,
      );
      String? cover;
      if (anime.imageUrl != null) {
        cover = await _fetchCover(anime.imageUrl!, anime.malId).catchError((_) => null);
      }
      await _backend.schedule(n, _lookOf(n, cover, prefs.largeImage));
      return true;
    } catch (e) {
      debugPrint('Notifications test: $e');
      return false;
    }
  }

  /// Id of the test notification (a real one is `malId * 8 + slot`, never 1).
  static const int testId = 1;

  static const AiringCandidate _sampleCandidate = AiringCandidate(
    malId: 21,
    title: 'One Piece',
    status: 'watching',
    imageUrl: 'https://cdn.myanimelist.net/images/anime/1244/138851l.jpg',
  );

  void dispose() {
    _debounceTimer?.cancel();
    _prefsSub?.cancel();
    _boundTrackers?.removeListener(_onTrackerChanged);
    _boundTrackers = null;
  }

  // ---- defaults ----

  static Future<List<AiringEpisode>> _loadScheduleEpisodes() async {
    await AiringSchedule.instance.ensureLoaded();
    return AiringSchedule.instance.episodes;
  }

  /// Whose lists feed the notifications: the active tracker when it is AniList, Kitsu or
  /// Simkl and connected, else MyAnimeList.
  static AccountType candidateTracker(
      AccountType active, bool Function(AccountType tracker) isAuthenticated) {
    switch (active) {
      case AccountType.anilist:
      case AccountType.kitsu:
      case AccountType.simkl:
        return isAuthenticated(active) ? active : AccountType.myanimelist;
      case AccountType.myanimelist:
      case AccountType.none:
        return AccountType.myanimelist;
    }
  }

  static AccountType _userFeedTracker() =>
      candidateTracker(UserManager.instance.currentTracker, UserManager.instance.isAuthenticated);

  /// The watching and plan-to-watch lists of the active tracker: AniList, Kitsu and Simkl
  /// map their entries to MAL ids (the schedule is keyed by them), MyAnimeList (also the
  /// fallback when no tracker is active) reads its own lists.
  static Future<List<AiringCandidate>> _loadMalCandidates() async {
    switch (_userFeedTracker()) {
      case AccountType.anilist:
        return AnilistListService.instance.airingCandidates();
      case AccountType.kitsu:
        return KitsuLibrary.instance.airingCandidates();
      case AccountType.simkl:
        return SimklListService.instance.airingCandidates();
      case AccountType.myanimelist:
      case AccountType.none:
        break;
    }
    if (!UserManager.instance.isAuthenticated(AccountType.myanimelist)) throw const _NeedsMal();
    const fields = ['status', 'num_episodes', 'broadcast', 'main_picture'];
    final api = MalApi();
    final lists = await Future.wait([
      api.getUserAnimeList(status: AnimeListStatus.watching, fields: fields),
      api.getUserAnimeList(status: AnimeListStatus.planToWatch, fields: fields),
    ]);
    return [
      for (var i = 0; i < lists.length; i++)
        for (final a in lists[i])
          if (a.status != 'finished_airing')
            AiringCandidate(
              malId: a.id,
              title: a.title,
              status: i == 0 ? 'watching' : 'plan_to_watch',
              imageUrl: a.imageUrl.isEmpty ? null : a.imageUrl,
              numEpisodes: a.numEpisodes,
              airingStatus: a.status,
              broadcastDay: a.broadcast?.dayOfTheWeek,
              broadcastTime: a.broadcast?.startTime,
            ),
    ];
  }

  static Future<String?> _downloadCover(String url, int malId) async {
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/notification_covers');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$malId.jpg');
      if (await file.exists() && await file.length() > 0) return file.path;
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

class _NeedsMal implements Exception {
  const _NeedsMal();
}

/// The strings of the notifications, read from `S` when a run starts (current language).
class _SNotificationTexts implements NotificationTexts {
  const _SNotificationTexts();

  @override
  String episodeTitle(String anime, int episode) => S.current.Notif_Episode_Title(episode, anime);

  @override
  String newEpisodeTitle(String anime) => S.current.Notif_New_Episode_Title(anime);

  @override
  String get watchingBody => S.current.Notif_Body_Watching;

  @override
  String get planToWatchBody => S.current.Notif_Body_Plan;

  @override
  String get watchingChannel => S.current.Notif_Channel_Watching;

  @override
  String get watchingChannelDescription => S.current.Notif_Channel_Watching_Desc;

  @override
  String get planToWatchChannel => S.current.Notif_Channel_Plan;

  @override
  String get planToWatchChannelDescription => S.current.Notif_Channel_Plan_Desc;

  @override
  String get testBody => S.current.Notif_Test_Body;
}
