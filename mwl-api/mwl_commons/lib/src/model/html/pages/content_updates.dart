import 'json_utils.dart';

/// One row of the "Recently Updated By" table of MAL's stats page
/// (`/anime/<id>/x/stats`, `/manga/<id>/x/stats`): a member's latest list
/// update of the title.
class ContentUpdateHtml {
  final String username;

  /// Avatar URL; null when the member has none (MAL's kaomoji placeholder).
  final String? imageUrl;

  /// Score given, null when the member gave none (`-`).
  final int? score;

  /// List status as MAL prints it (`Watching`, `On-Hold`, `Plan to Read`…).
  final String? status;

  /// Anime: episodes seen and total (null when MAL prints `-` or `?`).
  final int? episodesSeen;
  final int? episodesTotal;

  /// Manga: volumes and chapters read, and their totals.
  final int? volumesRead;
  final int? volumesTotal;
  final int? chaptersRead;
  final int? chaptersTotal;

  /// The activity text as MAL prints it (`31 minutes ago`, `Yesterday,
  /// 4:59 PM`, `Sep 27, 7:51 PM`, `Jul 6, 2025 9:29 AM`).
  final String? activity;

  /// [activity] as an ISO 8601 UTC time, read when the page was parsed;
  /// null when the text is not one of MAL's formats.
  final String? date;

  const ContentUpdateHtml({
    required this.username,
    this.imageUrl,
    this.score,
    this.status,
    this.episodesSeen,
    this.episodesTotal,
    this.volumesRead,
    this.volumesTotal,
    this.chaptersRead,
    this.chaptersTotal,
    this.activity,
    this.date,
  });

  factory ContentUpdateHtml.fromJson(Map<String, dynamic> json) =>
      ContentUpdateHtml(
        username: json['username'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
        score: asInt(json['score']),
        status: json['status'] as String?,
        episodesSeen: asInt(json['episodes_seen']),
        episodesTotal: asInt(json['episodes_total']),
        volumesRead: asInt(json['volumes_read']),
        volumesTotal: asInt(json['volumes_total']),
        chaptersRead: asInt(json['chapters_read']),
        chaptersTotal: asInt(json['chapters_total']),
        activity: json['activity'] as String?,
        date: json['date'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'image_url': imageUrl,
        'score': score,
        'status': status,
        'episodes_seen': episodesSeen,
        'episodes_total': episodesTotal,
        'volumes_read': volumesRead,
        'volumes_total': volumesTotal,
        'chapters_read': chaptersRead,
        'chapters_total': chaptersTotal,
        'activity': activity,
        'date': date,
      };
}

/// One page (75 rows) of the "Recently Updated By" table, newest first.
class ContentUpdatesHtml {
  final List<ContentUpdateHtml> updates;

  /// True when MAL links a next page.
  final bool hasNextPage;

  const ContentUpdatesHtml({this.updates = const [], this.hasNextPage = false});

  /// Rows per page of MAL's table (the `show` offset step).
  static const int pageSize = 75;

  factory ContentUpdatesHtml.fromJson(Map<String, dynamic> json) =>
      ContentUpdatesHtml(
        updates: asList(json['updates'], ContentUpdateHtml.fromJson),
        hasNextPage: json['has_next_page'] == true,
      );

  Map<String, dynamic> toJson() => {
        'updates': updates.map((e) => e.toJson()).toList(),
        'has_next_page': hasNextPage,
      };
}
