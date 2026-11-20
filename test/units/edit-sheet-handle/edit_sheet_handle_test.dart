import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/edit_swipe.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../edit-sheet/fixtures.dart';

/// In-memory MAL entry: nothing leaves the test.
class _FakeEntries implements ListEntryService {
  @override
  bool get canEdit => true;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) async =>
      EditableContent.fromMalJson(completedAnimeJson(), isAnime: isAnime);

  @override
  Future<EntryUpdate> update(int id, {required bool isAnime, required EntryPatch patch, ListEntry? previous}) async {
    final entry = ListEntry(status: patch.status ?? '', score: patch.score ?? 0, progress: patch.progress ?? 0);
    return EntryUpdate(entry, entry);
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) async {}
}

/// Opens the edit sheet the way the app does (no Material drag handle, the editor's own handle).
Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [S.delegate],
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: false,
              builder: (sheetContext) => SingleChildScrollView(
                child: ContentEditWidget(
                  id: 5114,
                  category: 'anime',
                  service: _FakeEntries(),
                  onDismiss: () => Navigator.pop(sheetContext),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final _handle = find.byKey(const ValueKey('edit-handle'));

bool _expanded(WidgetTester tester) =>
    tester.getSemantics(_handle).label == S.current.Edit_Fewer_Options;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('one handle only: the sheet has no second Material handle', (tester) async {
    await _open(tester);
    expect(_handle, findsOneWidget);
    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle, isNot(true));
  });

  testWidgets('tap toggles More options', (tester) async {
    await _open(tester);
    expect(_expanded(tester), isFalse);
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    expect(_expanded(tester), isTrue);
    await tester.tap(_handle);
    await tester.pumpAndSettle();
    expect(_expanded(tester), isFalse);
  });

  testWidgets('swipe up expands, swipe down collapses, then closes the sheet', (tester) async {
    await _open(tester);
    await tester.fling(_handle, const Offset(0, -200), 1000);
    await tester.pumpAndSettle();
    expect(_expanded(tester), isTrue);

    await tester.fling(_handle, const Offset(0, 200), 1000);
    await tester.pumpAndSettle();
    expect(_expanded(tester), isFalse);
    expect(find.byType(BottomSheet), findsOneWidget, reason: 'the first swipe down only collapses');

    await tester.fling(_handle, const Offset(0, 200), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('a slow swipe on the body of the sheet works too', (tester) async {
    await _open(tester);
    final body = find.byKey(const ValueKey('edit-form'));
    // Slow drag (no fling) away from the handle.
    await tester.timedDrag(body, const Offset(0, -120), const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(_expanded(tester), isTrue);

    await tester.timedDrag(body, const Offset(0, 120), const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(_expanded(tester), isFalse);
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.timedDrag(body, const Offset(0, 120), const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  test('swipe decision', () {
    EditSwipe f(double dy, double v, bool e) => editSwipeFor(dy: dy, velocity: v, expanded: e);
    expect(f(-60, 0, false), EditSwipe.expand);
    expect(f(-10, -900, false), EditSwipe.expand);
    expect(f(-60, 0, true), EditSwipe.none);
    expect(f(60, 0, true), EditSwipe.collapse);
    expect(f(60, 0, false), EditSwipe.dismiss);
    expect(f(10, 100, false), EditSwipe.none, reason: 'a small move is not a swipe');
    expect(f(-60, 900, false), EditSwipe.none, reason: 'contradictory signals');
  });
}
