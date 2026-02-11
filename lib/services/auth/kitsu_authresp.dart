class KitsuAuthResponse {
  final String? accessToken;
  final String? tokenType;
  final int? expiresIn;
  final String? refreshToken;
  final DateTime? createdTime;

  KitsuAuthResponse({
    this.accessToken,
    this.tokenType,
    this.expiresIn,
    this.refreshToken,
    this.createdTime,
  });

  factory KitsuAuthResponse.fromJson(Map<String, dynamic> json) {
    DateTime? parseCreatedTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      return DateTime.now();
    }

    return KitsuAuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'],
      createdTime: parseCreatedTime(json["created_at"]),
      refreshToken: json['refresh_token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'refresh_token': refreshToken,
      'created_at': createdTime?.toString(),
    };
  }
}
