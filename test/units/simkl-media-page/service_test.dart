import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/SimKl/scrapper/simkl_web_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';

import '../../helpers/no_network.dart';
import 'fakes.dart';

void main() {
  setUpAll(forbidNetwork);

  const frierenUrl = 'https://simkl.com/anime/1990194/sousou-no-frieren';

  FakeSimklSite site() => FakeSimklSite(
        api: {
          '/anime/831411': () => jsonDecode(fixture('simkl_anime_831411.json')),
          '/anime/episodes/831411': () => jsonDecode(fixture('simkl_episodes_831411.json')),
          '/anime/1': () => <Object>[],
        },
        pages: {
          frierenUrl: () => fixture('simkl_title_frieren.html'),
          '$frierenUrl/reviews/': () => fixture('simkl_reviews_frieren.html'),
          '$frierenUrl/comments/': () => fixture('simkl_comments_frieren.html'),
          '$frierenUrl/memos/': () => fixture('simkl_memos_frieren.html'),
        },
      );

  test('record and episodes come from the API with the app identification, then from memory', () async {
    final s = site();
    final service = s.service();
    final title = await service.title(831411);
    expect(title.title, 'Kimetsu no Yaiba');
    expect((await service.episodes(831411)), hasLength(2));
    await service.title(831411);
    await service.episodes(831411);
    expect(s.apiCalls.map((u) => u.path), ['/anime/831411', '/anime/episodes/831411']);
    expect(s.apiCalls.first.queryParameters['client_id'], 'cid');
    expect(s.apiCalls.first.queryParameters['app-name'], 'MyWatchList');
  });

  test('concurrent asks share one request; force asks again', () async {
    final s = site();
    final service = s.service();
    await Future.wait([service.title(831411), service.title(831411)]);
    expect(s.apiCalls, hasLength(1));
    await service.title(831411, force: true);
    expect(s.apiCalls, hasLength(2));
  });

  test('kept answers expire after the ttl', () async {
    final s = site();
    final service = s.service();
    await service.title(831411);
    s.clock = s.clock.add(const Duration(minutes: 31));
    expect(service.peek(SimklDetailService.titleKey(831411)), isNull);
    await service.title(831411);
    expect(s.apiCalls, hasLength(2));
  });

  test('an unknown id is SimklTitleNotFound', () async {
    final service = site().service();
    expect(() => service.title(1), throwsA(isA<SimklTitleNotFound>()));
  });

  test('pages: desktop user agent, one request per second, parsed and kept', () async {
    final s = site();
    final service = s.service();
    final page = await service.page(1990194, 'sousou-no-frieren');
    final reviews = await service.reviews(1990194, 'sousou-no-frieren');
    final comments = await service.comments(1990194, 'sousou-no-frieren');
    final memos = await service.memos(1990194, 'sousou-no-frieren');
    await service.page(1990194, 'sousou-no-frieren');
    expect(page.watchers!.total, 34432);
    expect(reviews!.items, hasLength(6));
    expect(comments, hasLength(3));
    expect(memos, isNotEmpty);
    expect(s.pageCalls.map((u) => u.toString()), [
      frierenUrl,
      '$frierenUrl/reviews/',
      '$frierenUrl/comments/',
      '$frierenUrl/memos/',
    ]);
    // Four back-to-back requests: the 2nd, 3rd and 4th each waited for their one-second slot.
    expect(s.waits, everyElement(lessThanOrEqualTo(const Duration(seconds: 1))));
    expect(s.waits.fold(Duration.zero, (a, b) => a + b), const Duration(seconds: 3));
  });

  test('a blocked page throws SimklPageUnavailable and is not kept', () async {
    final s = site();
    final service = s.service();
    expect(() => service.page(5, 'x'), throwsA(isA<SimklPageUnavailable>()));
    await Future<void>.delayed(Duration.zero);
    expect(service.peek(SimklDetailService.pageKey(5)), isNull);
  });

  test('the web client sends a desktop browser User-Agent', () async {
    late Map<String, String> sent;
    final web = SimklWebClient(
      get: (uri, h) async {
        sent = h;
        return http.Response('<html></html>', 200);
      },
      sleep: (_) async {},
    );
    await web.page('https://simkl.com/anime/1');
    expect(sent['User-Agent'], contains('Mozilla/5.0 (X11; Linux x86_64)'));
  });
}
