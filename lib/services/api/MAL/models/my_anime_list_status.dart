import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

/// Enriched anime list status returned by updateMyAnimeListStatus (and built
/// from saveAnimeListStatus' answer by the edit sheet).
/// Contains all fields the MAL API returns for an anime list entry.
class MyAnimeListStatus {
  final String? status;
  final int? score;
  final int? numEpisodesWatched;
  final bool? isRewatching;
  final DateTime? updatedAt;

  /// MAL's own date text: `YYYY-MM-DD`, or partial `YYYY-MM` / `YYYY`.
  /// Kept as text: a `DateTime` cannot hold a partial date.
  final String? startDate;
  final String? finishDate;
  final int? priority;
  final int? numTimesRewatched;
  final int? rewatchValue;
  final List<String>? tags;
  final String? comments;

  MyAnimeListStatus({
    this.status,
    this.score,
    this.numEpisodesWatched,
    this.isRewatching,
    this.updatedAt,
    this.startDate,
    this.finishDate,
    this.priority,
    this.numTimesRewatched,
    this.rewatchValue,
    this.tags,
    this.comments,
  });

  factory MyAnimeListStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MyAnimeListStatus();
    return MyAnimeListStatus(
      status: json['status'] as String?,
      score: json['score'] as int?,
      numEpisodesWatched: json['num_episodes_watched'] as int?,
      isRewatching: json['is_rewatching'] as bool?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      startDate: _date(json['start_date']),
      finishDate: _date(json['finish_date']),
      priority: json['priority'] as int?,
      numTimesRewatched: json['num_times_rewatched'] as int?,
      rewatchValue: json['rewatch_value'] as int?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      comments: json['comments'] as String?,
    );
  }

  /// From the entry `MalApi.saveAnimeListStatus` returns, so its
  /// callers keep getting this type.
  factory MyAnimeListStatus.fromListStatus(MyListStatus s) {
    return MyAnimeListStatus(
      status: s.status.isEmpty ? null : s.status,
      score: s.score,
      numEpisodesWatched: s.numEpisodesWatched,
      isRewatching: s.isRewatching,
      updatedAt: DateTime.tryParse(s.updatedAt),
      startDate: s.startDate,
      finishDate: s.finishDate,
      priority: s.priority,
      numTimesRewatched: s.numTimesRewatched,
      rewatchValue: s.rewatchValue,
      tags: s.tags,
      comments: s.comments,
    );
  }

  static String? _date(Object? v) {
    final text = v?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() {
    return {
      if (status != null) 'status': status,
      if (score != null) 'score': score,
      if (numEpisodesWatched != null)
        'num_episodes_watched': numEpisodesWatched,
      if (isRewatching != null) 'is_rewatching': isRewatching,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (startDate != null) 'start_date': startDate,
      if (finishDate != null) 'finish_date': finishDate,
      if (priority != null) 'priority': priority,
      if (numTimesRewatched != null)
        'num_times_rewatched': numTimesRewatched,
      if (rewatchValue != null) 'rewatch_value': rewatchValue,
      if (tags != null) 'tags': tags,
      if (comments != null) 'comments': comments,
    };
  }
}
