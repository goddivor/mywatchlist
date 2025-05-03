class AnimeStaff {
  final Person person;
  final List<String>? positions;

  AnimeStaff({
    required this.person,
    this.positions,
  });

  factory AnimeStaff.fromJson(Map<String, dynamic> json) {
    return AnimeStaff(
      person: Person.fromJson(json['person']),
      positions: json['positions'] != null ? List<String>.from(json['positions']) : null,
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
