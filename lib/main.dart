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
import 'package:mywatchlist/services/auth/simkl_auth.dart';
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

/// Global reference to the current logged-in MAL user
late UserMal usermal;
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

  // Initialize user data from stored preferences
  await UserMal.instance.loadFromPreferences();
  await UserAnilist.instance.loadFromPreferences();
  await UserKitsu.instance.loadFromPreferences();
  await UserSimkl.instance.loadFromPreferences();

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
          ChangeNotifierProvider(create: (_) => UserMal()),
          ChangeNotifierProvider(create: (_) => UserAnilist()),
          ChangeNotifierProvider(create: (_) => UserKitsu()),
          ChangeNotifierProvider(create: (_) => UserSimkl()),
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
    // Listen for deep links (auth callbacks)
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.toString().startsWith('mywatchlist://callback')) {
        SimklAuth().handleSimklAuthRedirect(uri);
      }
    });
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
