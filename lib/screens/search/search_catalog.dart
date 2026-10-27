import 'package:mywatchlist/enums.dart' show Mal;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/data/anime_genres.dart' as anime_data;
import 'package:mywatchlist/screens/search/data/anime_producers.dart';
import 'package:mywatchlist/screens/search/data/manga_genres.dart' as manga_data;
import 'package:mywatchlist/screens/search/data/manga_magazines.dart';

/// A group of genres of the picker (Genres, Explicit genres, Themes, Demographics).
class GenreGroup {
  final String title;
  final List<int> ids;
  const GenreGroup(this.title, this.ids);
}

/// MyAnimeList genre, producer and magazine tables, and the lookups from the names other screens
/// pass to the search ("Slice_of_Life", "Sci-Fi", "Idols_Female") to the ids the Jikan search
/// endpoints take.
///
/// The ids are the current MyAnimeList ones (the tables come from the DailyAL reference, built
/// from the site). `Mal.mangaGenresEng` in `enums.dart` still holds the old manga table (3 is
/// "Cars", 5 "Dementia", 28 "Yaoi"…), so a name that is not in the current table is matched
/// against the old tables by name and keeps the id it had there when that id still exists.
abstract final class SearchCatalog {
  /// Lower case, letters and digits only: "Slice_of_Life", "Slice of Life" and "slice-of-life"
  /// all become `sliceoflife`, "Idols (Female)" and "Idols_Female" become `idolsfemale`.
  static String normalize(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Map<int, String> genresEng({required bool manga}) =>
      manga ? manga_data.mangaGenresEng : anime_data.animeGenresEng;

  static final Map<String, int> _animeByName = _index(anime_data.animeGenresEng);
  static final Map<String, int> _mangaByName = _index(manga_data.mangaGenresEng);
  static final Map<String, int> _animeProducers = _index(animeStudios);
  static final Map<String, int> _magazines = _index(mangaMagazines);

  static Map<String, int> _index(Map<int, String> table) => {
        for (final entry in table.entries) normalize(entry.value): entry.key,
      };

  /// The id of a genre given by name (any spelling, English) or by number; null when unknown.
  static int? genreId(String name, {required bool manga}) {
    final table = genresEng(manga: manga);
    final numeric = int.tryParse(name.trim());
    if (numeric != null) return table.containsKey(numeric) ? numeric : null;
    final key = normalize(name);
    final current = (manga ? _mangaByName : _animeByName)[key];
    if (current != null) return current;
    final legacy = manga ? Mal.mangaGenresEng : Mal.animeGenresEng;
    for (final entry in legacy.entries) {
      if (normalize(entry.value) == key && table.containsKey(entry.key)) return entry.key;
    }
    return null;
  }

  /// The ids of [names], unknown names dropped, duplicates removed, order kept.
  static List<int> genreIds(Iterable<String> names, {required bool manga}) {
    final ids = <int>[];
    for (final name in names) {
      final id = genreId(name, manga: manga);
      if (id != null && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  static String genreNameEng(int id, {required bool manga}) =>
      genresEng(manga: manga)[id] ?? '$id';

  /// The genre name in the app language ("Slice of Life", "Tranche de vie").
  static String genreLabel(int id, {required bool manga}) {
    final translated = (manga ? manga_data.mangaGenres : anime_data.animeGenres)[id];
    final label = translated ?? genreNameEng(id, manga: manga);
    return label.replaceAll('_', ' ');
  }

  /// The picker sections, with their ids in MyAnimeList's order.
  static List<GenreGroup> genreGroups({required bool manga}) {
    final ids = manga ? manga_data.mangaGenreGroupIds : anime_data.animeGenreGroupIds;
    final titles = [
      S.current.Srch_Group_Genres,
      S.current.Srch_Group_Explicit,
      S.current.Srch_Group_Themes,
      S.current.Srch_Group_Demographics,
    ];
    return [
      for (var i = 0; i < ids.length; i++) GenreGroup(titles[i], ids[i]),
    ];
  }

  static int? producerId(String name) => int.tryParse(name.trim()) ?? _animeProducers[normalize(name)];

  static String? producerName(int id) => animeStudios[id];

  static int? magazineId(String name) => int.tryParse(name.trim()) ?? _magazines[normalize(name)];

  static String? magazineName(int id) => mangaMagazines[id];

  /// Producers and magazines, A to Z (the tables are by id).
  static final List<MapEntry<int, String>> producers = _sorted(animeStudios);

  static final List<MapEntry<int, String>> magazines = _sorted(mangaMagazines);

  static List<MapEntry<int, String>> _sorted(Map<int, String> table) => table.entries.toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
}
