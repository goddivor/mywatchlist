import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';

void main() {
  test('list genre chips read in French, other names kept (#119)', () async {
    await S.load(const Locale('fr', 'FR'));
    expect(genreLabelOf('Slice of Life', isAnime: true), 'Tranche de vie');
    expect(genreLabelOf('Comedy', isAnime: true), 'Comédie');
    expect(genreLabelOf('Some Kitsu Category', isAnime: true), 'Some Kitsu Category');
  });

  test('French genre names are real French, not the machine-translated base', () async {
    await S.load(const Locale('fr', 'FR'));
    String anime(String name) => SearchCatalog.genreLabel(SearchCatalog.genreId(name, manga: false)!, manga: false);
    expect(anime('Shounen'), 'Shounen');
    expect(anime('Seinen'), 'Seinen');
    expect(anime('Josei'), 'Josei');
    expect(anime('Space'), 'Espace');
    expect(anime('Mahou Shoujo'), 'Mahou shoujo');
    expect(anime('Kids'), 'Enfants');
    expect(anime('School'), 'École');
    for (final id in SearchCatalog.genresEng(manga: false).keys) {
      expect(SearchCatalog.genreLabel(id, manga: false), isNot(contains('_')), reason: 'genre $id');
    }
  });

  test('English keeps MAL names', () async {
    await S.load(const Locale('en'));
    expect(genreLabelOf('Action', isAnime: true), 'Action');
    expect(genreLabelOf('Slice of Life', isAnime: true), 'Slice of Life');
  });
}
