import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';

/// Minimal user, same refresh behaviour as UserMalV2 without its singleton.
class FakeUser extends BaseUser<AuthResponse> {
  FakeUser({this.refreshable = true});

  final bool refreshable;

  @override
  bool get supportsRefresh =>
      refreshable && (refreshToken?.isNotEmpty ?? false);
  @override
  String get authResponseKey => 'fake_auth';
  @override
  String get usernameKey => 'fake_user';
  @override
  String get profileImageKey => 'fake_img';
  @override
  String get clientId => 'cid';
  @override
  String get clientSecret => 'sec';
  @override
  String get redirectUri => 'app://cb';
  @override
  String get tokenEndPoint => 'https://auth.test/token';
  @override
  AuthResponse? authResponseFromJson(Map<String, dynamic> json) =>
      AuthResponse.fromJson(json);
  @override
  Map<String, dynamic>? authResponseToJson(AuthResponse? r) => r?.toJson();
  @override
  String? get accessToken => authResponse?.accessToken;
  @override
  String? get refreshToken => authResponse?.refreshToken;
  @override
  DateTime? get tokenExpiryTime {
    final a = authResponse;
    if (a?.createdTime == null || a?.expiresIn == null) return null;
    return a!.createdTime!.add(Duration(seconds: a.expiresIn!));
  }
}
