import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/accounts/account_manager.dart';

/// UserMal v2 - Inherits from BaseUser with auto-refresh and retry logic
class UserMalV2 extends BaseUser<AuthResponse> {
  static final UserMalV2 _instance = UserMalV2._internal();

  factory UserMalV2() {
    return _instance;
  }

  UserMalV2._internal();

  static UserMalV2 get instance => _instance;

  // Storage keys
  @override
  String get authResponseKey => 'mal_auth_response';

  @override
  String get usernameKey => 'mal_username';

  @override
  String get profileImageKey => 'mal_profile_image';

  // OAuth configuration
  @override
  String get clientId => Constants.malclientId;

  @override
  String get clientSecret => Constants.malClientSecret;

  @override
  String get redirectUri => Constants.malredirectUri;

  @override
  String get tokenEndPoint => Constants.maltokenEndPoint;

  // AuthResponse serialization
  @override
  AuthResponse? authResponseFromJson(Map<String, dynamic> json) {
    return AuthResponse.fromJson(json);
  }

  @override
  Map<String, dynamic>? authResponseToJson(AuthResponse? response) {
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
}
