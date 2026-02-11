import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/anilist_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/accounts/account_manager.dart';

/// UserAnilist v2 - Inherits from BaseUser with auto-refresh and retry logic
class UserAnilistV2 extends BaseUser<AnilistAuthResponse> {
  static final UserAnilistV2 _instance = UserAnilistV2._internal();

  factory UserAnilistV2() {
    return _instance;
  }

  UserAnilistV2._internal();

  static UserAnilistV2 get instance => _instance;

  // Storage keys
  @override
  String get authResponseKey => 'anilist_auth_response';

  @override
  String get usernameKey => 'anilist_username';

  @override
  String get profileImageKey => 'anilist_profile_image';

  // OAuth configuration
  @override
  String get clientId => Constants.anilistClientId;

  @override
  String get clientSecret => Constants.anilistClientSecret;

  @override
  String get redirectUri => Constants.anilistRedirectUri;

  @override
  String get tokenEndPoint => Constants.anilistTokenEndPoint;

  // AuthResponse serialization
  @override
  AnilistAuthResponse? authResponseFromJson(Map<String, dynamic> json) {
    return AnilistAuthResponse.fromJson(json);
  }

  @override
  Map<String, dynamic>? authResponseToJson(AnilistAuthResponse? response) {
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
