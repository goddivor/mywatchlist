// ignore_for_file: library_private_types_in_public_api

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

/// Global UserData
late UserMal usermal;
final int homeIndex = 0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Load environment variables from the .env file
  await dotenv.load(fileName: "assets/.env");

  // Load shared preferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Initialize user data
  await UserMal.instance.loadFromPreferences();
  await UserAnilist.instance.loadFromPreferences();
  await UserKitsu.instance.loadFromPreferences();
  await UserSimkl.instance.loadFromPreferences();

  // Initialize APIs
  final jikanApi = JikanApi();
  final malApi = MalApi();
  final malScraper = MalScraper();

  // Initialize blocs
  final accountBloc = AccountBloc();
  final themeBloc = ThemeBloc(prefs: sharedPreferences);
  final languageBloc = LanguageBloc(prefs: sharedPreferences);

  // Load initial data for blocs
  accountBloc.add(LoadAccountEvent());
  themeBloc.add(ThemeLoadStarted());
  languageBloc.add(LanguageLoadStarted());

  // Mettre à jour le singleton lorsqu'il y a un changement d'état dans AccountBloc
  accountBloc.stream.listen((state) {
    if (state is AccountLoaded) {
      AccountManagerSingleton().updateAccountType(state.selectedAccountType);
    }
  });

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
            BlocProvider(
                create: (context) => AccountBloc()..add(LoadAccountEvent())),
            BlocProvider(create: (context) => themeBloc),
            BlocProvider(create: (context) => languageBloc),
            BlocProvider(
              create: (context) => RequestsBloc(
                malScraper: malScraper,
                jikanApi: jikanApi,
                malApi: malApi,
              ),
            ),
            BlocProvider(
                create: (context) =>
                    HomePreferencesBloc()..add(LoadHomePreferencesEvent())),
            // I will add another BlocProvider for requests here
          ],
          child: MyWatchListApp(),
        ),
      ),
    ),
  );
}

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
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.toString().startsWith('mywatchlist://callback')) {
        SimklAuth().handleSimklAuthRedirect(
            uri); // Traitement de l'authentification Simkl
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Apply the selected theme
          theme: themeState.themeData,
          home: const OpenScreen(),
          routes: {
            '/login': (context) => const LoginPage(),
          },
        );
      },
    );
  }
}

// Fonction pour redémarrer l'application
void restartApp(BuildContext context) {
  Phoenix.rebirth(context);
}
