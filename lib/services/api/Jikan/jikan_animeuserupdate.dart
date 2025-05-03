class AnimeUserUpdate {
  final User? user;
  final int? score;
  final String? status;
  final int? episodesSeen;
  final int? episodesTotal;
  final String? date;

  AnimeUserUpdate({
    this.user,
    this.score,
    this.status,
    this.episodesSeen,
    this.episodesTotal,
    this.date,
  });

  factory AnimeUserUpdate.fromJson(Map<String, dynamic> json) {
    return AnimeUserUpdate(
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      score: json['score'],
      status: json['status'],
      episodesSeen: json['episodes_seen'],
      episodesTotal: json['episodes_total'],
      date: json['date'],
    );
  }
}

class User {
  final String? username;
  final String? url;
  final Images? images;

  User({
    this.username,
    this.url,
    this.images,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
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

class AnimeUserUpdatesResponse {
  final List<AnimeUserUpdate> data;
  final Pagination pagination;

  AnimeUserUpdatesResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeUserUpdatesResponse.fromJson(Map<String, dynamic> json) {
    return AnimeUserUpdatesResponse(
      data: (json['data'] as List).map((e) => AnimeUserUpdate.fromJson(e)).toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}
