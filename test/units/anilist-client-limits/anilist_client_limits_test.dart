import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';

import '../../helpers/no_network.dart';

/// A clock that only moves when the limiter sleeps.
class FakeClock {
  DateTime now = DateTime.utc(2026, 10, 29, 12);
  final List<Duration> sleeps = [];

  DateTime call() => now;

  Future<void> sleep(Duration d) async {
    sleeps.add(d);
    now = now.add(d);
  }

  Duration get slept => sleeps.fold(Duration.zero, (a, b) => a + b);
}

/// One recorded call of a fake sender.
class Call {
  final Map<String, dynamic> body;
  final bool auth;
  final bool write;
  Call(String body, this.auth, this.write) : body = jsonDecode(body) as Map<String, dynamic>;
  String get query => body['query'] as String;
  Map<String, dynamic> get variables => body['variables'] as Map<String, dynamic>;
}

http.Response ok(Object data, {Map<String, String> headers = const {}}) =>
    http.Response(jsonEncode({'data': data}), 200, headers: headers);

/// A client whose reads and writes answer from [answers] (in order) and are logged in [log].
AnilistGraphql fakeClient(
  List<http.Response> answers,
  List<Call> log, {
  AnilistRateLimiter? limiter,
  Duration maxReadRetryWait = const Duration(minutes: 1),
}) {
  var i = 0;
  Future<http.Response?> answer(String body, bool auth, bool write) async {
    log.add(Call(body, auth, write));
    // The last answer repeats once the list is used up.
    return answers[i < answers.length ? i++ : answers.length - 1];
  }

  return AnilistGraphql(
    sender: (body, {required auth}) => answer(body, auth, false),
    mutationSender: (body, {required auth}) => answer(body, auth, true),
    limiter: limiter,
    maxReadRetryWait: maxReadRetryWait,
  );
}

void main() {
  setUpAll(forbidNetwork);

  group('AnilistRateLimiter', () {
    test('30 requests go out at once, the 31st waits one refill (2 s)', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      for (var i = 0; i < 30; i++) {
        await limiter.acquire();
      }
      expect(clock.slept, Duration.zero);
      await limiter.acquire();
      expect(clock.slept, const Duration(seconds: 2));
    });

    test('a minute later the bucket is full again, never fuller', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      for (var i = 0; i < 30; i++) {
        await limiter.acquire();
      }
      clock.now = clock.now.add(const Duration(minutes: 5));
      expect(limiter.available, 30);
    });

    test('concurrent callers are served in order, each one interval apart', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(limit: 2, clock: clock.call, sleep: clock.sleep);
      final done = <int>[];
      await Future.wait([
        for (var i = 0; i < 5; i++) limiter.acquire().then((_) => done.add(i)),
      ]);
      expect(done, [0, 1, 2, 3, 4]);
      // 2 immediate, then 3 refills of 30 s.
      expect(clock.slept, const Duration(seconds: 90));
    });

    test('follows X-RateLimit-Remaining and X-RateLimit-Limit', () {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      limiter.observe(200, {'x-ratelimit-limit': '30', 'x-ratelimit-remaining': '3'});
      expect(limiter.available, 3);
      // A higher remaining never adds tokens the bucket has not earned.
      limiter.observe(200, {'x-ratelimit-remaining': '29'});
      expect(limiter.available, 3);
      limiter.observe(200, {'x-ratelimit-limit': '90'});
      expect(limiter.limit, 90);
    });

    test('a 429 pauses every request for Retry-After', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      final pause = limiter.observe(429, {'retry-after': '45', 'x-ratelimit-remaining': '0'});
      expect(pause, const Duration(seconds: 45));
      expect(limiter.available, 0);
      expect(limiter.pausedUntil, clock.now.add(const Duration(seconds: 45)));
      await limiter.acquire();
      expect(clock.slept, greaterThanOrEqualTo(const Duration(seconds: 45)));
      expect(limiter.pausedUntil, isNull);
    });

    test('a 429 without Retry-After uses X-RateLimit-Reset, else a minute', () {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      final reset = clock.now.add(const Duration(seconds: 20)).millisecondsSinceEpoch ~/ 1000;
      expect(limiter.observe(429, {'x-ratelimit-reset': '$reset'}), const Duration(seconds: 20));
      expect(limiter.observe(429, const {}), const Duration(minutes: 1));
    });
  });

  group('AnilistGraphql', () {
    test('every request takes a token of the limiter', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(limit: 1, clock: clock.call, sleep: clock.sleep);
      final log = <Call>[];
      final gql = fakeClient([ok({'x': 1})], log, limiter: limiter);
      await gql.query('query { x }');
      await gql.query('query { x }');
      expect(log, hasLength(2));
      expect(clock.slept, const Duration(minutes: 1));
    });

    test('a read refused with 429 waits Retry-After and is sent again', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      final log = <Call>[];
      final gql = fakeClient([
        http.Response('{"errors":[{"message":"Too Many Requests.","status":429}]}', 429,
            headers: {'retry-after': '30', 'x-ratelimit-remaining': '0'}),
        ok({'x': 1}),
      ], log, limiter: limiter);
      expect(await gql.query('query { x }'), {'x': 1});
      expect(log, hasLength(2));
      expect(clock.slept, greaterThanOrEqualTo(const Duration(seconds: 30)));
    });

    test('a longer Retry-After throws AnilistRateLimited', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      final log = <Call>[];
      final gql = fakeClient([
        http.Response('{"errors":[{"message":"Too Many Requests."}]}', 429,
            headers: {'retry-after': '120'}),
      ], log, limiter: limiter);
      final error = await gql.query('query { x }').then<Object?>((_) => null, onError: (e) => e);
      expect(error, isA<AnilistRateLimited>());
      error as AnilistRateLimited;
      expect(error.isRateLimited, isTrue);
      expect(error.retryAfter, const Duration(seconds: 120));
      expect(error.message, 'Too Many Requests.');
      expect(log, hasLength(1));
    });

    test('a write refused with 429 is never sent again', () async {
      final clock = FakeClock();
      final limiter = AnilistRateLimiter(clock: clock.call, sleep: clock.sleep);
      final log = <Call>[];
      final gql = fakeClient([
        http.Response('{}', 429, headers: {'retry-after': '5'}),
      ], log, limiter: limiter);
      await expectLater(gql.mutate('mutation { x }'), throwsA(isA<AnilistRateLimited>()));
      expect(log, hasLength(1));
    });

    test('without a limiter (fake sender) a 429 throws at once', () async {
      final log = <Call>[];
      final gql = fakeClient([http.Response('{}', 429, headers: {'retry-after': '1'})], log);
      await expectLater(gql.query('query { x }'), throwsA(isA<AnilistRateLimited>()));
      expect(log, hasLength(1));
    });

    test('mutate goes through the write sender, signed in', () async {
      final log = <Call>[];
      final gql = fakeClient([ok({'SaveX': {'id': 1}})], log);
      final data = await gql.mutate(r'mutation ($id: Int) { SaveX(id: $id) { id } }',
          variables: {'id': 1});
      expect(data, {'SaveX': {'id': 1}});
      expect(log.single.write, isTrue);
      expect(log.single.auth, isTrue);
      expect(log.single.variables, {'id': 1});
    });

    test('query goes through the read sender', () async {
      final log = <Call>[];
      await fakeClient([ok({'x': 1})], log).query('query { x }', auth: true);
      expect(log.single.write, isFalse);
      expect(log.single.auth, isTrue);
    });

    test('a write without a session is AnilistSessionExpired', () async {
      final gql = AnilistGraphql(sender: (_, {required auth}) async => null);
      await expectLater(gql.mutate('mutation { x }'), throwsA(isA<AnilistSessionExpired>()));
    });
  });

  group('batch', () {
    test('builds one aliased request with shared variables', () async {
      final log = <Call>[];
      final gql = fakeClient([
        ok({
          'trending': {'media': [{'id': 1}]},
          'top': {'media': [{'id': 2}]},
        }),
      ], log);
      final rows = await gql.batch({
        'trending': 'Page(perPage: 10) { media(sort: TRENDING_DESC) { id } }',
        'top': r'Page(perPage: 10) { media(type: $type, sort: SCORE_DESC) { id } }',
      }, variables: {'type': const GqlVar('MediaType', 'ANIME')});
      expect(log, hasLength(1));
      expect(log.single.query, startsWith(r'query ($type: MediaType) {'));
      expect(log.single.query, contains('trending: Page(perPage: 10)'));
      expect(log.single.query, contains('top: Page(perPage: 10)'));
      expect(log.single.variables, {'type': 'ANIME'});
      expect(rows['trending']?['media'], [{'id': 1}]);
      expect(rows.require('top')['media'], [{'id': 2}]);
      expect(rows.errors, isEmpty);
    });

    test('one failed alias does not fail the others', () async {
      final gql = fakeClient([
        http.Response(
            jsonEncode({
              'data': {'a': {'id': 1}, 'b': null},
              'errors': [
                {'message': 'Not Found.', 'status': 404, 'path': ['b']},
              ],
            }),
            404),
      ], []);
      final rows = await gql.batch({'a': 'Media(id: 1) { id }', 'b': 'Media(id: 0) { id }'});
      expect(rows['a'], {'id': 1});
      expect(rows['b'], isNull);
      expect(rows.errors['b']?.statusCode, 404);
      expect(() => rows.require('b'), throwsA(isA<AnilistError>()));
    });

    test('an error without a path is given to every alias without data', () async {
      final gql = fakeClient([
        http.Response(
            jsonEncode({
              'data': {'a': {'id': 1}, 'b': null},
              'errors': [{'message': 'Private.', 'status': 403}],
            }),
            200),
      ], []);
      final rows = await gql.batch({'a': 'A { id }', 'b': 'B { id }'});
      expect(rows.errors.keys, ['b']);
      expect(rows.errors['b']?.message, 'Private.');
    });

    test('no data at all throws, an empty batch sends nothing', () async {
      final log = <Call>[];
      final gql = fakeClient([http.Response('{"errors":[{"message":"bad"}]}', 400)], log);
      await expectLater(gql.batch({'a': 'A { id }'}), throwsA(isA<AnilistError>()));
      expect((await gql.batch(const {})).data, isEmpty);
      expect(log, hasLength(1));
    });

    test('aliases and variables must be GraphQL names', () {
      final gql = fakeClient([ok({})], []);
      expect(() => gql.batch({'not ok': 'A { id }'}), throwsArgumentError);
      expect(() => gql.batch({'a': 'A { id }'}, variables: {'1x': const GqlVar('Int', 1)}),
          throwsArgumentError);
    });
  });

  group('AnilistMedia score', () {
    test('fields ask weightedScore, not the deprecated averageScore', () {
      expect(AnilistMedia.fields, contains('weightedScore'));
      expect(AnilistMedia.fields, isNot(contains('averageScore')));
    });

    test('weightedScore first, averageScore as fallback, 0 is no score', () {
      expect(AnilistMedia.scoreOf({'weightedScore': 91, 'averageScore': 80}), 9.1);
      expect(AnilistMedia.scoreOf({'averageScore': 82}), 8.2);
      expect(AnilistMedia.scoreOf({'weightedScore': 0}), isNull);
      expect(AnilistMedia.scoreOf({'weightedScore': null, 'averageScore': 70}), 7.0);
      expect(AnilistMedia.scoreOf(const {}), isNull);
      expect(AnilistMedia.fromJson({'id': 1, 'weightedScore': 91}).score, 9.1);
    });
  });

  group('AnilistActions', () {
    test('toggleFavourite sends the argument of the kind', () async {
      for (final kind in AnilistFavouriteKind.values) {
        final log = <Call>[];
        final actions = AnilistActions(
            client: fakeClient([ok({'ToggleFavourite': {'__typename': 'Favourites'}})], log));
        await actions.toggleFavourite(kind, 7);
        expect(log.single.write, isTrue);
        expect(log.single.query, contains('ToggleFavourite(${kind.argument}: \$id)'));
        expect(log.single.variables, {'id': 7});
      }
    });

    test('toggleLike uses ToggleLikeV2 and reads the new like', () async {
      final log = <Call>[];
      final actions = AnilistActions(
          client: fakeClient([
        ok({'ToggleLikeV2': {'isLiked': true, 'likeCount': 12}}),
      ], log));
      final like = await actions.toggleLike(AnilistLikeable.threadComment, 55);
      expect(like, const AnilistLikeState(isLiked: true, likeCount: 12));
      expect(log.single.query, contains('ToggleLikeV2('));
      expect(log.single.query, isNot(contains('ToggleLike(')));
      expect(log.single.variables, {'id': 55, 'type': 'THREAD_COMMENT'});
      for (final type in ['ListActivity', 'TextActivity', 'MessageActivity', 'ActivityReply',
          'Thread', 'ThreadComment']) {
        expect(log.single.query, contains('... on $type { isLiked likeCount }'));
      }
    });

    test('toggleFollow reads the new follow', () async {
      final log = <Call>[];
      final actions = AnilistActions(
          client: fakeClient([
        ok({'ToggleFollow': {'id': 3, 'isFollowing': true, 'isFollower': false}}),
      ], log));
      expect(await actions.toggleFollow(3),
          const AnilistFollowState(isFollowing: true, isFollower: false));
      expect(log.single.variables, {'id': 3});
      expect(log.single.write, isTrue);
    });

    test('a null answer is an AnilistError', () async {
      final actions = AnilistActions(client: fakeClient([ok({'ToggleFollow': null})], []));
      await expectLater(actions.toggleFollow(3), throwsA(isA<AnilistError>()));
    });
  });
}
