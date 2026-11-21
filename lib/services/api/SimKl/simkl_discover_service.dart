import 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/user_simkl_v2.dart';

export 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart' show SimklTrendingWindow;
export 'package:mywatchlist/services/api/SimKl/simkl_kind.dart' show SimklKind;

/// Anime format filter of the Simkl catalogue calls (`type` of best, premieres and genres).
enum SimklFormat {
  all('all'),
  tv('tv'),
  movies('movies'),
  ovas('ovas'),
  onas('onas');

  const SimklFormat(this.api);
  final String api;
}

/// Bucket of `GET /anime/best/{filter}`.
enum SimklBest { all, year, month, voted, watched }

/// Order of `GET /anime/genres/...`.
enum SimklGenreSort {
  popularMonth('popular-this-month'),
  popularAll('popular-all-time'),
  rank('rank'),
  releaseDate('release-date'),
  voted('voted');

  const SimklGenreSort(this.api);
  final String api;
}

/// The genre slugs of each catalogue (checked against the API on 2026-11-21), `all` first.
List<String> simklGenresOf(SimklKind kind) => switch (kind) {
      SimklKind.anime => simklGenres,
      SimklKind.tv => simklTvGenres,
      SimklKind.movie => simklMovieGenres,
    };

const List<String> simklTvGenres = [
  'all', 'action', 'adventure', 'animation', 'awards-show', 'children', 'comedy', 'crime',
  'documentary', 'drama', 'family', 'fantasy', 'food', 'game-show', 'history', 'home-and-garden',
  'horror', 'indie', 'martial-arts', 'mini-series', 'musical', 'mystery', 'news', 'podcast',
  'reality', 'romance', 'science-fiction', 'soap', 'sport', 'suspense', 'talk-show', 'thriller',
  'travel', 'video-game-play', 'war', 'western',
];

const List<String> simklMovieGenres = [
  'all', 'action', 'adventure', 'animation', 'comedy', 'crime', 'documentary', 'drama', 'erotica',
  'family', 'fantasy', 'history', 'horror', 'music', 'mystery', 'romance', 'science-fiction',
  'thriller', 'tv-movie', 'war', 'western',
];

/// The genre slugs `GET /anime/genres/{genre}/...` accepts (https://api.simkl.org), `all` first.
const List<String> simklGenres = [
  'all', 'action', 'adventure', 'comedy', 'drama', 'ecchi', 'educational', 'fantasy', 'gag-humor',
  'gore', 'harem', 'historical', 'horror', 'idol', 'isekai', 'josei', 'kids', 'magic',
  'martial-arts', 'mecha', 'military', 'music', 'mystery', 'mythology', 'parody', 'psychological',
  'racing', 'reincarnation', 'romance', 'samurai', 'school', 'sci-fi', 'seinen', 'shoujo',
  'shoujo-ai', 'shounen', 'shounen-ai', 'slice-of-life', 'space', 'sports', 'strategy-game',
  'super-power', 'supernatural', 'thriller', 'vampire', 'yaoi', 'yuri',
];

/// One page of a paged Simkl list.
class SimklPage {
  final List<SimklMedia> items;
  final bool hasMore;

  const SimklPage(this.items, {required this.hasMore});
}

/// Public Simkl catalogue (no session needed).
///
/// - Trending and the airing calendar come from the free CDN files ([SimklCdn]: no quota, no
///   token, they keep working under AUTH V2); when the CDN cannot be reached the API's own
///   `/anime/trending` and `/anime/airing` answer instead.
/// - New premieres, coming soon, best anime, genre browse and search use the API. Under AUTH V2
///   these answer `401 user_token_required` without a user token, so they carry the Simkl
///   session's token when one exists; without a session (or when it is refused) they go out with
///   the client id only, which AUTH V1 still accepts.
class SimklDiscoverService {
  SimklDiscoverService({SimklClient? client, SimklCdn? cdn, bool Function()? signedIn})
      : _client = client ?? SimklClient.instance,
        _cdn = cdn,
        _signedIn = signedIn ?? _hasSession;

  static SimklDiscoverService instance = SimklDiscoverService();

  /// Most items a page of `premieres` and `genres` holds (Simkl's cap).
  static const int pageSize = 60;

  /// Last page Simkl serves for genres (higher pages are clamped).
  static const int maxPage = 20;

  final SimklClient _client;
  final SimklCdn? _cdn;
  final bool Function() _signedIn;

  static bool _hasSession() => UserSimklV2.instance.status == AuthStatus.AUTHENTICATED;

  /// GET of a catalogue path: with the user token when a session exists, else anonymous.
  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    if (_signedIn()) {
      try {
        return await _client.getAuth(path, query: query);
      } on SimklSessionExpired {
        // Dead or refused session: the anonymous call still works under AUTH V1.
      }
    }
    return _client.getPublic(path, query: query);
  }

  SimklCdn get cdn => _cdn ?? SimklCdn.instance;

  /// Trending titles of [kind] in [window] (CDN), the API's trending list when the CDN fails.
  Future<List<SimklMedia>> trending({
    SimklTrendingWindow window = SimklTrendingWindow.today,
    SimklKind kind = SimklKind.anime,
    int limit = 100,
  }) async {
    List<SimklMedia> items;
    try {
      items = await cdn.trending(window, kind: kind);
    } catch (_) {
      items = SimklMedia.listFrom(await _get('/${kind.api}/trending', query: {'extended': 'overview'}), kind);
    }
    return _take(items, limit);
  }

  /// The episodes (movies: the releases) of [kind] on the local day of [date] (today by
  /// default), by air time: the CDN calendar, the API's `/{tv|anime}/airing` when the CDN fails.
  Future<List<SimklMedia>> airingToday({DateTime? date, SimklKind kind = SimklKind.anime, int limit = 40}) async {
    final day = date ?? DateTime.now();
    try {
      return _take(await cdn.airingOn(day, kind: kind), limit);
    } catch (_) {
      if (kind == SimklKind.movie) rethrow; // the API has no movie airing list
      final text = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      final data = await _get('/${kind.api}/airing', query: {'date': text, 'sort': 'time'});
      return _take(SimklMedia.listFrom(data, kind), limit);
    }
  }

  /// The whole CDN calendar of [kind] (rolling 33 days), by air time.
  Future<List<SimklMedia>> calendar({SimklKind kind = SimklKind.anime}) => cdn.calendar(kind: kind);

  /// `GET /{tv|anime}/premieres/new`: the latest premieres (Simkl has none for movies).
  Future<List<SimklMedia>> premieres({
    SimklFormat format = SimklFormat.all,
    SimklKind kind = SimklKind.anime,
    int limit = pageSize,
  }) =>
      _premieres('new', format, kind, limit);

  /// `GET /{tv|anime}/premieres/soon`: the upcoming titles, soonest first.
  Future<List<SimklMedia>> comingSoon({
    SimklFormat format = SimklFormat.all,
    SimklKind kind = SimklKind.anime,
    int limit = pageSize,
  }) =>
      _premieres('soon', format, kind, limit);

  Future<List<SimklMedia>> _premieres(String which, SimklFormat format, SimklKind kind, int limit) async {
    final data = await _get('/${kind.api}/premieres/$which', query: {
      'type': kind == SimklKind.anime ? format.api : 'all',
      'limit': '${limit.clamp(1, pageSize)}',
    });
    return _take(SimklMedia.listFrom(data, kind), limit);
  }

  /// `GET /{tv|anime}/best/{filter}`: the best rated titles of the bucket (Simkl answers `null`
  /// when the format leaves nothing; it has no such list for movies).
  Future<List<SimklMedia>> best({
    SimklBest filter = SimklBest.all,
    SimklFormat format = SimklFormat.all,
    SimklKind kind = SimklKind.anime,
  }) async {
    final data = await _get('/${kind.api}/best/${filter.name}', query: {
      'type': kind == SimklKind.anime ? format.api : 'all',
    });
    return SimklMedia.listFrom(data, kind);
  }

  /// One page of the genre browse:
  /// - anime `GET /anime/genres/{genre}/{type}/all/all/{sort}`;
  /// - shows `GET /tv/genres/{genre}/all-types/all-countries/all-networks/all-years/{sort}`;
  /// - movies `GET /movies/genres/{genre}/all-types/all-countries/all-years/{sort}`.
  Future<SimklPage> byGenre({
    String genre = 'all',
    SimklFormat format = SimklFormat.all,
    SimklGenreSort sort = SimklGenreSort.popularMonth,
    SimklKind kind = SimklKind.anime,
    int page = 1,
  }) async {
    final type = format == SimklFormat.all ? 'all' : format.api;
    final path = switch (kind) {
      SimklKind.anime => '/anime/genres/$genre/$type/all/all/${sort.api}',
      SimklKind.tv => '/tv/genres/$genre/all-types/all-countries/all-networks/all-years/${sort.api}',
      SimklKind.movie => '/movies/genres/$genre/all-types/all-countries/all-years/${sort.api}',
    };
    final data = await _get(path, query: {
      'page': '$page',
      'limit': '$pageSize',
    });
    final items = SimklMedia.listFrom(data, kind);
    return SimklPage(items, hasMore: items.length >= pageSize && page < maxPage);
  }

  /// `GET /search/{tv|anime|movie}`.
  Future<List<SimklMedia>> search(String query, {SimklKind kind = SimklKind.anime, int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _get('/search/${kind.searchKey}', query: {
      'q': q,
      'limit': '$limit',
      'extended': 'full',
    });
    return SimklMedia.listFrom(data, kind);
  }

  /// The MyAnimeList id of a Simkl title (`GET /anime/{id}`), null when Simkl has none.
  Future<int?> malIdOf(int simklId) async {
    final data = await _get('/anime/$simklId');
    final ids = data is Map ? data['ids'] : null;
    final mal = ids is Map ? ids['mal'] : null;
    return mal is num ? mal.toInt() : int.tryParse('$mal');
  }

  static List<SimklMedia> _take(List<SimklMedia> list, int limit) =>
      list.length > limit ? list.sublist(0, limit) : list;
}
