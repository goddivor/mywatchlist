class Genre {
  final int? malId;
  final String? name;
  final String? url;
  final int? count;

  Genre({
    this.malId,
    this.name,
    this.url,
    this.count,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      malId: json['mal_id'],
      name: json['name'],
      url: json['url'],
      count: json['count'],
    );
  }
}

class GenreResponse {
  final List<Genre> data;

  GenreResponse({required this.data});

  factory GenreResponse.fromJson(Map<String, dynamic> json) {
    return GenreResponse(
      data: (json['data'] as List).map((e) => Genre.fromJson(e)).toList(),
    );
  }
}
