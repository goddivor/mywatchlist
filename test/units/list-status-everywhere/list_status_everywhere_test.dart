import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/list_cache/list_status_sync.dart';
import 'package:mywatchlist/widgets/user/list/list_status_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _page(List<(int, String, int)> rows, {String? next, bool manga = false}) => jsonEncode({
      'data': [
        for (final (id, status, score) in rows)
          {
            'node': {'id': id, 'title': 'T$id'},
            'list_status': {
              'status': status,
              'score': score,
              manga ? 'num_chapters_read' : 'num_episodes_watched': 3,
            },
          },
      ],
      'paging': {if (next != null) 'next': next},
    });

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ListStatusCache.instance.resetForTest();
  });

  test('a list page: id to status, score and progress, and the next page', () {
    final page = parseListStatusPage(
        _page([(21, 'watching', 9), (5114, 'completed', 0)], next: 'https://next'), 'anime');
    expect(page.next, 'https://next');
    expect(page.values[21], const CachedListStatus(status: 'watching', score: 9, progress: 3));
    expect(page.values[5114]!.status, 'completed');
  });

  group('sync', () {
    late List<String> asked;
    late String owner;
    var now = DateTime(2026, 11, 20, 8);

    ListStatusSync build() => ListStatusSync(
          signedIn: () => true,
          owner: () => owner,
          clock: () => now,
          get: (url) async {
            asked.add(url);
            if (url.contains('mangalist')) return _page([(2, 'reading', 10)], manga: true);
            if (url == 'page2') return _page([(30, 'dropped', 2)]);
            return _page([(21, 'watching', 9)], next: 'page2');
          },
        );

    setUp(() {
      asked = [];
      owner = 'goddivor';
      now = DateTime(2026, 11, 20, 8);
    });

    test('reads every page of both lists into the cache', () async {
      await build().syncIfDue();
      final cache = ListStatusCache.instance;
      expect(cache.entryOf(21)!.score, 9);
      expect(cache.entryOf(30)!.status, 'dropped');
      expect(cache.entryOf(2, category: 'manga')!.status, 'reading');
      expect(asked.where((u) => u.contains('@me/animelist')), hasLength(1));
      expect(asked, contains('page2'));
    });

    test('at most every 12 hours for the same account, at once for another', () async {
      final sync = build();
      await sync.syncIfDue();
      final first = asked.length;
      now = now.add(const Duration(hours: 1));
      await sync.syncIfDue();
      expect(asked.length, first, reason: 'fresh');
      owner = 'someone_else';
      await sync.syncIfDue();
      expect(asked.length, greaterThan(first), reason: 'another account is read at once');
    });

    test('an entry removed on another device leaves the cache', () async {
      ListStatusCache.instance.put(999, const CachedListStatus(status: 'watching'));
      await build().syncIfDue(force: true);
      expect(ListStatusCache.instance.entryOf(999), isNull);
    });

    test('signed out: nothing is asked', () async {
      await ListStatusSync(signedIn: () => false, get: (u) async {
        asked.add(u);
        return null;
      }).syncIfDue();
      expect(asked, isEmpty);
    });
  });

  group('pill', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(body: child),
        ));

    testWidgets('not in the list: nothing; in it: the status and the score', (tester) async {
      await pump(tester, const ListStatusPill(id: 21, category: 'anime'));
      expect(find.byType(Container), findsNothing);
      ListStatusCache.instance.put(21, const CachedListStatus(status: 'completed', score: 8));
      await tester.pump();
      expect(find.text('CMP'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // the cache's delayed save
    });

    testWidgets('a result row shows the status of the user\'s list', (tester) async {
      ListStatusCache.instance.put(5114, const CachedListStatus(status: 'on_hold'));
      await pump(
        tester,
        MediaTile(
          item: Anime(id: 5114, title: 'FMA:B', imageUrl: '', score: 9.1, members: 3000000),
          category: 'anime',
        ),
      );
      expect(find.byType(ListStatusPill), findsOneWidget);
      expect(find.text('OH'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1)); // the cache's delayed save
    });
  });
}
