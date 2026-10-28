/// Simkl tokens, AUTH V1 or AUTH V2.
///
/// V1 (`/oauth/token`): one access token, valid for years, no refresh token, no expiry, no
/// scope (full access). V2 (`/oauth2/token`): a `simkl_at_` access token valid 7 days, a
/// `simkl_rt_` refresh token (180 days, slid forward on use) and the granted scope.
class SimklAuthResponse {
  /// The access token, sent exactly as issued (matching is case-sensitive).
  final String? accessToken;

  /// `bearer` (V1) or `Bearer` (V2): compare without case.
  final String? tokenType;

  /// The scope granted: `media:read` or `media:read media:write` (V2), null for V1.
  final String? scope;

  /// The refresh token (V2 only).
  final String? refreshToken;

  /// Access token lifetime in seconds from [createdTime] (V2: 604800); null = no expiry.
  final int? expiresIn;

  /// When the access token was issued (the time it was received).
  final DateTime? createdTime;

  SimklAuthResponse({
    this.accessToken,
    this.tokenType,
    this.scope,
    this.refreshToken,
    this.expiresIn,
    this.createdTime,
  });

  /// Whether these are AUTH V2 tokens (the access token's prefix says so, no call needed).
  bool get isV2 => accessToken != null && accessToken!.startsWith('simkl_at_');

  /// Whether the session may write to the list. V1 tokens are full access; a V2 grant without
  /// `media:write` is read only.
  bool get canWrite => !isV2 || (scope ?? '').split(' ').contains('media:write');

  factory SimklAuthResponse.fromJson(Map<String, dynamic> json) {
    final expires = json['expires_in'];
    final created = json['created_time'];
    return SimklAuthResponse(
      accessToken: json['access_token'] as String?,
      tokenType: json['token_type'] as String?,
      scope: json['scope'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: expires is num ? expires.toInt() : int.tryParse('${expires ?? ''}'),
      createdTime: created is String ? DateTime.tryParse(created) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        'scope': scope,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
        'created_time': createdTime?.toIso8601String(),
      };

  @override
  String toString() => 'SimklAuthResponse(${isV2 ? 'v2' : 'v1'}, scope: $scope)';
}
