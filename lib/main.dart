// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/login_page.dart';
import 'package:mywatchlist/screens/explore/explore_images.dart';
import 'package:mywatchlist/screens/open_screen.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/anilist_auth_v2.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:mywatchlist/services/notifications/notification_backend.dart' show PluginNotificationBackend;
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:app_links/app_links.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/deep_links.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/language/language_state.dart';
import 'package:mywatchlist/user/language/supported_languages.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/requests/requests_bloc.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:workmanager/workmanager.dart';

// The message poller lives with the hub poller; kept visible here for the settings screen.
export 'package:mywatchlist/services/notifications/mal_hub_poller.dart' show MalHubMessagesPoller, MalMessagesWatcher;

/// Global UserManager instance (POO architecture for multi-tracker)
late UserManager userManager;
/// Initial index for home navigation
final int homeIndex = 0;

/// Navigator of the app: lets a tapped notification open a screen from outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Application entry point
/// Initializes services, preferences and runs the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ExploreImages.registerLicense();

  // Run at the panel's highest refresh rate (90/120 Hz) instead of the 60 Hz default.
  await _useHighRefreshRate();

  // Load environment variables from .env
  await dotenv.load(fileName: "assets/.env");

  // Load shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // DailyAL preferences (the contract read by every feature): legacy keys moved first, then
  // the bloc starts from the saved values so the first frame already uses them.
  final preferencesStore = PreferencesStore(sharedPreferences);
  await preferencesStore.migrateLegacy();
  final preferencesBloc = PreferencesBloc(store: preferencesStore);

  // Airing notifications: plugin start and the notification that launched the app (never
  // throws), then follow the notification preferences to reschedule when they change.
  // Registration only: the poller (mal_hub_poller.dart) also reads the MAL inbox each round.
  MalHubPoller.instance = MalHubMessagesPoller();
  await NotificationService.instance.init();
  NotificationService.instance.bindPreferences(preferencesBloc.stream);

  // Saved list statuses in memory before the first frame, so cards show their badges at once.
  await ListStatusCache.instance.ensureLoaded();

  // Initialize UserManager (POO architecture with BaseUser inheritance)
  userManager = UserManager.instance;
  await userManager.initializeAllUsers();

  // MAL notifications and messages, and AniList notifications, while the app is closed
  // (Android WorkManager, every 30 min).
  unawaited(MalBackgroundPolling.instance.start(preferencesBloc.stream, userManager));

  // Initialize API clients
  final jikanApi = JikanApi(); // Jikan REST client
  final malApi = MalApi();     // MAL REST client
  final malScraper = MalScraper(); // MAL scraper client

  // Initialize Blocs for state management
  final accountBloc = AccountBloc();
  final themeBloc = ThemeBloc(prefs: sharedPreferences);
  // Starts from the saved language; its strings are loaded before the first frame.
  final languageBloc = LanguageBloc(prefs: sharedPreferences);
  await languageBloc.applyCurrent();

  // Trigger initial loading of data in Blocs
  accountBloc.add(LoadAccountEvent());
  themeBloc.add(ThemeLoadStarted());

  // Update account singleton on account changes
  accountBloc.stream.listen((state) {
    if (state is AccountLoaded) {
      AccountManagerSingleton().updateAccountType(state.selectedAccountType);
    }
  });

  // Run the Flutter app with Phoenix for hot restart
  runApp(
    Phoenix(
      child: MultiProvider(
        providers: [
          // Legacy User singletons (used by existing API/UI code)
          ChangeNotifierProvider(create: (_) => UserMal()),
          ChangeNotifierProvider(create: (_) => UserAnilist()),
          ChangeNotifierProvider(create: (_) => UserKitsu()),
          ChangeNotifierProvider(create: (_) => UserSimkl()),
          // UserManager with V2 architecture
          ChangeNotifierProvider.value(value: userManager),
        ],
        child: MultiBlocProvider(
          providers: [
            // The instances created above: the AccountManagerSingleton listener watches this one.
            BlocProvider.value(value: accountBloc),
            BlocProvider.value(value: themeBloc),
            BlocProvider.value(value: languageBloc),
            BlocProvider.value(value: preferencesBloc),
            BlocProvider(
              create: (context) => RequestsBloc(
                malScraper: malScraper,
                jikanApi: jikanApi,
                malApi: malApi,
              ),
            ),
            BlocProvider(create: (context) => HomePreferencesBloc()..add(LoadHomePreferencesEvent())),
          ],
          child: MyWatchListApp(),
        ),
      ),
    ),
  );
}

/// Asks Android for the display mode with the highest refresh rate at the current resolution
/// (DailyAL does the same). Without it most 90/120 Hz phones keep Flutter at 60 Hz. Never throws:
/// unsupported devices (Android < 6, emulators without modes) simply stay where they are.
Future<void> _useHighRefreshRate() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e) {
    debugPrint('High refresh rate unavailable: $e');
  }
}

/// Root widget of the MyWatchList application
class MyWatchListApp extends StatefulWidget {
  const MyWatchListApp({super.key});

  @override
  _MyWatchListAppState createState() => _MyWatchListAppState();
}

class _MyWatchListAppState extends State<MyWatchListApp> {
  StreamSubscription? _sub;

  /// Payload of the notification that launched the app, taken once so a Phoenix restart or a
  /// rebuilt root does not open it again.
  String? _launchPayload;

  @override
  void initState() {
    super.initState();
    _launchPayload = NotificationService.instance.takeLaunchPayload();
    // A notification tapped while the app runs opens its screen on the app navigator.
    NotificationService.instance.onOpen = _openNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.flushPendingTap();
      // Refresh the airing reminders (at most once a day) once the first frame is out of the way.
      Future<void>.delayed(const Duration(seconds: 5), NotificationService.instance.refreshIfDue);
    });
    // myanimelist.net links (tapped in the app or handed by the system) open their screen.
    unawaited(DeepLinks.start());
    // Listen for deep links (OAuth callbacks from multiple trackers)
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.scheme == 'com.teen.mywatchlist') {
        _handleOAuthCallback(uri);
      }
    });
  }

  void _openNotification(String payload) {
    final context = appNavigatorKey.currentContext;
    if (context == null) return;
    AppRoutes.openFromNotification(context, payload);
  }

  /// Route OAuth callbacks to the appropriate tracker auth handler
  /// Based on the callback host (myanimelist-callback, anilist-callback, simkl-callback)
  /// Uses new V2 Auth classes with UserManager architecture
  Future<void> _handleOAuthCallback(Uri uri) async {
    print('🔗 OAuth callback received: ${uri.toString()}');
    print('   Host: ${uri.host}');
    print('   Code: ${uri.queryParameters['code']?.substring(0, 10)}...');

    // Route based on callback host
    switch (uri.host) {
      case 'myanimelist-callback':
        print('✅ Routing to MAL auth handler (V2)');
        final malAuth = MalAuthV2();
        final success = await malAuth.checkIfSignIn(uri);
        if (success) {
          print('   ✅ MAL authentication successful');
          // UserMalV2 is already updated via setAuthResponse
          // UserManager listeners will propagate the change
        } else {
          print('   ❌ MAL authentication failed');
        }
        break;

      case 'anilist-callback':
        print('✅ Routing to AniList auth handler (V2)');
        final anilistAuth = AnilistAuthV2();
        final success = await anilistAuth.checkIfSignIn(uri);
        if (success) {
          print('   ✅ AniList authentication successful');
        } else {
          print('   ❌ AniList authentication failed');
        }
        break;

      case 'simkl-callback':
        print('✅ Routing to Simkl auth handler (V2)');
        final simklAuth = SimklAuthV2();
        final success = await simklAuth.checkIfSignIn(uri);
        if (success) {
          print('   ✅ Simkl authentication successful');
        } else {
          print('   ❌ Simkl authentication failed');
        }
        break;

      default:
        print('❌ Unknown callback host: ${uri.host}');
    }
  }

  @override
  void dispose() {
    _sub?.cancel(); // Cancel deep link subscription
    if (NotificationService.instance.onOpen == _openNotification) {
      NotificationService.instance.onOpen = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild UI when theme or language changes
    // Only what MaterialApp reads may rebuild it: a rebuild here re-runs every route's build.
    return BlocConsumer<LanguageBloc, LanguageState>(
      listenWhen: (previous, current) => previous != current,
      buildWhen: (previous, current) => previous.appLocale != current.appLocale,
      // Many widgets read S.current (no inherited dependency): rebuild the whole tree once the
      // new strings are loaded, keeping every route and its state.
      listener: (context, _) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll(context)),
      builder: (context, languageState) => BlocBuilder<ThemeBloc, ThemeState>(
      // The background image, its visibility and the other ThemeState fields are read by the
      // screens that draw them, not by MaterialApp.
      buildWhen: _themeChanged,
      builder: (context, themeState) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'MyWatchList',
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // null = follow the device; Arabic switches the whole app to right-to-left.
          locale: languageState.appLocale,
          localeListResolutionCallback: (deviceLocales, supported) =>
              localeFromCode(SupportedLanguages.resolveSystem(deviceLocales ?? const [])),
          supportedLocales: S.delegate.supportedLocales,
          theme: themeState.lightThemeData, // Light theme
          darkTheme: themeState.darkThemeData, // Dark theme
          themeMode: themeState.themeMode, // Theme mode (light/dark/system)
          home: OpenScreen(notificationPayload: _launchPayload),
          routes: {
            '/login': (context) => const LoginPage(),
          },
        );
      },
      ),
    );
  }

  static bool _themeChanged(ThemeState previous, ThemeState current) =>
      previous.themeMode != current.themeMode ||
      previous.lightThemeData != current.lightThemeData ||
      previous.darkThemeData != current.darkThemeData;

  static void _rebuildAll(BuildContext context) {
    if (!context.mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }
}

/// Restarts the application using Phoenix
void restartApp(BuildContext context) {
  Phoenix.rebirth(context);
}


// ---------------------------------------------------------------------------------------------
// MAL hub and AniList notifications in the background
// ---------------------------------------------------------------------------------------------

/// Unique name and task name of the periodic WorkManager job.
const String malHubWorkerName = 'com.teen.mywatchlist.mal_hub_poll';
const String malHubWorkerTask = 'mal_hub_poll';

/// How often the job runs (Android's own minimum is 15 minutes).
const Duration malHubWorkerFrequency = Duration(minutes: 30);

/// Entry point of the background isolate started by WorkManager.
@pragma('vm:entry-point')
void malHubCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await runMalHubWorker();
    await runAnilistWorker();
    // Never "retry": the next period comes in 30 minutes anyway.
    return true;
  });
}

/// One background round: rebuilds what the poller needs in a bare isolate (preferences, the
/// MAL session, the language, the notification plugin), then polls the hub (the job's period
/// is the hub's); the friends' feeds keep their own 3 h interval. Never throws.
Future<void> runMalHubWorker({
  Future<SharedPreferences> Function()? storage,
  MalHubPoller? poller,
}) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await (storage ?? SharedPreferences.getInstance)();
    // The app process wrote the switches: read the file again, not this isolate's copy.
    await prefs.reload();
    await UserManager.instance.mal.loadFromPreferences();
    final language = LanguageBloc(prefs: prefs);
    await language.applyCurrent();
    await language.close();
    final store = PreferencesStore(prefs);
    final round = poller ?? MalHubMessagesPoller(readPrefs: () => store.read().notifications);
    if (round is MalHubMessagesPoller) await round.loadSwitches(prefs);
    MalHubPoller.instance = round;
    if (poller == null) await PluginNotificationBackend().init((_) {});
    await MalHubPoller.instance.poll(forceHub: true);
  } catch (e) {
    debugPrint('MAL hub worker: $e');
  }
}

/// The AniList part of a background round (same job as the MAL hub): rebuilds the AniList
/// session, the language and the notification plugin in the bare isolate, then lets
/// [AnilistBackgroundNotifier] read the inbox. Skipped without an AniList account or with
/// its switch off. Never throws.
Future<void> runAnilistWorker({
  Future<SharedPreferences> Function()? storage,
  AnilistBackgroundNotifier? notifier,
}) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await (storage ?? SharedPreferences.getInstance)();
    await prefs.reload();
    await UserManager.instance.anilist.loadFromPreferences();
    final store = PreferencesStore(prefs);
    final round = notifier ??
        AnilistBackgroundNotifier(readPrefs: () => store.read().notifications, storage: storage);
    await round.loadSwitch(prefs);
    if (!round.wanted) return;
    if (notifier == null) {
      final language = LanguageBloc(prefs: prefs);
      await language.applyCurrent();
      await language.close();
      await PluginNotificationBackend().init((_) {});
    }
    await round.poll();
  } catch (e) {
    debugPrint('AniList worker: $e');
  }
}

/// The part of WorkManager the app uses (a fake in tests).
abstract class MalHubScheduler {
  bool get isSupported;
  Future<void> register();
  Future<void> cancel();
}

class WorkmanagerMalHubScheduler implements MalHubScheduler {
  bool _initialized = false;

  @override
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<void> _init() async {
    if (_initialized) return;
    await Workmanager().initialize(malHubCallbackDispatcher);
    _initialized = true;
  }

  @override
  Future<void> register() async {
    await _init();
    await Workmanager().registerPeriodicTask(
      malHubWorkerName,
      malHubWorkerTask,
      frequency: malHubWorkerFrequency,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      // Battery friendly: only with a network, and not while the battery is low.
      constraints: Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true),
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await Workmanager().cancelByUniqueName(malHubWorkerName);
  }
}

/// Keeps the background job registered exactly while it can be useful: the notification
/// master switch is on and either a MyAnimeList account is signed in with at least one of
/// the MAL switches (hub, friends, messages) on, or an AniList account is signed in with
/// its switch on ([AnilistBackgroundNotifier.wanted]).
class MalBackgroundPolling {
  MalBackgroundPolling({MalHubScheduler? scheduler, bool Function()? wanted})
      : _scheduler = scheduler ?? WorkmanagerMalHubScheduler(),
        _wanted = wanted ?? _defaultWanted;

  static MalBackgroundPolling instance = MalBackgroundPolling();

  final MalHubScheduler _scheduler;
  final bool Function() _wanted;
  bool? _registered;

  bool get isRegistered => _registered == true;

  static bool _defaultWanted() {
    final poller = MalHubPoller.instance;
    final mal = Preferences.current.notifications.enabled &&
        UserManager.instance.isAuthenticated(AccountType.myanimelist) &&
        (poller.pushHub.value || poller.pushFriends.value || MalMessagesWatcher.instance.push.value);
    return mal || AnilistBackgroundNotifier.instance.wanted;
  }

  /// Registers the job at start and follows what decides it.
  Future<void> start(Stream<AppPreferences> preferences, Listenable accounts) async {
    if (!_scheduler.isSupported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final poller = MalHubPoller.instance;
      if (poller is MalHubMessagesPoller) await poller.loadSwitches(prefs);
      await AnilistBackgroundNotifier.instance.loadSwitch(prefs);
    } catch (_) {}
    preferences.listen((_) => unawaited(sync()));
    accounts.addListener(() => unawaited(sync()));
    await sync();
  }

  /// Registers or cancels the job to match [_wanted]. Never throws.
  Future<void> sync() async {
    if (!_scheduler.isSupported) return;
    final wanted = _wanted();
    if (_registered == wanted) return;
    try {
      if (wanted) {
        await _scheduler.register();
      } else {
        await _scheduler.cancel();
      }
      _registered = wanted;
    } catch (e) {
      debugPrint('MAL hub worker registration: $e');
    }
  }
}
