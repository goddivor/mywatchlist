import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';

import '../../helpers/pump_app.dart';

Anime _anime({
  String? status,
  String? startDate,
  Broadcast? broadcast,
  int? episodes = 12,
  String? mediaType = 'tv',
  MyListStatus? mine,
  double score = 9.04,
  int members = 252000,
}) =>
    Anime(
      id: 1,
      title: 'Frieren',
      imageUrl: '',
      score: score,
      members: members,
      numEpisodes: episodes,
      status: status,
      startDate: startDate,
      broadcast: broadcast,
      mediaType: mediaType,
      myListStatus: mine,
    );

MyListStatus _mine(String status, {int score = 0, int watched = 0}) => MyListStatus(
      status: status,
      score: score,
      numEpisodesWatched: watched,
      isRewatching: false,
      updatedAt: '',
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('estimateAiredEpisodes', () {
    final broadcast = Broadcast(dayOfTheWeek: 'friday', startTime: '23:00');

    test('counts one episode per week from the premiere', () {
      final anime = _anime(
          status: 'currently_airing', startDate: '2026-10-02', broadcast: broadcast);
      // Premiere 2026-10-02 23:00 JST = 14:00 UTC.
      expect(estimateAiredEpisodes(anime, DateTime.utc(2026, 10, 2, 13)), isNull);
      expect(estimateAiredEpisodes(anime, DateTime.utc(2026, 10, 2, 15)), 1);
      expect(estimateAiredEpisodes(anime, DateTime.utc(2026, 10, 9, 15)), 2);
      expect(estimateAiredEpisodes(anime, DateTime.utc(2026, 10, 27)), 4);
    });

    test('hides when it cannot be told', () {
      final now = DateTime.utc(2026, 10, 27);
      expect(estimateAiredEpisodes(_anime(status: 'finished_airing', startDate: '2026-10-02'), now), isNull);
      expect(estimateAiredEpisodes(_anime(status: 'currently_airing', startDate: '2026-10'), now), isNull);
      expect(estimateAiredEpisodes(_anime(status: 'currently_airing', startDate: '2026-10-02', episodes: 0), now), isNull);
      expect(estimateAiredEpisodes(_anime(status: 'currently_airing', startDate: '2026-10-02', mediaType: 'movie'), now), isNull);
      // More weeks than episodes: a break, the estimate would be wrong.
      expect(estimateAiredEpisodes(_anime(status: 'currently_airing', startDate: '2026-01-02'), now), isNull);
    });

    test('reads Jikan statuses and ISO dates', () {
      final anime = _anime(status: 'Currently Airing', startDate: '2026-10-02T00:00:00+00:00', mediaType: 'TV');
      expect(estimateAiredEpisodes(anime, DateTime.utc(2026, 10, 10)), 2);
    });
  });

  group('resolveCardEntry', () {
    test('cache wins over the node, a removal hides the node entry', () {
      final anime = _anime(mine: _mine('watching', score: 7, watched: 3));
      expect(resolveCardEntry(node: anime, category: 'anime')!.progress, 3);
      final cached = resolveCardEntry(
        node: anime,
        category: 'anime',
        cached: const CachedListStatus(status: 'completed', score: 9, progress: 12),
      )!;
      expect(cached.status, 'completed');
      expect(resolveCardEntry(node: anime, category: 'anime', deleted: true), isNull);
      expect(resolveCardEntry(node: _anime(), category: 'anime'), isNull);
    });
  });

  test('progressFraction', () {
    expect(progressFraction(3, 12), 0.25);
    expect(progressFraction(20, 12), 1);
    expect(progressFraction(3, 0), isNull);
    expect(progressFraction(null, 12), isNull);
  });

  test('NodeStatusValue translates and colours', () async {
    final v = NodeStatusValue.fromString('plan_to_watch');
    expect(v.status, 'PTW');
    expect(v.fullLabel, 'Plan to watch');
    expect(v.color, isNotNull);
    await S.load(const Locale('fr', 'FR'));
    expect(NodeStatusValue.fromString('completed').status, 'FIN');
    expect(NodeStatusValue.fromString('nonsense').status, isNull);
    await S.load(const Locale('en'));
  });

  testWidgets('compact card shows the score and members as separate texts', (tester) async {
    ListStatusCache.instance = ListStatusCache();
    await pumpInApp(
      tester,
      SizedBox(
        width: 140,
        height: 200,
        child: AnimeGridCard(
          node: _anime(),
          displaySubType: DisplaySubType.compact,
          gridHeight: 200,
        ),
      ),
    );
    expect(find.text('9.04'), findsOneWidget);
    expect(find.text('252K'), findsOneWidget);
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('status badge follows the list status cache', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cache = ListStatusCache.instance = ListStatusCache();
    cache.put(1, const CachedListStatus(status: 'watching', score: 8, progress: 2));
    await pumpInApp(
      tester,
      SizedBox(
        width: 140,
        height: 220,
        child: AnimeGridCard(
          node: _anime(),
          showCardBar: true,
          displaySubType: DisplaySubType.comfortable,
          gridHeight: 220,
        ),
      ),
    );
    expect(find.text('CW'), findsOneWidget);
    cache.put(1, const CachedListStatus(status: 'completed', score: 8, progress: 12));
    await tester.pump();
    expect(find.text('CMP'), findsOneWidget);
    expect(find.text('CW'), findsNothing);
    // Let the cache's delayed save fire before the test ends.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('right-to-left: badge texts stay whole', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SizedBox(
            width: 140,
            height: 200,
            child: AnimeGridCard(
              node: _anime(),
              displaySubType: DisplaySubType.compact,
              gridHeight: 200,
            ),
          ),
        ),
      ),
    ));
    expect(find.text('9.04'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty row is translated', (tester) async {
    await pumpInApp(tester, const ContentListWidget(category: 'manga', items: []));
    expect(find.text('No manga available'), findsOneWidget);
  });
}
