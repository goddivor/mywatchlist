class AnimeFeaturedResult {
  final List<AnimeFeatured> featuredArticles;

  AnimeFeaturedResult({required this.featuredArticles});

  factory AnimeFeaturedResult.fromJson(Map<String, dynamic> json) {
    return AnimeFeaturedResult(
      featuredArticles: (json['featuredArticles'] as List?)
          ?.map((item) => AnimeFeatured.fromJson(item))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'featuredArticles': featuredArticles.map((item) => item.toJson()).toList(),
    };
  }
}

class AnimeFeatured {
  final String title;
  final String text;
  final String url;
  final String imageUrl;
  final String author;
  final String authorUrl;
  final int views;
  final List<String> tags;

  AnimeFeatured({
    required this.title,
    required this.text,
    required this.url,
    required this.imageUrl,
    required this.author,
    required this.authorUrl,
    required this.views,
    required this.tags,
  });

  factory AnimeFeatured.fromJson(Map<String, dynamic> json) {
    return AnimeFeatured(
      title: json['title'] as String,
      text: json['text'] as String,
      url: json['url'] as String,
      imageUrl: json['imageUrl'] as String,
      author: json['author'] as String,
      authorUrl: json['authorUrl'] as String,
      views: json['views'] as int,
      tags: (json['tags'] as List).map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'text': text,
      'url': url,
      'imageUrl': imageUrl,
      'author': author,
      'authorUrl': authorUrl,
      'views': views,
      'tags': tags,
    };
  }
}