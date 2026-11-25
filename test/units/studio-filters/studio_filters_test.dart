import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/studios/studio_filters.dart';
import 'package:mywatchlist/screens/studios/studio_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/studio_page.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = StudioAnime(id: 1, title: 'Beta', score: 8, members: 100, startDate: 20200101, genres: [1, 4]);
const _b = StudioAnime(id: 2, title: 'Alpha', score: 9, members: 50, startDate: 20100101, genres: [4]);
const _c = StudioAnime(id: 3, title: 'Gamma', score: 7, members: 300, startDate: 20200501, genres: [1, 4, 8]);

void main() {
  setUpAll(() => S.load(const Locale('en')));

  test('the parser reads the genres of each anime (data-genre)', () {
    final page = parseStudioPage((File('test/units/studio-page/fixtures/kyoto_animation.html').readAsStringSync(), 2))!;
    expect(page.anime.first.genres, isNotEmpty);
  });

  test('facets: genres A to Z, years newest first, my list only when known (#461)', () {
    final facets = StudioFilters.facets([_a, _b, _c]);
    expect(facets.map((f) => f.key), [StudioFilters.genre, StudioFilters.year]);
    expect(facets.first.options.map((o) => o.label), ['Action', 'Comedy', 'Drama']);
    expect(facets[1].options.map((o) => o.value), ['2020', '2010']);

    final withList = StudioFilters.facets([_a, _b, _c], statusOf: (id) => id == 1 ? 'watching' : null);
    final mine = withList.firstWhere((f) => f.key == StudioFilters.myList);
    expect(mine.options.map((o) => o.label), ['Watching', 'Not on my list']);
  });

  test('genres all match, exclusions drop, sorts follow the direction', () {
    var settings = StudioFilters.initial.copyWith(
      filter: const ListFilter(included: {'genre': {'1', '4'}}),
    );
    expect(StudioFilters.apply([_a, _b, _c], settings).map((a) => a.id), [1, 3], reason: 'score high to low');

    settings = StudioFilters.initial.copyWith(
      sortKey: StudioFilters.sortTitle,
      direction: SortDirection.ascending,
      filter: const ListFilter(excluded: {'genre': {'8'}}),
    );
    expect(StudioFilters.apply([_a, _b, _c], settings).map((a) => a.title), ['Alpha', 'Beta']);

    settings = StudioFilters.initial.copyWith(filter: const ListFilter(included: {'my_list': {'none'}}));
    expect(StudioFilters.apply([_a, _b, _c], settings, statusOf: (id) => id == 1 ? 'watching' : null)
        .map((a) => a.id), [2, 3]);
  });

  testWidgets('the studio bar opens My List\'s Sort / Filter sheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    ListStatusCache.instance.resetForTest();
    StudioPages.reset();
    StudioPages.source = (_) async =>
        StudioPage(id: 2, name: 'Studio', anime: const [_a, _b, _c]);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: const StudioScreen(id: 2, name: 'Studio'),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('studio-sort')));
    await tester.pumpAndSettle();
    expect(find.byType(ListSortFilterSheet), findsOneWidget);
  });
}
