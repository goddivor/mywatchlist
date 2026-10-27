import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const _byUpdate = ListViewSettings(sortKey: ListSortKeys.updated);

List<ListEntryView> _many(int n, {ListEntryStatus status = ListEntryStatus.current}) => [
      for (var i = 1; i <= n; i++)
        entry(i, title: 'T$i', status: status, updatedAt: DateTime(2026, 1, 1).add(Duration(days: n - i))),
    ];

void main() {
  setUpAll(() => S.load(const Locale('en')));
  late ListStatusCache cache;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = ListStatusCache(saveDelay: const Duration(days: 1));
    await cache.ensureLoaded();
  });
  tearDown(() => cache.dispose());

  UserListTabController controller(FakeListAdapter adapter,
          {ListEntryStatus? status, ListViewSettings settings = _byUpdate, int pageSize = 3}) =>
      UserListTabController(
        adapter: adapter,
        category: 'anime',
        status: status,
        settings: settings,
        pageSize: pageSize,
        cache: cache,
      );

  test('an order MAL knows is loaded page by page', () async {
    final adapter = FakeListAdapter(_many(7));
    final c = controller(adapter);
    await c.refresh();
    expect(c.isPaged, isTrue);
    expect(c.entries.map((e) => e.id), [1, 2, 3]);
    expect(c.hasMore, isTrue);
    expect(c.totalCount, isNull);
    await c.loadMore();
    await c.loadMore();
    expect(c.entries.map((e) => e.id), [1, 2, 3, 4, 5, 6, 7]);
    expect(c.hasMore, isFalse);
    expect(c.totalCount, 7);
    expect(adapter.calls.map((x) => x.offset), [0, 3, 6]);
    expect(adapter.calls.every((x) => x.sort == 'list_updated_at'), isTrue);
    c.dispose();
  });

  test('a device sort loads the whole list then sorts it', () async {
    final adapter = FakeListAdapter(_many(5), pageLimit: 2);
    final c = controller(adapter,
        settings: const ListViewSettings(sortKey: ListSortKeys.title, direction: SortDirection.descending));
    await c.refresh();
    expect(c.isPaged, isFalse);
    expect(c.hasMore, isFalse);
    expect(c.entries.map((e) => e.title), ['T5', 'T4', 'T3', 'T2', 'T1']);
    expect(adapter.calls.map((x) => x.limit).toSet(), {2});
    c.dispose();
  });

  test('a filter on a partly loaded list reloads it whole, a hidden tab waits', () async {
    final adapter = FakeListAdapter(_many(5));
    final c = controller(adapter);
    await c.refresh();
    expect(c.hasMore, isTrue);
    final filtered = _byUpdate.copyWith(filter: ListFilter.none.toggle(ListFacetKeys.media, 'tv'));
    c.updateSettings(filtered);
    expect(adapter.calls, hasLength(1), reason: 'hidden tab: reload on next activate');
    c.activate();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.isPaged, isFalse);
    expect(c.entries, hasLength(5));
    c.dispose();
  });

  test('a search on a fully loaded list needs no request', () async {
    final adapter = FakeListAdapter(_many(3));
    final c = controller(adapter, pageSize: 10);
    await c.refresh();
    c.updateQuery('t2', visible: true);
    expect(c.entries.map((e) => e.id), [2]);
    expect(adapter.calls, hasLength(1));
    c.dispose();
  });

  test('an edited entry moves out of its old status tab and into the new one', () async {
    final adapter = FakeListAdapter([
      ..._many(2),
      entry(10, title: 'Done', status: ListEntryStatus.completed),
    ]);
    final watching = controller(adapter, status: ListEntryStatus.current, pageSize: 10);
    final completed = controller(adapter, status: ListEntryStatus.completed, pageSize: 10);
    final all = controller(adapter, pageSize: 10);
    await Future.wait([watching.refresh(), completed.refresh(), all.refresh()]);
    final moved = watching.entries.first.copyWith(status: ListEntryStatus.completed, progress: 12);
    for (final c in [watching, completed, all]) {
      c.applyChange(moved);
    }
    expect(watching.entries.map((e) => e.id), isNot(contains(moved.id)));
    expect(completed.entries.map((e) => e.id), contains(moved.id));
    expect(all.entries.firstWhere((e) => e.id == moved.id).progress, 12);
    all.removeEntry(10);
    expect(all.entries.map((e) => e.id), isNot(contains(10)));
    for (final c in [watching, completed, all]) {
      c.dispose();
    }
  });

  test('loaded statuses reach the status cache', () async {
    final adapter = FakeListAdapter(_many(2, status: ListEntryStatus.onHold));
    final c = controller(adapter, status: ListEntryStatus.onHold, pageSize: 10);
    await c.refresh();
    expect(cache.statusOf(1), 'on_hold');
    expect(cache.statusOf(2), 'on_hold');
    c.dispose();
  });

  test('a load error is kept and cleared by a retry', () async {
    final adapter = FakeListAdapter(_many(2))..error = Exception('offline');
    final c = controller(adapter);
    await c.refresh();
    expect(c.error, isNotNull);
    expect(c.entries, isEmpty);
    adapter.error = null;
    await c.refresh();
    expect(c.error, isNull);
    expect(c.entries, hasLength(2));
    c.dispose();
  });
}
