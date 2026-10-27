import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType, DisplayType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

const _width = 400.0;

Future<UserListTabController> _pumpTab(
  WidgetTester tester,
  ListStatusCache cache,
  ListDisplay display,
) async {
  final adapter = FakeListAdapter([
    for (var i = 1; i <= 6; i++)
      entry(i, title: 'T$i', genres: const ['Action'], updatedAt: DateTime(2026, 10, 10 - i)),
  ]);
  final controller = UserListTabController(
    adapter: adapter,
    category: 'anime',
    status: null,
    settings: ListViewSettings(sortKey: ListSortKeys.updated, display: display),
    cache: cache,
  );
  tester.view
    ..physicalSize = const Size(_width, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: UserListTab(
        controller: controller,
        adapter: adapter,
        display: display,
        cardProfile: null,
        actions: EntryActions(
          onOpen: (_) {},
          onEdit: (_) {},
          onStep: null,
          canStep: (_) => false,
          busy: ValueNotifier(const <int>{}),
        ),
        style: const EntryCardStyle(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

Rect _card(WidgetTester tester, int id) => tester.getRect(find.byKey(ValueKey(id)));

void main() {
  late ListStatusCache cache;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = ListStatusCache(saveDelay: const Duration(days: 1));
  });
  tearDown(() => cache.dispose());

  for (final (subType, column, row, edge) in const [
    (DisplaySubType.comfortable, 10.0, 7.0, 5.0),
    (DisplaySubType.compact, 12.0, 11.0, 6.0),
    (DisplaySubType.cover_only_grid, 12.0, 11.0, 6.0),
  ]) {
    testWidgets('the ${subType.name} grid uses DailyAL gaps', (tester) async {
      const display = ListDisplay(type: DisplayType.grid, subType: DisplaySubType.comfortable, gridColumns: 3);
      final c = await _pumpTab(tester, cache, display.copyWith(subType: subType));

      expect(find.byType(EntryGridCard), findsNWidgets(6));
      final first = _card(tester, 1), second = _card(tester, 2), third = _card(tester, 3);
      final below = _card(tester, 4);
      expect(first.left, edge, reason: 'screen edge');
      expect(_width - third.right, moreOrLessEquals(edge), reason: 'screen edge');
      expect(second.left - first.right, moreOrLessEquals(column), reason: 'column gap');
      expect(below.top - first.bottom, moreOrLessEquals(row), reason: 'row gap');
      // Fixed extent: every cell the same size.
      for (var id = 1; id <= 6; id++) {
        expect(_card(tester, id).height, display.gridHeight);
        expect(_card(tester, id).width, moreOrLessEquals(first.width));
      }
      c.dispose();
      cache.resetForTest();
    });
  }

  test('grid gaps are DailyAL values for each grid card', () {
    expect(listGridGaps(DisplaySubType.comfortable), (column: 10.0, row: 7.0, edge: 5.0));
    expect(listGridGaps(DisplaySubType.compact), (column: 12.0, row: 11.0, edge: 6.0));
    expect(listGridGaps(DisplaySubType.cover_only_grid), (column: 12.0, row: 11.0, edge: 6.0));
    final delegate = listGridDelegate(const ListDisplay(type: DisplayType.grid, gridColumns: 4, gridHeight: 280));
    expect(delegate.crossAxisCount, 4);
    expect(delegate.mainAxisExtent, 280);
  });
}
