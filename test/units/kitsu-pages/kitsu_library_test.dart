import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart' show SortDirection;
import 'package:mywatchlist/widgets/Kitsu/kitsu_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kitsu_fakes.dart';

Map<String, dynamic> entryResource(int entry, int media,
        {String status = 'current', int progress = 3, int? rating = 15}) =>
    {
      'id': '$entry',
      'type': 'libraryEntries',
      'attributes': {
        'status': status,
        'progress': progress,
        'ratingTwenty': rating,
        'reconsuming': false,
        'startedAt': '2024-04-07T10:00:00.000Z',
        'finishedAt': null,
        'progressedAt': '2024-05-01T08:30:00.000Z',
      },
      'relationships': {
        'anime': {
          'data': {'type': 'anime', 'id': '$media'}
        },
      },
    };

Map<String, dynamic> libraryBody({bool next = false}) => {
      'data': [entryResource(900, 1), entryResource(901, 2, rating: null, status: 'planned', progress: 0)],
      'included': [
        animeResource(1, 'One', malId: 11),
        animeResource(2, 'Two'),
        ...mappingsOf(1, malId: 11),
        ...mappingsOf(2),
      ],
      if (next) 'links': {'next': 'https://kitsu.io/api/edge/library-entries?page[offset]=2'},
    };

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await S.load(const Locale('en'));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeKitsu library({bool signedIn = true, bool next = false}) => FakeKitsu((r) async {
        final p = r.url.path;
        if (p.endsWith('/users')) {
          return jsonResponse({
            'data': [
              {'id': '42', 'type': 'users'}
            ]
          });
        }
        if (p.endsWith('/library-entries') && r.method == 'GET') {
          if (r.url.queryParameters['page[limit]'] == '1') {
            return jsonResponse({'data': [], 'meta': {'count': 7}});
          }
          return jsonResponse(libraryBody(next: next));
        }
        if (r.method == 'PATCH') return jsonResponse({'data': {}});
        return http.Response('', 404);
      }, signedIn: signedIn);

  group('KitsuLibrary', () {
    test('parses entries: status, half-point score, dates and the MAL id', () async {
      final fake = library(next: true);
      final lib = KitsuLibrary(http: fake.kitsu, owner: () => 'me');
      final result = await lib.page(
          isAnime: true, status: null, offset: 0, limit: 200, sort: '-progressedAt');
      final entries = result.page.entries;
      expect(result.page.hasMore, isTrue);
      expect(entries, hasLength(2));
      final first = entries.first;
      expect(first.id, 1);
      expect(first.malId, 11);
      expect(first.status, ListEntryStatus.current);
      expect(first.score, 8); // 15 / 20 = 7.5, half points round up
      expect(first.progress, 3);
      expect(first.listStartDate, '2024-04-07');
      expect(first.listFinishDate, isNull);
      expect(first.updatedAt, DateTime.utc(2024, 5, 1, 8, 30));
      expect(entries.last.status, ListEntryStatus.planned);
      expect(entries.last.score, 0);
      expect(entries.last.malId, isNull);
      expect(result.entryIds, {1: '900', 2: '901'});

      final request = fake.requests.last.url.queryParameters;
      expect(request['filter[userId]'], '42');
      expect(request['filter[kind]'], 'anime');
      expect(request['include'], 'anime,anime.mappings');
      expect(request['sort'], '-progressedAt');
    });

    test('a status filter uses Kitsu words', () async {
      final fake = library();
      final lib = KitsuLibrary(http: fake.kitsu, owner: () => 'me');
      await lib.page(isAnime: false, status: ListEntryStatus.onHold, offset: 10, limit: 50);
      final q = fake.requests.last.url.queryParameters;
      expect(q['filter[status]'], 'on_hold');
      expect(q['filter[kind]'], 'manga');
      expect(q['page[offset]'], '10');
    });

    test('status counts read the meta count of five cheap requests', () async {
      final lib = KitsuLibrary(http: library().kitsu, owner: () => 'me');
      final counts = await lib.statusCounts(isAnime: true);
      expect(counts.values, everyElement(7));
      expect(counts.keys, ListEntryStatus.values);
    });

    test('a signed-out session throws KitsuSessionExpired', () async {
      final lib = KitsuLibrary(http: library(signedIn: false).kitsu, owner: () => 'me');
      expect(() => lib.userId(), throwsA(isA<KitsuSessionExpired>()));
    });

    test('score rounding', () {
      expect(KitsuLibrary.scoreOfTwenty(0), 0);
      expect(KitsuLibrary.scoreOfTwenty(2), 1);
      expect(KitsuLibrary.scoreOfTwenty(3), 2);
      expect(KitsuLibrary.scoreOfTwenty(20), 10);
    });

    test('airing candidates keep unfinished titles that have a MAL id', () async {
      final fake = FakeKitsu((r) async {
        if (r.url.path.endsWith('/users')) {
          return jsonResponse({'data': [{'id': '42', 'type': 'users'}]});
        }
        return jsonResponse(libraryBody());
      });
      final lib = KitsuLibrary(http: fake.kitsu, owner: () => 'me');
      final candidates = await lib.airingCandidates();
      // Entry 2 has no MyAnimeList id: left out. The same list answers both statuses here.
      expect(candidates.map((c) => c.malId).toSet(), {11});
      expect(candidates.map((c) => c.status).toSet(), {'watching', 'plan_to_watch'});
      expect(candidates.first.airingStatus, 'currently_airing');
    });
  });

  group('KitsuUserListAdapter', () {
    KitsuUserListAdapter adapter(FakeKitsu fake,
            {Future<SyncEntry?> Function(BuildContext, ListEntryView, SyncEntry)? editor}) =>
        KitsuUserListAdapter(
          library: KitsuLibrary(http: fake.kitsu, owner: () => 'me'),
          owner: () => 'me',
          clock: () => DateTime.utc(2024, 6, 1),
          editor: editor,
        );

    test('only the last update is sorted by Kitsu', () {
      final a = adapter(library());
      expect(a.tracker.name, 'kitsu');
      expect(a.apiSort('anime', 'list_updated_at', SortDirection.descending), '-progressedAt');
      expect(a.apiSort('anime', 'list_score', SortDirection.descending), isNull);
      expect(a.sortOptions('anime').map((o) => o.key), isNot(contains('priority')));
      expect(a.sortOptions('manga').map((o) => o.key), isNot(contains('num_scoring_users')));
    });

    test('step +1 patches the progress with the entry id from the fetch', () async {
      final fake = library();
      final a = adapter(fake);
      final page = await a.fetch(category: 'anime', status: null, offset: 0, limit: 200);
      final updated = await a.step(page.entries.first, 1);
      expect(updated.progress, 4);
      final patch = fake.requests.lastWhere((r) => r.method == 'PATCH');
      expect(patch.url.path, endsWith('/library-entries/900'));
      final body = jsonDecode(patch.body) as Map;
      expect((body['data'] as Map)['attributes'], {'progress': 4});
    });

    test('step to the total completes the entry', () async {
      final fake = library();
      final a = adapter(fake);
      final page = await a.fetch(category: 'anime', status: null, offset: 0, limit: 200);
      final almost = page.entries.first.copyWith(progress: 11);
      final done = await a.step(almost, 1);
      expect(done.status, ListEntryStatus.completed);
      final attrs = ((jsonDecode(fake.requests.last.body) as Map)['data'] as Map)['attributes'] as Map;
      expect(attrs['status'], 'completed');
      expect(attrs['progress'], 12);
    });

    test('a failed fetch error is a session error only for KitsuSessionExpired', () {
      final a = adapter(library());
      expect(a.isSessionExpired(const KitsuSessionExpired()), isTrue);
      expect(a.isSessionExpired(const KitsuHttpError(500)), isFalse);
    });

    testWidgets('the editor result updates the entry', (tester) async {
      final fake = library();
      final a = adapter(fake, editor: (context, entry, initial) async {
        expect(initial.status, 'watching');
        expect(initial.entryId, '900');
        return const SyncEntry(
            status: 'completed', score: 9.5, progress: 12, finishDate: '2024-06-01', entryId: '900');
      });
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          context = c;
          return const SizedBox();
        }),
      ));
      final page = await tester.runAsync(
          () => a.fetch(category: 'anime', status: null, offset: 0, limit: 200));
      final result = await tester.runAsync(() => a.edit(context, page!.entries.first));
      expect(result, isA<ListEditUpdated>());
      final entry = (result! as ListEditUpdated).entry;
      expect(entry.status, ListEntryStatus.completed);
      expect(entry.score, 10);
      expect(entry.progress, 12);
      expect(entry.listFinishDate, '2024-06-01');
    });
  });
}
