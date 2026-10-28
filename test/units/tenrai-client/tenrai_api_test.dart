import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_api.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_params.dart';

import 'tenrai_fakes.dart';

void main() {
  late FakeTenrai fake;
  late TenraiApi api;

  setUp(() {
    fake = FakeTenrai();
    api = TenraiApi(client: fake.client());
  });

  test('one method per OpenAPI path: 103 paths, no duplicate', () {
    expect(TenraiApi.paths.length, 103);
    expect(TenraiApi.paths.toSet().length, 103);
    final spec = File('lib/services/api/Tenrai/tenrai_api.dart').readAsStringSync();
    for (final path in TenraiApi.paths) {
      expect(spec.contains('`GET $path`'), isTrue, reason: 'no method documented for $path');
    }
    expect(TenraiApi.keyOnlyPaths, everyElement(endsWith('/ids')));
  });

  group('real Tenrai answers parse with the Jikan models', () {
    test('anime details, cast, staff, episodes', () async {
      final anime = await api.getAnimeFull(1);
      expect(anime.malId, 1);
      expect(anime.title, isNotEmpty);
      expect(await api.getAnimeCharacters(1), isNotEmpty);
      expect(await api.getAnimeStaff(1), isNotEmpty);
      expect((await api.getAnimeEpisodes(1)).data, isNotEmpty);
    });

    test('news, forum, videos, pictures, statistics, reviews', () async {
      expect((await api.getAnimeNews(1)).data, isNotEmpty);
      expect((await api.getAnimeForum(1, filter: TenraiForumFilter.episode)).data, isNotEmpty);
      await api.getAnimeVideos(1);
      expect((await api.getAnimePictures(1)).data, isNotEmpty);
      final stats = await api.getAnimeStatistics(1);
      expect(stats.scores, isNotEmpty);
      expect((await api.getAnimeReviews(1)).data, isNotEmpty);
      expect((await api.getRecentAnimeReviews()).data, isNotEmpty);
    });

    test('search, seasons, top, schedules, random', () async {
      final search = await api.searchAnime(q: 'bebop', limit: 2);
      expect(search.data, isNotEmpty);
      expect(search.pagination, isNotNull);
      expect((await api.searchManga(q: 'berserk')).data, isNotEmpty);
      expect((await api.getSeasonNow()).data, isNotEmpty);
      expect((await api.getTopAnime()).data, isNotEmpty);
      expect((await api.getSchedules()).data, isNotEmpty);
      expect((await api.getRandomAnime()).malId, greaterThan(0));
      expect((await api.getMangaFull(2)).malId, 2);
    });

    test('characters, people, producers, genres', () async {
      expect((await api.getCharacterFull(417)).name, isNotEmpty);
      expect((await api.getPersonFull(118)).name, isNotEmpty);
      expect((await api.getTopCharacters()).data, isNotEmpty);
      expect((await api.getTopPeople()).data, isNotEmpty);
      expect((await api.getProducerFull(14)).malId, 14);
      expect((await api.searchProducers()).data, isNotEmpty);
      expect((await api.getAnimeGenres()).data, isNotEmpty);
    });
  });

  test('query parameters: lists comma separated, enums by value, nulls left out', () async {
    await api.searchAnime(
      q: 'x',
      type: [AnimeSearchQueryType.tv, AnimeSearchQueryType.tvSpecial],
      rating: [AnimeSearchQueryRating.pg13],
      status: AnimeSearchQueryStatus.airing,
      unapproved: TenraiTriState.only,
      sfwStrict: true,
      minScore: 7.5,
      season: TenraiSeason.fall,
    );
    final url = fake.requests.single;
    expect(url.host, 'api.tenrai.org');
    expect(url.path, '/v1/anime');
    expect(url.queryParameters, {
      'q': 'x',
      'type': 'tv,tv_special',
      'rating': 'pg13',
      'status': 'airing',
      'unapproved': 'only',
      'sfw-strict': 'true',
      'min_score': '7.5',
      'season': 'fall',
    });
  });

  test('path parameters: season and episode', () async {
    try {
      await api.getSeason(2024, TenraiSeason.fall, filter: [AnimeSearchQueryType.tv]);
    } on TenraiHttpError catch (_) {}
    try {
      await api.getAnimeEpisode(1, 5);
    } on TenraiHttpError catch (_) {}
    expect(fake.requests.map((u) => u.path), ['/v1/seasons/2024/fall', '/v1/anime/1/episodes/5']);
    expect(fake.requests.first.queryParameters['filter'], 'tv');
  });

  test('a non-200 answer throws TenraiHttpError with the status', () async {
    final api401 = TenraiApi(
      client: TenraiClient(
        client: MockClient((_) async => http.Response(jsonEncode({'status': 401}), 401)),
        minInterval: Duration.zero,
      ),
    );
    await expectLater(
      api401.getAnimeIds(),
      throwsA(isA<TenraiHttpError>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });
}
