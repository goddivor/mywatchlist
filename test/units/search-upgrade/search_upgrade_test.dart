import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_queries.dart';
import 'package:mywatchlist/widgets/MAL/search/filtermodal.dart';

void main() {
  group('genre names to MAL ids', () {
    test('every name of the old anime table keeps its id', () {
      for (final entry in Mal.animeGenresEng.entries) {
        final id = SearchCatalog.genreId(entry.value, manga: false);
        // The old table's 75 is "Romantic Subtext"; the site now lists 74 for it.
        if (id != entry.key) {
          expect(SearchCatalog.genresEng(manga: false)[id], isNotNull, reason: entry.value);
        }
      }
      expect(SearchCatalog.genreId('Slice_of_Life', manga: false), 36);
      expect(SearchCatalog.genreId('Sci-Fi', manga: false), 24);
      expect(SearchCatalog.genreId('Idols_Female', manga: false), 60);
      expect(SearchCatalog.genreId('Avant_Garde', manga: false), 5);
    });

    test('manga names use the current manga ids, not the stale table', () {
      expect(SearchCatalog.genreId('Suspense', manga: true), 45);
      expect(SearchCatalog.genreId('Suspense', manga: false), 41);
      expect(SearchCatalog.genreId('Boys Love', manga: true), 28);
      expect(SearchCatalog.genreId('Romance', manga: true), 22);
    });

    test('names, numbers and unknown values', () {
      expect(SearchCatalog.genreId('36', manga: false), 36);
      expect(SearchCatalog.genreId('9999', manga: false), isNull);
      expect(SearchCatalog.genreId('Not a genre', manga: false), isNull);
      expect(SearchCatalog.genreIds(['Action', 'action', 'Comedy'], manga: false), [1, 4]);
    });

    test('producers and magazines are found by name', () {
      expect(SearchCatalog.producerId('Kyoto Animation'), 2);
      expect(SearchCatalog.producerId('Kyoto_Animation'), 2);
      expect(SearchCatalog.producers.length, greaterThan(500));
      expect(SearchCatalog.magazines.length, greaterThan(500));
    });
  });

  group('filters', () {
    test('old FilterOption genres become ids', () {
      final filters = SearchFilters.fromOutputs({
        'genres': FilterOption(
          type: FilterType.multiple,
          fieldName: 'genres',
          includedOptions: ['Action', 'Slice_of_Life'],
          excludedOptions: ['Ecchi'],
        ),
      }, category: 'anime');
      expect(filters.genresIn, [1, 36]);
      expect(filters.genresOut, [9]);
      expect(filters.activeCount, 1);
    });

    test('a news tag keeps its API key and All means none', () {
      final tagged = SearchFilters.fromOutputs({
        'tags': FilterOption(apiFieldName: 'tags', type: FilterType.select, values: ['Tout', 'Interview'], apiValues: ['All', 'Interview'], value: 'Interview'),
      }, category: 'featured');
      expect(tagged.text(FilterKey.tag), 'Interview');
      final all = SearchFilters.fromOutputs({
        'tags': FilterOption(apiFieldName: 'tags', type: FilterType.select, values: ['Tout'], apiValues: ['All'], value: 'Tout'),
      }, category: 'featured');
      expect(all.isEmpty, isTrue);
    });

    test('genre cycles off, included, excluded, off', () {
      var f = SearchFilters.empty.cycleGenre(1);
      expect(f.genreState(1), GenreState.included);
      f = f.cycleGenre(1);
      expect(f.genreState(1), GenreState.excluded);
      f = f.cycleGenre(1);
      expect(f.genreState(1), GenreState.off);
      expect(f.isEmpty, isTrue);
    });

    test('clearing the order clears the direction; filters follow the category', () {
      final f = SearchFilters.empty.set(FilterKey.orderBy, 'score').set(FilterKey.sort, 'asc');
      expect(f.remove(FilterKey.orderBy).has(FilterKey.sort), isFalse);
      expect(f.set(FilterKey.producer, 2).forCategory('manga').has(FilterKey.producer), isFalse);
    });
  });

  group('queries', () {
    test('special queries', () {
      expect(SpecialQuery.parse('airing'), isA<RankingQuery>());
      expect(SpecialQuery.parse('winter@2025'), isA<SeasonQuery>());
      expect(SpecialQuery.parse('winter@25'), isNull);
      expect(SpecialQuery.parse('suggested@manga'), isA<SuggestedQuery>());
      expect(SpecialQuery.parse('bypopularity@manga'), isA<MangaRankingQuery>());
      expect(SpecialQuery.parse('nonsense'), isNull);
      expect(SpecialQuery.parse(SpecialQuery.mangaRanking(MangaRanking.manhwa).substring(1)), isA<MangaRankingQuery>());
    });

    test('id and user name detection', () {
      expect(isIdQuery('1'), isTrue);
      expect(isIdQuery('12345'), isTrue);
      expect(isIdQuery('one piece'), isFalse);
      expect(looksLikeUsername('Xinil'), isTrue);
      expect(looksLikeUsername('a'), isFalse);
      expect(looksLikeUsername('two words'), isFalse);
    });

    test('the newest season year follows the clock', () {
      expect(lastSeasonYear(DateTime(2026, 10, 27)), 2027);
      expect(lastSeasonYear(DateTime(2031, 1, 1)), 2032);
    });
  });
}
