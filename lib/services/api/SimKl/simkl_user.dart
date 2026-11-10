import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';

/// The signed-in user's Simkl calls. Every request runs through [SimklClient]
/// (`UserSimklV2.sendAuthenticated`): no Bearer header is built here, a 401 means sign in again
/// (`SimklSessionExpired`).
class SimklUser {
  SimklUser({SimklClient? client}) : _client = client ?? SimklClient.instance;

  final SimklClient _client;

  /// `GET /users/settings`.
  Future<UserProfSimkl> getUserInfo() async {
    final data = await _client.getAuth('/users/settings');
    if (data is! Map<String, dynamic>) throw const FormatException('Simkl settings');
    return UserProfSimkl.fromJson(data);
  }

  Map<String, dynamic> _map(Object? data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};

  /// `GET /sync/all-items/{type}`.
  Future<Map<String, dynamic>> syncAllItems({String type = 'anime'}) async =>
      _map(await _client.getAuth('/sync/all-items/$type'));

  /// `POST /sync/add-to-list`; [body] is `{"anime": [...], "shows": [...], "movies": [...]}`.
  Future<Map<String, dynamic>> addToList(Map<String, dynamic> body) async =>
      _map(await _client.postAuth('/sync/add-to-list', body));

  /// `POST /sync/remove-from-list`.
  Future<Map<String, dynamic>> removeFromList(Map<String, dynamic> body) async =>
      _map(await _client.postAuth('/sync/remove-from-list', body));

  /// `GET /sync/watchlist/{type}`.
  Future<Map<String, dynamic>> getWatchlist({String type = 'anime'}) async =>
      _map(await _client.getAuth('/sync/watchlist/$type'));

  /// `GET /sync/history/{type}`.
  Future<Map<String, dynamic>> getWatchHistory({String type = 'anime'}) async =>
      _map(await _client.getAuth('/sync/history/$type'));
}
