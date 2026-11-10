class AnimefeaturedTagsResult {
  final List<AnimeFeaturedTag> tags;

  AnimefeaturedTagsResult({required this.tags});

  factory AnimefeaturedTagsResult.fromJson(Map<String, dynamic> json) {
    return AnimefeaturedTagsResult(
      tags: (json['tags'] as List).map((item) => AnimeFeaturedTag.fromJson(item)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tags': tags.map((item) => item.toJson()).toList(),
    };
  }
}


class AnimeFeaturedTag {
  final String url;
  final String name;

  AnimeFeaturedTag({required this.url, required this.name});

  factory AnimeFeaturedTag.fromJson(Map<String, dynamic> json) {
    return AnimeFeaturedTag(
      url: json['url'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
    };
  }
}
