class AnimeEpisode {
  final int? malId;
  final String? url;
  final String? title;
  final String? titleJapanese;
  final String? titleRomanji;
  final int? duration;
  final String? aired;
  final bool? filler;
  final bool? recap;
  final String? forumUrl;

  AnimeEpisode({
    this.malId,
    this.url,
    this.title,
    this.titleJapanese,
    this.titleRomanji,
    this.duration,
    this.aired,
    this.filler,
    this.recap,
    this.forumUrl,
  });

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) {
    return AnimeEpisode(
      malId: json['mal_id'],
      url: json['url'],
      title: json['title'],
      titleJapanese: json['title_japanese'],
      titleRomanji: json['title_romanji'],
      duration: json['duration'],
      aired: json['aired'],
      filler: json['filler'],
      recap: json['recap'],
      forumUrl: json['forum_url'],
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

class AnimeEpisodesResponse {
  final List<AnimeEpisode> data;
  final Pagination pagination;

  AnimeEpisodesResponse({
    required this.data,
    required this.pagination,
  });

  factory AnimeEpisodesResponse.fromJson(Map<String, dynamic> json) {
    return AnimeEpisodesResponse(
      data: (json['data'] as List).map((e) => AnimeEpisode.fromJson(e)).toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}
