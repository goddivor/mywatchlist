class AnimeCharacter {
  final Character character;
  final String? role;
  final int? favorites;
  final List<VoiceActor>? voiceActors;

  AnimeCharacter({
    required this.character,
    this.role,
    this.favorites,
    this.voiceActors,
  });

  factory AnimeCharacter.fromJson(Map<String, dynamic> json) {
    return AnimeCharacter(
      character: Character.fromJson(json['character']),
      role: json['role'],
      favorites: json['favorites'],
      voiceActors: json['voice_actors'] != null
          ? (json['voice_actors'] as List).map((e) => VoiceActor.fromJson(e)).toList()
          : null,
    );
  }
}

class Character {
  final int? malId;
  final String? url;
  final Images? images;
  final String? name;

  Character({
    this.malId,
    this.url,
    this.images,
    this.name,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      malId: json['mal_id'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      name: json['name'],
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

  ImageFormat({this.imageUrl, this.smallImageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: json['image_url'],
      smallImageUrl: json['small_image_url'],
    );
  }
}

class VoiceActor {
  final Person? person;
  final String? language;

  VoiceActor({
    this.person,
    this.language,
  });

  factory VoiceActor.fromJson(Map<String, dynamic> json) {
    return VoiceActor(
      person: json['person'] != null ? Person.fromJson(json['person']) : null,
      language: json['language'],
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
