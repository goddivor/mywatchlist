/// Model for a detailed featured article / news article parsed from MAL HTML.
class FeaturedArticle {
  final int id;
  final String category;
  final String? title;
  final String? summary;
  final String? content;
  final List<String> tags;
  final String? postedBy;
  final String? postedDate;
  final String? views;
  final int? topicId;
  final Map<String, List<RelatedEntry>> relatedDatabaseEntries;
  final List<RelatedArticle> relatedArticles;
  final Map<String, List<RelatedArticle>> relatedNews;

  FeaturedArticle({
    required this.id,
    this.category = 'featured',
    this.title,
    this.summary,
    this.content,
    this.tags = const [],
    this.postedBy,
    this.postedDate,
    this.views,
    this.topicId,
    this.relatedDatabaseEntries = const {},
    this.relatedArticles = const [],
    this.relatedNews = const {},
  });

  factory FeaturedArticle.fromJson(Map<String, dynamic> json) {
    // Parse related database entries (anime, manga, etc.)
    final rawDbEntries = json['relatedDatabaseEntries'];
    final Map<String, List<RelatedEntry>> dbEntries = {};
    if (rawDbEntries is Map) {
      for (final entry in rawDbEntries.entries) {
        final key = entry.key as String;
        final value = entry.value;
        if (value is List) {
          dbEntries[key] = value
              .map((e) => RelatedEntry.fromJson(
                  e is Map<String, dynamic> ? e : <String, dynamic>{}))
              .toList();
        }
      }
    }

    // Parse related articles
    final rawRelArticles = json['relatedArticles'];
    final List<RelatedArticle> relArticles = [];
    if (rawRelArticles is List) {
      for (final item in rawRelArticles) {
        if (item is Map<String, dynamic>) {
          relArticles.add(RelatedArticle.fromJson(item));
        }
      }
    }

    // Parse related news (grouped by section header)
    final rawRelNews = json['relatedNews'];
    final Map<String, List<RelatedArticle>> relNews = {};
    if (rawRelNews is Map) {
      for (final entry in rawRelNews.entries) {
        final key = entry.key as String;
        final value = entry.value;
        if (value is List) {
          relNews[key] = value
              .map((e) => RelatedArticle.fromJson(
                  e is Map<String, dynamic> ? e : <String, dynamic>{}))
              .toList();
        }
      }
    }

    // Parse tags
    final rawTags = json['tags'];
    final List<String> tags = [];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag is String && tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    return FeaturedArticle(
      id: json['id'] as int? ?? 0,
      category: json['category'] as String? ?? 'featured',
      title: json['title'] as String?,
      summary: json['summary'] as String? ?? json['contentText'] as String?,
      content: json['content'] as String?,
      tags: tags,
      postedBy: json['postedBy'] as String? ?? json['author'] as String?,
      postedDate: json['postedDate'] as String? ?? json['date'] as String?,
      views: json['views'] as String?,
      topicId: json['topicId'] as int?,
      relatedDatabaseEntries: dbEntries,
      relatedArticles: relArticles,
      relatedNews: relNews,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'summary': summary,
        'content': content,
        'tags': tags,
        'postedBy': postedBy,
        'postedDate': postedDate,
        'views': views,
        'topicId': topicId,
        'relatedDatabaseEntries': relatedDatabaseEntries.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'relatedArticles': relatedArticles.map((e) => e.toJson()).toList(),
        'relatedNews': relatedNews.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
      };
}

/// A related database entry (anime, manga, character, person).
class RelatedEntry {
  final int? id;
  final String title;

  RelatedEntry({
    this.id,
    this.title = '',
  });

  factory RelatedEntry.fromJson(Map<String, dynamic> json) {
    return RelatedEntry(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
      };
}

/// A related article or news item.
class RelatedArticle {
  final int? id;
  final String? title;
  final String? imageUrl;
  final String? summary;
  final String? author;
  final String? views;
  final List<String> tags;

  RelatedArticle({
    this.id,
    this.title,
    this.imageUrl,
    this.summary,
    this.author,
    this.views,
    this.tags = const [],
  });

  factory RelatedArticle.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final List<String> tags = [];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag is String && tag.isNotEmpty) {
          tags.add(tag);
        }
      }
    }

    return RelatedArticle(
      id: json['id'] as int?,
      title: json['title'] as String?,
      imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
      summary: json['summary'] as String? ?? json['text'] as String?,
      author: json['author'] as String? ?? json['postedBy'] as String?,
      views: json['views'] as String?,
      tags: tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'summary': summary,
        'author': author,
        'views': views,
        'tags': tags,
      };
}
