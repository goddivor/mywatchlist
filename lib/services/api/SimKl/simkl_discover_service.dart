import 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/user_simkl_v2.dart';

export 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart' show SimklTrendingWindow;

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

  /// Trending anime of [window] (CDN), the API's trending list when the CDN fails.
  Future<List<SimklMedia>> trending({
    SimklTrendingWindow window = SimklTrendingWindow.today,
    int limit = 100,
  }) async {
    List<SimklMedia> items;
    try {
      items = await cdn.trending(window);
    } catch (_) {
      items = SimklMedia.listFrom(await _get('/anime/trending', query: {'extended': 'overview'}));
    }
    return _take(items, limit);
  }

  /// The episodes airing on the local day of [date] (today by default), by air time: the CDN
  /// calendar, the API's `/anime/airing` when the CDN fails.
  Future<List<SimklMedia>> airingToday({DateTime? date, int limit = 40}) async {
    final day = date ?? DateTime.now();
    try {
      return _take(await cdn.airingOn(day), limit);
    } catch (_) {
      final text = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      final data = await _get('/anime/airing', query: {'date': text, 'sort': 'time'});
      return _take(SimklMedia.listFrom(data), limit);
    }
  }

  /// The whole CDN calendar (rolling 33 days), by air time.
  Future<List<SimklMedia>> calendar() => cdn.calendar();

  /// `GET /anime/premieres/new`: the latest premieres.
  Future<List<SimklMedia>> premieres({SimklFormat format = SimklFormat.all, int limit = pageSize}) =>
      _premieres('new', format, limit);

  /// `GET /anime/premieres/soon`: the upcoming titles, soonest first.
  Future<List<SimklMedia>> comingSoon({SimklFormat format = SimklFormat.all, int limit = pageSize}) =>
      _premieres('soon', format, limit);

  Future<List<SimklMedia>> _premieres(String which, SimklFormat format, int limit) async {
    final data = await _get('/anime/premieres/$which', query: {
      'type': format.api,
      'limit': '${limit.clamp(1, pageSize)}',
    });
    return _take(SimklMedia.listFrom(data), limit);
  }

  /// `GET /anime/best/{filter}`: the best rated anime of the bucket (Simkl answers `null` when
  /// the format leaves nothing).
  Future<List<SimklMedia>> best({SimklBest filter = SimklBest.all, SimklFormat format = SimklFormat.all}) async {
    final data = await _get('/anime/best/${filter.name}', query: {'type': format.api});
    return SimklMedia.listFrom(data);
  }

  /// `GET /anime/genres/{genre}/{type}/all/all/{sort}`: one page of the genre browse.
  Future<SimklPage> byGenre({
    String genre = 'all',
    SimklFormat format = SimklFormat.all,
    SimklGenreSort sort = SimklGenreSort.popularMonth,
    int page = 1,
  }) async {
    final type = format == SimklFormat.all ? 'all' : format.api;
    final data = await _get('/anime/genres/$genre/$type/all/all/${sort.api}', query: {
      'page': '$page',
      'limit': '$pageSize',
    });
    final items = SimklMedia.listFrom(data);
    return SimklPage(items, hasMore: items.length >= pageSize && page < maxPage);
  }

  /// `GET /search/anime`.
  Future<List<SimklMedia>> search(String query, {int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _get('/search/anime', query: {
      'q': q,
      'limit': '$limit',
      'extended': 'full',
    });
    return SimklMedia.listFrom(data);
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
