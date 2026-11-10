import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_feeds_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_notifications_service.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_home_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';
import '../notifications/fakes.dart';

// Shapes follow AniList's live answers to anonymous reads (2026-10-29); nothing comes from an
// account and nothing is ever written: every request goes to a fake sender.

Map<String, dynamic> _media(int id, {String type = 'ANIME', bool adult = false, Object? entry}) => {
      'id': id,
      'idMal': id + 1000,
      'type': type,
      'format': 'TV',
      'status': 'RELEASING',
      'weightedScore': 82,
      'isAdult': adult,
      'title': {'romaji': 'Title $id'},
      'coverImage': {'large': 'https://x/$id.jpg'},
      if (entry != null) 'mediaListEntry': entry,
    };

typedef _Answer = Map<String, dynamic> Function(String query, bool auth);

AnilistGraphql _fake(List<({String query, bool auth})> log, _Answer answer) => AnilistGraphql(
      sender: (body, {required auth}) async {
        final query = (jsonDecode(body) as Map<String, dynamic>)['query'] as String;
        log.add((query: query, auth: auth));
        return http.Response(jsonEncode(answer(query, auth)), 200);
      },
    );

AnilistFeedsService _service(AnilistGraphql gql, {bool signedIn = false}) => AnilistFeedsService(
      client: gql,
      discover: AnilistDiscoverService(client: gql, signedIn: () => false, appAdult: () => false),
      signedIn: () => signedIn,
      titleLang: () => 'ro',
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('inline arguments', () {
    test('enums bare, strings quoted, lists bracketed', () {
      final text = AnilistFeedsService.inlineArguments({
        'type': 'ANIME',
        'sort': ['TRENDING_DESC'],
        'genre_in': ['Slice of Life'],
        'search': 'a "b"',
        'seasonYear': 2026,
        'isAdult': false,
        'skipped': null,
      });
      expect(text,
          'type: ANIME, sort: [TRENDING_DESC], genre_in: ["Slice of Life"], search: "a \\"b\\"", seasonYear: 2026, isAdult: false');
    });

    test('an enum argument that is not an enum name is refused', () {
      expect(() => AnilistFeedsService.inlineArguments({'type': 'ANIME) { x }'}), throwsArgumentError);
    });

    test('season start follows AniList (winter starts in December)', () {
      expect(AnilistFeedsService.seasonStart('WINTER', 2027), 20261201);
      expect(AnilistFeedsService.seasonStart('FALL', 2026), 20260901);
      expect(AnilistFeedsService.nextSeason('FALL', 2026), ('WINTER', 2027));
      expect(AnilistFeedsService.previousSeason('WINTER', 2027), ('FALL', 2026));
    });
  });

  group('explore', () {
    test('every row in one request, parsed per alias', () async {
      final log = <({String query, bool auth})>[];
      final gql = _fake(log, (q, _) => {
            'data': {
              'trendsToday': {
                'mediaTrends': [
                  {'trending': 9354, 'episode': 4, 'media': _media(1)},
                  {'trending': 100, 'episode': 3, 'media': _media(1)},
                  {'trending': 50, 'episode': null, 'media': _media(2, type: 'MANGA')},
                  {'trending': 40, 'episode': null, 'media': _media(3, adult: true)},
                ],
              },
              'airing': {
                'airingSchedules': [
                  {'episode': 5, 'airingAt': 1793247420, 'media': _media(4)},
                  {'episode': 6, 'airingAt': 1793250000, 'media': _media(4)},
                ],
              },
              'trending': {'media': [_media(5), _media(6)]},
              'season': null,
              'recommendations': {
                'recommendations': [
                  {
                    'id': 9,
                    'rating': 3,
                    'media': {'id': 7, 'type': 'ANIME', 'title': {'userPreferred': 'From'}},
                    'mediaRecommendation': _media(8),
                  },
                ],
              },
              'topCharacters': {
                'characters': [
                  {'id': 40, 'name': {'userPreferred': 'Lelouch'}, 'image': {'medium': 'https://x/c.jpg'}, 'favourites': 9},
                ],
              },
              'reviews': {
                'reviews': [
                  {'id': 33465, 'summary': 'A finale', 'score': 77, 'user': {'id': 1, 'name': 'Josh'},
                    'media': {'id': 1, 'type': 'ANIME', 'title': {'userPreferred': 'T'}}},
                ],
              },
            },
            'errors': [
              {'message': 'boom', 'status': 500, 'path': ['season']},
            ],
          });
      final service = _service(gql);
      final feed = await service.explore('anime');
      expect(log, hasLength(1), reason: 'one request for the whole tab');
      final query = log.single.query;
      for (final alias in ['trendsToday', 'airing', 'trending', 'season', 'nextSeason', 'top', 'popular',
        'reviews', 'recommendations', 'topCharacters', 'topStaff']) {
        expect(query, contains('$alias: Page('));
      }
      expect(query, contains('mediaTrends(date_greater:'));
      expect(query, contains('reviews(mediaType: ANIME, sort: [ID_DESC])'));
      expect(query, contains('isAdult: false'));

      final trends = feed.trends('trendsToday')!;
      expect(trends.map((t) => t.media.id), [1], reason: 'one per title, anime only, no adult');
      expect(trends.single.episode, 4);
      expect(feed.airing('airing')!.single.nextEpisode, 5);
      expect(feed.media('trending')!.map((m) => m.id), [5, 6]);
      expect(feed.media('trending')!.first.score, 8.2);
      expect(feed.media('season'), isNull, reason: 'a failed alias is null, the others stay');
      final rec = feed.recommendations('recommendations')!.single;
      expect(rec.from!.title, 'From');
      expect(rec.to.id, 8);
      expect(feed.people('topCharacters', isStaff: false)!.single.person.name, 'Lelouch');
      expect(feed.reviews('reviews')!.single.score, 77);

      await service.explore('anime');
      expect(log, hasLength(1), reason: 'kept ten minutes');
      await service.explore('anime', force: true);
      expect(log, hasLength(2));
      await service.explore('manga');
      expect(log.last.query, contains('manhwa: Page('));
      expect(log.last.query, isNot(contains('mediaTrends')));
    });
  });

  group('home', () {
    HomeSectionPreference section(SectionType type) => HomeSectionPreference(type: type, itemCount: 10);

    test('the plan maps sections to rows; suggested asks recommendations only signed in', () {
      final sections = [
        section(SectionType.userList),
        section(SectionType.suggested),
        section(SectionType.news),
        section(SectionType.topScore),
        section(SectionType.forum),
      ];
      final out = AnilistHomePlan.of(sections, signedIn: false);
      expect(out.sections.map((s) => s.type),
          [SectionType.userList, SectionType.suggested, SectionType.topScore, SectionType.forum]);
      expect(out.rowOf, {1: 0, 2: 1});
      expect(out.recommended, isFalse);
      expect(out.forum, isTrue);
      final signedIn = AnilistHomePlan.of(sections, signedIn: true);
      expect(signedIn.recommended, isTrue);
      expect(signedIn.key, isNot(out.key));
    });

    test('one signed-in request; recommendations drop what is on the list', () async {
      final log = <({String query, bool auth})>[];
      final gql = _fake(log, (q, auth) => {
            'data': {
              'row0': {'media': [_media(1)]},
              'recommended': {
                'recommendations': [
                  {'id': 1, 'rating': 10, 'media': {'id': 50, 'type': 'ANIME', 'title': {'userPreferred': 'Mine'}},
                    'mediaRecommendation': _media(60, entry: {'status': 'CURRENT'})},
                  {'id': 2, 'rating': 8, 'media': {'id': 50, 'type': 'ANIME', 'title': {'userPreferred': 'Mine'}},
                    'mediaRecommendation': _media(61)},
                  {'id': 3, 'rating': 0, 'media': {'id': 51, 'type': 'ANIME', 'title': {'userPreferred': 'Mine'}},
                    'mediaRecommendation': _media(62)},
                  {'id': 4, 'rating': 5, 'media': {'id': 52, 'type': 'ANIME', 'title': {'userPreferred': 'Other'}},
                    'mediaRecommendation': _media(61)},
                ],
              },
              'following': {
                'activities': [
                  {'__typename': 'ListActivity', 'id': 5, 'status': 'watched episode', 'progress': '4',
                    'user': {'id': 2, 'name': 'Ann'}, 'media': {'id': 1, 'type': 'ANIME', 'title': {'userPreferred': 'T'}}},
                ],
              },
              'forum': {'threads': [{'id': 8, 'title': 'Best of 2026'}]},
              'birthdayCharacters': {'characters': [{'id': 1, 'name': {'userPreferred': 'Kuririn'}}]},
              'birthdayStaff': {'staff': []},
            },
          });
      final plan = AnilistHomePlan.of(
        [section(SectionType.suggested), section(SectionType.forum)],
        signedIn: true,
      );
      final feed = await plan.load(_service(gql, signedIn: true));
      expect(log, hasLength(1));
      expect(log.single.auth, isTrue);
      expect(log.single.query, contains('recommendations(onList: true, sort: [RATING_DESC])'));
      expect(log.single.query, contains('activities(isFollowing: true'));
      final recs = feed.recommendations(AnilistHomeParts.recommended, notOnList: true)!;
      expect(recs.map((r) => r.to.id), [61], reason: 'not on the list, voted, once');
      expect(recs.single.from!.title, 'Mine');
      expect(feed.activities(AnilistHomeParts.following)!.single.user!.name, 'Ann');
      expect(feed.threads(AnilistHomeParts.forum)!.single.title, 'Best of 2026');
      expect(feed.people(AnilistHomeParts.birthdayCharacters, isStaff: false)!.single.person.name, 'Kuririn');
      expect(feed.media(AnilistHomeParts.row(0))!.single.id, 1);
    });

    test('a dead session sends the public parts anonymously', () async {
      final log = <({String query, bool auth})>[];
      final gql = AnilistGraphql(sender: (body, {required auth}) async {
        final query = (jsonDecode(body) as Map<String, dynamic>)['query'] as String;
        log.add((query: query, auth: auth));
        if (auth) throw const AnilistSessionExpired();
        return http.Response(jsonEncode({'data': {'row0': {'media': []}}}), 200);
      });
      final plan = AnilistHomePlan.of([section(SectionType.suggested)], signedIn: true);
      final feed = await plan.load(_service(gql, signedIn: true));
      expect(log.map((l) => l.auth), [true, false]);
      expect(log.last.query, isNot(contains('recommendations')));
      expect(feed.media(AnilistHomeParts.row(0)), isEmpty);
      expect(feed.recommendations(AnilistHomeParts.recommended), isNull);
    });
  });

  group('background notifications', () {
    late List<int> ids;
    late int unread;
    late _FakeNotifier notifier;
    late int requests;

    AnilistBackgroundNotifier make({bool enabled = true}) {
      final gql = AnilistGraphql(sender: (body, {required auth}) async {
        requests++;
        expect(auth, isTrue);
        expect(body, contains('resetNotificationCount: false'), reason: 'never marks the inbox read');
        return http.Response(
            jsonEncode({
              'data': {
                'Viewer': {'unreadNotificationCount': unread},
                'Page': {
                  'pageInfo': {'hasNextPage': false},
                  'notifications': [
                    for (final id in ids)
                      {
                        '__typename': 'FollowingNotification',
                        'id': id,
                        'type': 'FOLLOWING',
                        'createdAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        'user': {'id': 7, 'name': 'Josh'},
                      },
                  ],
                },
              },
            }),
            200);
      });
      return AnilistBackgroundNotifier(
        service: AnilistNotificationsService(client: gql, signedIn: true),
        notifier: notifier,
        readPrefs: () => NotificationPreferences(subscribedAt: enabled ? DateTime(2026) : null),
        signedIn: () => true,
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ids = [12, 11, 10];
      unread = 2;
      notifier = _FakeNotifier();
      requests = 0;
    });

    test('announces unread notifications once, then only newer ones', () async {
      final round = make();
      expect(await round.poll(), 2);
      expect(notifier.shown.single.title, '2 new AniList notifications');
      expect(notifier.shown.single.lines, ['Josh started following you', 'Josh started following you']);
      expect(notifier.shown.single.payload, AnilistBackgroundNotifier.payload);

      expect(await round.poll(), 0, reason: 'nothing newer');
      expect(notifier.shown, hasLength(1));

      ids = [13, 12, 11, 10];
      unread = 3;
      expect(await round.poll(), 1);
      expect(notifier.shown.last.title, '3 new AniList notifications');

      unread = 0;
      expect(await round.poll(), 0);
      expect(notifier.cancels, 1, reason: 'read elsewhere: the notification goes');
    });

    test('nothing is asked with the switch or the master switch off', () async {
      final round = make();
      await round.setPush(false);
      expect(await round.poll(), 0);
      expect(requests, 0);
      expect((await SharedPreferences.getInstance()).getBool(AnilistBackgroundNotifier.pushKey), isFalse);
      final off = make(enabled: false);
      expect(off.wanted, isFalse);
      expect(await off.poll(), 0);
      expect(requests, 0);
    });

    test('a tap on it opens the AniList inbox, also before the navigator exists', () async {
      final opened = <String>[];
      final backend = FakeBackend();
      final service = NotificationService(
        backend: backend,
        trackerChanges: ChangeNotifier(),
        openAnilistPayload: opened.add,
        openHubPayload: (_) => fail('not a MAL payload'),
      );
      await service.init();
      backend.tapHandler!(AnilistBackgroundNotifier.payload);
      expect(opened, isEmpty, reason: 'kept until the app is ready');
      service.onOpen = (_) => fail('not an app route');
      service.flushPendingTap();
      expect(opened, [AnilistBackgroundNotifier.payload]);
      backend.tapHandler!(AnilistBackgroundNotifier.payload);
      expect(opened, hasLength(2));
    });
  });
}

class _FakeNotifier implements AnilistSystemNotifier {
  final List<AnilistSystemNotification> shown = [];
  int cancels = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> allowed() async => true;

  @override
  Future<void> show(AnilistSystemNotification notification) async => shown.add(notification);

  @override
  Future<void> cancel() async => cancels++;
}
