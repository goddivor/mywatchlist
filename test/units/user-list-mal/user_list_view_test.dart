import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeListAdapter adapter, ListStatusCache cache,
    {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: UserListView(
        adapter: adapter,
        cache: cache,
        titleBuilder: (context, categorySwitch) => categorySwitch,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  late ListStatusCache cache;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = ListStatusCache(saveDelay: const Duration(days: 1));
  });
  tearDown(() => cache.dispose());

  testWidgets('shows the list with status tabs and steps an episode', (tester) async {
    final adapter = FakeListAdapter([
      entry(1, title: 'Frieren', progress: 3, total: 28, updatedAt: DateTime(2026, 10, 2)),
      entry(2, title: 'Monster', status: ListEntryStatus.completed, progress: 74, total: 74,
          updatedAt: DateTime(2026, 9, 1)),
    ]);
    await _pump(tester, adapter, cache);

    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Monster'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Watching'), findsWidgets);
    expect(find.text('3 / 28 ep.'), findsOneWidget);

    await tester.tap(find.byTooltip('Add one').first);
    await tester.pumpAndSettle();
    expect(adapter.steps, [(1, 1)]);
    expect(find.text('4 / 28 ep.'), findsOneWidget);
    expect(cache.entryOf(1)?.progress, 4);
    cache.resetForTest(); // drops the pending (1 day) write
  });

  testWidgets('the search narrows the list and the empty state offers to clear it',
      (tester) async {
    final adapter = FakeListAdapter([
      entry(1, title: 'Frieren'),
      entry(2, title: 'Monster'),
    ]);
    await _pump(tester, adapter, cache);
    await tester.tap(find.byTooltip('Search in the list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No entry matches'), findsOneWidget);
    await tester.tap(find.text('Clear search and filters'));
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsOneWidget);
    cache.resetForTest();
  });

  testWidgets('a load error shows a retry', (tester) async {
    final adapter = FakeListAdapter([entry(1, title: 'Frieren')])..error = Exception('offline');
    await _pump(tester, adapter, cache);
    expect(find.text("Couldn't load your list"), findsOneWidget);
    adapter.error = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsOneWidget);
    cache.resetForTest();
  });

  testWidgets('French strings on the list', (tester) async {
    final adapter = FakeListAdapter([entry(1, title: 'Frieren', progress: 3, total: 28)]);
    await _pump(tester, adapter, cache, locale: const Locale('fr', 'FR'));
    expect(find.text('Tout'), findsOneWidget);
    expect(find.text('3 / 28 ép.'), findsOneWidget);
    expect(find.text('Dernière mise à jour'), findsOneWidget);
    cache.resetForTest();
  });
}
