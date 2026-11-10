import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart';

/// A MyAnimeList user profile as the official API (`/users/@me`) or the Jikan fallback
/// (other users) describes it. Every field the API may omit has a safe default.
class MalUserProf {
  final int id;
  final String name;
  final String location;
  final String? gender;
  final DateTime? birthday;
  /// The account's time zone (`time_zone`, an IANA name such as `Africa/Lome`); own profile
  /// only, empty when MAL gives none.
  final String timezone;

  /// Whether the account is a MyAnimeList Supporter (`is_supporter`); own profile only.
  final bool isSupporter;
  final String joinedAt;
  final String picture;
  final UserAnimeStatistics animeStatistics;

  MalUserProf({
    required this.gender,
    required this.birthday,
    required this.timezone,
    this.isSupporter = false,
    required this.picture,
    required this.id,
    required this.name,
    required this.location,
    required this.joinedAt,
    required this.animeStatistics,
  });

  factory MalUserProf.fromJson(Map<String, dynamic> json) {
    final birthday = json['birthday'];
    return MalUserProf(
      gender: json['gender'] as String?,
      // A missing or blank birthday is normal (users may hide it).
      birthday: birthday is String ? DateTime.tryParse(birthday) : null,
      // The API key is `time_zone`; `timezone` is what older cached profiles stored.
      timezone: (json['time_zone'] ?? json['timezone']) as String? ?? '',
      isSupporter: json['is_supporter'] == true,
      picture: json['picture'] as String? ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      joinedAt: json['joined_at'] as String? ?? '',
      animeStatistics: UserAnimeStatistics.fromJson(
          json['anime_statistics'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'gender': gender,
        'birthday': birthday?.toIso8601String(),
        'time_zone': timezone,
        'is_supporter': isSupporter,
        'joined_at': joinedAt,
        'picture': picture,
        'anime_statistics': animeStatistics.toJson(),
      };
}
