/// A class representing the authentication response from Simkl.
class SimklAuthResponse {
  /// The access token provided by Simkl.
  final String? accessToken;

  /// The type of the token (e.g., Bearer).
  final String? tokenType;

  /// The scope of the access granted by the token.
  final String? scope;

  /// The refresh token (Simkl doesn't provide refresh tokens, so this is null)
  final String? refreshToken;

  /// Token expiration time in seconds (Simkl doesn't provide this, so we store it manually)
  final int? expiresIn;

  /// The timestamp when this token was created
  final DateTime? createdTime;

  /// Constructor for creating a [SimklAuthResponse] instance.
  SimklAuthResponse({
    this.accessToken,
    this.tokenType,
    this.scope,
    this.refreshToken,
    this.expiresIn,
    this.createdTime,
  });

  /// Factory constructor to create a [SimklAuthResponse] instance from a JSON map.
  ///
  /// Expects keys `access_token`, `token_type`, and `scope` in the JSON map.
  factory SimklAuthResponse.fromJson(Map<String, dynamic> json) {
    return SimklAuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      scope: json['scope'],
      refreshToken: json['refresh_token'], // Usually null for Simkl
      expiresIn: json['expires_in'], // Usually null for Simkl
      createdTime: json['created_time'] != null
          ? DateTime.tryParse(json['created_time'])
          : DateTime.now(),
    );
  }

  /// Converts the [SimklAuthResponse] instance to a JSON map.
  ///
  /// Returns a map with keys `access_token`, `token_type`, and `scope`.
  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'scope': scope,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'created_time': createdTime?.toString(),
    };
  }
}
