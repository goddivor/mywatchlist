import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import 'fakes.dart';

void main() {
  group('SimklClient', () {
    test('signed-in calls carry the token and the api key through the session sender', () async {
      final fake = FakeSimkl((_) => FakeSimkl.json({'ok': true}));
      final data = await fake.client.getAuth('/users/settings');
      expect(data, {'ok': true});
      final request = fake.seen.single;
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['simkl-api-key'], 'client-id');
      expect(request.url.path, '/users/settings');
    });

    test('no session or a 401 means sign in again', () async {
      final signedOut = FakeSimkl((_) => FakeSimkl.json({}), signedIn: false);
      await expectLater(signedOut.client.getAuth('/x'), throwsA(isA<SimklSessionExpired>()));
      final dead = FakeSimkl((_) => FakeSimkl.json({}, 401));
      await expectLater(dead.client.getAuth('/x'), throwsA(isA<SimklSessionExpired>()));
    });

    test('other errors keep their status and public calls add the client id', () async {
      final fake = FakeSimkl((_) => FakeSimkl.json({}, 503));
      await expectLater(
        fake.client.getPublic('/anime/trending'),
        throwsA(isA<SimklHttpError>().having((e) => e.statusCode, 'status', 503)),
      );
      expect(fake.seen.single.url.queryParameters['client_id'], 'client-id');
      expect(fake.seen.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('SimklListService', () {
    FakeSimkl serverWith(List<Map<String, dynamic>> items) => FakeSimkl((r) {
          if (r.method == 'GET' && r.url.path == '/sync/all-items/anime') {
            return FakeSimkl.json({'anime': items});
          }
          return FakeSimkl.json({'added': {}});
        });

    test('the list is fetched once while fresh and again when forced', () async {
      var now = DateTime(2026, 10, 27, 12);
      final fake = serverWith([simklItem(id: 1)]);
      final service = SimklListService(client: fake.client, clock: () => now, owner: () => 'me');
      await service.anime();
      await service.anime();
      expect(fake.seen.where((r) => r.url.path == '/sync/all-items/anime'), hasLength(1));
      await service.anime(force: true);
      expect(fake.seen.where((r) => r.url.path == '/sync/all-items/anime'), hasLength(2));
      now = now.add(const Duration(minutes: 10));
      await service.anime();
      expect(fake.seen.where((r) => r.url.path == '/sync/all-items/anime'), hasLength(3), reason: 'older than the ttl');
    });

    test('another account never sees the kept list', () async {
      var who = 'a';
      final fake = serverWith([simklItem(id: 1)]);
      final service = SimklListService(client: fake.client, owner: () => who);
      await service.anime();
      who = 'b';
      await service.anime();
      expect(fake.seen.where((r) => r.url.path == '/sync/all-items/anime'), hasLength(2));
    });

    test('save sends the status and the score together, and removes a score with its own call', () async {
      final fake = serverWith([]);
      final service = SimklListService(client: fake.client, owner: () => 'me');
      final entry = const ListEntryView(id: 7, malId: 70, category: 'anime', title: 'T', status: ListEntryStatus.current, score: 6);
      final saved = await service.save(entry, status: ListEntryStatus.completed, score: 9);
      final add = fake.seen.single;
      expect(add.url.path, '/sync/add-to-list');
      expect(add.body, {
        'anime': [
          {'ids': {'simkl': 7, 'mal': 70}, 'to': 'completed', 'rating': 9},
        ],
      });
      expect(saved.status, ListEntryStatus.completed);
      expect(saved.score, 9);

      fake.seen.clear();
      await service.save(entry, score: 0);
      expect(fake.seen.map((r) => r.url.path), ['/sync/add-to-list', '/sync/ratings/remove']);
    });

    test('progress adds the missing episodes, or takes the extra ones off', () async {
      final fake = serverWith([]);
      final service = SimklListService(client: fake.client, owner: () => 'me');
      const entry = ListEntryView(
          id: 7, category: 'anime', title: 'T', status: ListEntryStatus.planned, progress: 2, total: 5);
      final up = await service.setProgress(entry, 4);
      expect(fake.seen.single.url.path, '/sync/history');
      expect((fake.seen.single.body as Map)['shows'], [
        {
          'ids': {'simkl': 7},
          'episodes': [
            {'number': 3},
            {'number': 4}
          ],
        },
      ]);
      expect(up.progress, 4);
      expect(up.status, ListEntryStatus.current, reason: 'a planned title starts');

      fake.seen.clear();
      final down = await service.setProgress(up, 3);
      expect(fake.seen.single.url.path, '/sync/history/remove');
      expect(((fake.seen.single.body as Map)['shows'] as List).single['episodes'], [
        {'number': 4}
      ]);
      expect(down.progress, 3);
    });

    test('the last episode of a finished title completes it, an airing one does not', () async {
      final fake = serverWith([]);
      final service = SimklListService(client: fake.client, owner: () => 'me');
      const finished = ListEntryView(
          id: 1, category: 'anime', title: 'T', status: ListEntryStatus.current, progress: 11, total: 12, releaseState: ReleaseState.finished);
      expect((await service.step(finished, 1)).status, ListEntryStatus.completed);
      const releasing = ListEntryView(
          id: 2, category: 'anime', title: 'T', status: ListEntryStatus.current, progress: 11, total: 12, releaseState: ReleaseState.releasing);
      expect((await service.step(releasing, 1)).status, ListEntryStatus.current);
    });

    test('a step past the total or below zero sends nothing', () async {
      final fake = serverWith([]);
      final service = SimklListService(client: fake.client, owner: () => 'me');
      const entry = ListEntryView(id: 1, category: 'anime', title: 'T', status: ListEntryStatus.current, progress: 12, total: 12);
      expect(await service.step(entry, 1), entry);
      expect(await service.step(entry.copyWith(progress: 0), -1), entry.copyWith(progress: 0));
      expect(fake.seen, isEmpty);
    });

    test('airing candidates: watching and planned titles with a MAL id that can still air', () async {
      final fake = serverWith([
        simklItem(id: 1, mal: 11, status: 'watching', notAired: 3),
        simklItem(id: 2, mal: 22, status: 'plantowatch', total: 0),
        simklItem(id: 3, mal: 33, status: 'watching', notAired: 0, total: 12), // finished airing
        simklItem(id: 4, status: 'watching', notAired: 2), // no MAL id
        simklItem(id: 5, mal: 55, status: 'completed', notAired: 2),
      ]);
      final service = SimklListService(client: fake.client, owner: () => 'me');
      final candidates = await service.airingCandidates();
      expect(candidates.map((c) => c.malId), [11, 22]);
      expect(candidates[0].status, 'watching');
      expect(candidates[0].airingStatus, 'currently_airing');
      expect(candidates[1].status, 'plan_to_watch');
      expect(candidates[1].numEpisodes, isNull);
    });
  });

  group('SimklDiscoverService', () {
    test('trending, search and the MAL id lookup use the public endpoints', () async {
      final fake = FakeSimkl((r) {
        if (r.url.path == '/anime/trending') {
          return FakeSimkl.json([
            {'title': 'A', 'ids': {'simkl_id': 1}},
          ]);
        }
        if (r.url.path == '/search/anime') {
          return FakeSimkl.json([
            {'title': 'B', 'ids': {'simkl_id': 2}},
          ]);
        }
        return FakeSimkl.json({'ids': {'simkl': 9, 'mal': 1234}});
      });
      final service = SimklDiscoverService(client: fake.client);
      expect((await service.trending()).single.title, 'A');
      expect((await service.search(' naruto ')).single.title, 'B');
      expect(fake.seen.last.url.queryParameters['q'], 'naruto');
      expect(await service.search('  '), isEmpty);
      expect(await service.malIdOf(9), 1234);
      expect(fake.seen.every((r) => !r.headers.containsKey('Authorization')), isTrue);
    });
  });
}
