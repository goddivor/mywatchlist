import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';

/// Tenrai answers an empty review list for every title: that answer must not
/// hide the reviews read on MyAnimeList.
void main() {
  late JikanClient original;

  setUp(() {
    original = JikanClient.instance;
    JikanClient.instance = JikanClient(
      client: MockClient((_) async => http.Response('{}', 200)),
      minInterval: Duration.zero,
    );
    JikanFallbacks.headStart = const Duration(seconds: 5);
    JikanFallbacks.budget = const Duration(seconds: 2);
  });

  tearDown(() {
    JikanClient.instance = original;
    JikanFallbacks.reset();
  });

  test('an empty Jikan-leg answer starts the fallback at once, which wins', () async {
    final watch = Stopwatch()..start();
    final result = await JikanFallbacks.race<List<String>>(
      jikan: () async => const [],
      fallback: () async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return const ['review'];
      },
    );
    expect(result.value, ['review']);
    expect(result.winner, RaceWinner.fallback);
    expect(watch.elapsed < const Duration(seconds: 1), isTrue, reason: 'no head-start wait');
  });

  test('both empty: the empty Jikan answer is the result', () async {
    final result = await JikanFallbacks.race<List<String>>(
      jikan: () async => const [],
      fallback: () async => const [],
    );
    expect(result.value, isEmpty);
    expect(result.winner, RaceWinner.jikan);
  });

  test('an empty Jikan answer and a failing fallback: empty, not an error', () async {
    final result = await JikanFallbacks.race<List<String>>(
      jikan: () async => const [],
      fallback: () async => throw StateError('MAL down'),
    );
    expect(result.value, isEmpty);
  });

  test('a non-empty Jikan answer still wins at once', () async {
    var asked = false;
    final result = await JikanFallbacks.race<List<String>>(
      jikan: () async => const ['tenrai'],
      fallback: () async {
        asked = true;
        return const ['mal'];
      },
    );
    expect(result.value, ['tenrai']);
    expect(asked, isFalse);
  });
}
