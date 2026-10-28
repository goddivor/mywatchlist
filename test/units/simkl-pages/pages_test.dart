import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Simkl/simkl_explore_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_forum_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_home_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_profile_page.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSimkl fake;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    HomeSectionCache.clear();
    // No poster on purpose: a test never loads a picture over the network.
    fake = FakeSimkl((r) {
      if (r.url.path == '/search/anime') {
        final q = r.url.queryParameters['q'];
        return FakeSimkl.json(q == 'zzz'
            ? []
            : [
                {'title': 'Found $q', 'ids': {'simkl_id': 50}},
              ]);
      }
      final title = switch (r.url.path) {
        '/anime/trending' => 'Trending show',
        '/anime/premieres/new' => 'Premiere show',
        '/anime/airing' => 'Airing show',
        _ => 'Other',
      };
      return FakeSimkl.json([
        {'title': title, 'ids': {'simkl_id': 1, 'mal': 11}, 'ratings': {'simkl': {'rating': 8.0}}},
      ]);
    });
    SimklDiscoverService.instance = SimklDiscoverService(client: fake.client);
  });

  Future<void> pump(WidgetTester tester, Widget page, {Locale locale = const Locale('en')}) async {
    final prefs = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(prefs.close);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AccountBloc()),
        BlocProvider(create: (_) => HomePreferencesBloc()),
        BlocProvider.value(value: prefs),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: page,
      ),
    ));
    await tester.pumpAndSettle();
  }

  setUpAll(() async {
    await LanguageBloc.apply('en');
    await initializeDateFormatting();
  });

  testWidgets('home shows the rows of the default home preferences, "Continue watching" only signed in',
      (tester) async {
    await pump(tester, const SimklHomePage());
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('New premieres'), findsOneWidget);
    expect(find.text('Trending show'), findsOneWidget);
    expect(find.text('Premiere show'), findsOneWidget);
    expect(find.text('Airing today'), findsNothing, reason: 'not among the default sections');
    expect(find.text('Continue watching'), findsNothing);
  });

  testWidgets('home shows a retry when Simkl is unreachable', (tester) async {
    SimklDiscoverService.instance =
        SimklDiscoverService(client: FakeSimkl((_) => FakeSimkl.json({}, 503)).client);
    await pump(tester, const SimklHomePage());
    expect(find.text('Try again'), findsWidgets);
  });

  testWidgets('explore shows the trending grid, switches feed and searches', (tester) async {
    await pump(tester, const SimklExplorePage());
    expect(find.text('Trending show'), findsOneWidget);
    expect(find.text('★ 8.0'), findsOneWidget);

    await tester.tap(find.text('New premieres'));
    await tester.pumpAndSettle();
    expect(find.text('Premiere show'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'naruto');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Found naruto'), findsOneWidget);
    expect(find.text('New premieres'), findsNothing, reason: 'feeds are replaced by results');

    await tester.enterText(find.byType(SearchBar), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('No anime found'), findsOneWidget);
  });

  testWidgets('explore speaks French', (tester) async {
    await LanguageBloc.apply('fr_FR');
    addTearDown(() => LanguageBloc.apply('en'));
    await pump(tester, const SimklExplorePage(), locale: const Locale('fr', 'FR'));
    expect(find.text('Tendances'), findsOneWidget);
    expect(find.text('Nouvelles sorties'), findsOneWidget);
    expect(find.text('Rechercher un animé sur Simkl'), findsOneWidget);
  });

  testWidgets('forum says Simkl has none', (tester) async {
    await pump(tester, const SimklForumPage());
    expect(find.text('Simkl has no forum'), findsOneWidget);
  });

  testWidgets('list and profile ask to sign in when Simkl is not connected', (tester) async {
    await pump(tester, const SimklUserPage());
    expect(find.text('Sign in with Simkl'), findsOneWidget);
    expect(find.text('Anime'), findsOneWidget, reason: 'no anime / manga switch');
    expect(find.text('Manga'), findsNothing);

    await pump(tester, const SimklUserProfilePage(isSelf: true));
    expect(find.text('Sign in with Simkl'), findsOneWidget);
  });
}
