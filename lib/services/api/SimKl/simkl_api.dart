import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';

/// Simkl catalogue lookups used outside the Simkl pages (tracker search, sync dialog), through
/// [SimklClient] (app identification, 429 back-off).
///
/// AUTH V2 keeps only lookups by Simkl id anonymous; search and the browse lists need the user's
/// token. So a search runs with the signed-in session when there is one and anonymously (V1
/// client id, served until V1 retires) otherwise; a title by id is always anonymous, as Simkl
/// asks for its cached catalogue endpoints.
class SimklApi {
  SimklApi({SimklClient? client, bool Function()? signedIn})
      : _client = client ?? sessionClient,
        _signedIn = signedIn ?? _hasSession;

  /// Client whose client id follows the session's AUTH version (a token only works with the
  /// client id it was issued for). Shared by the auth flow and the sync clients.
  static final SimklClient sessionClient =
      SimklClient(clientId: () => UserSimklV2.instance.apiClientId);

  final SimklClient _client;
  final bool Function() _signedIn;

  static bool _hasSession() {
    final user = UserSimklV2.instance;
    return user.accessToken != null && !user.needsReLogin;
  }

  /// GET with the token when signed in, else anonymous. A dead session falls back to the
  /// anonymous call so a lookup never fails only because the session expired.
  Future<dynamic> _get(String path, Map<String, String> query) async {
    if (_signedIn()) {
      try {
        return await _client.getAuth(path, query: query);
      } on SimklSessionExpired {
        // fall through
      }
    }
    return _client.getPublic(path, query: query);
  }

  static List<Map<String, dynamic>> _maps(Object? data) =>
      data is List ? data.whereType<Map<String, dynamic>>().toList() : const [];

  static Map<String, String> _searchQuery(String query, int? page, int? limit) => {
        'q': query,
        'extended': 'full',
        if (page != null) 'page': '$page',
        if (limit != null) 'limit': '$limit',
      };

  /// `GET /search/anime`.
  Future<List<Map<String, dynamic>>> searchAnime(String query, {int? page, int? limit}) async =>
      _maps(await _get('/search/anime', _searchQuery(query, page, limit)));

  /// `GET /search/tv`.
  Future<List<Map<String, dynamic>>> searchTv(String query, {int? page, int? limit}) async =>
      _maps(await _get('/search/tv', _searchQuery(query, page, limit)));

  /// `GET /search/movie`.
  Future<List<Map<String, dynamic>>> searchMovie(String query, {int? page, int? limit}) async =>
      _maps(await _get('/search/movie', _searchQuery(query, page, limit)));

  /// `GET /anime/{id}` (cached catalogue, anonymous on V1 and V2, no Authorization header).
  Future<Map<String, dynamic>> getAnimeDetails(int id) async {
    final data = await _client.getPublic('/anime/$id', query: {'extended': 'full'});
    if (data is! Map<String, dynamic>) throw const SimklHttpError(404);
    return data;
  }
}
