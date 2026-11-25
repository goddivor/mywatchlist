import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';

const _genres = ListFilterFacet(
  key: 'genre',
  label: 'Genres',
  allowExclude: true,
  matchAll: true,
  picker: true,
  options: [
    SelectOption('1', 'Action'),
    SelectOption('2', 'Adventure'),
    SelectOption('3', 'Comedy'),
    SelectOption('4', 'Drama'),
    SelectOption('5', 'Fantasy'),
    SelectOption('6', 'Horror'),
    SelectOption('7', 'Mystery'),
    SelectOption('8', 'Romance'),
    SelectOption('9', 'Sports'),
  ],
);

const _media = ListFilterFacet(
  key: 'media',
  label: 'Type',
  options: [SelectOption('tv', 'TV'), SelectOption('movie', 'Movie')],
);

void main() {
  setUpAll(() => S.load(const Locale('en')));

  test('remove drops one value, included or excluded', () {
    final f = ListFilter.none
        .toggle('genre', '1')
        .toggle('genre', '2')
        .toggle('genre', '2', allowExclude: true);
    expect(f.includedOf('genre'), {'1'});
    expect(f.excludedOf('genre'), {'2'});
    final g = f.remove('genre', '2').remove('genre', '1');
    expect(g.isEmpty, isTrue);
  });

  Future<ListViewSettings?> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    ListViewSettings? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showListSortFilterSheet(
            context,
            settings: const ListViewSettings(sortKey: 'title'),
            options: ListSortFilterOptions(
              sorts: [ListSortOption('title', 'Title')],
              facets: const [_media, _genres],
              displayTypes: const [],
            ),
            initialTab: ListSortFilterTab.filter,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('a picker facet shows a Choose button, not every value (owner request)', (tester) async {
    await open(tester);
    expect(find.text('TV'), findsOneWidget, reason: 'short facets keep their chips');
    expect(find.text('Action'), findsNothing);
    expect(find.text('Choose'), findsOneWidget);
  });

  testWidgets('picked values come back as chips; tap again excludes', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('facet-pick-genre')));
    await tester.pumpAndSettle();
    expect(find.byType(FacetPickerSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'dra');
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsNothing, reason: 'searchable');
    await tester.tap(find.text('Drama'));
    await tester.pumpAndSettle();
    expect(find.text('Included'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.byType(FacetPickerSheet), findsNothing);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Drama'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Excluded'), findsOneWidget);
  });

  testWidgets('Apply returns the picked values', (tester) async {
    ListViewSettings? applied;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => applied = await showListSortFilterSheet(
            context,
            settings: const ListViewSettings(sortKey: 'title'),
            options: ListSortFilterOptions(
              sorts: [ListSortOption('title', 'Title')],
              facets: const [_genres],
              displayTypes: const [],
            ),
            initialTab: ListSortFilterTab.filter,
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('facet-pick-genre')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Action'));
    await tester.tap(find.text('Horror'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.UserList_Apply));
    await tester.pumpAndSettle();
    expect(applied?.filter.includedOf('genre'), {'1', '6'});
  });
}
