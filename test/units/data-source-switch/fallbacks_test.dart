import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/MAL/web/friends_updates_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/widgets/MAL/review/reviews_feed.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'source_fakes.dart';

class _NoCookies implements WebViewCookies {
  @override
  Future<String?> read(String url) async => null;
  @override
  Future<void> clear(String url) async {}
}

String _fixture(String name) => File('test/units/data-source-switch/fixtures/$name').readAsStringSync();

void main() {
  late JikanClient original;

  setUp(() {
    original = JikanClient.instance;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    JikanClient.instance = original;
    JikanFallbacks.reset();
  });

  group('#361: an empty fallback never wins against a loading Jikan leg', () {
    test('an empty list waits; the slower Jikan answer wins', () async {
      JikanFallbacks.headStart = Duration.zero;
      final result = await JikanFallbacks.race<List<int>>(
        jikan: () => Future.delayed(const Duration(milliseconds: 40), () => [1, 2, 3]),
        fallback: () async => <int>[],
      );
      expect(result.winner, RaceWinner.jikan);
      expect(result.value, [1, 2, 3]);
    });

    test('the empty answer is used when the Jikan leg fails', () async {
      JikanFallbacks.headStart = Duration.zero;
      final result = await JikanFallbacks.race<List<int>>(
        jikan: () => Future.delayed(const Duration(milliseconds: 20), () => throw StateError('down')),
        fallback: () async => <int>[],
      );
      expect(result.winner, RaceWinner.fallback);
      expect(result.value, isEmpty);
    });

    test('the empty answer is used when the budget ends', () async {
      JikanFallbacks.headStart = Duration.zero;
      JikanFallbacks.budget = const Duration(milliseconds: 50);
      final result = await JikanFallbacks.race<List<int>>(
        jikan: () => Completer<List<int>>().future,
        fallback: () async => <int>[],
      );
      expect(result.value, isEmpty);
    });

    test('a non-empty fallback still wins at once', () async {
      JikanFallbacks.headStart = Duration.zero;
      final result = await JikanFallbacks.race<List<int>>(
        jikan: () => Completer<List<int>>().future,
        fallback: () async => [7],
      );
      expect(result.winner, RaceWinner.fallback);
    });

    test('One Piece reviews: mwl-api unreachable, Jikan muted, Tenrai answers -> reviews shown',
        () async {
      final rig = SourceRig(probe: false);
      rig.tenraiServer.body = (_) =>
          '{"data":[{"mal_id":9,"review":"Peak fiction","score":10,"user":{"username":"luffy"}}],'
          '"pagination":{"has_next_page":false}}';
      await rig.source.start(await SharedPreferences.getInstance());
      JikanClient.instance = rig.client;
      JikanFallbacks.headStart = Duration.zero;
      JikanFallbacks.reviews = (id, category, page) async =>
          throw const MwlApiNoAnswer('reviews', 'no answer');
      final feed = ReviewsFeed(id: 21);
      await feed.start();
      expect(feed.failed, isFalse);
      expect(feed.reviews.single.review, 'Peak fiction');
      expect(rig.tenraiServer.requests.single.path, '/v1/anime/21/reviews');
      expect(rig.jikanServer.requests, isEmpty);
      feed.dispose();
    });

    test('an empty mwl-api page no longer hides the Jikan reviews', () async {
      JikanFallbacks.headStart = Duration.zero;
      JikanFallbacks.reviews = (id, category, page) async => <AnimeReview>[];
      JikanClient.instance = JikanClient(
        minInterval: Duration.zero,
        client: MockClient((r) => Future.delayed(
            const Duration(milliseconds: 40),
            () => http.Response(
                '{"data":[{"mal_id":1,"review":"From Jikan","score":8,"user":{"username":"a"}}],'
                '"pagination":{"has_next_page":false}}',
                200))),
      );
      final feed = ReviewsFeed(id: 21);
      await feed.start();
      expect(feed.reviews.single.review, 'From Jikan');
      feed.dispose();
    });

  });

  group('Recently Updated By, all members, from MAL page', () {
    test('parser: header row skipped, rows read, next page seen', () {
      final page = parseAllUpdates(_fixture('anime_all.html'), now: DateTime.utc(2026, 10, 30, 12));
      expect(page.updates.map((u) => u.username), ['GBlaken', 'yugenop', 'jek50']);
      expect(page.updates.first.score, 9);
      expect(page.updates.first.status, 'Watching');
      expect(page.updates.first.episodesSeen, 231);
      expect(page.updates[2].score, isNull);
      expect(page.hasNextPage, isTrue);
      final jikanShape = userUpdatesFromHtml(page);
      expect(jikanShape.data.first.user?.username, 'GBlaken');
      expect(jikanShape.pagination?.hasNextPage, isTrue);
    });

    test('fetchAll reads ?m=all without a session; page 2 uses show=75', () async {
      final sent = <Uri>[];
      final headers = <Map<String, String>>[];
      final api = FriendsUpdatesApi(
        client: MalWebClient(
          session: MalWebSession(cookies: _NoCookies(), platformSupported: true),
          minGap: Duration.zero,
          clientFactory: () => MockClient((r) async {
            sent.add(r.url);
            headers.add(r.headers);
            return http.Response(_fixture('anime_all.html'), 200,
                headers: {'content-type': 'text/html; charset=utf-8'});
          }),
        ),
      );
      final first = await api.fetchAll('anime', 21);
      expect(first.updates, hasLength(3));
      await api.fetchAll('manga', 13, page: 2);
      expect(sent[0].toString(), 'https://myanimelist.net/anime/21/_/stats?m=all');
      expect(sent[1].toString(), 'https://myanimelist.net/manga/13/_/stats?m=all&show=75');
      expect(headers.first.containsKey('Cookie'), isFalse);
    });

    test('MAL refusing the page fails (the section shows its error)', () async {
      final api = FriendsUpdatesApi(
        client: MalWebClient(
          session: MalWebSession(cookies: _NoCookies(), platformSupported: true),
          minGap: Duration.zero,
          clientFactory: () => MockClient((r) async => http.Response('', 403)),
        ),
      );
      await expectLater(api.fetchAll('anime', 21), throwsA(isA<MalWebActionFailed>()));
    });
  });

  test('manga statistics with Jikan muted: no profile numbers -> no Jikan request, null', () async {
    final rig = SourceRig(probe: false);
    await rig.source.start(await SharedPreferences.getInstance());
    JikanClient.instance = rig.client;
    final adapter = MalUserListAdapter(owner: () => 'someone', mangaStats: (_) async => null);
    expect(await adapter.statusCounts('manga'), isNull);
    expect(rig.jikanServer.requests, isEmpty, reason: 'users/{name}/statistics is not on Tenrai');
    expect(rig.tenraiServer.requests, isEmpty);
  });

  test('manga statistics with Jikan muted come from the MAL profile page', () async {
    final rig = SourceRig(probe: false);
    await rig.source.start(await SharedPreferences.getInstance());
    JikanClient.instance = rig.client;
    final adapter = MalUserListAdapter(
      owner: () => 'someone',
      mangaStats: (_) async => const ListStats(totalEntries: 37, current: 2, completed: 30, onHold: 1, planned: 4),
    );
    final counts = await adapter.statusCounts('manga');
    expect(counts![ListEntryStatus.completed], 30);
    expect(rig.jikanServer.requests, isEmpty);
  });
}
