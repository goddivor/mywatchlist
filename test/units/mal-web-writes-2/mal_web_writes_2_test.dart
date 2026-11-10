import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/MAL/web/forum_poll_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/recommendation_write_api.dart';
import 'package:mywatchlist/services/api/MAL/web/review_write_api.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCookies implements WebViewCookies {
  String? jar;
  _FakeCookies([this.jar]);
  @override
  Future<String?> read(String url) async => jar;
  @override
  Future<void> clear(String url) async => jar = null;
}

Future<MalWebSession> _connected() async {
  final session = MalWebSession(cookies: _FakeCookies('MALSESSIONID=abc; is_logged_in=1'), platformSupported: true);
  expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
  return session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ForumPollApi.parseInline = true;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  final topicPage = File('test/units/mal-web-writes-2/fixtures/topic_poll_reconstructed.html').readAsStringSync();

  test('vote buttons are read from the topic page, bad ids skipped, text normalised', () {
    final options = parsePollVoteOptions(topicPage);
    expect(options.map((o) => o.id), [9001, 9002]);
    expect(options[1].text, 'Kasumigaoka, Utaha');
    expect(parsePollVoteOptions('<html><body>results only</body></html>'), isEmpty);
  });

  test('voteOptions reads the topic page; vote posts option_id with the csrf token', () async {
    final sent = <http.Request>[];
    final client = MalWebClient(
      session: await _connected(),
      minGap: Duration.zero,
      clientFactory: () => MockClient((r) async {
        sent.add(r);
        if (r.method == 'POST') return http.Response('{"ok":true}', 200);
        return http.Response(topicPage, 200);
      }),
    );
    final api = ForumPollApi(client: client);
    final options = await api.voteOptions(1353158);
    expect(options, hasLength(2));
    expect(sent.single.url.path, '/forum/');
    expect(sent.single.url.queryParameters['topicid'], '1353158');

    await api.vote(1353158, 9002);
    final post = sent.last;
    expect(post.method, 'POST');
    expect(post.url.path, '/forum/1353158/vote/option');
    expect(Uri.splitQueryString(post.body), {'option_id': '9002', 'csrf_token': 'tok123'});
    expect(post.headers['Cookie'], contains('MALSESSIONID=abc'));
  });

  test('a refused vote carries MAL text; a login redirect expires the session', () async {
    final session = await _connected();
    var mode = 'error';
    final client = MalWebClient(
      session: session,
      minGap: Duration.zero,
      clientFactory: () => MockClient((r) async {
        if (r.method == 'GET') return http.Response(topicPage, 200);
        if (mode == 'error') {
          return http.Response('{"error":{"message":"Poll closed","code":403}}', 200);
        }
        return http.Response('', 303, headers: {'location': 'https://myanimelist.net/login.php?from=x'});
      }),
    );
    final api = ForumPollApi(client: client);
    await expectLater(
      api.vote(1, 2),
      throwsA(isA<MalWebActionFailed>().having((e) => e.message, 'message', 'Poll closed')),
    );
    mode = 'login';
    await expectLater(api.vote(1, 2), throwsA(isA<MalWebSessionExpired>()));
  });

  test('without a website session nothing is sent', () async {
    var requests = 0;
    final client = MalWebClient(
      session: MalWebSession(cookies: _FakeCookies(), platformSupported: true),
      minGap: Duration.zero,
      clientFactory: () => MockClient((r) async {
        requests++;
        return http.Response('', 200);
      }),
    );
    final api = ForumPollApi(client: client);
    await expectLater(api.voteOptions(1), throwsA(isA<MalWebNoSession>()));
    await expectLater(api.vote(1, 2), throwsA(isA<MalWebNoSession>()));
    expect(requests, 0);
  });

  test('checkVoteAnswer accepts plain answers and refuses error statuses', () {
    checkVoteAnswer(http.Response('[]', 200));
    checkVoteAnswer(http.Response('not json', 200));
    expect(() => checkVoteAnswer(http.Response('', 500)), throwsA(isA<MalWebActionFailed>()));
    expect(
      () => checkVoteAnswer(http.Response(jsonEncode({'error': 'Nope'}), 200)),
      throwsA(isA<MalWebActionFailed>().having((e) => e.message, 'message', 'Nope')),
    );
  });

  test('review and recommendation pages are the ones MAL links', () {
    expect(ReviewWriteApi.writeUrl(category: 'anime', id: 1), 'https://myanimelist.net/myreviews.php?seriesid=1&go=write');
    expect(ReviewWriteApi.writeUrl(category: 'manga', id: 2), 'https://myanimelist.net/myreviews.php?mid=2&go=write');
    expect(RecommendationWriteApi.pageUrl(category: 'manga', id: 2), 'https://myanimelist.net/manga/2/_/userrecs');
  });
}
