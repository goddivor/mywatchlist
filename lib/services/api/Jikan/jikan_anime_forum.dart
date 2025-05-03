class AnimeForum {
  final int? malId;
  final String? url;
  final String? title;
  final String? date;
  final String? authorUsername;
  final String? authorUrl;
  final int? comments;
  final LastComment? lastComment;

  AnimeForum({
    this.malId,
    this.url,
    this.title,
    this.date,
    this.authorUsername,
    this.authorUrl,
    this.comments,
    this.lastComment,
  });

  factory AnimeForum.fromJson(Map<String, dynamic> json) {
    return AnimeForum(
      malId: json['mal_id'],
      url: json['url'],
      title: json['title'],
      date: json['date'],
      authorUsername: json['author_username'],
      authorUrl: json['author_url'],
      comments: json['comments'],
      lastComment: json['last_comment'] != null ? LastComment.fromJson(json['last_comment']) : null,
    );
  }
}

class LastComment {
  final String? url;
  final String? authorUsername;
  final String? authorUrl;
  final String? date;

  LastComment({
    this.url,
    this.authorUsername,
    this.authorUrl,
    this.date,
  });

  factory LastComment.fromJson(Map<String, dynamic> json) {
    return LastComment(
      url: json['url'],
      authorUsername: json['author_username'],
      authorUrl: json['author_url'],
      date: json['date'],
    );
  }
}

class AnimeForumResponse {
  final List<AnimeForum> data;

  AnimeForumResponse({required this.data});

  factory AnimeForumResponse.fromJson(Map<String, dynamic> json) {
    return AnimeForumResponse(
      data: (json['data'] as List).map((e) => AnimeForum.fromJson(e)).toList(),
    );
  }
}
