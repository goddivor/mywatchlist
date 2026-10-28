import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';

Map<String, dynamic> media(int id,
        {int? mal, String status = 'FINISHED', String type = 'ANIME', Map? next}) =>
    {
      'id': id,
      'idMal': mal,
      'type': type,
      'format': type == 'ANIME' ? 'TV' : 'MANGA',
      'status': status,
      'episodes': 12,
      'chapters': 40,
      'volumes': 4,
      'genres': ['Action'],
      'averageScore': 82,
      'popularity': 1000,
      'title': {'romaji': 'Romaji $id', 'english': 'English $id', 'native': 'Native $id'},
      'synonyms': ['Syn $id'],
      'coverImage': {'large': 'https://x/$id.jpg', 'extraLarge': 'https://x/$id-xl.jpg'},
      'startDate': {'year': 2024, 'month': 4, 'day': 6},
      'endDate': {'year': null, 'month': null, 'day': null},
      'nextAiringEpisode': next,
    };

Map<String, dynamic> entry(Map<String, dynamic> m, String status,
        {int progress = 3, num score = 8.5}) =>
    {
      'id': 900 + (m['id'] as int),
      'status': status,
      'progress': progress,
      'progressVolumes': 0,
      'priority': 0,
      'updatedAt': 1700000000 + (m['id'] as int),
      'score': score,
      'startedAt': {'year': 2024, 'month': 4, 'day': 7},
      'completedAt': {'year': null, 'month': null, 'day': null},
      'media': m,
    };

http.Response ok(Object data) => http.Response(jsonEncode({'data': data}), 200);

AnilistGraphql fakeGql(List<Map<String, dynamic>> entries, {List<String>? log}) =>
    AnilistGraphql(sender: (body, {required auth}) async {
      log?.add(auth ? 'auth' : 'public');
      return ok({
        'MediaListCollection': {
          'hasNextChunk': false,
          'lists': [
            {'entries': entries},
          ],
        },
      });
    });

class _FakeClient implements TrackerEntryClient {
  final writes = <SyncEntry>[];

  @override
  AccountType get tracker => AccountType.anilist;
  @override
  bool supports({required bool isAnime}) => true;
  @override
  Future<SyncEntry?> read(String mediaId, {required bool isAnime, int? malId}) async => null;
  @override
  Future<SyncEntry> write(String mediaId, SyncEntry entry,
      {required bool isAnime, int? malId}) async {
    writes.add(entry);
    return entry;
  }

  @override
  Future<void> delete(String mediaId, {required bool isAnime, int? malId}) async {}
  @override
  Future<String?> findByMalId(int malId, {required bool isAnime}) async => null;
}

void main() {
  group('parseAnilistEntries', () {
    test('maps status, score, progress, ids and dates', () {
      final entries = parseAnilistEntries([
        entry(media(1, mal: 11), 'CURRENT'),
        entry(media(2), 'REPEATING'),
        entry(media(3, mal: 33), 'PAUSED'),
        entry(media(4), 'PLANNING', score: 0),
      ], category: 'anime', titleLang: 'en');
      expect(entries.map((e) => e.status), [
        ListEntryStatus.current,
        ListEntryStatus.current,
        ListEntryStatus.onHold,
        ListEntryStatus.planned,
      ]);
      expect(entries[0].malId, 11);
      expect(entries[1].malId, isNull);
      expect(entries[1].repeating, isTrue);
      expect(entries[0].title, 'English 1');
      expect(entries[0].score, 9);
      expect(entries[3].score, 0);
      expect(entries[0].meanScore, 8.2);
      expect(entries[0].releaseStart, '2024-04-06');
      expect(entries[0].listStartDate, '2024-04-07');
      expect(entries[0].listFinishDate, isNull);
      expect(entries[0].mediaType, 'tv');
      expect(entries[0].total, 12);
      expect(entries[0].otherTitles, contains('Syn 1'));
    });

    test('title follows the preferred language', () {
      final raw = [entry(media(1), 'CURRENT')];
      expect(parseAnilistEntries(raw, category: 'anime', titleLang: 'ro').first.title, 'Romaji 1');
      expect(parseAnilistEntries(raw, category: 'anime', titleLang: 'ja').first.title, 'Native 1');
    });

    test('manga uses chapters and volumes', () {
      final e = parseAnilistEntries([entry(media(5, type: 'MANGA'), 'CURRENT')],
          category: 'manga', titleLang: 'ro').single;
      expect(e.total, 40);
      expect(e.totalVolumes, 4);
      expect(e.mediaType, 'manga');
    });

    test('next airing episode gives the Japan time slot', () {
      // 2024-04-06 14:30 UTC = Saturday 23:30 JST.
      final at = DateTime.utc(2024, 4, 6, 14, 30).millisecondsSinceEpoch ~/ 1000;
      final e = parseAnilistEntries([
        entry(media(1, mal: 1, status: 'RELEASING', next: {'episode': 4, 'airingAt': at}),
            'CURRENT'),
      ], category: 'anime', titleLang: 'ro').single;
      expect(e.releaseState, ReleaseState.releasing);
      expect(e.broadcast, const BroadcastSlot(DateTime.saturday, 23 * 60 + 30));
    });
  });

  group('AnilistListService', () {
    test('merges custom lists, keeps one request per minute and counts statuses', () async {
      final log = <String>[];
      var now = DateTime(2026, 1, 1, 12);
      final m = media(1, mal: 1);
      final service = AnilistListService(
        client: fakeGql([entry(m, 'CURRENT'), entry(m, 'CURRENT'), entry(media(2), 'COMPLETED')],
            log: log),
        owner: () => 'me',
        clock: () => now,
        titleLang: () => 'ro',
      );
      final first = await service.all('anime');
      expect(first.length, 2);
      await service.all('anime');
      expect(log, ['auth']);
      now = now.add(const Duration(minutes: 2));
      await service.all('anime');
      expect(log.length, 2);
      final counts = AnilistListService.countStatuses(first);
      expect(counts[ListEntryStatus.current], 1);
      expect(counts[ListEntryStatus.completed], 1);
    });

    test('no session means AnilistSessionExpired', () async {
      final service = AnilistListService(
        client: AnilistGraphql(sender: (_, {required auth}) async => null),
        owner: () => 'me',
      );
      expect(service.all('anime'), throwsA(isA<AnilistSessionExpired>()));
    });

    test('airing candidates carry MAL ids and the JST slot', () {
      final at = DateTime.utc(2024, 4, 6, 14, 30).millisecondsSinceEpoch ~/ 1000;
      final entries = parseAnilistEntries([
        entry(media(1, mal: 11, status: 'RELEASING', next: {'episode': 4, 'airingAt': at}),
            'CURRENT'),
        entry(media(2, status: 'RELEASING'), 'CURRENT'),
        entry(media(3, mal: 33, status: 'FINISHED'), 'CURRENT'),
        entry(media(4, mal: 44, status: 'NOT_YET_RELEASED'), 'PLANNING'),
        entry(media(5, mal: 55, status: 'RELEASING'), 'DROPPED'),
      ], category: 'anime', titleLang: 'ro');
      final c = AnilistListService.airingCandidatesOf(entries);
      expect(c.map((e) => e.malId), [11, 44]);
      expect(c.first.status, 'watching');
      expect(c.first.broadcastDay, 'saturday');
      expect(c.first.broadcastTime, '23:30');
      expect(c.last.status, 'plan_to_watch');
    });
  });

  group('AnilistUserListAdapter', () {
    final entries = [
      for (var i = 1; i <= 5; i++) entry(media(i, mal: i), i <= 3 ? 'CURRENT' : 'COMPLETED'),
    ];
    AnilistUserListAdapter adapter({_FakeClient? client, List<String>? log}) =>
        AnilistUserListAdapter(
          service: AnilistListService(
            client: fakeGql(entries, log: log),
            owner: () => 'me',
            titleLang: () => 'ro',
          ),
          sync: TrackerSyncService(clients: {AccountType.anilist: client ?? _FakeClient()}),
          clock: () => DateTime(2026, 2, 3),
        );

    test('cuts status tabs and pages from one request', () async {
      final log = <String>[];
      final a = adapter(log: log);
      final all = await a.fetch(category: 'anime', status: null, offset: 0, limit: 1000);
      expect(all.entries.length, 5);
      expect(all.hasMore, isFalse);
      final current = await a.fetch(
          category: 'anime', status: ListEntryStatus.current, offset: 0, limit: 2);
      expect(current.entries.length, 2);
      expect(current.hasMore, isTrue);
      final rest = await a.fetch(
          category: 'anime', status: ListEntryStatus.current, offset: 2, limit: 2);
      expect(rest.entries.length, 1);
      expect(rest.hasMore, isFalse);
      expect(log.length, 1);
      expect((await a.statusCounts('anime'))![ListEntryStatus.completed], 2);
    });

    test('the same first page twice is a refresh and asks AniList again', () async {
      final log = <String>[];
      final a = adapter(log: log);
      await a.fetch(category: 'anime', status: null, offset: 0, limit: 1000);
      await a.fetch(category: 'anime', status: null, offset: 0, limit: 1000);
      expect(log.length, 2);
    });

    test('step +1 writes progress, the last episode completes with a finish date', () async {
      final client = _FakeClient();
      final a = adapter(client: client);
      final page = await a.fetch(category: 'anime', status: null, offset: 0, limit: 1000);
      final first = page.entries.first;
      final next = await a.step(first, 1);
      expect(next.progress, first.progress + 1);
      expect(client.writes.last.status, 'watching');
      final lastEp = first.copyWith(progress: 11);
      final done = await a.step(lastEp, 1);
      expect(done.status, ListEntryStatus.completed);
      expect(done.listFinishDate, '2026-02-03');
      expect(client.writes.last.status, 'completed');
    });

    test('step never goes below zero or past the total', () async {
      final a = adapter();
      final e = (await a.fetch(category: 'anime', status: null, offset: 0, limit: 1)).entries.single;
      expect((await a.step(e.copyWith(progress: 0), -1)).progress, 0);
      expect((await a.step(e.copyWith(progress: 12), 1)).progress, 12);
    });

    test('session errors are recognised', () {
      expect(adapter().isSessionExpired(const AnilistSessionExpired()), isTrue);
      expect(adapter().isSessionExpired(StateError('x')), isFalse);
    });
  });

  group('AnilistGraphql', () {
    test('GraphQL errors without data throw AnilistError', () {
      final gql = AnilistGraphql(
          sender: (_, {required auth}) async => http.Response(
              jsonEncode({'errors': [{'message': 'nope'}]}), 400));
      expect(gql.query('query {x}'), throwsA(isA<AnilistError>()));
    });

    test('401 on an authenticated call is a dead session', () {
      final gql = AnilistGraphql(sender: (_, {required auth}) async => http.Response('{}', 401));
      expect(gql.query('query {x}', auth: true), throwsA(isA<AnilistSessionExpired>()));
    });
  });

  group('discover', () {
    test('seasonOf follows AniList seasons, December belongs to next winter', () {
      expect(AnilistDiscoverService.seasonOf(DateTime(2026, 1, 10)), ('WINTER', 2026));
      expect(AnilistDiscoverService.seasonOf(DateTime(2026, 4, 10)), ('SPRING', 2026));
      expect(AnilistDiscoverService.seasonOf(DateTime(2026, 10, 10)), ('FALL', 2026));
      expect(AnilistDiscoverService.seasonOf(DateTime(2026, 12, 10)), ('WINTER', 2027));
    });

    test('parses a media page', () {
      final page = AnilistDiscoverService.parseMediaPage({
        'Page': {
          'pageInfo': {'hasNextPage': true},
          'media': [media(1, mal: 5), media(2)],
        },
      }, titleLang: 'en');
      expect(page.hasNext, isTrue);
      expect(page.items.map((m) => m.malId), [5, null]);
      expect(page.items.first.title, 'English 1');
      expect(page.items.first.score, 8.2);
      expect(page.items.first.url, 'https://anilist.co/anime/1');
    });

    test('parses a thread', () {
      final t = AnilistThread.fromJson({
        'id': 7,
        'title': ' Hello ',
        'replyCount': 3,
        'isSticky': true,
        'user': {'name': 'bob', 'avatar': {'medium': 'a'}},
        'categories': [{'name': 'Anime'}],
      });
      expect(t.title, 'Hello');
      expect(t.author, 'bob');
      expect(t.sticky, isTrue);
      expect(t.categories, ['Anime']);
    });
  });

  group('profile', () {
    test('parses header data, statuses, scores and favorites', () {
      final p = AnilistProfileService.parseProfile({
        'id': 1,
        'name': 'me',
        'about': '<p>hi</p>',
        'createdAt': 1600000000,
        'avatar': {'large': 'https://x/a.png'},
        'statistics': {
          'anime': {
            'count': 10,
            'meanScore': 75.5,
            'minutesWatched': 2880,
            'episodesWatched': 100,
            'statuses': [
              {'status': 'CURRENT', 'count': 2},
              {'status': 'REPEATING', 'count': 1},
              {'status': 'COMPLETED', 'count': 5},
              {'status': 'PLANNING', 'count': 2},
            ],
            'scores': [
              {'score': 80, 'count': 3},
              {'score': 0, 'count': 9},
            ],
            'formats': [{'format': 'TV', 'count': 8, 'meanScore': 70}],
            'genres': [{'genre': 'Action', 'count': 4, 'meanScore': 80}],
          },
          'manga': {'count': 0},
        },
        'favourites': {
          'anime': {
            'nodes': [
              {
                'id': 5,
                'idMal': 50,
                'title': {'userPreferred': 'A'},
                'coverImage': {'large': 'c'},
              },
            ],
          },
          'studios': {
            'nodes': [
              {'id': 9, 'name': 'Studio'},
            ],
          },
        },
      });
      expect(p.data.username, 'me');
      expect(p.data.anime.meanScore, 7.55);
      expect(p.data.anime.days, 2);
      expect(p.data.anime.current, 3);
      expect(p.data.anime.statusCounts, [3, 5, 0, 0, 2]);
      expect(p.anime.scores, {8: 3});
      expect(p.anime.genres.single.mean, 8);
      expect(p.favorites.anime.single.malId, 50);
      expect(p.favorites.studios.single.title, 'Studio');
      expect(p.manga.list.isEmpty, isTrue);
      expect(p.url, 'https://anilist.co/user/me');
    });
  });
}
