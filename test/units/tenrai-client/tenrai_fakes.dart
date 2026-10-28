import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';

/// Real Tenrai answers (trimmed to two rows per list), saved on 2026-10-28.
String tenraiFixture(String name) =>
    File('test/units/tenrai-client/fixtures/$name.json').readAsStringSync();

/// Tenrai path (after `/v1`) -> fixture name.
const Map<String, String> tenraiFixtureRoutes = {
  '/anime/1/full': 'anime_full',
  '/anime/1/characters': 'anime_characters',
  '/anime/1/staff': 'anime_staff',
  '/anime/1/episodes': 'anime_episodes',
  '/anime/1/news': 'anime_news',
  '/anime/1/forum': 'anime_forum',
  '/anime/1/videos': 'anime_videos',
  '/anime/1/pictures': 'anime_pictures',
  '/anime/1/statistics': 'anime_statistics',
  '/anime/1/reviews': 'anime_reviews',
  '/anime': 'anime_search',
  '/manga/2/full': 'manga_full',
  '/manga': 'manga_search',
  '/characters/417/full': 'character_full',
  '/people/118/full': 'person_full',
  '/producers/14/full': 'producer_full',
  '/producers': 'producers',
  '/genres/anime': 'genres_anime',
  '/seasons/now': 'season_now',
  '/top/anime': 'top_anime',
  '/top/characters': 'top_characters',
  '/top/people': 'top_people',
  '/schedules': 'schedules',
  '/reviews/anime': 'reviews_anime',
  '/random/anime': 'random_anime',
};

/// A fake Tenrai serving the fixtures; records every request.
class FakeTenrai {
  final List<Uri> requests = [];
  bool down = false;

  late final MockClient http_ = MockClient((request) async {
    requests.add(request.url);
    if (down) throw http.ClientException('Tenrai down', request.url);
    final path = request.url.path.replaceFirst('/v1', '');
    final name = tenraiFixtureRoutes[path];
    if (name == null) return http.Response('{"status":404}', 404);
    return http.Response.bytes(
      File('test/units/tenrai-client/fixtures/$name.json').readAsBytesSync(),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  TenraiClient client() => TenraiClient(client: http_, minInterval: Duration.zero);
}
