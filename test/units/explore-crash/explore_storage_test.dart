import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/MAL/mal_explore_page.dart';
import 'package:mywatchlist/screens/explore/explore_sections.dart';

import '../../helpers/no_network.dart';

/// The Explore layout that crashed: the page's single PageStorageKey, the seasonal picker
/// (DailyAL's ScrollablePositionedList year row), then horizontal strips far below it.
Widget _explore({required bool fixed, required int visit, bool picker = true}) {
  Widget strip(String name) {
    final list = SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30,
        itemBuilder: (_, i) => SizedBox(width: 100, child: Text('$name $i')),
      ),
    );
    return fixed
        ? SliverToBoxAdapter(key: ExploreStorage.strip(name), child: list)
        : SliverToBoxAdapter(child: list);
  }

  return MaterialApp(
    // A new route on each visit rebuilds the page from the stored state, as leaving the tab does.
    key: ValueKey(visit),
    home: Scaffold(
      body: PageStorage(
        bucket: _bucket,
        child: CustomScrollView(
          key: const PageStorageKey('explore-anime'),
          slivers: [
            if (picker)
              SliverToBoxAdapter(
                child:
                    fixed ? ExploreStorage.isolated(const SeasonalPicker()) : const SeasonalPicker(),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 1500)),
            strip('recommendations'),
            strip('reviews'),
            const SliverToBoxAdapter(child: SizedBox(height: 1500)),
          ],
        ),
      ),
    ),
  );
}

PageStorageBucket _bucket = PageStorageBucket();

/// Scrolls the page down to the strips, scrolls one strip, comes back up, then revisits.
Future<List<Object>> _run(WidgetTester tester, {required bool fixed}) async {
  _bucket = PageStorageBucket();
  final errors = <Object>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exception);
  try {
    for (var visit = 0; visit < 2; visit++) {
      await tester.pumpWidget(_explore(fixed: fixed, visit: visit));
      await tester.pumpAndSettle();
      final page = find.byKey(const PageStorageKey('explore-anime'));
      await tester.drag(page, const Offset(0, -1700));
      await tester.pumpAndSettle();
      final strip = find.text('recommendations 0');
      if (strip.evaluate().isNotEmpty) {
        await tester.drag(strip, const Offset(-300, 0));
        await tester.pumpAndSettle();
      }
      await tester.drag(page, const Offset(0, 3000));
      await tester.pumpAndSettle();
    }
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  testWidgets('without separate storage the strips crash (the bug)', (tester) async {
    final errors = await _run(tester, fixed: false);
    expect(
      errors.map((e) => '$e'),
      // Whichever list reads the shared slot second fails: the strips (`'ItemPosition' is not a
      // subtype of type 'double?'`) or, on the next visit, the picker itself.
      contains(allOf(contains('ItemPosition'), contains('is not a subtype of type'))),
    );
  });

  testWidgets('with ExploreStorage nothing crashes, on the first visit or the next', (tester) async {
    final errors = await _run(tester, fixed: true);
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each strip keeps its own scroll offset', (tester) async {
    _bucket = PageStorageBucket();
    // Without the picker: its seasons row centres itself with Scrollable.ensureVisible, which
    // also scrolls the page back to it when it is built.
    await tester.pumpWidget(_explore(fixed: true, visit: 0, picker: false));
    await tester.pumpAndSettle();
    final page = find.byKey(const PageStorageKey('explore-anime'));
    await tester.drag(page, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.drag(find.text('reviews 0'), const Offset(-250, 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_explore(fixed: true, visit: 1, picker: false));
    await tester.pumpAndSettle();

    double offsetOf(String name) => tester
        .state<ScrollableState>(find
            .descendant(of: find.byKey(ExploreStorage.strip(name)), matching: find.byType(Scrollable))
            .first)
        .position
        .pixels;
    expect(offsetOf('reviews'), greaterThan(0));
    expect(offsetOf('recommendations'), 0);
  });
}
