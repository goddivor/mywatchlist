import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show RankedPersonHtml;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/explore/explore_images.dart';
import 'package:mywatchlist/screens/explore/explore_sections.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart' show SearchCatalog;
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_screen.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart' show ShadowButton;

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

String _fixture(String name) =>
    File('test/units/profile-tabs/fixtures/$name').readAsStringSync();

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('ExploreImages', () {
    test('every bundled file exists and every alias points to one', () {
      for (final path in ExploreImages.allFiles) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
      for (final target in ExploreImages.aliasTargets) {
        expect(ExploreImages.hasFile(target), isTrue, reason: target);
      }
      expect(File(ExploreImages.licenseAsset).readAsStringSync(), contains('MIT License'));
    });

    test('every ranking and genre group has its picture', () {
      for (final r in rankingMap.keys) {
        expect(rankingImage(r, isAnime: true), isNotNull, reason: '$r');
      }
      for (final r in mangaRankingMap.keys) {
        expect(rankingImage(r, isAnime: false), isNotNull, reason: '$r');
      }
      for (final category in ['anime', 'manga']) {
        for (final g in ExploreData.genreGroups(category)) {
          expect(ExploreImages.genreGroup(g.type, category), isNotNull, reason: g.type);
        }
      }
    });

    test('genres have a picture except the few DailyAL never drew', () {
      final missing = <String>[];
      for (final category in ['anime', 'manga']) {
        for (final g in ExploreData.genreGroups(category)) {
          for (final id in g.ids) {
            if (ExploreImages.genre(id, category) == null) missing.add('${id}_$category');
          }
        }
      }
      expect(missing, unorderedEquals(['82_anime', '83_anime', '83_manga']));
    });

    test('identical pictures resolve to one file', () {
      expect(ExploreImages.genre(8, 'anime'), ExploreImages.genre(1, 'anime'));
      expect(ExploreImages.genre(999, 'anime'), isNull);
    });
  });

  group('genre groups', () {
    test('come offline, in MAL order, explicit genres included', () {
      for (final category in ['anime', 'manga']) {
        final groups = ExploreData.genreGroups(category);
        expect(groups.map((g) => g.type),
            ['Genres', 'Explicit Genres', 'Themes', 'Demographics']);
        final explicit = groups.firstWhere((g) => g.isExplicit);
        expect(explicit.ids, [9, 49, 12]);
        for (final id in [for (final g in groups) ...g.ids]) {
          expect(SearchCatalog.genresEng(manga: category == 'manga').containsKey(id), isTrue);
        }
      }
    });
  });

  group('ExploreSources.firstNonEmpty', () {
    test('the first source with rows wins, a late one is not started', () async {
      var lateStarted = false;
      final rows = await ExploreSources.firstNonEmpty<int>([
        ExploreSource(() async => [1, 2]),
        ExploreSource(() async {
          lateStarted = true;
          return [3];
        }, delay: const Duration(milliseconds: 200)),
      ]);
      expect(rows, [1, 2]);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(lateStarted, isFalse);
    });

    test('a delayed source starts at once when the running ones failed', () async {
      final watch = Stopwatch()..start();
      final rows = await ExploreSources.firstNonEmpty<int>([
        ExploreSource(() async => throw Exception('MAL page')),
        ExploreSource(() async => null),
        ExploreSource(() async => [7], delay: const Duration(seconds: 30)),
      ]);
      expect(rows, [7]);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('empty answers give an empty list, failures an error', () async {
      expect(
        await ExploreSources.firstNonEmpty<int>([
          ExploreSource(() async => const []),
          ExploreSource(() async => throw Exception('x')),
        ]),
        isEmpty,
      );
      await expectLater(
        ExploreSources.firstNonEmpty<int>([
          ExploreSource(() async => throw Exception('a')),
          ExploreSource(() async => null),
        ]),
        throwsException,
      );
    });

    test('gives up after the budget', () async {
      final never = Completer<List<int>?>();
      await expectLater(
        ExploreSources.firstNonEmpty<int>([ExploreSource(() => never.future)],
            budget: const Duration(milliseconds: 50)),
        throwsA(anything),
      );
    });
  });

  group('MAL pages read on the device', () {
    setUp(() => ExploreMalPages.parseInline = true);
    tearDown(() => ExploreMalPages.parseInline = false);

    test('the recommendation feed becomes community recommendations', () {
      final rows = ExploreMalPages.parseRecommendations(
          (body: _fixture('recommendations_feed.html'), category: 'anime'));
      final recs = [
        for (final r in rows)
          if (CommunityRecommendation.fromHtml(r) case final c?) c,
      ];
      expect(recs, hasLength(3));
      expect(recs.first.first.id, 486);
      expect(recs.first.second.id, 35838);
      expect(recs.first.username, 'Anonymous_Llama');
      expect(recs.first.first.imageUrl, isNotNull);
    });

    test('the stacks listing becomes interest stacks', () {
      final stacks = ExploreMalPages.parseStacks(_fixture('stacks_search.html'));
      expect(stacks, isNotEmpty);
      expect(stacks.first.title, isNotEmpty);
    });

    test('a page that is not MAL (challenge, maintenance) is an error', () {
      expect(() => ExploreMalPages.parseStacks('<html><body>Just a moment</body></html>'),
          throwsFormatException);
    });
  });

  group('widgets', () {
    testWidgets('a character card shows its favourites badge', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpInApp(
        tester,
        const SizedBox(
          height: 240,
          child: PersonTile(
            person: RankedPersonHtml(id: 1, name: 'Lelouch', rank: 1, favorites: 171234),
            isPerson: false,
          ),
        ),
      );
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('171K'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Favorited by 171.?234 people')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the explicit genres card is not listed with NSFW off', (tester) async {
      await pumpInApp(tester, const SizedBox(width: 400, child: GenresRow(category: 'anime')));
      expect(find.text(S.current.Explore_Genre_Explicit), findsNothing);
      expect(find.byType(ExplorePictureCard), findsWidgets);
      expect(find.byIcon(Icons.eighteen_up_rating_rounded), findsNothing);
    });

    for (final locale in ['en', 'fr_FR']) {
      testWidgets('seasonal picker: years, seasons, then two uncut buttons ($locale)',
          (tester) async {
        await S.load(Locale.fromSubtags(
            languageCode: locale.split('_').first,
            countryCode: locale.contains('_') ? locale.split('_').last : null));
        addTearDown(() => S.load(const Locale('en')));
        tester.view.physicalSize = const Size(2400, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Future<(Rect, Rect)> layout(double width, double scale) async {
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: const SingleChildScrollView(child: SeasonalPicker()),
                    ),
                  ),
                ),
              ),
            ),
          ));
          expect(tester.takeException(), isNull);
          // DailyAL's order: the years row, the seasons row, then the buttons.
          final now = SeasonKey.current();
          final year = tester.getRect(find.text('${now.year}'));
          final season = tester.getRect(find.text(seasonLabel(now.season)));
          expect(season.top, greaterThan(year.bottom));
          for (final label in [S.current.Search_By_Season, S.current.WeeklyAnime]) {
            final text = tester.widget<Text>(find.text(label));
            expect(text.maxLines, isNull, reason: label);
            expect(text.overflow, isNull, reason: label);
            expect(tester.getRect(find.text(label)).top, greaterThan(season.bottom));
          }
          return (
            tester.getRect(find.widgetWithText(ShadowButton, S.current.Search_By_Season)),
            tester.getRect(find.widgetWithText(ShadowButton, S.current.WeeklyAnime)),
          );
        }

        // A narrow phone with large text: one button under the other.
        final (a, b) = await layout(320, 1.3);
        expect(b.top, greaterThanOrEqualTo(a.bottom));
        // A wide screen: side by side, as in DailyAL.
        final (c, d) = await layout(2000, 1.0);
        expect(d.top, c.top);
        expect(d.left, greaterThan(c.right));
      });
    }

    testWidgets('the picked year and season open that season', (tester) async {
      final pushed = <Route<dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [_RouteLog(pushed)],
        home: const Scaffold(body: SingleChildScrollView(child: SeasonalPicker())),
      ));
      final now = SeasonKey.current();
      final year = now.year - 1;
      // Tap the previous year, then another season than the current one.
      await tester.tap(find.text('$year'));
      await tester.pump();
      final other = SeasonType.values[(now.season.index + 2) % 4];
      await tester.tap(find.text(seasonLabel(other)));
      await tester.pump();
      pushed.clear();
      await tester.tap(find.text(S.current.Search_By_Season));
      expect(pushed, hasLength(1));
      final route = pushed.single as MaterialPageRoute<dynamic>;
      final page = route.builder(tester.element(find.byType(SeasonalPicker)));
      expect(page, isA<SeasonalScreen>());
      expect((page as SeasonalScreen).initial, SeasonKey(other, year));
      // Do not build the seasonal screen (it would load the season).
      route.navigator!.removeRoute(route);
      await tester.pump();
    });
    testWidgets('a picture card falls back to a tile without a picture', (tester) async {
      await pumpInApp(
        tester,
        ExplorePictureCard(
          asset: null,
          label: 'Urban Fantasy',
          icon: Icons.category_rounded,
          hue: 10,
          onTap: () {},
        ),
      );
      expect(find.byType(ExploreTile), findsOneWidget);
    });
  });
}

/// Keeps the routes pushed on the navigator.
class _RouteLog extends NavigatorObserver {
  final List<Route<dynamic>> pushed;

  _RouteLog(this.pushed);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}
