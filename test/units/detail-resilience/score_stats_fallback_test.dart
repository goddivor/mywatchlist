import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show ContentStatsHtml, ScoreVotesHtml, StatusCountsHtml;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/content_stats_source.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/content/scorestatisticswidget.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

/// MAL's stats page as `MwlApi.getContentStats` returns it: highest score first.
ContentStatsHtml _malPage() => ContentStatsHtml(
      scores: [
        for (var s = 10; s >= 1; s--) ScoreVotesHtml(score: s, votes: s * 100, percentage: s * 1.8),
      ],
      statuses: const StatusCountsHtml(
        watching: 40,
        completed: 300,
        onHold: 10,
        dropped: 5,
        planToWatch: 145,
        total: 500,
      ),
    );

Future<AnimeStatistics> _jikanDown(int id, String category) async =>
    throw StateError('Jikan unreachable');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  tearDown(ContentStatsSource.reset);

  group('Score Stats: Jikan, then MAL stats page, then MAL figures (#134)', () {
    testWidgets('Jikan down, MAL stats page answers: bars from MAL with a source note', (tester) async {
      ContentStatsSource.jikan = _jikanDown;
      final asked = <String>[];
      ContentStatsSource.mal = (id, category) async {
        asked.add('$category:$id');
        return _malPage();
      };
      await pumpInApp(
        tester,
        SizedBox(width: 400, child: ScoreStatisticsWidget(id: 7, category: 'anime', horizPadding: 0)),
      );
      await _settle(tester);
      expect(asked, ['anime:7']);
      final bars = tester.widget<ScoreBars>(find.byType(ScoreBars));
      expect(bars.scores.map((s) => s.score), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(bars.fromMyAnimeList, isTrue);
      expect(find.text(S.current.Res_Score_Total_Votes('5.5K')), findsOneWidget);
      expect(find.text(S.current.Res_Source_Mal), findsOneWidget);
      expect(find.text(S.current.Res_Score_Unavailable), findsNothing);
    });

    testWidgets('Jikan down, MAL stats page null: MAL figures and Retry', (tester) async {
      ContentStatsSource.jikan = _jikanDown;
      ContentStatsSource.mal = (id, category) async => null;
      final mal = MalAnime(id: 8, title: 'T', mean: 7.5, rank: 12);
      await pumpInApp(
        tester,
        SingleChildScrollView(child: ScoreStatisticsWidget(id: 8, category: 'anime', horizPadding: 0, mal: mal)),
      );
      await _settle(tester);
      expect(find.byType(ScoreBars), findsNothing);
      expect(find.text('7.50'), findsOneWidget);
      expect(find.text(S.current.Res_Score_Unavailable), findsOneWidget);
      expect(find.text(S.current.Res_Retry), findsOneWidget);
    });

    testWidgets('Retry after both failed asks the MAL stats page again', (tester) async {
      ContentStatsSource.jikan = _jikanDown;
      var calls = 0;
      ContentStatsSource.mal = (id, category) async => ++calls == 1 ? null : _malPage();
      await pumpInApp(
        tester,
        SingleChildScrollView(
          child: ScoreStatisticsWidget(id: 9, category: 'anime', horizPadding: 0, mal: MalAnime(id: 9, title: 'T', mean: 7)),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text(S.current.Res_Retry));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(calls, 2);
      expect(find.byType(ScoreBars), findsOneWidget);
    });

    testWidgets('Jikan answers: MAL stats page not asked, no source note', (tester) async {
      ContentStatsSource.jikan = (id, category) async => AnimeStatistics(scores: [
            for (var s = 1; s <= 10; s++) ScoreStatistics(score: s, votes: 10, percentage: 10),
          ]);
      ContentStatsSource.mal = (id, category) async => fail('MAL stats page asked while Jikan answered');
      await pumpInApp(
        tester,
        SizedBox(width: 400, child: ScoreStatisticsWidget(id: 10, category: 'anime', horizPadding: 0)),
      );
      await _settle(tester);
      expect(tester.widget<ScoreBars>(find.byType(ScoreBars)).fromMyAnimeList, isFalse);
      expect(find.text(S.current.Res_Source_Mal), findsNothing);
    });
  });

  test('concurrent loads of one title share one request', () async {
    var jikanCalls = 0;
    ContentStatsSource.jikan = (id, category) async {
      jikanCalls++;
      throw StateError('down');
    };
    ContentStatsSource.mal = (id, category) async => _malPage();
    final a = ContentStatsSource.load(14, 'anime');
    final b = ContentStatsSource.load(14, 'anime');
    expect(identical(a, b), isTrue);
    expect((await a).source, StatsSource.myAnimeList);
    await b;
    expect(jikanCalls, 1);
  });
}
