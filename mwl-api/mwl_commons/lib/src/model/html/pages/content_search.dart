import 'json_utils.dart';

/// One row of MyAnimeList's own search pages (`anime.php`, `manga.php`,
/// `character.php`, `people.php`).
///
/// Anime and manga rows carry what the result table shows (type, episodes or
/// chapters, volumes, score, dates, members, rating); character and person
/// rows only the name, the picture and the other names.
class MalSearchItemHtml {
  final int id;

  /// `anime`, `manga`, `character` or `person`.
  final String category;
  final String title;

  /// Full-size picture (MAL's resized thumbnail path removed), null when MAL
  /// shows its "no picture" placeholder.
  final String? image;

  /// The start of the synopsis as MAL cuts it (anime and manga).
  final String? synopsis;

  /// MAL's label: `TV`, `Movie`, `Manga`, `Light Novel`…
  final String? type;

  /// Episodes (anime) or chapters (manga); null when unknown.
  final int? episodes;
  final int? volumes;

  /// Mean score; null when not scored yet.
  final double? score;

  /// `yyyy-mm-dd`, `yyyy-mm` or `yyyy` (MAL hides unknown parts).
  final String? startDate;
  final String? endDate;
  final int? members;

  /// `G`, `PG`, `PG-13`, `R`, `R+`, `Rx` (anime).
  final String? rated;

  /// Other names of a character or a person (`Mugiwara, Straw Hat`).
  final String? alternative;

  const MalSearchItemHtml({
    required this.id,
    required this.category,
    required this.title,
    this.image,
    this.synopsis,
    this.type,
    this.episodes,
    this.volumes,
    this.score,
    this.startDate,
    this.endDate,
    this.members,
    this.rated,
    this.alternative,
  });

  factory MalSearchItemHtml.fromJson(Map<String, dynamic> json) =>
      MalSearchItemHtml(
        id: asInt(json['id']) ?? 0,
        category: (json['category'] as String?) ?? 'anime',
        title: (json['title'] as String?) ?? '',
        image: json['image'] as String?,
        synopsis: json['synopsis'] as String?,
        type: json['type'] as String?,
        episodes: asInt(json['episodes']),
        volumes: asInt(json['volumes']),
        score: (json['score'] as num?)?.toDouble(),
        startDate: json['startDate'] as String?,
        endDate: json['endDate'] as String?,
        members: asInt(json['members']),
        rated: json['rated'] as String?,
        alternative: json['alternative'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'image': image,
        'synopsis': synopsis,
        'type': type,
        'episodes': episodes,
        'volumes': volumes,
        'score': score,
        'startDate': startDate,
        'endDate': endDate,
        'members': members,
        'rated': rated,
        'alternative': alternative,
      };
}

/// One page of a MyAnimeList search: 50 rows at most.
class MalSearchPageHtml {
  final List<MalSearchItemHtml> items;

  /// MAL links a next page.
  final bool hasNext;

  /// MAL refused the text: it needs at least three characters.
  final bool tooShort;

  const MalSearchPageHtml({
    this.items = const [],
    this.hasNext = false,
    this.tooShort = false,
  });

  factory MalSearchPageHtml.fromJson(Map<String, dynamic> json) =>
      MalSearchPageHtml(
        items: [
          for (final row in (json['items'] as List?) ?? const [])
            if (row is Map) MalSearchItemHtml.fromJson(asMap(row)!),
        ],
        hasNext: json['hasNext'] == true,
        tooShort: json['tooShort'] == true,
      );

  Map<String, dynamic> toJson() => {
        'items': [for (final item in items) item.toJson()],
        'hasNext': hasNext,
        'tooShort': tooShort,
      };
}

/// An anime company (studio, producer, licensor) of MAL's company directory
/// (`/company`).
class CompanyHtml {
  final int id;
  final String name;

  /// Name in Japanese (or another script) when MAL gives one.
  final String? japaneseName;

  /// Logo (70×70), null when MAL has none.
  final String? logo;

  /// Number of anime; only the directory listing gives it.
  final int? animeCount;

  /// Users who favorited it; only the directory listing gives it.
  final int? favorites;

  const CompanyHtml({
    required this.id,
    required this.name,
    this.japaneseName,
    this.logo,
    this.animeCount,
    this.favorites,
  });

  factory CompanyHtml.fromJson(Map<String, dynamic> json) => CompanyHtml(
        id: asInt(json['id']) ?? 0,
        name: (json['name'] as String?) ?? '',
        japaneseName: json['japaneseName'] as String?,
        logo: json['logo'] as String?,
        animeCount: asInt(json['animeCount']),
        favorites: asInt(json['favorites']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'japaneseName': japaneseName,
        'logo': logo,
        'animeCount': animeCount,
        'favorites': favorites,
      };
}

/// One page (50) of the company directory or of a company search.
class CompanyPageHtml {
  final List<CompanyHtml> items;
  final bool hasNext;

  const CompanyPageHtml({this.items = const [], this.hasNext = false});

  factory CompanyPageHtml.fromJson(Map<String, dynamic> json) =>
      CompanyPageHtml(
        items: [
          for (final row in (json['items'] as List?) ?? const [])
            if (row is Map) CompanyHtml.fromJson(asMap(row)!),
        ],
        hasNext: json['hasNext'] == true,
      );

  Map<String, dynamic> toJson() => {
        'items': [for (final item in items) item.toJson()],
        'hasNext': hasNext,
      };
}
