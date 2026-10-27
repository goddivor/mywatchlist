import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_data.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_screen.dart';
import 'package:mywatchlist/widgets/graph/related_grid_screen.dart';
import 'package:mywatchlist/widgets/graph/related_groups.dart';

AnimeGraphData _franchise() => AnimeGraphData.fromJson({
      'nodes': [
        for (var i = 1; i <= 6; i++)
          {
            'id': i,
            'title': 'Title $i',
            'media_type': 'tv',
            'status': 'finished_airing',
            'mean': 8.1,
            'start_season': {'year': 2008 + i, 'season': 'spring'}
          },
      ],
      'edges': [
        {'source': 1, 'target': 2, 'relation_type': 'sequel'},
        {'source': 2, 'target': 3, 'relation_type': 'sequel'},
        {'source': 3, 'target': 4, 'relation_type': 'sequel'},
        {'source': 2, 'target': 5, 'relation_type': 'side_story'},
        {'source': 6, 'target': 1, 'relation_type': 'other'},
      ],
    });

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    home: home,
  ));
}

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ListStatusCache.instance.resetForTest();
  });

  testWidgets('draws the franchise and opens a title sheet on tap',
      (tester) async {
    animeGraphLoader = (_) async => _franchise();
    await _pump(tester, const AnimeGraphScreen(id: 2, title: 'Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Relation graph'), findsOneWidget);
    expect(find.text('6 titles'), findsOneWidget);
    expect(find.text('Title 2'), findsOneWidget);

    await tester.tap(find.text('Title 2'));
    await tester.pumpAndSettle();
    expect(find.text('Not in your list'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    // The opened title is already the selected one.
    expect(find.text('Selected'), findsOneWidget);
  });

  testWidgets('a list status from the cache shows in the sheet',
      (tester) async {
    ListStatusCache.instance
        .put(3, const CachedListStatus(status: 'completed'));
    animeGraphLoader = (_) async => _franchise();
    await _pump(tester, const AnimeGraphScreen(id: 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Title 3'));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('a graph without edges explains itself', (tester) async {
    animeGraphLoader = (_) async => AnimeGraphData.empty;
    await _pump(tester, const AnimeGraphScreen(id: 2));
    await tester.pumpAndSettle();
    expect(find.text('The relation graph is not available for this title.'),
        findsOneWidget);
  });

  testWidgets('a failed load offers a retry that loads again', (tester) async {
    var calls = 0;
    animeGraphLoader = (_) async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return _franchise();
    };
    await _pump(tester, const AnimeGraphScreen(id: 99));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 2);
    expect(find.text('6 titles'), findsOneWidget);
  });

  testWidgets('the grid has an All tab and one tab per relation',
      (tester) async {
    Anime anime(int id) => Anime(
        id: id,
        title: 'Anime $id',
        imageUrl: '',
        score: 0,
        members: 0,
        mediaType: 'tv');
    final groups = groupRelated([
      RelatedAnime(
          animenode: anime(1),
          relationType: 'sequel',
          relationTypeFormatted: 'Sequel'),
      RelatedAnime(
          animenode: anime(2),
          relationType: 'side_story',
          relationTypeFormatted: 'Side story'),
    ]);
    await _pump(
        tester,
        RelatedGridScreen(
            category: 'anime', groups: groups, onOpenGraph: () {}));
    await tester.pump();
    expect(find.text('Related anime'), findsOneWidget);
    expect(find.text('2 related titles'), findsOneWidget);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Sequel (1)'), findsOneWidget);
    expect(find.text('Side story (1)'), findsOneWidget);
    expect(find.byTooltip('Relation graph'), findsOneWidget);
  });
}
