class UserProfSimkl {
  final String name;
  final DateTime joinedAt;
  final String gender;
  final String avatar;
  final String bio;
  final String location;
  final String age;
  final int accountId;
  final String timezone;
  final String accountType;
  final bool isConnectedToFacebook;

  UserProfSimkl({
    required this.name,
    required this.joinedAt,
    required this.gender,
    required this.avatar,
    required this.bio,
    required this.location,
    required this.age,
    required this.accountId,
    required this.timezone,
    required this.accountType,
    required this.isConnectedToFacebook,
  });

  factory UserProfSimkl.fromJson(Map<String, dynamic> json) {
    return UserProfSimkl(
      name: json['user']['name'],
      joinedAt: DateTime.parse(json['user']['joined_at']),
      gender: json['user']['gender'],
      avatar: json['user']['avatar'],
      bio: json['user']['bio'],
      location: json['user']['loc'],
      age: json['user']['age'],
      accountId: json['account']['id'],
      timezone: json['account']['timezone'],
      accountType: json['account']['type'],
      isConnectedToFacebook: json['connections']['facebook'],
    );
  }
}
