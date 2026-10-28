import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/simkl_auth.dart';
import 'package:mywatchlist/services/auth/simkl_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/accounts/account_manager.dart';

/// The Simkl session, AUTH V1 or AUTH V2 side by side (Simkl's "run both client IDs" migration).
///
/// A V2 session (`simkl_at_` token) renews itself through `/oauth2/token` with its refresh token,
/// in [BaseUser.sendAuthenticated] (60 s before expiry, or once on a 401). A V1 session stored by
/// an older build keeps working unchanged until Simkl retires V1 (around April 2027): it has no
/// refresh token, so a 401 still asks to sign in again, and that sign in goes through V2 when a
/// V2 client id is configured. A token only works with the client id it was issued for:
/// [apiClientId] is the one every call of this session must send.
class UserSimklV2 extends BaseUser<SimklAuthResponse> {
  static final UserSimklV2 _instance = UserSimklV2._internal();

  factory UserSimklV2() {
    return _instance;
  }

  UserSimklV2._internal();

  static UserSimklV2 get instance => _instance;

  // Storage keys (unchanged: a V1 session saved by an older build is read as is).
  @override
  String get authResponseKey => 'simkl_auth_response';

  @override
  String get usernameKey => 'simkl_username';

  @override
  String get profileImageKey => 'simkl_profile_image';

  /// Whether the stored session uses AUTH V2 tokens.
  bool get isV2Session => authResponse?.isV2 ?? false;

  /// A V1 session that a V2 sign in could replace (settings may offer "Reconnect").
  bool get canUpgradeToV2 =>
      authResponse != null && !isV2Session && SimklOAuth2.isConfigured;

  /// The client id that goes with the session's token (`client_id` / `simkl-api-key`).
  /// Without a session it is the V1 one, the only one Simkl still serves anonymously.
  String get apiClientId => isV2Session ? SimklOAuth2.clientId : Constants.simklClientId;

  // OAuth configuration, following the session's version.
  @override
  String get clientId => apiClientId;

  /// V2 apps of the "Mobile, desktop & browser" type have no secret.
  @override
  String get clientSecret => isV2Session ? '' : Constants.simklClientSecret;

  @override
  String get redirectUri => Constants.simklRedirectUri;

  @override
  String get tokenEndPoint =>
      isV2Session ? SimklOAuth2.tokenUri.toString() : Constants.simklTokenEndPoint;

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

  /// V2: issue time + 7 days. V1 tokens carry no expiry: null, the 401 path handles them.
  @override
  DateTime? get tokenExpiryTime {
    final created = authResponse?.createdTime;
    final expires = authResponse?.expiresIn;
    if (created == null || expires == null) return null;
    return created.add(Duration(seconds: expires));
  }

  /// Only V2 sessions renew silently; V1 never had a refresh token.
  @override
  bool get supportsRefresh => isV2Session && super.supportsRefresh;

  /// `refresh_token` grant on `/oauth2/token`: client id only (no secret), form encoded.
  @override
  Future<http.Response> sendRefreshRequest(http.Client client, String refreshTok) =>
      SimklOAuth2.postForm(
        client,
        SimklOAuth2.tokenUri,
        SimklOAuth2.refreshGrant(refreshToken: refreshTok, clientId: SimklOAuth2.clientId),
      );

  // Clear override to include AccountManager
  @override
  void clear() {
    super.clear();
    AccountManager().clear();
  }
}
