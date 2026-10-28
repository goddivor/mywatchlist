import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';

import 'tenrai_fakes.dart';

/// A Jikan that fails the way the owner's network does.
enum JikanMode { up, refused, silent, error503 }

class FakeJikan {
  JikanMode mode;
  final List<Uri> requests = [];
  FakeJikan(this.mode);

  late final MockClient http_ = MockClient((request) {
    requests.add(request.url);
    switch (mode) {
      case JikanMode.up:
        return Future.value(http.Response('{"data":{"mal_id":1,"title":"from jikan"}}', 200));
      case JikanMode.refused:
        throw http.ClientException('Failed host lookup: api.jikan.moe', request.url);
      case JikanMode.silent:
        return Completer<http.Response>().future;
      case JikanMode.error503:
        return Future.value(http.Response('{"status":503}', 503));
    }
  });
}

void main() {
  late FakeJikan jikan;
  late FakeTenrai tenrai;
  late JikanSource source;
  late JikanClient client;
  late JikanClient original;
  var now = DateTime(2026, 10, 28, 12);

  void build(JikanMode mode, {Duration hedgeAfter = const Duration(seconds: 2)}) {
    now = DateTime(2026, 10, 28, 12);
    jikan = FakeJikan(mode);
    tenrai = FakeTenrai();
    source = JikanSource(
      tenrai: tenrai.client(),
      hedgeAfter: hedgeAfter,
      probeTimeout: const Duration(milliseconds: 100),
      now: () => now,
    );
    client = JikanClient(
      client: jikan.http_,
      minInterval: Duration.zero,
      requestTimeout: const Duration(milliseconds: 200),
      source: source,
      now: () => now,
    );
    JikanClient.instance = client;
  }

  setUp(() => original = JikanClient.instance);
  tearDown(() {
    JikanClient.instance = original;
    JikanFallbacks.reset();
  });

  test('Jikan dead (DNS failure): JikanApi answers from Tenrai, then skips Jikan', () async {
    build(JikanMode.refused);
    final anime = await JikanApi().getAnimeFullById(1);
    expect(anime.malId, 1);
    expect(anime.title, isNot('from jikan'));
    expect(tenrai.requests.single.toString(), 'https://api.tenrai.org/v1/anime/1/full');
    expect(source.jikanDown, isTrue);
    expect(client.isUnreachable, isFalse, reason: 'Tenrai answered, nothing is unreachable');

    final cast = await JikanApi().getAnimeCharacters(1);
    expect(cast, isNotEmpty);
    expect(jikan.requests.length, 1, reason: 'Jikan is not asked again while it is down');
  });

  test('a silent Jikan: Tenrai is asked after the hedge delay and wins', () async {
    build(JikanMode.silent, hedgeAfter: const Duration(milliseconds: 30));
    final watch = Stopwatch()..start();
    final stats = await JikanApi.getAnimeStatistics(1);
    expect(stats.scores, isNotEmpty);
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 190)),
        reason: 'answered before the Jikan timeout');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(source.jikanDown, isTrue, reason: 'the Jikan timeout still marks it down');
  });

  test('a 5xx from Jikan goes to Tenrai', () async {
    build(JikanMode.error503);
    final reviews = await JikanApi().getAnimeReviews(1);
    expect(reviews.data, isNotEmpty);
    expect(tenrai.requests.map((u) => u.path), contains('/v1/anime/1/reviews'));
  });

  test('query parameters reach Tenrai unchanged', () {
    build(JikanMode.up);
    final url = Uri.parse('https://api.jikan.moe/v4/top/anime?type=tv&filter=airing&limit=25');
    expect(source.toTenrai(url).toString(),
        'https://api.tenrai.org/v1/top/anime?type=tv&filter=airing&limit=25');
  });

  test('Tenrai serves the Jikan paths it has, never users, clubs or user updates', () {
    build(JikanMode.up);
    bool serves(String path) => source.tenraiServes(Uri.parse('https://api.jikan.moe/v4$path'));
    expect(serves('/anime/1/full'), isTrue);
    expect(serves('/seasons/2024/fall?filter=tv'), isTrue);
    expect(serves('/characters/417/pictures'), isTrue);
    expect(serves('/recommendations/anime'), isTrue);
    expect(serves('/anime/1/forum?filter=episode'), isTrue);
    expect(serves('/anime/1/forum?filter=all'), isFalse, reason: 'Tenrai only has episode threads');
    expect(serves('/users/someone/full'), isFalse);
    expect(serves('/users/someone/statistics'), isFalse);
    expect(serves('/clubs/1'), isFalse);
    expect(serves('/anime/1/userupdates'), isFalse);
    expect(serves('/random/users'), isFalse);
    expect(serves('/watch/episodes'), isFalse);
    expect(serves('/anime/ids'), isFalse, reason: 'server key only');
    expect(source.isJikan(Uri.parse('https://api.tenrai.org/v1/anime/1')), isFalse);
  });

  test('while Jikan is down, an endpoint Tenrai lacks fails at once without pausing the rest', () async {
    build(JikanMode.refused);
    await JikanApi().getAnimeFullById(1);
    final asked = jikan.requests.length;
    await expectLater(JikanApi().getUserFullProfile('someone'), throwsA(isA<JikanUnavailable>()));
    expect(jikan.requests.length, asked, reason: 'no wait for a dead Jikan');
    expect(client.isUnreachable, isFalse);
  });

  test('Jikan and Tenrai both down: JikanUnavailable, then the race goes to its fallback', () async {
    build(JikanMode.refused);
    tenrai.down = true;
    await expectLater(JikanApi().getAnimeFullById(1), throwsA(isA<JikanUnavailable>()));
    expect(client.isUnreachable, isTrue);
    final result = await JikanFallbacks.race<String>(
      jikan: () async => 'jikan',
      fallback: () async => 'mal page',
    );
    expect(result.winner, RaceWinner.fallback);
  });

  test('race: with Jikan dead, Tenrai answers the Jikan leg before the MAL page', () async {
    build(JikanMode.refused);
    JikanFallbacks.headStart = const Duration(seconds: 2);
    var malAsked = false;
    final result = await JikanFallbacks.race<int>(
      jikan: () async => (await JikanApi().getAnimeReviews(1)).data.length,
      fallback: () async {
        malAsked = true;
        return -1;
      },
    );
    expect(result.winner, RaceWinner.jikan);
    expect(result.value, greaterThan(0));
    expect(malAsked, isFalse);
  });

  test('after the re-probe delay Jikan is tried again and takes over when back', () async {
    build(JikanMode.refused);
    await JikanApi().getAnimeFullById(1);
    expect(source.jikanDown, isTrue);
    jikan.mode = JikanMode.up;
    now = now.add(const Duration(minutes: 6));
    client.clearCache();
    final response = await client.get(Uri.parse('https://api.jikan.moe/v4/anime/1/full'), useCache: false);
    expect(response.statusCode, 200);
    // While re-probing Tenrai is asked at once too; whichever answers first wins.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(source.jikanSuspect, isFalse, reason: 'Jikan answered: marked up');
    expect(source.jikanDown, isFalse);
  });

  test('Retry lets the next request probe Jikan again', () async {
    build(JikanMode.refused);
    await JikanApi().getAnimeFullById(1);
    expect(source.jikanDown, isTrue);
    client.resetReachability();
    expect(source.jikanDown, isFalse);
    expect(source.jikanSuspect, isTrue);
  });

  test('a JikanClient without a source keeps the Jikan-only behaviour', () async {
    final plain = JikanClient(
      client: MockClient((_) async => throw http.ClientException('down')),
      minInterval: Duration.zero,
    );
    await expectLater(plain.get(Uri.parse('https://api.jikan.moe/v4/anime/1/full')),
        throwsA(isA<JikanUnavailable>()));
    expect(plain.isUnreachable, isTrue);
    expect(plain.source, isNull);
  });

  test('the app client fails over through the shared selector', () {
    expect(original.source, same(JikanSource.instance));
    expect(JikanSource.instance.reprobeAfter, const Duration(minutes: 5));
    expect(JikanSource.instance.hedgeAfter < JikanFallbacks.headStart, isTrue,
        reason: 'Tenrai starts before the MAL page fallback');
  });
}
