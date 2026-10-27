import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/top_characters.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import '../../helpers/pump_app.dart';

class _MemoryStore implements TopCharactersStore {
  String? saved;

  @override
  Future<String?> read(Duration maxAge) async => saved;

  @override
  Future<void> write(String body) async => saved = body;
}

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('TopCharacters', () {
    test('parse sorts by favorites and drops bad rows', () {
      final rows = TopCharacters.parse(
          '[{"mal_id":1,"favorites":10,"name":"A"},{"mal_id":"2","favorites":50},{"mal_id":3},"x"]');
      expect(rows.map((r) => r.id), [2, 1]);
      expect(rows.first.favorites, 50);
      expect(TopCharacters.parse('not json'), isEmpty);
      expect(TopCharacters.parse('{"a":1}'), isEmpty);
    });

    test('downloads once, falls back to the second file and saves the body', () async {
      final store = _MemoryStore();
      final urls = <String>[];
      final top = TopCharacters(
        store: store,
        parser: (b) async => TopCharacters.parse(b),
        download: (url) async {
          urls.add(url.pathSegments.last);
          return url.pathSegments.last == 'top_characters.json'
              ? '[{"mal_id":7,"favorites":120}]'
              : null;
        },
      );
      await Future.wait([top.ensureLoaded(), top.ensureLoaded()]);
      expect(urls, ['top_characters.min.json', 'top_characters.json']);
      expect(top.favoritesOf(7), 120);
      expect(top.topIds, [7]);
      expect(store.saved, isNotNull);
    });

    test('offline leaves the list empty without throwing', () async {
      final top = TopCharacters(
        store: _MemoryStore(),
        parser: (b) async => TopCharacters.parse(b),
        download: (_) async => throw Exception('offline'),
      );
      await top.ensureLoaded();
      expect(top.isLoaded, isTrue);
      expect(top.topIds, isEmpty);
    });
  });

  group('CommunityRecommendation.fromJikan', () {
    Map<String, dynamic> entry(int id) => {
          'mal_id': id,
          'title': 'T$id',
          'images': {'jpg': {'image_url': 'https://x/$id.jpg'}},
        };

    test('reads a pair, the text and the user', () {
      final r = CommunityRecommendation.fromJikan({
        'entry': [entry(1), entry(2)],
        'content': '  great  ',
        'user': {'username': 'bob'},
      })!;
      expect(r.first.id, 1);
      expect(r.second.imageUrl, 'https://x/2.jpg');
      expect(r.text, 'great');
      expect(r.username, 'bob');
    });

    test('rejects a malformed item', () {
      expect(CommunityRecommendation.fromJikan({'entry': [entry(1)]}), isNull);
      expect(CommunityRecommendation.fromJikan('x'), isNull);
    });
  });

  group('SeasonKey', () {
    test('shifts across years in both directions', () {
      const k = SeasonKey(SeasonType.WINTER, 2026);
      expect(k.shifted(-1), const SeasonKey(SeasonType.FALL, 2025));
      expect(const SeasonKey(SeasonType.FALL, 2026).shifted(1), const SeasonKey(SeasonType.WINTER, 2027));
      expect(k.shifted(5), const SeasonKey(SeasonType.SPRING, 2027));
      expect(k.storageKey, '2026-winter');
    });
  });

  test('entryFromAnime maps the list status and scores', () {
    final a = Anime(
      id: 5,
      title: 'Show',
      imageUrl: 'https://x/5.jpg',
      score: 8.1,
      members: 1000,
      numEpisodes: 12,
      mediaType: 'tv',
      status: 'currently_airing',
      genres: const ['Action'],
      myListStatus: MyListStatus.fromJson({
        'status': 'watching',
        'score': 7,
        'num_episodes_watched': 3,
        'is_rewatching': false,
        'updated_at': '2026-01-02T03:04:05+00:00',
      }),
    );
    final e = entryFromAnime(a);
    expect(e.status, ListEntryStatus.current);
    expect(e.releaseState, ReleaseState.releasing);
    expect(e.progress, 3);
    expect(e.score, 7);
    expect(e.total, 12);
    expect(e.meanScore, 8.1);
  });

  group('ExploreCache', () {
    test('shares a load and retries after a failure', () async {
      final cache = ExploreCache.instance..clear();
      var calls = 0;
      expect(await cache.load('k', () async => ++calls), 1);
      expect(await cache.load('k', () async => ++calls), 1);
      await expectLater(cache.load('bad', () async => throw StateError('x')), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(await cache.load('bad', () async => 9), 9);
    });
  });

  testWidgets('AsyncSection shows an error then retries', (tester) async {
    var fail = true;
    await pumpInApp(
      tester,
      AsyncSection<int>(
        reloadKey: 'a',
        load: () async {
          if (fail) throw StateError('no');
          return 42;
        },
        skeleton: const Text('loading'),
        builder: (_, v) => Text('value $v'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.current.Explore_Section_Failed), findsOneWidget);
    fail = false;
    await tester.tap(find.text(S.current.Explore_Try_Again));
    await tester.pumpAndSettle();
    expect(find.text('value 42'), findsOneWidget);
  });
}
