import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart';

class MalUserProf {
  final int id;
  final String name;
  final String location;
  final String? gender;
  final DateTime? birthday;
  final String timezone;
  final String joinedAt;
  final String picture;
  final UserAnimeStatistics animeStatistics;

  MalUserProf({
    required this.gender,
    required this.birthday,
    required this.timezone,
    required this.picture,
    required this.id,
    required this.name,
    required this.location,
    required this.joinedAt,
    required this.animeStatistics,
  });

  factory MalUserProf.fromJson(Map<String, dynamic> json) {
    return MalUserProf(
      gender: json['gender'] ?? '',
      birthday: DateTime.tryParse(json['birthday']),
      timezone: json['timezone'] ?? '',
      picture: json['picture'] ?? '',
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      joinedAt: json['joined_at'] ?? '',
      animeStatistics: UserAnimeStatistics.fromJson(json['anime_statistics']),
    );
  }
}
