import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

/// Result from searchAllCategories (HTML scrape of MAL's /search/all page).
/// Contains categorized results: anime, manga, character, person, forum, club, featured, news.
class AllSearchResult {
  final Map<String, List<Anime>> categories;

  static const allTypes = [
    'anime',
    'manga',
    'character',
    'person',
    'forum',
    'club',
    'featured',
    'news',
  ];

  AllSearchResult({this.categories = const {}});

  factory AllSearchResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AllSearchResult();

    final cats = <String, List<Anime>>{};
    for (final type in allTypes) {
      final list = json[type] as List<dynamic>? ?? [];
      cats[type] = list
          .map((item) => Anime.fromMAlJson(item as Map<String, dynamic>))
          .toList();
    }
    return AllSearchResult(categories: cats);
  }

  Map<String, dynamic> toJson() {
    return categories.map(
      (key, value) => MapEntry(key, value.map((a) => a.toJson()).toList()),
    );
  }

  List<Anime> get anime => categories['anime'] ?? [];
  List<Anime> get manga => categories['manga'] ?? [];
  List<Anime> get character => categories['character'] ?? [];
  List<Anime> get person => categories['person'] ?? [];
  List<Anime> get forum => categories['forum'] ?? [];
  List<Anime> get club => categories['club'] ?? [];
  List<Anime> get featured => categories['featured'] ?? [];
  List<Anime> get news => categories['news'] ?? [];
}
