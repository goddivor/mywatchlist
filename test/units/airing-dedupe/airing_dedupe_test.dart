import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/screens/MAL/detail/header/next_episode.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';

import '../../helpers/pump_app.dart';

LiveChartEpisode _ep(int mal, int n, DateTime at) =>
    LiveChartEpisode(timestamp: at.millisecondsSinceEpoch ~/ 1000, episode: n, malId: mal);

Anime _anime({int episodes = 12, String status = 'currently_airing'}) => Anime(
      id: 1,
      title: 'Frieren',
      imageUrl: '',
      score: 9,
      members: 1,
      numEpisodes: episodes,
      status: status,
      startDate: '2026-10-02',
      mediaType: 'tv',
    );

/// The aired fraction the compact card's progress line paints.
double? _paintedAired(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((c) => c.painter)
    .where((p) => p.runtimeType.toString() == '_ProgressPainter')
    .map((p) => (p as dynamic).aired as double?)
    .single;

void main() {
  final now = DateTime.utc(2026, 10, 27);
  setUpAll(() => S.load(const Locale('en')));

  group('airedEpisodes', () {
    test('reads the real schedule before the weekly estimate', () {
      final schedule = AiringSchedule(fetcher: ({required fromCache}) async => const [])
        // A break in the season: episode 3 airs next although four weeks went by.
        ..replace([_ep(1, 3, now.add(const Duration(days: 2)))], now: now);
      expect(airedEpisodes(_anime(), now, schedule: schedule), 2);
    });

    test('falls back to the estimate when the schedule does not list the anime', () {
      final schedule = AiringSchedule(fetcher: ({required fromCache}) async => const []);
      expect(airedEpisodes(_anime(), now, schedule: schedule), estimateAiredEpisodes(_anime(), now));
    });

    test('never above the total, nothing for a finished anime', () {
      final schedule = AiringSchedule(fetcher: ({required fromCache}) async => const [])
        ..replace([_ep(1, 20, now.add(const Duration(days: 2)))], now: now);
      expect(airedEpisodes(_anime(), now, schedule: schedule), 12);
      expect(airedEpisodes(_anime(status: 'finished_airing'), now, schedule: schedule), isNull);
    });
  });

  group('one LiveChart request for the app', () {
    late AiringSchedule saved;
    setUp(() => saved = AiringSchedule.instance);
    tearDown(() {
      AiringSchedule.instance = saved;
      NextEpisodes.reset();
    });

    test('the detail page next episode reads the shared schedule', () async {
      var calls = 0;
      AiringSchedule.instance = AiringSchedule(fetcher: ({required fromCache}) async {
        calls++;
        return [_ep(7, 2, DateTime.now().add(const Duration(days: 1)))];
      });
      NextEpisodes.reset();
      expect((await NextEpisodes.forMalId(7))?.episode, 2);
      await AiringSchedule.instance.ensureLoaded();
      expect((await NextEpisodes.forMalId(7))?.episode, 2);
      expect(calls, 1);
    });

    test('a failed load throws from season() so callers retry', () async {
      AiringSchedule.instance =
          AiringSchedule(fetcher: ({required fromCache}) async => throw Exception('offline'));
      await expectLater(AiringSchedule.instance.season(), throwsException);
      NextEpisodes.reset();
      expect(await NextEpisodes.forMalId(7), isNull);
    });
  });

  testWidgets('the compact card paints the aired part from the real schedule', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final saved = AiringSchedule.instance;
    addTearDown(() => AiringSchedule.instance = saved);
    final schedule = AiringSchedule.instance =
        AiringSchedule(fetcher: ({required fromCache}) async => const []);
    final today = DateTime.now().toUtc();
    final start = today.subtract(const Duration(days: 30));
    final anime = Anime(
      id: 1,
      title: 'Frieren',
      imageUrl: '',
      score: 9,
      members: 1,
      numEpisodes: 12,
      status: 'currently_airing',
      startDate: '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      mediaType: 'tv',
    );
    final cache = ListStatusCache.instance = ListStatusCache();
    cache.put(1, const CachedListStatus(status: 'watching', score: 0, progress: 1));
    await pumpInApp(
      tester,
      SizedBox(
        width: 140,
        height: 200,
        child: AnimeGridCard(
            node: anime, showCardBar: true, displaySubType: DisplaySubType.compact, gridHeight: 200),
      ),
    );
    // Nothing loaded yet: the weekly estimate (5 episodes in 30 days).
    expect(_paintedAired(tester), closeTo(5 / 12, 1e-9));
    // The schedule loads: episode 3 airs next, so 2 aired (a break in the season).
    schedule.replace([_ep(1, 3, today.add(const Duration(days: 2)))]);
    schedule.notifyListeners();
    await tester.pump();
    expect(_paintedAired(tester), closeTo(2 / 12, 1e-9));
    await tester.pump(const Duration(seconds: 1));
  });
}
