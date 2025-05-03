class AnimeNews {
  final int? malId;
  final String? url;
  final String? title;
  final String? date;
  final String? authorUsername;
  final String? authorUrl;
  final String? forumUrl;
  final Images? images;
  final int? comments;
  final String? excerpt;

  AnimeNews({
    this.malId,
    this.url,
    this.title,
    this.date,
    this.authorUsername,
    this.authorUrl,
    this.forumUrl,
    this.images,
    this.comments,
    this.excerpt,
  });

  factory AnimeNews.fromJson(Map<String, dynamic> json) {
    return AnimeNews(
      malId: json['mal_id'],
      url: json['url'],
      title: json['title'],
      date: json['date'],
      authorUsername: json['author_username'],
      authorUrl: json['author_url'],
      forumUrl: json['forum_url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      comments: json['comments'],
      excerpt: json['excerpt'],
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

class AnimeNewsResponse {
  final List<AnimeNews> data;
  final Pagination pagination;

  AnimeNewsResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeNewsResponse.fromJson(Map<String, dynamic> json) {
    return AnimeNewsResponse(
      data: (json['data'] as List).map((e) => AnimeNews.fromJson(e)).toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}
