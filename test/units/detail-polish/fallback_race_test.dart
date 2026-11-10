import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/content_stats_source.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mwl_commons/mwl_commons.dart' show ContentStatsHtml, StatusCountsHtml;

/// A Jikan call that never answers (the owner's network).
Future<T> _hang<T>() => Completer<T>().future;

void main() {
  late JikanClient original;

  setUp(() {
    original = JikanClient.instance;
    JikanClient.instance = JikanClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      minInterval: Duration.zero,
    );
  });

  tearDown(() {
    JikanClient.instance = original;
    JikanFallbacks.reset();
    ContentStatsSource.reset();
  });

  test('the default budget is about 12 s with a short head start', () {
    expect(JikanFallbacks.budget, const Duration(seconds: 12));
    expect(JikanFallbacks.headStart < const Duration(seconds: 5), isTrue);
  });

  test('a silent Jikan: the fallback starts after the head start and wins', () async {
    JikanFallbacks.headStart = const Duration(milliseconds: 50);
    JikanFallbacks.budget = const Duration(seconds: 2);
    final watch = Stopwatch()..start();
    var fallbackStartedAt = Duration.zero;
    final result = await JikanFallbacks.race<String>(
      jikan: _hang,
      fallback: () async {
        fallbackStartedAt = watch.elapsed;
        return 'mal';
      },
    );
    expect(result.value, 'mal');
    expect(result.winner, RaceWinner.fallback);
    expect(fallbackStartedAt >= const Duration(milliseconds: 50), isTrue);
    expect(watch.elapsed < const Duration(seconds: 1), isTrue, reason: 'never waits for the Jikan timeout');
  });

  test('a failing Jikan starts the fallback at once', () async {
    JikanFallbacks.headStart = const Duration(seconds: 5);
    final watch = Stopwatch()..start();
    final result = await JikanFallbacks.race<String>(
      jikan: () async => throw StateError('down'),
      fallback: () async => 'mal',
    );
    expect(result.value, 'mal');
    expect(watch.elapsed < const Duration(seconds: 1), isTrue);
  });

  test('Jikan answering first wins and the fallback is never asked', () async {
    var asked = false;
    final result = await JikanFallbacks.race<String>(
      jikan: () async => 'jikan',
      fallback: () async {
        asked = true;
        return 'mal';
      },
    );
    expect(result.fromJikan, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(asked, isFalse);
  });

  test('while the Jikan client skips requests, Jikan is not asked at all', () async {
    JikanClient.instance = JikanClient(
      client: MockClient((_) async => throw http.ClientException('timed out')),
      minInterval: Duration.zero,
    );
    await expectLater(JikanClient.instance.get(Uri.parse('https://api.jikan.moe/v4/x')),
        throwsA(isA<JikanUnavailable>()));
    expect(JikanClient.instance.isUnreachable, isTrue);
    var jikanAsked = false;
    final result = await JikanFallbacks.race<String>(
      jikan: () async {
        jikanAsked = true;
        return 'jikan';
      },
      fallback: () async => 'mal',
    );
    expect(jikanAsked, isFalse);
    expect(result.value, 'mal');
  });

  test('nothing answers: an error at the budget, not later', () async {
    JikanFallbacks.headStart = const Duration(milliseconds: 20);
    JikanFallbacks.budget = const Duration(milliseconds: 200);
    final watch = Stopwatch()..start();
    await expectLater(
      JikanFallbacks.race<String>(jikan: _hang, fallback: _hang),
      throwsA(isA<NoSourceAnswered>().having((e) => e.timedOut, 'timedOut', isTrue)),
    );
    expect(watch.elapsed < const Duration(seconds: 1), isTrue);
  });

  test('both sources fail: NoSourceAnswered with both errors', () async {
    await expectLater(
      JikanFallbacks.race<String>(
        jikan: () async => throw StateError('jikan'),
        fallback: () async => throw StateError('mal'),
      ),
      throwsA(isA<NoSourceAnswered>().having((e) => e.timedOut, 'timedOut', isFalse)),
    );
  });

  test('score stats: a silent Jikan gives MAL stats within the budget', () async {
    JikanFallbacks.headStart = const Duration(milliseconds: 30);
    JikanFallbacks.budget = const Duration(seconds: 2);
    ContentStatsSource.jikan = (id, category) => _hang<AnimeStatistics>();
    ContentStatsSource.mal = (id, category) async => const ContentStatsHtml(
          scores: [],
          statuses: StatusCountsHtml(watching: 1, completed: 2, onHold: 0, dropped: 0, planToWatch: 3, total: 6),
        );
    final stats = await ContentStatsSource.load(9, 'anime').timeout(const Duration(seconds: 1));
    expect(stats.source, StatsSource.myAnimeList);
  });
}
