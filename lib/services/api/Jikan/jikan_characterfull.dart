// ignore_for_file: library_private_types_in_public_api

class CharacterFull {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;
  final String? nameKanji;
  final List<String>? nicknames;
  final int? favorites;
  final String? about;
  final List<Animeography>? anime;
  final List<Mangaography>? manga;
  final List<VoiceActor>? voices;

  CharacterFull({
    this.malId,
    this.url,
    this.images,
    this.name,
    this.nameKanji,
    this.nicknames,
    this.favorites,
    this.about,
    this.anime,
    this.manga,
    this.voices,
  });

  factory CharacterFull.fromJson(Map<String, dynamic> json) {
    return CharacterFull(
      malId: json['mal_id'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      name: json['name'],
      nameKanji: json['name_kanji'],
      nicknames: json['nicknames'] != null ? List<String>.from(json['nicknames']) : null,
      favorites: json['favorites'],
      about: json['about'],
      anime: json['anime'] != null ? (json['anime'] as List).map((e) => Animeography.fromJson(e)).toList() : null,
      manga: json['manga'] != null ? (json['manga'] as List).map((e) => Mangaography.fromJson(e)).toList() : null,
      voices: json['voices'] != null ? (json['voices'] as List).map((e) => VoiceActor.fromJson(e)).toList() : null,
    );
  }
}

class Images {
  final ImageFormat? jpg;
  final ImageFormat? webp;

  Images({this.jpg, this.webp});

  factory Images.fromJson(Map<String, dynamic> json) {
    return Images(
      jpg: json['jpg'] != null ? ImageFormat.fromJson(json['jpg']) : null,
      webp: json['webp'] != null ? ImageFormat.fromJson(json['webp']) : null,
    );
  }
}

class ImageFormat {
  final String? imageUrl;
  final String? smallImageUrl;
  final String? largeImageUrl;

  ImageFormat({this.imageUrl, this.smallImageUrl, this.largeImageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: json['image_url'],
      smallImageUrl: json['small_image_url'],
      largeImageUrl: json['large_image_url'],
    );
  }
}

class Animeography {
  final String? role;
  final _Anime? anime;

  Animeography({this.role, this.anime});

  factory Animeography.fromJson(Map<String, dynamic> json) {
    return Animeography(
      role: json['role'],
      anime: json['anime'] != null ? _Anime.fromJson(json['anime']) : null,
    );
  }
}

class Mangaography {
  final String? role;
  final _Manga? manga;

  Mangaography({this.role, this.manga});

  factory Mangaography.fromJson(Map<String, dynamic> json) {
    return Mangaography(
      role: json['role'],
      manga: json['manga'] != null ? _Manga.fromJson(json['manga']) : null,
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

class VoiceActor {
  final String? language;
  final Person? person;

  VoiceActor({this.language, this.person});

  factory VoiceActor.fromJson(Map<String, dynamic> json) {
    return VoiceActor(
      language: json['language'],
      person: json['person'] != null ? Person.fromJson(json['person']) : null,
    );
  }
}

class Person {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;

  Person({
    this.malId,
    this.url,
    this.images,
    this.name,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      malId: json['mal_id'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      name: json['name'],
    );
  }
}
