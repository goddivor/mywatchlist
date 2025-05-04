class AnimeReview {
  final User? user;
  final int? malId;
  final String? url;
  final String? type;
  final Reactions? reactions;
  final String? date;
  final String? review;
  final int? score;
  final List<String>? tags;
  final bool? isSpoiler;
  final bool? isPreliminary;
  final int? episodesWatched;

  AnimeReview({
    this.user,
    this.malId,
    this.url,
    this.type,
    this.reactions,
    this.date,
    this.review,
    this.score,
    this.tags,
    this.isSpoiler,
    this.isPreliminary,
    this.episodesWatched,
  });

  factory AnimeReview.fromJson(Map<String, dynamic> json) {
    return AnimeReview(
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      malId: json['mal_id'],
      url: json['url'],
      type: json['type'],
      reactions: json['reactions'] != null ? Reactions.fromJson(json['reactions']) : null,
      date: json['date'],
      review: json['review'],
      score: json['score'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      isSpoiler: json['is_spoiler'],
      isPreliminary: json['is_preliminary'],
      episodesWatched: json['episodes_watched'],
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

class Reactions {
  final int? overall;
  final int? nice;
  final int? loveIt;
  final int? funny;
  final int? confusing;
  final int? informative;
  final int? wellWritten;
  final int? creative;

  Reactions({
    this.overall,
    this.nice,
    this.loveIt,
    this.funny,
    this.confusing,
    this.informative,
    this.wellWritten,
    this.creative,
  });

  factory Reactions.fromJson(Map<String, dynamic> json) {
    return Reactions(
      overall: json['overall'],
      nice: json['nice'],
      loveIt: json['love_it'],
      funny: json['funny'],
      confusing: json['confusing'],
      informative: json['informative'],
      wellWritten: json['well_written'],
      creative: json['creative'],
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

class AnimeReviewsResponse {
  final List<AnimeReview> data;
  final Pagination pagination;

  AnimeReviewsResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeReviewsResponse.fromJson(Map<String, dynamic> json) {
    return AnimeReviewsResponse(
      data: (json['data'] as List).map((e) => AnimeReview.fromJson(e)).toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}
