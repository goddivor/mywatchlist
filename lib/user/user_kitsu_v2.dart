import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/auth/kitsu_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/accounts/account_manager.dart';

/// UserKitsu v2 - Inherits from BaseUser with auto-refresh and retry logic
class UserKitsuV2 extends BaseUser<KitsuAuthResponse> {
  static final UserKitsuV2 _instance = UserKitsuV2._internal();

  factory UserKitsuV2() {
    return _instance;
  }

  UserKitsuV2._internal();

  static UserKitsuV2 get instance => _instance;

  // Storage keys
  @override
  String get authResponseKey => 'kitsu_auth_response';

  @override
  String get usernameKey => 'kitsu_username';

  @override
  String get profileImageKey => 'kitsu_profile_image';

  // OAuth configuration - Note: Kitsu uses password auth, not OAuth 2.0
  // These are placeholder values for compatibility with BaseUser
  @override
  String get clientId => '';

  @override
  String get clientSecret => '';

  @override
  String get redirectUri => '';

  @override
  String get tokenEndPoint => 'https://kitsu.io/api/oauth/token';

  // AuthResponse serialization
  @override
  KitsuAuthResponse? authResponseFromJson(Map<String, dynamic> json) {
    return KitsuAuthResponse.fromJson(json);
  }

  @override
  Map<String, dynamic>? authResponseToJson(KitsuAuthResponse? response) {
    return response?.toJson();
  }

  // Token getters
  @override
  String? get accessToken => authResponse?.accessToken;

  @override
  String? get refreshToken => authResponse?.refreshToken;

  @override
  DateTime? get tokenExpiryTime {
    if (authResponse?.createdTime == null || authResponse?.expiresIn == null) {
      return null;
    }
    return authResponse!.createdTime!.add(Duration(seconds: authResponse!.expiresIn!));
  }

  // Clear override to include AccountManager
  @override
  void clear() {
    super.clear();
    AccountManager().clear();
  }

  // Kitsu expects a JSON body on its token endpoint.
  @override
  Future<http.Response> sendRefreshRequest(
      http.Client client, String refreshTok) {
    return client.post(
      Uri.parse(tokenEndPoint),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'grant_type': 'refresh_token',
        'refresh_token': refreshTok,
      }),
    );
  }
}
