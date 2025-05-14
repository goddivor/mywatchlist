/// A class representing the authentication response from Simkl.
class SimklAuthResponse {
  /// The access token provided by Simkl.
  final String accessToken;

  /// The type of the token (e.g., Bearer).
  final String tokenType;

  /// The scope of the access granted by the token.
  final String scope;

  /// Constructor for creating a [SimklAuthResponse] instance.
  /// 
  /// Requires [accessToken], [tokenType], and [scope] to be provided.
  SimklAuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.scope,
  });

  /// Factory constructor to create a [SimklAuthResponse] instance from a JSON map.
  /// 
  /// Expects keys `access_token`, `token_type`, and `scope` in the JSON map.
  factory SimklAuthResponse.fromJson(Map<String, dynamic> json) {
    return SimklAuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      scope: json['scope'],
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
    };
  }
}
