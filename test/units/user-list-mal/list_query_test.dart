import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';

import 'fixtures.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('filter', () {
    final list = [
      entry(1, title: 'Alpha', mediaType: 'tv', genres: ['Action', 'Drama'], priority: 2),
      entry(2, title: 'Beta', mediaType: 'movie', genres: ['Action']),
      entry(3, title: 'Gamma', mediaType: 'ova', genres: ['Comedy'], score: 9),
    ];

    test('values of one facet are ORed, genres are ANDed', () {
      var f = ListFilter.none.toggle(ListFacetKeys.media, 'tv').toggle(ListFacetKeys.media, 'movie');
      expect(filterEntries(list, f).map((e) => e.id), [1, 2]);
      f = ListFilter.none
          .toggle(ListFacetKeys.genre, 'Action')
          .toggle(ListFacetKeys.genre, 'Drama');
      expect(filterEntries(list, f).map((e) => e.id), [1]);
    });

    test('a second tap excludes, a third clears', () {
      var f = ListFilter.none.toggle(ListFacetKeys.genre, 'Action', allowExclude: true);
      f = f.toggle(ListFacetKeys.genre, 'Action', allowExclude: true);
      expect(f.excludedOf(ListFacetKeys.genre), {'Action'});
      expect(filterEntries(list, f).map((e) => e.id), [3]);
      f = f.toggle(ListFacetKeys.genre, 'Action', allowExclude: true);
      expect(f.isEmpty, isTrue);
    });

    test('priority and score buckets', () {
      expect(filterEntries(list, ListFilter.none.toggle(ListFacetKeys.priority, '2')).map((e) => e.id),
          [1]);
      expect(filterEntries(list, ListFilter.none.toggle(ListFacetKeys.score, '9')).map((e) => e.id),
          [3]);
      expect(filterEntries(list, ListFilter.none.toggle(ListFacetKeys.score, '0')).map((e) => e.id),
          [1, 2]);
    });

    test('search matches any title, case-insensitive', () {
      final withAlt = [
        ...list,
        const ListEntryView(id: 4, category: 'anime', title: 'Shingeki', otherTitles: ['Attack on Titan']),
      ];
      expect(filterEntries(withAlt, ListFilter.none, query: 'titan').map((e) => e.id), [4]);
      expect(filterEntries(withAlt, ListFilter.none, query: ' ALP ').map((e) => e.id), [1]);
    });

    test('filters survive a JSON round trip', () {
      final f = ListFilter.none
          .toggle(ListFacetKeys.media, 'tv')
          .toggle(ListFacetKeys.genre, 'Drama', allowExclude: true)
          .toggle(ListFacetKeys.genre, 'Drama', allowExclude: true);
      expect(ListFilter.fromJson(f.toJson()), f);
    });
  });

  group('sort', () {
    test('entries without a value go last in both directions', () {
      final list = [
        entry(1, title: 'b', score: 0),
        entry(2, title: 'a', score: 7),
        entry(3, title: 'c', score: 9),
      ];
      expect(sortEntries(list, ListSortKeys.score, SortDirection.descending).map((e) => e.id),
          [3, 2, 1]);
      expect(sortEntries(list, ListSortKeys.score, SortDirection.ascending).map((e) => e.id),
          [2, 3, 1]);
    });

    test('title is case-insensitive, ties keep the title order', () {
      final list = [
        entry(1, title: 'beta', progress: 1),
        entry(2, title: 'Alpha', progress: 1),
        entry(3, title: 'gamma', progress: 5),
      ];
      expect(sortEntries(list, ListSortKeys.title, SortDirection.ascending).map((e) => e.id),
          [2, 1, 3]);
      expect(sortEntries(list, ListSortKeys.progress, SortDirection.descending).map((e) => e.id),
          [3, 2, 1]);
    });

    test('popularity descending lists the best rank first', () {
      final list = [
        const ListEntryView(id: 1, category: 'anime', title: 'a', popularity: 300),
        const ListEntryView(id: 2, category: 'anime', title: 'b', popularity: 4),
        const ListEntryView(id: 3, category: 'anime', title: 'c'),
      ];
      expect(sortEntries(list, ListSortKeys.popularity, SortDirection.descending).map((e) => e.id),
          [2, 1, 3]);
    });

    test('partial release dates sort before full ones of the same month', () {
      final list = [
        const ListEntryView(id: 1, category: 'anime', title: 'a', releaseStart: '2024-03-15'),
        const ListEntryView(id: 2, category: 'anime', title: 'b', releaseStart: '2024-03'),
        const ListEntryView(id: 3, category: 'anime', title: 'c', releaseStart: '2023'),
      ];
      expect(sortEntries(list, ListSortKeys.releaseStart, SortDirection.ascending).map((e) => e.id),
          [3, 2, 1]);
    });
  });

  group('airing', () {
    test('next airing of a Saturday 23:30 JST slot is Saturday 14:30 UTC', () {
      const slot = BroadcastSlot(DateTime.saturday, 23 * 60 + 30);
      final next = slot.nextAiring(DateTime.utc(2026, 10, 27, 12)); // a Tuesday
      expect(next, DateTime.utc(2026, 10, 31, 14, 30));
      // A slot before 09:00 JST airs the day before in UTC.
      const early = BroadcastSlot(DateTime.monday, 1 * 60);
      expect(early.nextAiring(DateTime.utc(2026, 10, 27, 12)), DateTime.utc(2026, 11, 1, 16));
    });

    test('unseen episodes of an airing anime are estimated weekly', () {
      final airing = ListEntryView(
        id: 1,
        category: 'anime',
        title: 'a',
        releaseState: ReleaseState.releasing,
        releaseStart: '2026-10-04',
        total: 12,
        status: ListEntryStatus.current,
        progress: 2,
      );
      // 4 weeks after the first episode: 4 aired, 2 seen.
      expect(airing.releasedCount(DateTime(2026, 10, 27)), 4);
      expect(airing.unseenCount(DateTime(2026, 10, 27)), 2);
    });
  });
}
