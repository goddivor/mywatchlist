import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';

Map<String, dynamic> _anime(int id, String title, int rank) => {
      'mal_id': id,
      'title': title,
      'images': {
        'jpg': {'large_image_url': 'https://cdn.example/$id.jpg'}
      },
      'score': 8.5,
      'members': 1000,
      'rank': rank,
      'popularity': 10,
      'synopsis': 's',
      'episodes': 12,
      'aired': {'from': '2020-01-01T00:00:00+00:00', 'to': null},
      'type': 'ONA',
      'status': 'Finished Airing',
      'genres': [
        {'name': 'Action'}
      ],
      'themes': [],
    };

void main() {
  late JikanClient saved;
  late List<Uri> requests;

  setUp(() {
    saved = JikanClient.instance;
    requests = [];
    JikanClient.instance = JikanClient(
      client: MockClient((req) async {
        requests.add(req.url);
        final page = int.parse(req.url.queryParameters['page'] ?? '1');
        return http.Response(
            jsonEncode({
              'data': [_anime(page * 10, 'ONA $page', page)],
              'pagination': {'current_page': page, 'has_next_page': page < 2},
            }),
            200);
      }),
      minInterval: Duration.zero,
      source: JikanSource(),
    );
  });

  tearDown(() => JikanClient.instance = saved);

  test('the ONA ranking goes to Jikan with type=ona and maps to a SearchResult', () async {
    final result = await MalApi.getContentRankingResult(RankingType.ONA, limit: 25);
    expect(requests, hasLength(1));
    expect(requests.single.host, 'api.jikan.moe');
    expect(requests.single.path, '/v4/top/anime');
    expect(requests.single.queryParameters['type'], 'ona');
    expect(requests.single.toString(), isNot(contains('ranking_type')));
    expect(result.data.single.id, 10);
    expect(result.data.single.title, 'ONA 1');
    expect(result.hasNextPage, isTrue);
  });

  test('the next page loads from Jikan page 2 and ends the paging', () async {
    final first = await MalApi.getContentRankingResult(RankingType.ONA, limit: 25);
    final second = await MalApi.getContentListPage(first.paging!);
    expect(requests.last.queryParameters['page'], '2');
    expect(requests.last.queryParameters['type'], 'ona');
    expect(second.data.single.id, 20);
    expect(second.hasNextPage, isFalse);
  });

  test('an offset maps to a page', () async {
    await MalApi.getContentRankingResult(RankingType.ONA, limit: 25, offset: 25);
    expect(requests.single.queryParameters['page'], '2');
  });
}
