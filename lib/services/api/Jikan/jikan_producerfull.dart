class ProducerFull {
  final int? malId;
  final String? url;
  final List<Title>? titles;
  final Images? images;
  final int? favorites;
  final int? count;
  final String? established;
  final String? about;
  final List<ExternalLink>? external;

  ProducerFull({
    this.malId,
    this.url,
    this.titles,
    this.images,
    this.favorites,
    this.count,
    this.established,
    this.about,
    this.external,
  });

  factory ProducerFull.fromJson(Map<String, dynamic> json) {
    return ProducerFull(
      malId: json['mal_id'],
      url: json['url'],
      titles: json['titles'] != null ? (json['titles'] as List).map((e) => Title.fromJson(e)).toList() : null,
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      favorites: json['favorites'],
      count: json['count'],
      established: json['established'],
      about: json['about'],
      external: json['external'] != null ? (json['external'] as List).map((e) => ExternalLink.fromJson(e)).toList() : null,
    );
  }
}

class Title {
  final String? type;
  final String? title;

  Title({this.type, this.title});

  factory Title.fromJson(Map<String, dynamic> json) {
    return Title(
      type: json['type'],
      title: json['title'],
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

class ExternalLink {
  final String? name;
  final String? url;

  ExternalLink({this.name, this.url});

  factory ExternalLink.fromJson(Map<String, dynamic> json) {
    return ExternalLink(
      name: json['name'],
      url: json['url'],
    );
  }
}
