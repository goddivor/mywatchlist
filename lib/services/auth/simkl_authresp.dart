class SimklAuthResponse {
  final String accessToken;
  final String tokenType;
  final String scope;

  SimklAuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.scope,
  });

  factory SimklAuthResponse.fromJson(Map<String, dynamic> json) {
    return SimklAuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      scope: json['scope'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'scope': scope,
    };
  }
}
