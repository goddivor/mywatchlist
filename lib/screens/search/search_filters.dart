import 'package:flutter/foundation.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart';
import 'package:mywatchlist/widgets/MAL/search/filtermodal.dart';

/// The categories the search screen can look into, as the strings the rest of the app
/// already passes (`GeneralSearchScreen(category: 'manga')`).
abstract final class SearchCategory {
  static const all = 'all';
  static const anime = 'anime';
  static const manga = 'manga';
  static const character = 'character';
  static const person = 'person';
  static const user = 'user';
  static const forum = 'forum';
  static const featured = 'featured';
  static const news = 'news';
  static const club = 'club';
  static const interestStack = 'interest_stack';

  /// In the order of the category picker (DailyAL's order).
  static const values = [
    all,
    anime,
    manga,
    forum,
    character,
    person,
    user,
    featured,
    news,
    club,
    interestStack,
  ];

  /// Anime and manga: the categories with the rich filters and the display options.
  static bool isMedia(String category) => category == anime || category == manga;
}

/// Keys of [SearchFilters], the names the old `FilterOption.apiFieldName` used.
abstract final class FilterKey {
  static const type = 'type';
  static const status = 'status';
  static const rating = 'rating';
  static const orderBy = 'order_by';
  static const sort = 'sort';
  static const score = 'score';
  static const letter = 'letter';
  static const startDate = 'start_date';
  static const endDate = 'end_date';
  static const producer = 'producer';
  static const magazine = 'magazines';
  static const genresIn = 'genres_in';
  static const genresOut = 'genres_out';
  static const boardId = 'board_id';
  static const subboardId = 'subboard_id';
  static const topicUser = 'topic_user_name';
  static const user = 'user_name';
  static const location = 'loc';
  static const ageLow = 'agelow';
  static const ageHigh = 'agehigh';
  static const gender = 'g';
  static const tag = 'tags';
  static const stackType = 'stack_type';

  /// Display name of a producer or magazine whose id is not in the tables (a studio opened
  /// from another screen); never sent to an API.
  static const producerLabel = 'producer_label';
  static const magazineLabel = 'magazines_label';
}

enum GenreState { off, included, excluded }

/// The filters of one search, immutable. Values are API values (genre ids, producer ids, `tv`,
/// `r17`, `2024-04-07`…), never display text, so they do not depend on the app language.
@immutable
class SearchFilters {
  final Map<String, Object> _values;

  const SearchFilters._(this._values);

  static const empty = SearchFilters._({});

  bool get isEmpty => _values.isEmpty;
  bool get isNotEmpty => _values.isNotEmpty;

  bool has(String key) => _values.containsKey(key);

  String? text(String key) => _values[key] as String?;
  int? integer(String key) => _values[key] as int?;

  List<int> get genresIn => (_values[FilterKey.genresIn] as List<int>?) ?? const [];
  List<int> get genresOut => (_values[FilterKey.genresOut] as List<int>?) ?? const [];

  /// How many filters are on; the genre include/exclude pair counts as one.
  int get activeCount {
    var count = 0;
    for (final key in _values.keys) {
      if (key == FilterKey.genresOut && _values.containsKey(FilterKey.genresIn)) continue;
      if (key == FilterKey.producerLabel || key == FilterKey.magazineLabel) continue;
      count++;
    }
    return count;
  }

  /// A copy with [key] set to [value]; a null or empty value removes the filter. Removing
  /// `order_by` removes `sort`, which means nothing alone, and a board excludes a sub board.
  SearchFilters set(String key, Object? value) {
    final next = Map<String, Object>.of(_values);
    final empty = value == null ||
        (value is List && value.isEmpty) ||
        (value is String && value.isEmpty);
    if (empty) {
      next.remove(key);
      if (key == FilterKey.orderBy) next.remove(FilterKey.sort);
      if (key == FilterKey.producer) next.remove(FilterKey.producerLabel);
      if (key == FilterKey.magazine) next.remove(FilterKey.magazineLabel);
    } else {
      next[key] = value;
      if (key == FilterKey.boardId) next.remove(FilterKey.subboardId);
      if (key == FilterKey.subboardId) next.remove(FilterKey.boardId);
    }
    return SearchFilters._(next);
  }

  SearchFilters remove(String key) => set(key, null);

  /// The API values by key, display labels left out (what MyAnimeList's search page route
  /// takes, see `MalSearchQuery`).
  Map<String, Object?> toApiMap() => {
        for (final entry in _values.entries)
          if (entry.key != FilterKey.producerLabel && entry.key != FilterKey.magazineLabel)
            entry.key: entry.value,
      };

  GenreState genreState(int id) {
    if (genresIn.contains(id)) return GenreState.included;
    if (genresOut.contains(id)) return GenreState.excluded;
    return GenreState.off;
  }

  /// Cycles one genre off → included → excluded → off.
  SearchFilters cycleGenre(int id) {
    final state = genreState(id);
    final inc = List<int>.of(genresIn)..remove(id);
    final exc = List<int>.of(genresOut)..remove(id);
    if (state == GenreState.off) {
      inc.add(id);
    } else if (state == GenreState.included) {
      exc.add(id);
    }
    return set(FilterKey.genresIn, inc).set(FilterKey.genresOut, exc);
  }

  /// Keeps only the filters that make sense for [category].
  SearchFilters forCategory(String category) {
    final allowed = allowedKeys(category);
    return SearchFilters._({
      for (final entry in _values.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    });
  }

  static Set<String> allowedKeys(String category) {
    switch (category) {
      case SearchCategory.anime:
        return {
          FilterKey.type,
          FilterKey.status,
          FilterKey.rating,
          FilterKey.orderBy,
          FilterKey.sort,
          FilterKey.score,
          FilterKey.letter,
          FilterKey.startDate,
          FilterKey.endDate,
          FilterKey.producer,
          FilterKey.producerLabel,
          FilterKey.genresIn,
          FilterKey.genresOut,
        };
      case SearchCategory.manga:
        return {
          FilterKey.type,
          FilterKey.status,
          FilterKey.orderBy,
          FilterKey.sort,
          FilterKey.score,
          FilterKey.letter,
          FilterKey.startDate,
          FilterKey.endDate,
          FilterKey.magazine,
          FilterKey.magazineLabel,
          FilterKey.genresIn,
          FilterKey.genresOut,
        };
      case SearchCategory.forum:
        return {FilterKey.boardId, FilterKey.subboardId, FilterKey.topicUser, FilterKey.user};
      case SearchCategory.user:
        return {FilterKey.location, FilterKey.ageLow, FilterKey.ageHigh, FilterKey.gender};
      case SearchCategory.featured:
      case SearchCategory.news:
        return {FilterKey.tag};
      case SearchCategory.interestStack:
        return {FilterKey.stackType};
      default:
        return const {};
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SearchFilters && mapEquals(_values, other._values);

  @override
  int get hashCode => Object.hashAllUnordered(_values.entries.map((e) =>
      Object.hash(e.key, e.value is List ? Object.hashAll(e.value as List) : e.value)));

  /// Reads the `FilterOption` map the other screens pass to `GeneralSearchScreen(filterOutputs:)`:
  /// genres by name, a producer or a magazine by name or id, a news / featured tag.
  /// Genre names go through [SearchCatalog.genreId], so `Slice_of_Life`, `Slice of Life` and
  /// the id `36` all land on the same MyAnimeList genre.
  static SearchFilters fromOutputs(
    Map<String, FilterOption>? outputs, {
    required String category,
  }) {
    if (outputs == null || outputs.isEmpty) return empty;
    final manga = category == SearchCategory.manga;
    var filters = empty;
    for (final entry in outputs.entries) {
      final option = entry.value;
      final key = option.apiFieldName ?? entry.key;
      switch (key) {
        case 'genres':
          filters = filters
              .set(FilterKey.genresIn,
                  SearchCatalog.genreIds(option.includedOptions ?? const [], manga: manga))
              .set(FilterKey.genresOut,
                  SearchCatalog.genreIds(option.excludedOptions ?? const [], manga: manga));
        case FilterKey.producer:
          final id = _idOf(option, SearchCatalog.producerId);
          if (id != null) {
            filters = filters
                .set(FilterKey.producer, id)
                .set(FilterKey.producerLabel, _labelOf(option, SearchCatalog.producerName(id)));
          }
        case FilterKey.magazine:
          final id = _idOf(option, SearchCatalog.magazineId);
          if (id != null) {
            filters = filters
                .set(FilterKey.magazine, id)
                .set(FilterKey.magazineLabel, _labelOf(option, SearchCatalog.magazineName(id)));
          }
        case FilterKey.tag:
          final tag = _tagOf(option);
          if (tag != null) filters = filters.set(FilterKey.tag, tag);
        default:
          final value = option.value;
          if (value != null && value.isNotEmpty && allowedKeys(category).contains(key)) {
            final api = _apiValueOf(option);
            filters = filters.set(key, api is int || api is String ? api : value);
          }
      }
    }
    return filters.forCategory(category);
  }

  static int? _idOf(FilterOption option, int? Function(String name) byName) {
    final value = option.value;
    if (value == null || value.isEmpty) return null;
    final api = _apiValueOf(option);
    if (api is int) return api;
    return int.tryParse(value) ?? byName(value);
  }

  /// The name to show for an id: the table's, else the option's own text when it is not a number.
  static String? _labelOf(FilterOption option, String? known) {
    if (known != null) return null;
    final value = option.value;
    return value == null || int.tryParse(value.trim()) != null ? null : value;
  }

  /// The API value matching `option.value` in `option.values` / `option.apiValues`, if both exist.
  static Object? _apiValueOf(FilterOption option) {
    final values = option.values;
    final api = option.apiValues;
    final value = option.value;
    if (values == null || api == null || value == null) return null;
    final index = values.indexOf(value);
    return index >= 0 && index < api.length ? api[index] as Object? : null;
  }

  /// A news / featured tag key: an API key as is, a display label through `apiValues`; `All`
  /// means no tag.
  static String? _tagOf(FilterOption option) {
    final api = _apiValueOf(option);
    final value = api is String ? api : option.value;
    if (value == null || value.isEmpty || value == 'All') return null;
    return value;
  }
}
