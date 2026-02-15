class AnimeNewsTagsResult {
  final List<AnimeNewsTagCat> categories;

  AnimeNewsTagsResult({required this.categories});

  factory AnimeNewsTagsResult.fromJson(Map<String, dynamic> json) {
    return AnimeNewsTagsResult(
      categories: (json['categories'] as List).map((item) => AnimeNewsTagCat.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((item) => item.toJson()).toList(),
    };
  }
}


class AnimeNewsTagCat {
  final String categoryName;
  final List<AnimeNewsTag> tags;

  AnimeNewsTagCat({required this.categoryName, required this.tags});

  factory AnimeNewsTagCat.fromJson(Map<String, dynamic> json) {
    return AnimeNewsTagCat(
      categoryName: json['categoryName'],
      tags: (json['tags'] as List).map((item) => AnimeNewsTag.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryName': categoryName,
      'tags': tags.map((item) => item.toJson()).toList(),
    };
  }
}

class AnimeNewsTag {
  final String url;
  final String name;
  final String description;

  AnimeNewsTag({required this.url, required this.name, required this.description});

  factory AnimeNewsTag.fromJson(Map<String, dynamic> json) {
    return AnimeNewsTag(
      url: json['url'],
      name: json['name'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
      'description': description,
    };
  }
}
