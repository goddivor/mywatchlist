import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_user_prof.dart';

/// The signed-in Kitsu user: identity and library calls.
///
/// Every request goes through [KitsuHttp], so tokens are refreshed and replayed by
/// `UserKitsuV2.sendAuthenticated` and no call builds its own Bearer header.
class KitsuUser {
  KitsuUser({KitsuHttp? http, KitsuLibrary? library})
      : _http = http,
        _library = library;

  final KitsuHttp? _http;
  final KitsuLibrary? _library;
  KitsuHttp get _client => _http ?? KitsuHttp.instance;
  KitsuLibrary get _lib => _library ?? KitsuLibrary.instance;

  /// Kitsu id of the signed-in user.
  Future<String?> getSelfUserId() async {
    try {
      return await _lib.userId();
    } on KitsuSessionExpired {
      return null;
    }
  }

  /// The signed-in user's profile attributes (name, avatar…); throws when the request fails.
  Future<KitsuUserProf> getUserInfo() async {
    final json = await _client.getJson('/users', query: {'filter[self]': 'true'}, auth: true);
    final data = KitsuDocument.from(json).data;
    if (data.isEmpty) throw const KitsuHttpError(404);
    return KitsuUserProf.fromJson(kitsuAttrs(data.first));
  }

  /// The raw library entry of media [mediaId] (`anime` or `manga` [mediaType]), or null.
  Future<Map<String, dynamic>?> getLibraryEntryForMedia({
    required String mediaId,
    required String mediaType,
  }) async {
    final id = int.tryParse(mediaId);
    if (id == null) return null;
    final entry = await _lib.entryIdOf(id, isAnime: mediaType == 'anime');
    if (entry == null) return null;
    return {'id': entry, 'type': 'libraryEntries'};
  }

  /// Changes status, progress or rating (0-20, Kitsu's own scale) of library entry [entryId].
  Future<void> updateLibraryEntry({
    required String entryId,
    String? status,
    int? progress,
    double? ratingTwenty,
  }) =>
      _lib.update(entryId, {
        if (status != null) 'status': status,
        if (progress != null) 'progress': progress,
        if (ratingTwenty != null) 'ratingTwenty': ratingTwenty.round(),
      });
}
