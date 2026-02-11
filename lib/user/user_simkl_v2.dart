import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/simkl_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/accounts/account_manager.dart';

/// UserSimkl v2 - Inherits from BaseUser with auto-refresh and retry logic
class UserSimklV2 extends BaseUser<SimklAuthResponse> {
  static final UserSimklV2 _instance = UserSimklV2._internal();

  factory UserSimklV2() {
    return _instance;
  }

  UserSimklV2._internal();

  static UserSimklV2 get instance => _instance;

  // Storage keys
  @override
  String get authResponseKey => 'simkl_auth_response';

  @override
  String get usernameKey => 'simkl_username';

  @override
  String get profileImageKey => 'simkl_profile_image';

  // OAuth configuration
  @override
  String get clientId => Constants.simklClientId;

  @override
  String get clientSecret => Constants.simklClientSecret;

  @override
  String get redirectUri => Constants.simklRedirectUri;

  @override
  String get tokenEndPoint => Constants.simklTokenEndPoint;

  // AuthResponse serialization
  @override
  SimklAuthResponse? authResponseFromJson(Map<String, dynamic> json) {
    return SimklAuthResponse.fromJson(json);
  }

  @override
  Map<String, dynamic>? authResponseToJson(SimklAuthResponse? response) {
    return response?.toJson();
  }

  // Token getters
  @override
  String? get accessToken => authResponse?.accessToken;

  @override
  String? get refreshToken => authResponse?.refreshToken;

  @override
  DateTime? get tokenExpiryTime {
    // Simkl tokens don't expire (or expiry is not provided by API)
    // Return null to indicate no expiration tracking
    if (authResponse?.createdTime == null || authResponse?.expiresIn == null) {
      return null;
    }
    return authResponse!.createdTime!.add(Duration(seconds: authResponse!.expiresIn!));
  }

  // Override refresh token since Simkl doesn't provide refresh tokens
  @override
  Future<bool> refreshAccessToken() async {
    print('Simkl does not support refresh tokens');
    return false;
  }

  // Clear override to include AccountManager
  @override
  void clear() {
    super.clear();
    AccountManager().clear();
  }
}
