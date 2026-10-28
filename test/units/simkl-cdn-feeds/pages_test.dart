import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Simkl/simkl_explore_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_home_page.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCdn cdn;
  late FakeApi api;

  setUpAll(() async {
    await LanguageBloc.apply('en');
    await initializeDateFormatting();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeSectionCache.clear();
    final now = DateTime.now();
    cdn = FakeCdn((path) {
      if (path == '/calendar/v2/anime.json') {
        return jsonResponse(calendarFile({
          7: DateTime(now.year, now.month, now.day, 23, 59),
          8: DateTime(now.year, now.month, now.day + 1, 12),
        }));
      }
      final window = path.split('/').last.split('_').first;
      return jsonResponse(trendingFile('Trend $window', count: 2));
    });
    api = FakeApi((url) {
      final label = switch (url.path) {
        '/anime/premieres/new' => 'Premiere',
        '/anime/premieres/soon' => 'Soon',
        final p when p.startsWith('/anime/best/') => 'Best ${p.split('/').last} ${url.queryParameters['type']}',
        final p when p.startsWith('/anime/genres/') => 'Genre ${p.split('/')[3]} p${url.queryParameters['page']}',
        _ => 'Other',
      };
      final count = url.path.startsWith('/anime/genres/') && url.queryParameters['page'] == '1' ? 60 : 2;
      return jsonResponse([
        for (var i = 1; i <= count; i++)
          {
            'title': '$label #$i',
            'ids': {'simkl_id': (url.queryParameters['page'] == '2' ? 500 : 0) + i, 'mal': 9},
          },
      ]);
    });
    SimklDiscoverService.instance = SimklDiscoverService(client: api.client, cdn: cdn.cdn);
  });

  Future<void> pump(WidgetTester tester, Widget page, {Locale locale = const Locale('en')}) async {
    final prefs = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(prefs.close);
    tester.view.physicalSize = const Size(1500, 2400);
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

  testWidgets('explore: trending periods come from the CDN', (tester) async {
    await pump(tester, const SimklExplorePage());
    expect(find.text('Trend today 1'), findsOneWidget);
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(find.text('Trend week 1'), findsOneWidget);
    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(find.text('Trend month 1'), findsOneWidget);
    expect(cdn.seen.map((s) => s.url.path), [
      '/discover/trending/anime/today_100.json',
      '/discover/trending/anime/week_100.json',
      '/discover/trending/anime/month_100.json',
    ]);
    expect(api.seen, isEmpty, reason: 'no quota spent on trending');
  });

  testWidgets('explore: the schedule lists the picked day from the calendar', (tester) async {
    await pump(tester, const SimklExplorePage());
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.text('Show 7'), findsOneWidget);
    expect(find.text('Show 8'), findsNothing);
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    expect(find.text('Show 8'), findsOneWidget);
    expect(find.text('Show 7'), findsNothing);
    expect(cdn.seen.where((s) => s.url.path == '/calendar/v2/anime.json'), hasLength(1));
  });

  testWidgets('explore: coming soon and best anime with its bucket and format', (tester) async {
    await pump(tester, const SimklExplorePage());
    await tester.tap(find.text('Coming soon'));
    await tester.pumpAndSettle();
    expect(find.text('Soon #1'), findsOneWidget);

    await tester.tap(find.text('Best anime'));
    await tester.pumpAndSettle();
    expect(find.text('Best all all #1'), findsOneWidget);
    await tester.tap(find.text('Most voted'));
    await tester.pumpAndSettle();
    expect(find.text('Best voted all #1'), findsOneWidget);
    await tester.tap(find.text('All formats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Movies').last);
    await tester.pumpAndSettle();
    expect(find.text('Best voted movies #1'), findsOneWidget);

    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Best anime'));
    await tester.pumpAndSettle();
    expect(find.text('Best voted movies #1'), findsOneWidget, reason: 'options kept per list');
  });

  testWidgets('explore: genre browse picks a genre and loads the next page at the end', (tester) async {
    await pump(tester, const SimklExplorePage());
    await tester.tap(find.text('Genres'));
    await tester.pumpAndSettle();
    expect(find.text('Genre all p1 #1'), findsOneWidget);
    await tester.tap(find.text('All genres'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Isekai'));
    await tester.pumpAndSettle();
    expect(find.text('Genre isekai p1 #1'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Genre isekai p2 #1'), 600, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Genre isekai p2 #1'), findsOneWidget);
    expect(api.seen.where((s) => s.url.path == '/anime/genres/isekai/all/all/all/popular-this-month').map((s) => s.url.queryParameters['page']),
        ['1', '2']);
  });

  testWidgets('explore speaks French', (tester) async {
    await LanguageBloc.apply('fr_FR');
    addTearDown(() => LanguageBloc.apply('en'));
    await pump(tester, const SimklExplorePage(), locale: const Locale('fr', 'FR'));
    for (final text in ['Tendances', 'Programme', 'Bientôt', 'Meilleurs animés', 'Genres', 'Cette semaine', 'Ce mois-ci']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    await tester.tap(find.text('Meilleurs animés'));
    await tester.pumpAndSettle();
    expect(find.text('Tous les formats'), findsOneWidget);
    expect(find.text('Les plus vus'), findsOneWidget);
  });

  testWidgets('home rows read the CDN and their header opens the whole list', (tester) async {
    await pump(tester, const SimklHomePage());
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('Trend today 1'), findsOneWidget);
    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    expect(find.byType(SimklFeedPage), findsOneWidget);
    expect(find.text('Trend today 2'), findsOneWidget);
    expect(cdn.seen.where((s) => s.url.path.contains('today_100')), hasLength(1), reason: 'the row answer is reused');
  });
}
