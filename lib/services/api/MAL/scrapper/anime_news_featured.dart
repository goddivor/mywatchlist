import 'package:mywatchlist/services/api/MAL/scrapper/paging.dart';

class AnimeNewsOrFeaturedResult {
  final List<AnimeNewsOrFeaturedItem> newsorfeatured;
  final Paging paging;

  AnimeNewsOrFeaturedResult({required this.newsorfeatured, required this.paging});

  factory AnimeNewsOrFeaturedResult.fromJson(Map<String, dynamic> json) {
    final list = json['newsorfeatured'] as List? ?? json['news'] as List? ?? [];
    return AnimeNewsOrFeaturedResult(
      newsorfeatured: list.map((item) => AnimeNewsOrFeaturedItem.fromJson(item as Map<String, dynamic>)).toList(),
      paging: Paging.fromJson(json['paging'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'newsorfeatured': newsorfeatured.map((item) => item.toJson()).toList(),
      'paging': paging.toJson(),
    };
  }
}

class AnimeNewsOrFeaturedItem {
  final int id;
  final String title;
  final String text;
  final String tags;
  final String imageUrl;
  final String url;

  AnimeNewsOrFeaturedItem({required this.id, required this.title, required this.text, required this.tags, required this.imageUrl, required this.url});

  factory AnimeNewsOrFeaturedItem.fromJson(Map<String, dynamic> json) {
    return AnimeNewsOrFeaturedItem(
      id: json['id'],
      title: json['title'],
      text: json['text'],
      tags: json['tags'],
      imageUrl: json['imageUrl'],
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'text': text,
      'tags': tags,
      'imageUrl': imageUrl,
      'url': url,
    };
  }
}