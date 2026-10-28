import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';

/// Public Simkl catalogue calls (no session needed): trending, premieres, airing today, search
/// and the lookup of a title's MyAnimeList id.
class SimklDiscoverService {
  SimklDiscoverService({SimklClient? client}) : _client = client ?? SimklClient.instance;

  static SimklDiscoverService instance = SimklDiscoverService();

  final SimklClient _client;

  /// `GET /anime/trending`.
  Future<List<SimklMedia>> trending({int limit = 30}) async => _take(
        SimklMedia.listFrom(await _client.getPublic('/anime/trending', query: {'extended': 'overview'})),
        limit,
      );

  /// `GET /anime/premieres/new`: the latest premieres.
  Future<List<SimklMedia>> premieres({int limit = 30}) async => _take(
        SimklMedia.listFrom(await _client.getPublic('/anime/premieres/new', query: {'extended': 'overview'})),
        limit,
      );

  /// `GET /anime/airing`: the episodes airing on [date] (today by default), by air time.
  Future<List<SimklMedia>> airingToday({DateTime? date, int limit = 40}) async {
    final day = date ?? DateTime.now();
    final text = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final data = await _client.getPublic('/anime/airing', query: {'date': text, 'sort': 'time'});
    return _take(SimklMedia.listFrom(data), limit);
  }

  /// `GET /search/anime`.
  Future<List<SimklMedia>> search(String query, {int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final data = await _client.getPublic('/search/anime', query: {
      'q': q,
      'limit': '$limit',
      'extended': 'full',
    });
    return SimklMedia.listFrom(data);
  }

  /// The MyAnimeList id of a Simkl title (`GET /anime/{id}`), null when Simkl has none.
  Future<int?> malIdOf(int simklId) async {
    final data = await _client.getPublic('/anime/$simklId');
    final ids = data is Map ? data['ids'] : null;
    final mal = ids is Map ? ids['mal'] : null;
    return mal is num ? mal.toInt() : int.tryParse('$mal');
  }

  static List<SimklMedia> _take(List<SimklMedia> list, int limit) =>
      list.length > limit ? list.sublist(0, limit) : list;
}
