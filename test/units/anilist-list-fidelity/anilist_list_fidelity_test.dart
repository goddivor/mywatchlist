import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_bulk_edit.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_entry_editor.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_sections.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';

import '../../helpers/no_network.dart';

// Fakes only: every AniList call below is answered in memory, nothing reaches AniList and no
// account is written.

Map<String, dynamic> _media(int id, {String type = 'ANIME', String format = 'TV'}) => {
      'id': id,
      'idMal': id,
      'type': type,
      'format': format,
      'status': 'FINISHED',
      'episodes': 12,
      'chapters': 40,
      'volumes': 4,
      'genres': ['Drama'],
      'weightedScore': 80,
      'popularity': 10,
      'title': {'romaji': 'Title $id'},
      'coverImage': {'large': 'https://x/$id.jpg'},
    };

Map<String, dynamic> _row(
  int id,
  String status, {
  int raw = 75,
  int progress = 3,
  int repeat = 0,
  int priority = 0,
  bool private = false,
  bool hidden = false,
  Object? customLists,
  Object? advanced,
  String notes = '',
  String format = 'TV',
  int createdAt = 1700000000,
}) =>
    {
      'id': 900 + id,
      'status': status,
      'scoreRaw': raw,
      'score': raw / 10,
      'progress': progress,
      'progressVolumes': 0,
      'repeat': repeat,
      'priority': priority,
      'private': private,
      'hiddenFromStatusLists': hidden,
      'notes': notes,
      'customLists': customLists,
      'advancedScores': advanced,
      'updatedAt': 1700000100 + id,
      'createdAt': createdAt + id,
      'startedAt': {'year': 2024, 'month': 1, 'day': 2},
      'completedAt': {'year': null, 'month': null, 'day': null},
      'media': _media(id, format: format),
    };

const _options = {
  'scoreFormat': 'POINT_10_DECIMAL',
  'rowOrder': 'score',
  'animeList': {
    'sectionOrder': ['Completed', 'Watching', 'Favourites', 'Rewatching', 'Planning'],
    'splitCompletedSectionByFormat': false,
    'customLists': ['Favourites', 'Later'],
    'advancedScoring': ['Story', 'Visuals'],
    'advancedScoringEnabled': true,
  },
  'mangaList': {'sectionOrder': <String>[]},
};

http.Response _ok(Object data) => http.Response(jsonEncode({'data': data}), 200);

/// A client answering the list read with [rows]; writes are recorded in [writes] and answer
/// [onWrite].
AnilistGraphql _gql(
  List<Map<String, dynamic>> rows, {
  List<Map<String, dynamic>>? writes,
  Map<String, dynamic> Function(Map<String, dynamic> body)? onWrite,
  Map<String, dynamic> options = _options,
}) =>
    AnilistGraphql(
      sender: (body, {required auth}) async => _ok({
        'MediaListCollection': {
          'hasNextChunk': false,
          'user': {'mediaListOptions': options},
          'lists': [
            {'entries': rows},
          ],
        },
      }),
      mutationSender: (body, {required auth}) async {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        writes?.add(decoded);
        return _ok(onWrite?.call(decoded) ?? const {});
      },
    );

AnilistListService _service(AnilistGraphql gql) =>
    AnilistListService(client: gql, owner: () => 'me', titleLang: () => 'ro');

class _FakeSync implements TrackerEntryClient {
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

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    }),
  ));
  return context;
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('AnilistScoreFormat', () {
    test('reads and writes every format on the raw 0-100 scale', () {
      expect(AnilistScoreFormat.point100.fromRaw(73), 73);
      expect(AnilistScoreFormat.point100.toRaw(73), 73);
      expect(AnilistScoreFormat.point10Decimal.fromRaw(75), 7.5);
      expect(AnilistScoreFormat.point10Decimal.toRaw(7.5), 75);
      expect(AnilistScoreFormat.point10Decimal.format(75), '7.5');
      expect(AnilistScoreFormat.point10Decimal.format(80), '8');
      expect(AnilistScoreFormat.point10.fromRaw(73), 7);
      expect(AnilistScoreFormat.point10.toRaw(7), 70);
      expect(AnilistScoreFormat.point5.fromRaw(60), 3);
      expect(AnilistScoreFormat.point5.toRaw(3), 60);
      expect(AnilistScoreFormat.point5.fromRaw(100), 5);
      expect(AnilistScoreFormat.point3.fromRaw(35), 1);
      expect(AnilistScoreFormat.point3.fromRaw(60), 2);
      expect(AnilistScoreFormat.point3.fromRaw(85), 3);
      expect(AnilistScoreFormat.point3.toRaw(2), 60);
      for (final f in AnilistScoreFormat.values) {
        expect(f.fromRaw(0), 0, reason: '$f: 0 is not scored');
        expect(f.toRaw(0), 0);
      }
      expect(AnilistScoreFormat.parse('POINT_3'), AnilistScoreFormat.point3);
      expect(AnilistScoreFormat.parse(null), AnilistScoreFormat.point10);
    });
  });

  group('list read', () {
    test('keeps the exact score, Rewatching and every AniList field', () async {
      final service = _service(_gql([
        _row(1, 'REPEATING', raw: 73, repeat: 2, priority: 5, private: true, notes: 'hi',
            customLists: [
              {'name': 'Favourites', 'enabled': true},
              {'name': 'Later', 'enabled': false},
            ],
            advanced: {'Story': 8.5, 'Visuals': 7}),
        _row(2, 'COMPLETED', customLists: {'Later': true}),
      ]));
      final rows = await service.all('anime');
      final one = rows.firstWhere((e) => e.id == 1);
      expect(one.status, ListEntryStatus.current);
      expect(one.repeating, isTrue);
      expect(one.score, 7);
      expect(one.priority, 2);
      final d = service.detailOf('anime', 1)!;
      expect(d.status, 'REPEATING');
      expect(d.scoreRaw, 73);
      expect(d.repeat, 2);
      expect(d.priority, 5);
      expect(d.private, isTrue);
      expect(d.notes, 'hi');
      expect(d.customLists, ['Favourites']);
      expect(d.advancedScores, {'Story': 8.5, 'Visuals': 7.0});
      expect(d.entryId, 901);
      expect(d.startedAt, '2024-01-02');
      expect(service.detailOf('anime', 2)!.customLists, ['Later']);

      final o = service.optionsOf('anime')!;
      expect(o.scoreFormat, AnilistScoreFormat.point10Decimal);
      expect(o.customLists, ['Favourites', 'Later']);
      expect(o.showsAdvanced, isTrue);
    });

    test('an answer without scoreRaw reads the 0-10 score', () {
      final d = AnilistListEntry.fromJson({'id': 1, 'score': 8.5}, category: 'anime', mediaId: 4);
      expect(d.scoreRaw, 85);
    });
  });

  group('sections', () {
    AnilistListEntry d(int id, String status,
            {bool hidden = false, List<String> lists = const [], String format = 'TV'}) =>
        AnilistListEntry(
          entryId: id,
          mediaId: id,
          category: 'anime',
          status: status,
          hiddenFromStatusLists: hidden,
          customLists: lists,
          format: format,
        );

    test('follow the account order, custom lists included, Rewatching only when used', () {
      final options = AnilistListOptions.fromJson(_options, isAnime: true);
      final keys = anilistSections(options, [d(1, 'CURRENT')], isAnime: true)
          .map((s) => s.key)
          .toList();
      expect(keys, [
        'all',
        'status:COMPLETED',
        'status:CURRENT',
        'custom:Favourites',
        'status:PLANNING',
        'status:PAUSED',
        'status:DROPPED',
        'custom:Later',
      ]);
      final withRewatch =
          anilistSections(options, [d(1, 'REPEATING')], isAnime: true).map((s) => s.key);
      expect(withRewatch, contains('status:REPEATING'));
    });

    test('split Completed by format and keep hidden entries out of status lists', () {
      const options = AnilistListOptions(splitCompletedSectionByFormat: true);
      final details = [
        d(1, 'COMPLETED'),
        d(2, 'COMPLETED', format: 'MOVIE'),
        d(3, 'COMPLETED', format: 'TV_SHORT', hidden: true, lists: ['X']),
      ];
      final sections = anilistSections(options, details, isAnime: true);
      final keys = sections.map((s) => s.key).toList();
      expect(keys, containsAllInOrder(['status:COMPLETED:TV', 'status:COMPLETED:MOVIE']));
      expect(keys, isNot(contains('status:COMPLETED:TV_SHORT')));
      final counts = anilistSectionCounts(sections, details);
      expect(counts[AnilistSection.all], 3);
      expect(counts[const AnilistSection.status('COMPLETED', format: 'MOVIE')], 1);
      expect(const AnilistSection.custom('X').contains(details[2]), isTrue);
    });
  });

  group('writes', () {
    test('save sends only the set fields, through mutate', () async {
      final writes = <Map<String, dynamic>>[];
      final write = AnilistListWrite(
        client: _gql(const [], writes: writes, onWrite: (_) => {
              'SaveMediaListEntry': {'id': 9, 'status': 'PAUSED', 'scoreRaw': 40},
            }),
      );
      final saved = await write.save(const AnilistEntryInput(
        mediaId: 5,
        status: 'PAUSED',
        scoreRaw: 40,
        private: true,
        customLists: ['Later'],
        advancedScores: [7.5, 8],
        startedAt: '2024-03',
        completedAt: '',
      ));
      expect(saved['id'], 9);
      final sent = writes.single;
      final vars = sent['variables'] as Map;
      expect(vars.keys.toSet(), {
        'mediaId', 'status', 'scoreRaw', 'private', 'customLists', 'advancedScores',
        'startedAt', 'completedAt',
      });
      expect(vars['startedAt'], {'year': 2024, 'month': 3, 'day': null});
      expect(vars['completedAt'], {'year': null, 'month': null, 'day': null});
      final query = sent['query'] as String;
      expect(query, startsWith('mutation'));
      expect(query, contains(r'$customLists: [String]'));
      expect(query, isNot(contains('progress:')));
    });

    test('delete and bulk update go through mutate', () async {
      final writes = <Map<String, dynamic>>[];
      final write = AnilistListWrite(
        client: _gql(const [], writes: writes, onWrite: (body) {
          final q = body['query'] as String;
          if (q.contains('DeleteMediaListEntry')) {
            return {
              'DeleteMediaListEntry': {'deleted': true}
            };
          }
          return {
            'UpdateMediaListEntries': [
              {'id': 901, 'status': 'DROPPED'},
            ]
          };
        }),
      );
      expect(await write.delete(901), isTrue);
      final rows = await write.updateMany([901], const AnilistBulkInput(status: 'DROPPED'));
      expect(rows.single['status'], 'DROPPED');
      expect((writes.last['variables'] as Map)['ids'], [901]);
      expect(writes.last['query'], contains('UpdateMediaListEntries(status: \$status, ids: \$ids)'));
    });

    test('the sync client writes through the non-replayed sender', () async {
      final reads = <String>[];
      final writes = <String>[];
      final client = AnilistEntryClient(
        graphql: AnilistGraphql(
          sender: (body, {required auth}) async {
            reads.add(body);
            return _ok({
              'Media': {
                'mediaListEntry': {'id': 3, 'status': 'CURRENT', 'score': 7.5}
              }
            });
          },
          mutationSender: (body, {required auth}) async {
            writes.add(body);
            return _ok({
              'SaveMediaListEntry': {'id': 3, 'status': 'COMPLETED', 'score': 7.5}
            });
          },
        ),
      );
      await client.read('1', isAnime: true);
      await client.write('1', const SyncEntry(status: 'completed'), isAnime: true);
      expect(reads, hasLength(1));
      expect(writes.single, contains('SaveMediaListEntry'));
    });

    test('a 429 on a write is a SyncRequestFailed, not a crash', () async {
      final client = AnilistEntryClient(
        graphql: AnilistGraphql(
          sender: (_, {required auth}) async => http.Response('{}', 200),
          mutationSender: (_, {required auth}) async =>
              http.Response('{}', 429, headers: {'retry-after': '5'}),
        ),
      );
      expect(() => client.write('1', const SyncEntry(progress: 2), isAnime: true),
          throwsA(isA<Exception>()));
    });
  });

  group('adapter', () {
    test('+1 never sends the score and keeps Rewatching', () async {
      final sync = _FakeSync();
      final service = _service(_gql([
        _row(1, 'CURRENT', raw: 75, progress: 3),
        _row(2, 'REPEATING', raw: 73, progress: 5, repeat: 1),
      ]));
      final adapter = AnilistUserListAdapter(
        service: service,
        sync: TrackerSyncService(clients: {AccountType.anilist: sync}),
        clock: () => DateTime(2026, 10, 29),
      );
      final rows = await service.all('anime');
      final watching = rows.firstWhere((e) => e.id == 1);
      await adapter.step(watching, 1);
      expect(sync.writes.last.score, isNull);
      expect(sync.writes.last.progress, 4);

      final rewatch = rows.firstWhere((e) => e.id == 2);
      final next = await adapter.step(rewatch, 1);
      expect(sync.writes.last.status, isNull, reason: 'no CURRENT over REPEATING');
      expect(next.repeating, isTrue);
      expect(service.detailOf('anime', 2)!.status, 'REPEATING');
      expect(service.detailOf('anime', 2)!.scoreRaw, 73);

      final done = await adapter.step(next.copyWith(progress: 11), 1);
      expect(sync.writes.last.status, 'completed');
      expect(sync.writes.last.repeat, 2);
      expect(done.status, ListEntryStatus.completed);
      expect(done.repeating, isFalse);
    });

    testWidgets('the AniList editor result updates the row and the kept fields',
        (tester) async {
      final service = _service(_gql([_row(1, 'CURRENT')]));
      final adapter = AnilistUserListAdapter(
        service: service,
        anilistEditor: (context, entry, detail) async => AnilistEditSaved(detail!.merge({
          'id': 901,
          'status': 'REPEATING',
          'scoreRaw': 92,
          'progress': 1,
          'private': true,
          'customLists': [
            {'name': 'Later', 'enabled': true}
          ],
        })),
      );
      final context = await _context(tester);
      final rows = (await tester.runAsync(() => service.all('anime')))!;
      final result = await tester.runAsync(() => adapter.edit(context, rows.single));
      expect(result, isA<ListEditUpdated>());
      final saved = (result as ListEditUpdated).entry;
      expect(saved.repeating, isTrue);
      expect(saved.score, 9);
      expect(saved.listFinishDate, isNull);
      final kept = service.detailOf('anime', 1)!;
      expect(kept.private, isTrue);
      expect(kept.customLists, ['Later']);
      expect(kept.format, 'TV', reason: 'the media format survives a write');
    });

    test('AniList sorts read the AniList fields', () async {
      final service = _service(_gql([
        _row(1, 'COMPLETED', createdAt: 100, repeat: 3),
        _row(2, 'COMPLETED', createdAt: 300),
        _row(3, 'COMPLETED', createdAt: 200, repeat: 1),
      ]));
      final adapter = AnilistUserListAdapter(service: service);
      final rows = await service.all('anime');
      final added = adapter.sortByAnilist(
          rows, 'anime', AnilistSortKeys.added, SortDirection.descending);
      expect(added.map((e) => e.id), [2, 3, 1]);
      final repeat = adapter.sortByAnilist(
          rows, 'anime', AnilistSortKeys.repeat, SortDirection.descending);
      expect(repeat.map((e) => e.id), [1, 3, 2], reason: 'no rewatch goes last');
      expect(adapter.sortOptions('anime').map((o) => o.key),
          containsAll([AnilistSortKeys.added, AnilistSortKeys.exactScore]));
    });

    test('bulk edit sends one request and applies the answer', () async {
      final writes = <Map<String, dynamic>>[];
      final gql = _gql([_row(1, 'CURRENT'), _row(2, 'PLANNING')], writes: writes,
          onWrite: (body) => {
                'UpdateMediaListEntries': [
                  for (final id in (body['variables'] as Map)['ids'] as List)
                    {'id': id, 'status': 'DROPPED', 'private': true},
                ]
              });
      final service = _service(gql);
      final adapter = AnilistUserListAdapter(service: service, write: AnilistListWrite(client: gql));
      final rows = await service.all('anime');
      final saved = await applyAnilistBulkEdit(adapter,
          category: 'anime',
          entries: rows,
          input: const AnilistBulkInput(status: 'DROPPED', private: true));
      expect(writes, hasLength(1));
      expect(saved.map((e) => e.status).toSet(), {ListEntryStatus.dropped});
      expect(service.detailOf('anime', 2)!.private, isTrue);
    });
  });

  group('editor', () {
    testWidgets('saves all the fields in one SaveMediaListEntry', (tester) async {
      final writes = <Map<String, dynamic>>[];
      final gql = _gql(const [], writes: writes, onWrite: (_) => {
            'SaveMediaListEntry': {'id': 901, 'status': 'CURRENT', 'scoreRaw': 75}
          });
      const entry = ListEntryView(
          id: 1, category: 'anime', title: 'One', status: ListEntryStatus.current, total: 12);
      final detail = AnilistListEntry.fromJson(
          _row(1, 'CURRENT', notes: 'n', customLists: {'Later': true}, advanced: {'Story': 8}),
          category: 'anime',
          mediaId: 1);
      AnilistEditResult? popped;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => popped = await showAnilistEntryEditor(
                  context,
                  entry: entry,
                  detail: detail,
                  options: AnilistListOptions.fromJson(_options, isAnime: true),
                  write: AnilistListWrite(client: gql),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('One'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text(S.current.Edit_Save));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(popped, isA<AnilistEditSaved>());
      final vars = writes.single['variables'] as Map;
      expect(vars.keys.toSet(), {
        'mediaId', 'status', 'scoreRaw', 'progress', 'repeat', 'priority', 'private', 'notes',
        'hiddenFromStatusLists', 'customLists', 'advancedScores', 'startedAt', 'completedAt',
      });
      expect(vars['scoreRaw'], 75);
      expect(vars['notes'], 'n');
      expect(vars['customLists'], ['Later']);
      expect(vars['advancedScores'], [8.0, 0.0]);
    });
  });
}
