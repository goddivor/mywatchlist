// ignore_for_file: library_private_types_in_public_api

class PersonFull {
  final int? malId;
  final String? url;
  final String? websiteUrl;
  final Images? images;
  final String? name;
  final String? givenName;
  final String? familyName;
  final List<String>? alternateNames;
  final String? birthday;
  final int? favorites;
  final String? about;
  final List<_AnimeStaff>? anime;
  final List<_MangaStaff>? manga;
  final List<_VoiceRole>? voices;

  PersonFull({
    this.malId,
    this.url,
    this.websiteUrl,
    this.images,
    this.name,
    this.givenName,
    this.familyName,
    this.alternateNames,
    this.birthday,
    this.favorites,
    this.about,
    this.anime,
    this.manga,
    this.voices,
  });

  factory PersonFull.fromJson(Map<String, dynamic> json) {
    return PersonFull(
      malId: json['mal_id'],
      url: json['url'],
      websiteUrl: json['website_url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      name: json['name'],
      givenName: json['given_name'],
      familyName: json['family_name'],
      alternateNames: json['alternate_names'] != null ? List<String>.from(json['alternate_names']) : null,
      birthday: json['birthday'],
      favorites: json['favorites'],
      about: json['about'],
      anime: json['anime'] != null ? (json['anime'] as List).map((e) => _AnimeStaff.fromJson(e)).toList() : null,
      manga: json['manga'] != null ? (json['manga'] as List).map((e) => _MangaStaff.fromJson(e)).toList() : null,
      voices: json['voices'] != null ? (json['voices'] as List).map((e) => _VoiceRole.fromJson(e)).toList() : null,
    );
  }
}

class Images {
  final ImageFormat? jpg;

  Images({this.jpg});

  factory Images.fromJson(Map<String, dynamic> json) {
    return Images(
      jpg: json['jpg'] != null ? ImageFormat.fromJson(json['jpg']) : null,
    );
  }
}

class ImageFormat {
  final String? imageUrl;

  ImageFormat({this.imageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: json['image_url'],
    );
  }
}

class _AnimeStaff {
  final String? position;
  final _Anime? anime;

  _AnimeStaff({this.position, this.anime});

  factory _AnimeStaff.fromJson(Map<String, dynamic> json) {
    return _AnimeStaff(
      position: json['position'],
      anime: json['anime'] != null ? _Anime.fromJson(json['anime']) : null,
    );
  }
}

class _MangaStaff {
  final String? position;
  final _Manga? manga;

  _MangaStaff({this.position, this.manga});

  factory _MangaStaff.fromJson(Map<String, dynamic> json) {
    return _MangaStaff(
      position: json['position'],
      manga: json['manga'] != null ? _Manga.fromJson(json['manga']) : null,
    );
  }
}

class _VoiceRole {
  final String? role;
  final _Anime? anime;
  final _Character? character;

  _VoiceRole({this.role, this.anime, this.character});

  factory _VoiceRole.fromJson(Map<String, dynamic> json) {
    return _VoiceRole(
      role: json['role'],
      anime: json['anime'] != null ? _Anime.fromJson(json['anime']) : null,
      character: json['character'] != null ? _Character.fromJson(json['character']) : null,
    );
  }
}

class _Anime {
  final int? malId;
  final String? url;
  final Images? images;
  final String? title;

  _Anime({
    this.malId,
    this.url,
    this.images,
    this.title,
  });

  factory _Anime.fromJson(Map<String, dynamic> json) {
    return _Anime(
      malId: json['mal_id'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      title: json['title'],
    );
  }
}

class _Manga {
  final int? malId;
  final String? url;
  final Images? images;
  final String? title;

  _Manga({
    this.malId,
    this.url,
    this.images,
    this.title,
  });

  factory _Manga.fromJson(Map<String, dynamic> json) {
    return _Manga(
      malId: json['mal_id'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      title: json['title'],
    );
  }
}

class _Character {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;

  _Character({
    this.malId,
    this.url,
    this.images,
    this.name,
  });

  factory _Character.fromJson(Map<String, dynamic> json) {
    return _Character(
      malId: json['mal_id'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      name: json['name'],
    );
  }
}
