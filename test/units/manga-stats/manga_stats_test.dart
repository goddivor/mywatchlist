import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/content_stats_source.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/stats_section.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

DetailData _manga() => DetailData(
      id: 2,
      category: 'manga',
      content: MalAnime(id: 2, title: 'Berserk', mediaType: 'manga', status: 'currently_publishing'),
      state: DetailLoadState.loaded,
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  tearDown(ContentStatsSource.reset);

  test('manga pages show Stats then Score stats by default (#110)', () {
    final manga = defaultMangaTabOrder;
    expect(manga, containsAll([TabType.Stats, TabType.ScoreStats]));
    expect(manga.indexOf(TabType.ScoreStats), manga.indexOf(TabType.Stats) + 1);
    expect(manga.last, TabType.More_Info);
  });

  test('Jikan manga statistics fill reading and plan to read', () {
    final s = AnimeStatistics.fromJson(
        {'reading': 12, 'completed': 30, 'on_hold': 4, 'dropped': 2, 'plan_to_read': 50, 'total': 98});
    expect(s.watching, 12);
    expect(s.planToWatch, 50);
  });

  test('a manga without MAL API statistics still gets a Stats section', () {
    expect(statsSection(_manga())?.type, TabType.Stats);
    final anime = DetailData(
      id: 1,
      category: 'anime',
      content: MalAnime(id: 1, title: 'Cowboy Bebop', mediaType: 'tv', status: 'finished_airing'),
      state: DetailLoadState.loaded,
    );
    expect(statsSection(anime), isNull, reason: 'an anime has its statistics in the MAL API');
  });

  testWidgets('the manga Stats section draws Jikan\'s statuses with manga labels', (tester) async {
    ContentStatsSource.jikan = (id, category) async {
      expect(category, 'manga');
      return AnimeStatistics(
          watching: 12, completed: 30, onHold: 4, dropped: 2, planToWatch: 50, total: 98, scores: const []);
    };
    ContentStatsSource.mal = (id, category) async => null;
    await pumpInApp(tester, const MangaStatusStats(id: 2));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Plan to read'), findsOneWidget);
    expect(find.text('Watching'), findsNothing);
  });
}
