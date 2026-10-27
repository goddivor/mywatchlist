import 'common.dart';
import 'json_utils.dart';

/// One result of MAL's "all" search (`/search/all?q=`).
class SearchAllItem {
  final int id;
  final String title;
  final ImageSet? image;

  /// Anime and manga only.
  final String? mediaType;

  /// Episodes (anime) or volumes/chapters count shown (manga).
  final int? numEpisodes;
  final double? mean;
  final int? numListUsers;

  /// Free text under the title for other categories (favorites, date, …).
  final String? additional;

  const SearchAllItem({
    required this.id,
    required this.title,
    this.image,
    this.mediaType,
    this.numEpisodes,
    this.mean,
    this.numListUsers,
    this.additional,
  });

  factory SearchAllItem.fromJson(Map<String, dynamic> json) => SearchAllItem(
        id: asInt(json['id']) ?? 0,
        title: json['title'] as String? ?? '',
        image: asMap(json['image']) == null
            ? null
            : ImageSet.fromJson(asMap(json['image'])),
        mediaType: json['mediaType'] as String?,
        numEpisodes: asInt(json['numEpisodes']),
        mean: asDouble(json['mean']),
        numListUsers: asInt(json['numListUsers']),
        additional: json['additional'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image': image?.toJson(),
        'mediaType': mediaType,
        'numEpisodes': numEpisodes,
        'mean': mean,
        'numListUsers': numListUsers,
        'additional': additional,
      };
}

/// MAL "all" search results grouped by category.
class SearchAllResult {
  /// Categories in MAL's order; every key is always present.
  static const categories = [
    'anime',
    'manga',
    'character',
    'person',
    'forum',
    'club',
    'featured',
    'news',
  ];

  final Map<String, List<SearchAllItem>> results;

  const SearchAllResult(this.results);

  List<SearchAllItem> of(String category) => results[category] ?? const [];

  factory SearchAllResult.fromJson(Map<String, dynamic>? json) {
    final map = <String, List<SearchAllItem>>{};
    for (final category in categories) {
      map[category] = asList(json?[category], SearchAllItem.fromJson);
    }
    return SearchAllResult(map);
  }

  Map<String, dynamic> toJson() => results
      .map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()));
}

/// One upcoming episode from a LiveChart.me season page.
class LiveChartEpisode {
  /// Air time, seconds since epoch (UTC).
  final int timestamp;
  final int episode;
  final String? title;

  /// MyAnimeList id, read from the card's MAL link.
  final int? malId;

  /// Link kind (`mal`, `anilist`, `website`, `twitter`, …) to URL.
  final Map<String, String> relatedLinks;

  const LiveChartEpisode({
    required this.timestamp,
    required this.episode,
    this.title,
    this.malId,
    this.relatedLinks = const {},
  });

  DateTime get airingAt =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

  factory LiveChartEpisode.fromJson(Map<String, dynamic> json) =>
      LiveChartEpisode(
        timestamp: asInt(json['timestamp']) ?? 0,
        episode: asInt(json['episode']) ?? 0,
        title: json['title'] as String?,
        malId: asInt(json['malId']),
        relatedLinks: (asMap(json['relatedLinks']) ?? const {})
            .map((k, v) => MapEntry(k, '$v')),
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'episode': episode,
        'title': title,
        'malId': malId,
        'relatedLinks': relatedLinks,
      };
}
