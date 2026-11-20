import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/anime_graph_builder.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_data.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mal-graph-local/fixtures.dart';

/// A saved `GET /manga/{id}?fields=...,related_manga` answer: a start date, no season, and
/// anime adaptations that the manga graph must not follow.
Map<String, dynamic> _manga(int id, List<(int, String)> related, {String start = '2010-04-07'}) => {
      'id': id,
      'title': 'Manga $id',
      'main_picture': {'large': 'https://cdn.myanimelist.net/images/manga/${id}l.jpg'},
      'mean': 8.5,
      'media_type': 'manga',
      'status': 'finished',
      'start_date': start,
      'related_manga': [
        for (final (target, relation) in related)
          {
            'node': {'id': target, 'title': 'Manga $target'},
            'relation_type': relation,
          },
      ],
      'related_anime': [
        {
          'node': {'id': 999, 'title': 'The anime'},
          'relation_type': 'adaptation',
        },
      ],
    };

final Map<int, Map<String, dynamic>> _berserk = {
  2: _manga(2, [(21, 'spin_off'), (22, 'sequel')], start: '1989-08-25'),
  21: _manga(21, [(2, 'parent_story')], start: '2014'),
  22: _manga(22, [(2, 'prequel')], start: '2021-12-10'),
};

List<String> _edges(Map<String, dynamic> json) => [
      for (final e in json['edges'] as List)
        '${e['source']}>${e['target']}:${e['relation_type']}'
    ];

void main() {
  // Built outside the widget test: its fake clock never runs the fetches' real futures.
  late Map<String, dynamic> berserkGraph;
  setUpAll(() async {
    berserkGraph = (await AnimeGraphBuilder(category: 'manga', fetch: FakeMal(_berserk).call)
            .build(2))
        .json;
  });

  test('a manga graph walks related_manga, never the anime adaptations', () async {
    final mal = FakeMal(_berserk);
    final result = await AnimeGraphBuilder(category: 'manga', fetch: mal.call).build(2);
    expect(result.complete, isTrue);
    expect(_edges(result.json), ['2>21:spin_off', '2>22:sequel']);
    expect(mal.asked.toSet(), {2, 21, 22}, reason: 'the anime 999 is never fetched');
  });

  test('a manga start date gives the year and season the layout sorts by', () async {
    final result =
        await AnimeGraphBuilder(category: 'manga', fetch: FakeMal(_berserk).call).build(2);
    final data = AnimeGraphData.fromJson(result.json);
    expect(data.nodes[2]!.year, 1989);
    expect(data.nodes[2]!.season, 'summer');
    expect(data.nodes[21]!.year, 2014);
    expect(data.nodes[21]!.season, isNull, reason: 'a year alone has no season');
    expect(data.nodes[22]!.season, 'fall', reason: 'December is fall on MAL');
    expect(data.nodes[2]!.mediaType, 'manga');
  });

  test('an anime builder still reads related_anime', () async {
    final result = await AnimeGraphBuilder(fetch: FakeMal(franchise).call).build(1);
    expect(_edges(result.json), contains('1>2:sequel'));
  });

  test('anime and manga have their own repository', () {
    expect(AnimeGraphRepository.of('manga'), same(AnimeGraphRepository.manga));
    expect(AnimeGraphRepository.of('anime'), same(AnimeGraphRepository.instance));
  });

  testWidgets('the graph screen of a manga loads the manga graph', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ListStatusCache.instance.resetForTest();
    clearAnimeGraphCache();
    await S.load(const Locale('en'));
    var animeAsked = false;
    animeGraphLoader = (_) async {
      animeAsked = true;
      return AnimeGraphData.empty;
    };
    mangaGraphLoader = (_) async => AnimeGraphData.fromJson(berserkGraph);
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: const AnimeGraphScreen(id: 2, title: 'Berserk', category: 'manga'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(animeAsked, isFalse);
    expect(find.text('3 titles'), findsOneWidget);
    expect(find.text('Manga 22'), findsOneWidget);
  });
}
