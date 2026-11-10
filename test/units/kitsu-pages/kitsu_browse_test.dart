import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_browse_screen.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_media_page.dart' as title_page;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media_detail.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';

import 'kitsu_fakes.dart';

Future<void> pumpBrowse(WidgetTester tester, Widget screen) => tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: screen,
    ));

void main() {
  setUpAll(() => S.load(const Locale('en')));
  late KitsuCatalog original;
  setUp(() => original = KitsuCatalog.instance);
  tearDown(() => KitsuCatalog.instance = original);

  testWidgets('a browse screen lists the titles of its query', (tester) async {
    final fake = FakeKitsu((r) async => jsonResponse({
          'data': [animeResource(1, 'Frieren', malId: 5), animeResource(2, 'Dungeon Meshi')],
          'included': [...mappingsOf(1, malId: 5), ...mappingsOf(2)],
        }));
    KitsuCatalog.instance = KitsuCatalog(http: fake.kitsu);
    await pumpBrowse(
      tester,
      const KitsuBrowseScreen(
        title: 'Top rated',
        query: KitsuMediaQuery(isAnime: true, sort: 'ratingRank'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Top rated'), findsOneWidget);
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Dungeon Meshi'), findsOneWidget);
    expect(fake.requests.single.url.queryParameters['sort'], 'ratingRank');
  });

  testWidgets('a title without a MyAnimeList page still opens its Kitsu page on tap', (tester) async {
    final detail = KitsuMediaDetailService.instance;
    addTearDown(() => KitsuMediaDetailService.instance = detail);
    KitsuMediaDetailService.instance = KitsuMediaDetailService(
        graphql: KitsuGraphql(client: MockClient((_) async => http.Response('{}', 503))));
    final fake = FakeKitsu((r) async => jsonResponse({
          'data': [animeResource(2, 'Dungeon Meshi')],
          'included': mappingsOf(2),
        }));
    KitsuCatalog.instance = KitsuCatalog(http: fake.kitsu);
    await pumpBrowse(tester,
        const KitsuBrowseScreen(title: 'x', query: KitsuMediaQuery(isAnime: true)));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Dungeon Meshi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(title_page.KitsuMediaPage), findsOneWidget);
  });

  testWidgets('a failed first page offers a retry', (tester) async {
    var fail = true;
    final fake = FakeKitsu((r) async => fail
        ? jsonResponse({}, 500)
        : jsonResponse({'data': [animeResource(1, 'Frieren', malId: 5)], 'included': mappingsOf(1, malId: 5)}));
    KitsuCatalog.instance = KitsuCatalog(http: fake.kitsu);
    await pumpBrowse(tester,
        const KitsuBrowseScreen(title: 'x', query: KitsuMediaQuery(isAnime: true)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Frieren'), findsOneWidget);
  });

  testWidgets('the search screen waits for text, then searches', (tester) async {
    final fake = FakeKitsu((r) async => jsonResponse({
          'data': [animeResource(1, 'Frieren', malId: 5)],
          'included': mappingsOf(1, malId: 5),
        }));
    KitsuCatalog.instance = KitsuCatalog(http: fake.kitsu);
    await pumpBrowse(tester, KitsuBrowseScreen.search());
    expect(find.text('Type a title to search the Kitsu catalogue.'), findsOneWidget);
    expect(fake.requests, isEmpty);
    await tester.enterText(find.byType(TextField), 'frieren');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(fake.requests.single.url.queryParameters['filter[text]'], 'frieren');
    expect(find.text('Frieren'), findsOneWidget);
  });
}
