/// Translates MyWatchList's search filters into the URL of MyAnimeList's own
/// search page (`anime.php`, `manga.php`, `character.php`, `people.php`), the
/// source that works when Jikan is unreachable.
///
/// Filters use the app's keys and API values (the ones Jikan takes, `tv`,
/// `r17`, `2024-04-01`, genre ids…); this class maps each one to the
/// parameter MAL's advanced search form sends:
///
/// | app key | anime.php | manga.php |
/// |---|---|---|
/// | `type` | `type` 1 TV, 2 OVA, 3 Movie, 4 Special, 5 ONA, 6 Music, 7 CM, 8 PV, 9 TV Special | `type` 1 Manga, 2 Light Novel, 3 One-shot, 4 Doujinshi, 5 Manhwa, 6 Manhua, 8 Novel |
/// | `status` | `status` 1 airing, 2 finished, 3 not yet aired | `status` 1 publishing, 2 finished, 3 not yet published, 4 hiatus, 5 discontinued |
/// | `rating` | `r` 1 G … 6 Rx | (none) |
/// | `score` (minimum) | `score` | `score` |
/// | `producer` | `p` | (none) |
/// | `magazines` | (none) | `mid` |
/// | `genres_in` / `genres_out` | `genre[]` / `genre_ex[]` | same |
/// | `start_date` / `end_date` | `sy sm sd` / `ey em ed` | same |
/// | `letter` | `letter` | `letter` |
/// | `order_by` + `sort` | `o` + `w` (1 descending, 2 ascending) | same |
///
/// MAL has no order by rank, popularity, favorites or number of scorers: rank
/// and scored-by sort by score, popularity and favorites by members (rank 1 and
/// popularity 1 are the best, so their direction is inverted). Pages are 50
/// rows (`show` = offset). A text shorter than [minQueryLength] is refused by
/// MAL; callers check [isTooShort] first.
abstract final class MalSearchQuery {
  static const int pageSize = 50;
  static const int minQueryLength = 3;

  /// Categories that have a MAL search page.
  static const categories = {'anime', 'manga', 'character', 'person'};

  /// The filter keys this class reads, as the app names them.
  static const filterKeys = [
    'type',
    'status',
    'rating',
    'order_by',
    'sort',
    'score',
    'letter',
    'start_date',
    'end_date',
    'producer',
    'magazines',
    'genres_in',
    'genres_out',
  ];

  static const animeTypes = {
    'tv': 1,
    'ova': 2,
    'movie': 3,
    'special': 4,
    'ona': 5,
    'music': 6,
    'cm': 7,
    'pv': 8,
    'tv_special': 9,
  };

  static const mangaTypes = {
    'manga': 1,
    'lightnovel': 2,
    'oneshot': 3,
    'doujin': 4,
    'manhwa': 5,
    'manhua': 6,
    'novel': 8,
  };

  static const animeStatuses = {'airing': 1, 'complete': 2, 'upcoming': 3};

  static const mangaStatuses = {
    'publishing': 1,
    'complete': 2,
    'upcoming': 3,
    'hiatus': 4,
    'discontinued': 5,
  };

  static const ratings = {'g': 1, 'pg': 2, 'pg13': 3, 'r17': 4, 'r': 5, 'rx': 6};

  /// `o` values; the record's flag inverts the direction (best = 1).
  static const animeOrders = <String, (int, bool)>{
    'title': (1, false),
    'start_date': (2, false),
    'score': (3, false),
    'episodes': (4, false),
    'end_date': (5, false),
    'type': (6, false),
    'members': (7, false),
    'rated': (8, false),
    'scored_by': (3, false),
    'rank': (3, true),
    'popularity': (7, true),
    'favorites': (7, false),
  };

  static const mangaOrders = <String, (int, bool)>{
    'title': (1, false),
    'start_date': (2, false),
    'score': (3, false),
    'volumes': (4, false),
    'end_date': (5, false),
    'chapters': (6, false),
    'members': (7, false),
    'type': (8, false),
    'scored_by': (3, false),
    'rank': (3, true),
    'popularity': (7, true),
    'favorites': (7, false),
  };

  /// Every column of the result table (type, episodes or volumes and
  /// chapters, score, dates, members, rating), so a row carries all MAL shows.
  static const _animeColumns = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
  static const _mangaColumns = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];

  static bool isTooShort(String query) {
    final text = query.trim();
    return text.isNotEmpty && text.length < minQueryLength;
  }

  /// The MAL search page for [category] (`anime`, `manga`, `character`,
  /// `person`), [query], [filters] (app keys, see the class comment; values
  /// are strings, ints or int lists, a genre list may also be `1,2,3`) and
  /// [page] (starts at 1). Filters a category does not have are ignored.
  static Uri url({
    required String category,
    String query = '',
    Map<String, Object?> filters = const {},
    int page = 1,
  }) {
    final params = <String, List<String>>{};
    void put(String key, Object value) => params[key] = ['$value'];
    void add(String key, Object value) =>
        (params[key] ??= <String>[]).add('$value');

    final text = query.trim();
    final offset = (page < 1 ? 0 : page - 1) * pageSize;
    switch (category) {
      case 'character':
      case 'person':
        put('q', text);
        put('cat', category);
        if (offset > 0) put('show', offset);
        return Uri.https('myanimelist.net',
            category == 'character' ? '/character.php' : '/people.php', params);
    }

    final manga = category == 'manga';
    put('q', text);
    put('cat', manga ? 'manga' : 'anime');

    final type = (manga ? mangaTypes : animeTypes)[_text(filters['type'])];
    if (type != null) put('type', type);

    final status =
        (manga ? mangaStatuses : animeStatuses)[_text(filters['status'])];
    if (status != null) put('status', status);

    if (!manga) {
      final rating = ratings[_text(filters['rating'])];
      if (rating != null) put('r', rating);
      final producer = _int(filters['producer']);
      if (producer != null && producer > 0) put('p', producer);
    } else {
      final magazine = _int(filters['magazines']);
      if (magazine != null && magazine > 0) put('mid', magazine);
    }

    final score = _int(filters['score']);
    if (score != null && score >= 1 && score <= 10) put('score', score);

    final letter = _text(filters['letter']);
    if (letter != null && letter.isNotEmpty) {
      put('letter', letter.substring(0, 1).toUpperCase());
    }

    _date(filters['start_date'], 's', put);
    _date(filters['end_date'], 'e', put);

    for (final id in _ids(filters['genres_in'])) {
      add('genre[]', id);
    }
    for (final id in _ids(filters['genres_out'])) {
      add('genre_ex[]', id);
    }

    final order = (manga ? mangaOrders : animeOrders)[_text(filters['order_by'])];
    if (order != null) {
      final ascending = _text(filters['sort']) == 'asc';
      put('o', order.$1);
      put('w', (ascending != order.$2) ? 2 : 1);
    }

    for (final column in manga ? _mangaColumns : _animeColumns) {
      add('c[]', column);
    }
    if (offset > 0) put('show', offset);
    return Uri.https(
        'myanimelist.net', manga ? '/manga.php' : '/anime.php', params);
  }

  /// `2024-04-07` → sy=2024 sm=4 sd=7 (or `ey em ed`); `2024-04` and `2024`
  /// set only the parts they have.
  static void _date(
      Object? value, String prefix, void Function(String, Object) put) {
    final text = _text(value);
    if (text == null || text.isEmpty) return;
    final parts = text.split('-').map(int.tryParse).toList();
    final year = parts.isNotEmpty ? parts[0] : null;
    if (year == null || year < 1900) return;
    put('${prefix}y', year);
    final month = parts.length > 1 ? parts[1] : null;
    if (month != null && month >= 1 && month <= 12) {
      put('${prefix}m', month);
      final day = parts.length > 2 ? parts[2] : null;
      if (day != null && day >= 1 && day <= 31) put('${prefix}d', day);
    }
  }

  static String? _text(Object? value) => value?.toString().trim();

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse('${value ?? ''}'.trim());

  static List<int> _ids(Object? value) {
    if (value == null) return const [];
    final Iterable<Object?> raw =
        value is Iterable ? value.cast<Object?>() : '$value'.split(',');
    return [
      for (final item in raw)
        if (_int(item) case final id? when id > 0) id,
    ];
  }
}
