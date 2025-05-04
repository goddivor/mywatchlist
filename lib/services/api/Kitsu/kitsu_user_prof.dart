class KitsuUserProf {
  final String name;
  final String about;
  final String location;
  final String waifu;
  final String waifuOrHusbando;
  final String proHero;
  final String proHeroFull;
  final int followersCount;
  final int followingCount;
  final String gender;
  final String birthday;
  final String joinDate;
  final String avatar;

  KitsuUserProf({
    required this.name,
    required this.about,
    required this.location,
    required this.waifu,
    required this.waifuOrHusbando,
    required this.proHero,
    required this.proHeroFull,
    required this.followersCount,
    required this.followingCount,
    required this.gender,
    required this.birthday,
    required this.joinDate,
    required this.avatar,
  });

  factory KitsuUserProf.fromJson(Map<String, dynamic> json) {
    return KitsuUserProf(
      name: json['name'],
      about: json['about'] ?? '',
      location: json['location'] ?? '',
      waifu: json['waifu'] ?? '',
      waifuOrHusbando: json['waifu_or_husbando'] ?? '',
      proHero: json['pro_hero'] ?? '',
      proHeroFull: json['pro_hero_full'] ?? '',
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      gender: json['gender'] ?? '',
      birthday: json['birthday'] ?? '',
      joinDate: json['created_at'] ?? '',
      avatar: json['avatar']['original'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'about': about,
      'location': location,
      'waifu': waifu,
      'waifu_or_husbando': waifuOrHusbando,
      'pro_hero': proHero,
      'pro_hero_full': proHeroFull,
      'followers_count': followersCount,
      'following_count': followingCount,
      'gender': gender,
      'birthday': birthday,
      'join_date': joinDate,
      'avatar': avatar,
    };
  }
}
