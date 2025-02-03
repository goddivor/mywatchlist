/// Represents the authentication response from the MyAnimeList API.
/// This class encapsulates the data received after a successful authentication.
class AuthResponse {
  final String? tokenType; /// The type of token, typically "Bearer".
  final int? expiresIn; /// The number of seconds until the access token expires.
  final String? accessToken; /// The access token used for authenticated API requests.
  final String? refreshToken; /// The refresh token used to obtain a new access token when the current one expires.
  final DateTime? createdTime; /// The timestamp when this authentication response was created.

  /// Constructs an AuthResponse instance.
  ///
  /// All parameters are optional to allow for partial or empty responses.
  AuthResponse(
      {this.accessToken,
      this.expiresIn,
      this.refreshToken,
      this.tokenType,
      this.createdTime});

  /// Creates an AuthResponse instance from a JSON map.
  ///
  /// If the JSON is null, an empty AuthResponse is returned.
  /// The 'created_time' is parsed from the JSON if present, otherwise set to the current time.
  factory AuthResponse.fromJson(Map<String, dynamic>? json) {
    return json != null
        ? AuthResponse(
            accessToken: json["access_token"],
            expiresIn: json["expires_in"],
            tokenType: json["token_type"],
            createdTime: json["created_time"] != null
                ? (DateTime.tryParse(json["created_time"]))
                : DateTime.now(),
            refreshToken: json["refresh_token"])
        : AuthResponse();
  }

 /// Converts the AuthResponse instance to a JSON map.
  ///
  /// This method is useful for storing the authentication response or sending it in requests.
  Map<String, dynamic> toJson() {
    return {
      "access_token": accessToken,
      "expires_in": expiresIn,
      "token_type": tokenType,
      "refresh_token": refreshToken,
      "created_time": createdTime.toString()
    };
  }
}
