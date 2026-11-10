import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_edit_sheet.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;

import 'fakes.dart';

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
    await initializeDateFormatting();
  });

  FakeSimkl server() => FakeSimkl((r) {
        if (r.method == 'GET' && r.url.path == '/sync/all-items/anime') {
          return FakeSimkl.json({
            'anime': [
              simklItem(id: 1, status: 'watching', lastWatched: '2026-10-01T00:00:00Z'),
              simklItem(id: 2, status: 'watching', lastWatched: '2026-10-05T00:00:00Z'),
              simklItem(id: 3, status: 'completed'),
              simklItem(id: 4, status: 'plantowatch'),
            ],
          });
        }
        return FakeSimkl.json({});
      });

  group('SimklUserListAdapter', () {
    late FakeSimkl fake;
    late SimklUserListAdapter adapter;

    setUp(() {
      fake = server();
      adapter = SimklUserListAdapter(
        service: SimklListService(client: fake.client, owner: () => 'me'),
        owner: () => 'me',
      );
    });

    test('is the Simkl tracker with no server sort', () {
      expect(adapter.tracker, AccountType.simkl);
      expect(adapter.owner, 'me');
      expect(adapter.apiSort('anime', ListSortKeys.updated, SortDirection.descending), isNull);
      final keys = adapter.sortOptions('anime').map((o) => o.key);
      expect(keys.first, ListSortKeys.updated);
      expect(keys, isNot(contains(ListSortKeys.priority)));
      expect(keys, isNot(contains(ListSortKeys.popularity)));
    });

    test('a status tab holds its entries, most recently watched first', () async {
      final page = await adapter.fetch(
          category: 'anime', status: ListEntryStatus.current, offset: 0, limit: adapter.maxPageSize);
      expect(page.entries.map((e) => e.id), [2, 1]);
      expect(page.hasMore, isFalse);
      final all = await adapter.fetch(category: 'anime', status: null, offset: 0, limit: 2);
      expect(all.entries, hasLength(2));
      expect(all.hasMore, isTrue);
    });

    test('there is no manga: that category is empty and asks for nothing', () async {
      final page = await adapter.fetch(category: 'manga', status: null, offset: 0, limit: 100);
      expect(page.entries, isEmpty);
      final counts = await adapter.statusCounts('manga');
      expect(counts!.values.every((c) => c == 0), isTrue);
      expect(fake.seen, isEmpty);
    });

    test('status counts come from the same fetch', () async {
      final counts = await adapter.statusCounts('anime');
      expect(counts![ListEntryStatus.current], 2);
      expect(counts[ListEntryStatus.planned], 1);
      expect(fake.seen.where((r) => r.url.path == '/sync/all-items/anime'), hasLength(1));
    });

    test('a failed list reports no counts, and a dead session is recognised', () async {
      final broken = SimklUserListAdapter(
        service: SimklListService(client: FakeSimkl((_) => FakeSimkl.json({}, 500)).client),
      );
      expect(await broken.statusCounts('anime'), isNull);
      expect(broken.isSessionExpired(const SimklSessionExpired()), isTrue);
      expect(broken.isSessionExpired(const SimklHttpError(500)), isFalse);
    });

    test('quick steps work on titles that are on the list only', () async {
      const onList = ListEntryView(id: 1, category: 'anime', title: 'T', status: ListEntryStatus.current, total: 12);
      expect(adapter.canStep(onList), isTrue);
      expect(adapter.canStep(const ListEntryView(id: 1, category: 'anime', title: 'T')), isFalse);
      final stepped = await adapter.step(onList, 1);
      expect(stepped.progress, 1);
      expect(fake.seen.last.url.path, '/sync/history');
    });
  });

  group('SimklEditSheet', () {
    Future<ListEditResult?> open(WidgetTester tester, FakeSimkl fake, ListEntryView entry) async {
      ListEditResult? result;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showSimklEditSheet(context, entry,
                  service: SimklListService(client: fake.client, owner: () => 'me')),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    const entry = ListEntryView(
        id: 9, category: 'anime', title: 'My show', status: ListEntryStatus.current, progress: 3, total: 12);

    testWidgets('Save stays off until something changes, then sends the progress', (tester) async {
      final fake = FakeSimkl((_) => FakeSimkl.json({}));
      await open(tester, fake, entry);
      FilledButton save() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
      expect(find.text('My show'), findsOneWidget);
      expect(find.text('3 / 12'), findsOneWidget);
      expect(save().onPressed, isNull);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(find.text('4 / 12'), findsOneWidget);
      expect(save().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(fake.seen.single.url.path, '/sync/history');
      expect(find.text('My show'), findsNothing, reason: 'the sheet closed');
    });

    testWidgets('a failed save stays open with a message', (tester) async {
      final fake = FakeSimkl((_) => FakeSimkl.json({}, 500));
      await open(tester, fake, entry);
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't save"), findsOneWidget);
      expect(find.text('My show'), findsOneWidget);
    });

    testWidgets('Remove takes the title off the list', (tester) async {
      final fake = FakeSimkl((_) => FakeSimkl.json({}));
      await open(tester, fake, entry);
      await tester.tap(find.text('Remove from list'));
      await tester.pumpAndSettle();
      expect(fake.seen.single.url.path, '/sync/remove-from-list');
    });

    testWidgets('a title not on the list has no Remove and Save adds it', (tester) async {
      final fake = FakeSimkl((_) => FakeSimkl.json({}));
      await open(tester, fake, const ListEntryView(id: 5, category: 'anime', title: 'New one'));
      expect(find.text('Remove from list'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(fake.seen.single.url.path, '/sync/add-to-list');
      expect((fake.seen.single.body as Map)['anime'][0]['to'], 'plantowatch');
    });
  });
}
