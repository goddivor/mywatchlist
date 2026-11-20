import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart' show MediaTile;
import 'package:mywatchlist/screens/studios/studio_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/studio_page.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _fixture() =>
    File('test/units/studio-page/fixtures/kyoto_animation.html').readAsStringSync();

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('parser', () {
    final page = parseStudioPage((_fixture(), 2))!;

    test('name, big logo, facts and description', () {
      expect(page.name, 'Kyoto Animation');
      expect(page.logo, contains('company_logos/'));
      expect(page.logo, contains('600x600'));
      expect({for (final f in page.facts) f.label: f.value}, {
        'Synonyms': 'KyoAni',
        'Japanese': '京都アニメーション',
        'Established': 'Jul 12, 1985',
        'Member Favorites': '40,625',
      });
      expect(page.about, startsWith('Kyoto Animation (Kyoto Animation Co., Ltd.)'));
      expect(page.about, contains('\n\n'), reason: 'paragraphs kept');
    });

    test('the links of Available At', () {
      expect(page.links.map((l) => l.label), contains('YouTube'));
      expect(page.links.first.url, startsWith('http'));
    });

    test('the anime with their kind, score, members and start date', () {
      expect(page.anime, hasLength(8));
      final first = page.anime.first;
      expect(first.id, 72);
      expect(first.title, 'Full Metal Panic? Fumoffu');
      expect(first.type, StudioAnimeType.tv);
      expect(first.score, 8.02);
      expect(first.members, 315576);
      expect(first.startDate, 20030826);
      expect(first.imageUrl, 'https://cdn.myanimelist.net/images/anime/4/75260.jpg');
      final types = page.anime.map((a) => a.type).toSet();
      expect(types, containsAll([StudioAnimeType.tv, StudioAnimeType.movie, StudioAnimeType.ona,
        StudioAnimeType.other]));
    });

    test('not a studio page: null', () {
      expect(parseStudioPage(('<html><body>Just a moment...</body></html>', 2)), isNull);
    });
  });

  group('screen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ListStatusCache.instance.resetForTest();
      StudioPages.reset();
    });

    final page = parseStudioPage((_fixture(), 2))!;

    Future<void> pump(WidgetTester tester) async {
      StudioPages.source = (_) async => page;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: const StudioScreen(id: 2, name: 'Kyoto Animation'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('facts, links and the anime under the pinned bar', (tester) async {
      await pump(tester);
      expect(find.text('Established'), findsOneWidget);
      expect(find.text('Jul 12, 1985'), findsOneWidget);
      expect(find.text('Anime · 8'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'TV'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'OVA'), findsNothing, reason: 'no OVA in the page');
    });

    testWidgets('a kind tab keeps only that kind', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Movie'));
      await tester.pump();
      final movies = page.anime.where((a) => a.type == StudioAnimeType.movie).toList();
      await tester.scrollUntilVisible(find.text(movies.first.title), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(movies.first.title), findsWidgets);
      expect(find.text('Full Metal Panic? Fumoffu'), findsNothing);
    });

    testWidgets('the display menu switches the grid to a list', (tester) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('studio-display')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('List').last);
      await tester.pumpAndSettle();
      expect(find.byType(MediaTile), findsWidgets);
    });

    testWidgets('links are round buttons named in their tooltip', (tester) async {
      await pump(tester);
      expect(find.byTooltip('YouTube'), findsOneWidget);
    });

    testWidgets('a failed page offers Retry', (tester) async {
      StudioPages.source = (_) async => throw const SocketException('down');
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: const StudioScreen(id: 2, name: 'Kyoto Animation'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('This studio could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Kyoto Animation'), findsWidgets, reason: 'the name is known before the page');
    });
  });
}
