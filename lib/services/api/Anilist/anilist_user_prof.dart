class AnilistUserProf {
  final int id;
  final String name;
  final String avatarUrl;
  final String? bannerImage;
  final String? about;
  final bool isFollowing;
  final bool isBlocked;
  final List<String> bans;

  AnilistUserProf({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.bannerImage,
    this.about,
    required this.isFollowing,
    required this.isBlocked,
    required this.bans,
  });

  factory AnilistUserProf.fromJson(Map<String, dynamic> json) {
    return AnilistUserProf(
      id: json['id'],
      name: json['name'],
      avatarUrl: json['avatar']['large'],
      bannerImage: json['bannerImage'],
      about: json['about'],
      isFollowing: json['isFollowing'],
      isBlocked: json['isBlocked'],
      bans: List<String>.from(json['bans']),
    );
  }
}
