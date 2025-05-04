class Producer {
  final int? malId;
  final String? url;
  final List<Title>? titles;
  final Images? images;
  final int? favorites;
  final int? count;
  final String? established;
  final String? about;

  Producer({
    this.malId,
    this.url,
    this.titles,
    this.images,
    this.favorites,
    this.count,
    this.established,
    this.about,
  });

  factory Producer.fromJson(Map<String, dynamic> json) {
    return Producer(
      malId: json['mal_id'],
      url: json['url'],
      titles: json['titles'] != null ? (json['titles'] as List).map((e) => Title.fromJson(e)).toList() : null,
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      favorites: json['favorites'],
      count: json['count'],
      established: json['established'],
      about: json['about'],
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

class Pagination {
  final int? lastVisiblePage;
  final bool? hasNextPage;

  Pagination({
    this.lastVisiblePage,
    this.hasNextPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      lastVisiblePage: json['last_visible_page'],
      hasNextPage: json['has_next_page'],
    );
  }
}

class ProducersResponse {
  final List<Producer> data;
  final Pagination pagination;

  ProducersResponse({
    required this.data,
    required this.pagination,
  });

  factory ProducersResponse.fromJson(Map<String, dynamic> json) {
    return ProducersResponse(
      data: (json['data'] as List).map((e) => Producer.fromJson(e)).toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}
