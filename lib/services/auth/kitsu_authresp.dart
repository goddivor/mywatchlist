class KitsuAuthResponse {
  final String? accessToken;
  final String? tokenType;
  final int? expiresIn;
  final String? refreshToken;
  // final DateTime? createdTime;

  KitsuAuthResponse(
      {this.accessToken, 
      this.tokenType, 
      this.expiresIn, 
      this.refreshToken,
      // this.createdTime
      });

  factory KitsuAuthResponse.fromJson(Map<String, dynamic> json) {
    return KitsuAuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'],
      // createdTime: json["created_at"] != null
      //           ? (DateTime.tryParse(json["created_at"]))
      //           : DateTime.now(),
      refreshToken: json['refresh_token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
      'refresh_token': refreshToken,
      // 'created_at': createdTime.toString()
    };
  }
}
