class GenreCategoryList {
  final List<GenreCategory> categories;

  GenreCategoryList({required this.categories});

  factory GenreCategoryList.fromJson(Map<String, dynamic> json) {
    var categoriesJson = json['categories'] as List<dynamic>;
    var categories = categoriesJson.map((item) => GenreCategory.fromJson(item as Map<String, dynamic>)).toList();
    return GenreCategoryList(categories: categories);
  }

  Map<String, dynamic> toJson() {
    return {
      'categories': categories.map((category) => category.toJson()).toList(),
    };
  }
}


class GenreCategory {
  final String type;
  final List<Genre> genres;

  GenreCategory({
    required this.type,
    required this.genres,
  });

  factory GenreCategory.fromJson(Map<String, dynamic> json) {
    var genresJson = json['genres'] as List<dynamic>;
    var genres = genresJson.map((item) => Genre.fromJson(item as Map<String, dynamic>)).toList();
    return GenreCategory(
      type: json['type'] as String,
      genres: genres,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'genres': genres.map((genre) => genre.toJson()).toList(),
    };
  }
}


class Genre {
  final int id;
  final String name;
  final int? count;

  Genre({
    required this.id,
    required this.name,
    this.count,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as int,
      name: json['name'] as String,
      count: json['count'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'count': count,
    };
  }
}
