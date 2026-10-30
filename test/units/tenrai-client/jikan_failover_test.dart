import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// [mode] is Jikan's behaviour; the launch probe says whether Jikan answers.
  Future<void> build(JikanMode mode, {bool probe = true}) async {
    now = DateTime(2026, 10, 28, 12);
    jikan = FakeJikan(mode);
    tenrai = FakeTenrai();
    source = JikanSource(
      tenrai: tenrai.client(),
      probe: () async => probe,
      now: () => now,
    );
    SharedPreferences.setMockInitialValues({});
    await source.start(await SharedPreferences.getInstance());
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

  test('Jikan dead mid-session: JikanApi answers from Tenrai, then never asks Jikan again', () async {
    await build(JikanMode.refused);
    final anime = await JikanApi().getAnimeFullById(1);
    expect(anime.malId, 1);
    expect(anime.title, isNot('from jikan'));
    expect(tenrai.requests.single.toString(), 'https://api.tenrai.org/v1/anime/1/full');
    expect(source.active, DataSource.tenrai);
    expect(source.jikanMuted, isTrue);
    expect(client.isUnreachable, isFalse, reason: 'Tenrai answered, nothing is unreachable');

    final cast = await JikanApi().getAnimeCharacters(1);
    expect(cast, isNotEmpty);
    expect(jikan.requests.length, 1, reason: 'Jikan is not asked again while it is muted');
  });

  test('Jikan muted at launch: every Tenrai endpoint answers, Jikan is never asked', () async {
    await build(JikanMode.up, probe: false);
    final stats = await JikanApi.getAnimeStatistics(1);
    expect(stats.scores, isNotEmpty);
    final reviews = await JikanApi().getAnimeReviews(1);
    expect(reviews.data, isNotEmpty);
    expect(tenrai.requests.map((u) => u.path), containsAll(['/v1/anime/1/statistics', '/v1/anime/1/reviews']));
    expect(jikan.requests, isEmpty);
  });

  test('a 5xx from Jikan is the caller\'s answer (no switch for one failing route)', () async {
    await build(JikanMode.error503);
    await expectLater(JikanApi().getAnimeReviews(1), throwsA(anything));
    expect(tenrai.requests, isEmpty);
    expect(source.active, DataSource.jikan);
  });

  test('query parameters reach Tenrai unchanged', () async {
    await build(JikanMode.up);
    final url = Uri.parse('https://api.jikan.moe/v4/top/anime?type=tv&filter=airing&limit=25');
    expect(source.toTenrai(url).toString(),
        'https://api.tenrai.org/v1/top/anime?type=tv&filter=airing&limit=25');
  });

  test('Tenrai serves the Jikan paths it has, never users, clubs or user updates', () async {
    await build(JikanMode.up);
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

  test('while Jikan is muted, an endpoint Tenrai lacks fails at once without pausing the rest', () async {
    await build(JikanMode.up, probe: false);
    await expectLater(JikanApi().getUserFullProfile('someone'), throwsA(isA<JikanUnavailable>()));
    expect(jikan.requests, isEmpty, reason: 'no request to a muted Jikan');
    expect(client.isUnreachable, isFalse);
  });

  test('Jikan muted and Tenrai down: JikanUnavailable, then the race goes to its fallback', () async {
    await build(JikanMode.up, probe: false);
    tenrai.down = true;
    await expectLater(JikanApi().getAnimeFullById(1), throwsA(isA<JikanUnavailable>()));
    expect(client.isUnreachable, isTrue);
    expect(jikan.requests, isEmpty);
    final result = await JikanFallbacks.race<String>(
      jikan: () async => 'jikan',
      fallback: () async => 'mal page',
    );
    expect(result.winner, RaceWinner.fallback);
  });

  test('race: with Jikan muted, Tenrai answers the Jikan leg before the MAL page', () async {
    await build(JikanMode.up, probe: false);
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

  test('the app client goes through the shared selector', () {
    expect(original.source, same(JikanSource.instance));
  });
}
