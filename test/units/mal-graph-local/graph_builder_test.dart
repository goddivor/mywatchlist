import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/anime_graph_builder.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_data.dart';

import 'fixtures.dart';

List<int> _nodeIds(Map<String, dynamic> json) =>
    [for (final n in json['nodes'] as List) (n as Map)['id'] as int];

List<String> _edges(Map<String, dynamic> json) => [
      for (final e in json['edges'] as List)
        '${e['source']}>${e['target']}:${e['relation_type']}'
    ];

void main() {
  group('AnimeGraphBuilder (mwl-rust-api algorithm)', () {
    test('follows other relations from the root only, never characters',
        () async {
      final mal = FakeMal(franchise);
      final result = await AnimeGraphBuilder(fetch: mal.call).build(1);

      expect(result.complete, isTrue);
      expect(_nodeIds(result.json), [1, 2, 9, 3, 4, 12]);
      expect(_edges(result.json), [
        '1>2:sequel',
        '1>9:other',
        '2>3:sequel',
        '3>4:side_story',
        '9>12:sequel',
      ]);
      // 10 is a character link, 11 an `other` link after the root: never asked.
      expect(mal.asked.toSet(), {1, 2, 9, 3, 4, 12});
      expect(mal.asked.where((id) => id == 3), hasLength(1));
    });

    test('nodes carry the fields the screen reads', () async {
      final result =
          await AnimeGraphBuilder(fetch: FakeMal(franchise).call).build(1);
      final data = AnimeGraphData.fromJson(result.json);
      final node = data.nodes[3]!;
      expect(node.title, 'Title 3');
      expect(node.imageUrl, 'https://cdn.myanimelist.net/images/anime/3l.jpg');
      expect(node.year, 2012);
      expect(node.season, 'spring');
      expect(node.mean, 8.0);
      expect(data.edges, hasLength(5));
      final raw = (result.json['nodes'] as List).first as Map;
      expect(raw['alternative_titles'], {'en': 'English 1', 'ja': ''});
    });

    test('a title of the chain opened first follows the same rules', () async {
      final mal = FakeMal(franchise);
      final result = await AnimeGraphBuilder(fetch: mal.call).build(2);
      // From 2, `other` (11) is followed as the root; 9 is only reachable through 1's
      // `other`, which is not followed after the root.
      expect(_nodeIds(result.json), [2, 1, 3, 11, 4]);
      expect(_edges(result.json),
          ['2>1:prequel', '2>3:sequel', '2>11:other', '3>4:side_story']);
    });

    test('stops at the node bound with what is loaded', () async {
      final mal = FakeMal(franchise);
      final result =
          await AnimeGraphBuilder(fetch: mal.call, maxNodes: 3).build(1);
      expect(result.complete, isFalse);
      expect(result.rateLimited, isFalse);
      expect(mal.asked.toSet(), {1, 2, 9});
      final data = AnimeGraphData.fromJson(result.json);
      expect(data.nodes.keys, unorderedEquals([1, 2, 9]));
      expect(data.edges, hasLength(2));
    });

    test('stops asking on 429 and keeps the graph loaded so far', () async {
      final mal = FakeMal(franchise, limitedAt: 3);
      final result = await AnimeGraphBuilder(fetch: mal.call).build(1);
      expect(result.complete, isFalse);
      expect(result.rateLimited, isTrue);
      expect(mal.asked, isNot(contains(4)));
      expect(mal.asked, isNot(contains(12)));
      expect(_nodeIds(result.json), [1, 2, 9]);
    });

    test('a 429 on the root is an unavailable graph', () async {
      final mal = FakeMal(franchise, limitedAt: 1);
      expect(
        AnimeGraphBuilder(fetch: mal.call).build(1),
        throwsA(isA<AnimeGraphUnavailable>()
            .having((e) => e.rateLimited, 'rateLimited', isTrue)),
      );
    });

    test('a failed neighbour is skipped, the rest is built', () async {
      final answers = Map.of(franchise)..remove(9);
      final result =
          await AnimeGraphBuilder(fetch: FakeMal(answers).call).build(1);
      expect(result.complete, isTrue);
      expect(_nodeIds(result.json), [1, 2, 3, 4]);
    });

    test('asks at most 5 titles at a time', () async {
      final answers = {
        1: malAnime(1, [for (var i = 2; i <= 13; i++) (i, 'side_story')]),
        for (var i = 2; i <= 13; i++) i: malAnime(i, [(1, 'parent_story')]),
      };
      var inFlight = 0;
      var peak = 0;
      Future<GraphFetch> fetch(int id) async {
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 2));
        inFlight--;
        return GraphFetch.ok(answers[id]!);
      }

      final progress = <int>[];
      final result = await AnimeGraphBuilder(fetch: fetch)
          .build(1, onProgress: progress.add);
      expect(peak, 5);
      expect(_nodeIds(result.json), hasLength(13));
      expect(progress.last, 13);
    });
  });

  group('AnimeGraphRepository', () {
    test('builds locally when the backend has nothing, then caches it',
        () async {
      final mal = FakeMal(franchise);
      final store = MemoryGraphStore();
      final repo = AnimeGraphRepository(
        builder: AnimeGraphBuilder(fetch: mal.call),
        store: store,
        remote: (_) async => null, // API_URL empty: no backend request.
        progressInterval: Duration.zero,
      );
      final first = await repo.load(1);
      expect(first.complete, isTrue);
      expect(repo.progressOf(1).value, 6);
      final asked = mal.asked.length;

      final again = await repo.load(1);
      expect(_nodeIds(again.json), _nodeIds(first.json));
      expect(mal.asked, hasLength(asked), reason: 'session cache');

      await Future<void>.delayed(Duration.zero);
      expect(store.saved.keys, [1]);
      final nextLaunch = AnimeGraphRepository(
        builder: AnimeGraphBuilder(fetch: mal.call),
        store: store,
        remote: (_) async => null,
      );
      await nextLaunch.load(1);
      expect(mal.asked, hasLength(asked), reason: 'disk cache');

      store.now = store.now.add(const Duration(days: 4));
      await AnimeGraphRepository(
        builder: AnimeGraphBuilder(fetch: mal.call),
        store: store,
        remote: (_) async => null,
      ).load(1);
      expect(mal.asked.length, greaterThan(asked), reason: 'expired copy');
    });

    test('a cut graph is shown but never cached', () async {
      final store = MemoryGraphStore();
      final repo = AnimeGraphRepository(
        builder: AnimeGraphBuilder(fetch: FakeMal(franchise, limitedAt: 3).call),
        store: store,
        remote: (_) async => null,
      );
      final result = await repo.load(1);
      expect(result.complete, isFalse);
      expect(result.rateLimited, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(store.saved, isEmpty);
    });

    test('uses the backend first when it answers', () async {
      final mal = FakeMal(franchise);
      final repo = AnimeGraphRepository(
        builder: AnimeGraphBuilder(fetch: mal.call),
        store: MemoryGraphStore(),
        remote: (id) async => {
          'nodes': [
            {'id': 1, 'title': 'A'},
            {'id': 2, 'title': 'B'},
          ],
          'edges': [
            {'source': 1, 'target': 2, 'relation_type': 'sequel'},
          ],
        },
      );
      final result = await repo.load(1);
      expect(_nodeIds(result.json), [1, 2]);
      expect(mal.asked, isEmpty);
    });

    test('a failing backend falls back to the local builder', () async {
      final mal = FakeMal(franchise);
      final repo = AnimeGraphRepository(
        builder: AnimeGraphBuilder(fetch: mal.call),
        store: MemoryGraphStore(),
        remote: (_) async => throw Exception('down'),
      );
      final result = await repo.load(1);
      expect(_nodeIds(result.json), hasLength(6));
    });
  });
}
