/// The signed-in Simkl user (`GET /users/settings`). Every field is optional on Simkl's side.
class UserProfSimkl {
  final String name;
  final DateTime? joinedAt;
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
    this.joinedAt,
    this.gender = '',
    this.avatar = '',
    this.bio = '',
    this.location = '',
    this.age = '',
    this.accountId = 0,
    this.timezone = '',
    this.accountType = '',
    this.isConnectedToFacebook = false,
  });

  factory UserProfSimkl.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map ? json['user'] as Map : const {};
    final account = json['account'] is Map ? json['account'] as Map : const {};
    final connections = json['connections'] is Map ? json['connections'] as Map : const {};
    String text(Object? v) => v == null ? '' : '$v'.trim();
    return UserProfSimkl(
      name: text(user['name']),
      joinedAt: DateTime.tryParse(text(user['joined_at'])),
      gender: text(user['gender']),
      avatar: text(user['avatar']),
      bio: text(user['bio']),
      location: text(user['loc']),
      age: text(user['age']),
      accountId: account['id'] is num ? (account['id'] as num).toInt() : 0,
      timezone: text(account['timezone']),
      accountType: text(account['type']),
      isConnectedToFacebook: connections['facebook'] == true,
    );
  }
}
