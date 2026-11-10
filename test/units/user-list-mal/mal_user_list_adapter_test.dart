import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';

import 'fixtures.dart';

class _FakeEntryService implements ListEntryService {
  final patches = <EntryPatch>[];

  @override
  bool get canEdit => true;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) => throw UnimplementedError();

  @override
  Future<EntryUpdate> update(int id,
      {required bool isAnime, required EntryPatch patch, ListEntry? previous}) async {
    patches.add(patch);
    final p = previous!;
    final entry = ListEntry(
      status: patch.status ?? p.status,
      score: p.score,
      progress: patch.progress ?? p.progress,
      startDate: patch.startDate ?? p.startDate,
      finishDate: patch.finishDate ?? p.finishDate,
    );
    return EntryUpdate(entry, entry);
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) async {}
}

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
    await initializeDateFormatting();
  });

  test('a MAL page becomes list entries with every field the cards use', () {
    final page = parseMalListPage({
      'data': [
        malAnimeItem(id: 5114, title: 'Hagane', en: 'Fullmetal', status: 'completed', score: 10, watched: 64, episodes: 64, priority: 2),
        {'node': {'title': 'no id'}},
      ],
      'paging': {'next': 'https://api.myanimelist.net/v2/users/@me/animelist?offset=300'},
    }, category: 'anime', titleLang: 'en');
    expect(page.hasMore, isTrue);
    expect(page.entries, hasLength(1));
    final e = page.entries.single;
    expect(e.id, 5114);
    expect(e.title, 'Fullmetal', reason: 'preferred English title');
    expect(e.otherTitles, containsAll(['Hagane', 'ジャ5114', 'Syn 5114']));
    expect(e.status, ListEntryStatus.completed);
    expect(e.score, 10);
    expect(e.progress, 64);
    expect(e.total, 64);
    expect(e.priority, 2);
    expect(e.genres, ['Action']);
    expect(e.releaseState, ReleaseState.finished);
    expect(e.broadcast, const BroadcastSlot(DateTime.saturday, 23 * 60 + 30));
    expect(e.updatedAt, DateTime.utc(2026, 10, 1, 10));
    expect(e.tags, ['fav']);
    expect(e.largeImageUrl, endsWith('5114l.jpg'));
  });

  test('manga pages read chapters, volumes and rereading', () {
    final page = parseMalListPage({
      'data': [
        {
          'node': {'id': 2, 'title': 'Berserk', 'num_chapters': 0, 'num_volumes': 41, 'status': 'on_hiatus'},
          'list_status': {
            'status': 'reading',
            'num_chapters_read': 300,
            'num_volumes_read': 30,
            'is_rereading': true,
          },
        },
      ],
      'paging': {},
    }, category: 'manga', titleLang: 'ro');
    final e = page.entries.single;
    expect(page.hasMore, isFalse);
    expect(e.isAnime, isFalse);
    expect(e.progress, 300);
    expect(e.progressVolumes, 30);
    expect(e.totalVolumes, 41);
    expect(e.repeating, isTrue);
    expect(e.releaseState, ReleaseState.onHiatus);
  });

  test('page URL asks the status, sort, page and list fields', () {
    final url = MalUserListAdapter.pageUrl(
        category: 'manga', status: ListEntryStatus.planned, offset: 300, limit: 300, sort: 'list_score');
    final uri = Uri.parse(url);
    expect(uri.path, '/v2/users/@me/mangalist');
    expect(uri.queryParameters['status'], 'plan_to_read');
    expect(uri.queryParameters['sort'], 'list_score');
    expect(uri.queryParameters['offset'], '300');
    expect(uri.queryParameters['fields'], contains('list_status{status,score,num_chapters_read'));
  });

  test('only the orders MAL knows are asked from MAL', () {
    final a = MalUserListAdapter(get: (_) => throw UnimplementedError());
    expect(a.apiSort('anime', ListSortKeys.updated, SortDirection.descending), 'list_updated_at');
    expect(a.apiSort('anime', ListSortKeys.updated, SortDirection.ascending), isNull);
    expect(a.apiSort('manga', ListSortKeys.score, SortDirection.descending), 'list_score');
    expect(a.apiSort('manga', ListSortKeys.title, SortDirection.ascending), 'manga_title');
    expect(a.apiSort('anime', ListSortKeys.mean, SortDirection.descending), isNull);
  });

  test('fetch pages through the given client and reports MAL errors', () async {
    final urls = <String>[];
    var status = 200;
    final a = MalUserListAdapter(get: (url) async {
      urls.add(url);
      return _json({
        'data': [malAnimeItem(id: 1), malAnimeItem(id: 2)],
        'paging': {},
      }, status);
    });
    final page = await a.fetch(category: 'anime', status: ListEntryStatus.current, offset: 0, limit: 5000);
    expect(page.entries.map((e) => e.id), [1, 2]);
    expect(Uri.parse(urls.single).queryParameters['limit'], '1000', reason: 'MAL caps lists at 1000');
    status = 500;
    await expectLater(a.fetch(category: 'anime', status: null, offset: 0, limit: 10),
        throwsA(isA<MalListError>()));
  });

  test('status counts: MAL statistics for anime, Jikan for manga', () async {
    final a = MalUserListAdapter(
      owner: () => 'Tester',
      get: (url) async => _json({
            'anime_statistics': {
              'num_items_watching': 3,
              'num_items_completed': 40,
              'num_items_on_hold': 1,
              'num_items_dropped': 2,
              'num_items_plan_to_watch': 9,
            }
          }),
      jikanGet: (uri) async {
        expect(uri.path, '/v4/users/Tester/statistics');
        return _json({
          'data': {
            'manga': {'reading': 4, 'completed': 5, 'on_hold': 0, 'dropped': 1, 'plan_to_read': 7}
          }
        });
      },
    );
    final anime = await a.statusCounts('anime');
    expect(anime![ListEntryStatus.completed], 40);
    expect(anime[ListEntryStatus.planned], 9);
    final manga = await a.statusCounts('manga');
    expect(manga![ListEntryStatus.current], 4);
    expect(manga[ListEntryStatus.planned], 7);
  });

  test('+1 on the last episode completes the entry with a finish date', () async {
    final service = _FakeEntryService();
    final a = MalUserListAdapter(
      get: (_) => throw UnimplementedError(),
      entryService: service,
      clock: () => DateTime(2026, 10, 27, 15),
    );
    final saved = await a.step(entry(1, progress: 11, total: 12), 1);
    expect(service.patches.single.progress, 12);
    expect(service.patches.single.status, 'completed');
    expect(saved.status, ListEntryStatus.completed);
    expect(saved.progress, 12);
    expect(saved.updatedAt, DateTime(2026, 10, 27, 15));
  });

  test('+1 past the known total is refused before any write', () async {
    final service = _FakeEntryService();
    final a = MalUserListAdapter(get: (_) => throw UnimplementedError(), entryService: service);
    await expectLater(a.step(entry(1, progress: 12, total: 12), 1), throwsArgumentError);
    expect(service.patches, isEmpty);
  });
}
