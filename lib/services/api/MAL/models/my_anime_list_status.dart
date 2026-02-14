/// Enriched anime list status returned by updateMyAnimeListStatus.
/// Contains all fields the MAL API returns for an anime list entry.
class MyAnimeListStatus {
  final String? status;
  final int? score;
  final int? numEpisodesWatched;
  final bool? isRewatching;
  final DateTime? updatedAt;
  final DateTime? startDate;
  final DateTime? finishDate;
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
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      finishDate: json['finish_date'] != null
          ? DateTime.tryParse(json['finish_date'].toString())
          : null,
      priority: json['priority'] as int?,
      numTimesRewatched: json['num_times_rewatched'] as int?,
      rewatchValue: json['rewatch_value'] as int?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      comments: json['comments'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (status != null) 'status': status,
      if (score != null) 'score': score,
      if (numEpisodesWatched != null)
        'num_episodes_watched': numEpisodesWatched,
      if (isRewatching != null) 'is_rewatching': isRewatching,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (finishDate != null) 'finish_date': finishDate!.toIso8601String(),
      if (priority != null) 'priority': priority,
      if (numTimesRewatched != null)
        'num_times_rewatched': numTimesRewatched,
      if (rewatchValue != null) 'rewatch_value': rewatchValue,
      if (tags != null) 'tags': tags,
      if (comments != null) 'comments': comments,
    };
  }
}
