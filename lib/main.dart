// ignore_for_file: library_private_types_in_public_api, depend_on_referenced_packages

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/login_page.dart';
import 'package:mywatchlist/screens/open_screen.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/anilist_auth_v2.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:app_links/app_links.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/language/language_event.dart';
import 'package:mywatchlist/user/requests/requests_bloc.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Global UserManager instance (POO architecture for multi-tracker)
late UserManager userManager;
/// Initial index for home navigation
final int homeIndex = 0;

/// Application entry point
/// Initializes services, preferences and runs the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env
  await dotenv.load(fileName: "assets/.env");

  // Load shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize UserManager (POO architecture with BaseUser inheritance)
  userManager = UserManager.instance;
  await userManager.initializeAllUsers();

  // Initialize API clients
  final jikanApi = JikanApi(); // Jikan REST client
  final malApi = MalApi();     // MAL REST client
  final malScraper = MalScraper(); // MAL scraper client

  // Initialize Blocs for state management
  final accountBloc = AccountBloc();
  final themeBloc = ThemeBloc(prefs: sharedPreferences);
  final languageBloc = LanguageBloc(prefs: sharedPreferences);

  // Trigger initial loading of data in Blocs
  accountBloc.add(LoadAccountEvent());
  themeBloc.add(ThemeLoadStarted());
  languageBloc.add(LanguageLoadStarted());

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
            BlocProvider(create: (context) => AccountBloc()..add(LoadAccountEvent())),
            BlocProvider(create: (context) => themeBloc),
            BlocProvider(create: (context) => languageBloc),
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

/// Root widget of the MyWatchList application
class MyWatchListApp extends StatefulWidget {
  const MyWatchListApp({super.key});

  @override
  _MyWatchListAppState createState() => _MyWatchListAppState();
}

class _MyWatchListAppState extends State<MyWatchListApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // Listen for deep links (OAuth callbacks from multiple trackers)
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.scheme == 'com.teen.mywatchlist') {
        _handleOAuthCallback(uri);
      }
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild UI when theme changes
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MyWatchList',
          localizationsDelegates: [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: Locale.fromSubtags(languageCode: "en_US"),
          supportedLocales: S.delegate.supportedLocales,
          theme: themeState.themeData, // Apply selected theme
          home: const OpenScreen(),
          routes: {
            '/login': (context) => const LoginPage(),
          },
        );
      },
    );
  }
}

/// Restarts the application using Phoenix
void restartApp(BuildContext context) {
  Phoenix.rebirth(context);
}
