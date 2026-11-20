import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/list/bulk/list_bulk.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Records the writes; [failing] ids throw like a refused MAL request.
class _FakeService implements ListEntryService {
  final List<(int, EntryPatch)> updates = [];
  final List<int> deletes = [];
  final Set<int> failing;

  _FakeService({this.failing = const {}});

  @override
  bool get canEdit => true;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) => throw UnimplementedError();

  @override
  Future<EntryUpdate> update(int id, {required bool isAnime, required EntryPatch patch, ListEntry? previous}) async {
    if (failing.contains(id)) throw Exception('refused');
    updates.add((id, patch));
    return EntryUpdate(ListEntry(status: patch.status!, score: 7, progress: patch.progress ?? 0), Object());
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) async {
    if (failing.contains(id)) throw Exception('refused');
    deletes.add(id);
  }
}

ListEntryView _entry(int id, {int total = 12}) =>
    ListEntryView(id: id, malId: id, category: 'anime', title: 'T$id', total: total);

void main() {
  setUpAll(() => S.load(const Locale('en')));

  test('selection: start with a pick, toggle, all / none, keep only what is listed', () {
    final s = ListSelection();
    s.start(1);
    expect(s.active, isTrue);
    expect(s.ids, {1});
    s.toggle(2);
    s.toggle(1);
    expect(s.ids, {2});
    s.toggleAll([1, 2, 3]);
    expect(s.ids, {1, 2, 3});
    s.toggleAll([1, 2, 3]);
    expect(s.ids, isEmpty);
    s.toggleAll([4, 5]);
    s.retain([5]);
    expect(s.ids, {5});
    s.stop();
    expect(s.active, isFalse);
    expect(s.ids, isEmpty);
  });

  test('bulk status: every title written, completed gets its episodes, the cache follows', () async {
    final service = _FakeService(failing: {3});
    final cache = ListStatusCache(saveDelay: const Duration(days: 1));
    final saved = <int>[];
    final progress = <int>[];
    final result = await MalBulkWriter(service: service, cache: cache).setStatus(
      [_entry(1), _entry(2, total: 0), _entry(3)],
      ListEntryStatus.completed,
      onProgress: progress.add,
      onSaved: (old, entry) => saved.add(entry.id),
    );
    expect(result.done, 2);
    expect(result.failed, 1);
    expect(progress, [1, 2, 3]);
    expect(saved, [1, 2]);
    expect(service.updates.map((u) => (u.$1, u.$2.status, u.$2.progress)), [
      (1, 'completed', 12),
      // No known total: the progress is left as it is.
      (2, 'completed', null),
    ]);
    expect(cache.entryOf(1, category: 'anime')!.status, 'completed');
    expect(cache.entryOf(1, category: 'anime')!.score, 7);
    expect(cache.entryOf(3, category: 'anime'), isNull);
  });

  test('bulk remove: deleted on MAL and forgotten by the cache', () async {
    final service = _FakeService();
    final cache = ListStatusCache(saveDelay: const Duration(days: 1));
    cache.put(1, const CachedListStatus(status: 'watching'));
    final removed = <int>[];
    final result = await MalBulkWriter(service: service, cache: cache)
        .remove([_entry(1)], onRemoved: (e) => removed.add(e.id));
    expect(result.done, 1);
    expect(service.deletes, [1]);
    expect(removed, [1]);
    expect(cache.entryOf(1, category: 'anime'), isNull);
  });

  testWidgets('a card in selection mode toggles instead of opening', (tester) async {
    final selection = ListSelection();
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SelectableEntry(
          selection: selection,
          id: 7,
          child: SizedBox(
            width: 120,
            height: 180,
            child: InkWell(onTap: () => opened++, child: const Text('card')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('card'));
    expect(opened, 1);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    selection.start();
    await tester.pump();
    await tester.tap(find.text('card'));
    await tester.pump();
    expect(opened, 1);
    expect(selection.ids, {7});
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });
}
