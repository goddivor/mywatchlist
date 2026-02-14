/// Enriched manga list status returned by updateMyMangaListStatus.
/// Contains all fields the MAL API returns for a manga list entry.
class MyMangaListStatus {
  final String? status;
  final int? score;
  final int? numVolumesRead;
  final int? numChaptersRead;
  final bool? isRereading;
  final DateTime? updatedAt;
  final DateTime? startDate;
  final DateTime? finishDate;
  final int? priority;
  final int? numTimesReread;
  final int? rereadValue;
  final List<String>? tags;
  final String? comments;

  MyMangaListStatus({
    this.status,
    this.score,
    this.numVolumesRead,
    this.numChaptersRead,
    this.isRereading,
    this.updatedAt,
    this.startDate,
    this.finishDate,
    this.priority,
    this.numTimesReread,
    this.rereadValue,
    this.tags,
    this.comments,
  });

  factory MyMangaListStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MyMangaListStatus();
    return MyMangaListStatus(
      status: json['status'] as String?,
      score: json['score'] as int?,
      numVolumesRead: json['num_volumes_read'] as int?,
      numChaptersRead: json['num_chapters_read'] as int?,
      isRereading: json['is_rereading'] as bool?,
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
      numTimesReread: json['num_times_reread'] as int?,
      rereadValue: json['reread_value'] as int?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      comments: json['comments'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (status != null) 'status': status,
      if (score != null) 'score': score,
      if (numVolumesRead != null) 'num_volumes_read': numVolumesRead,
      if (numChaptersRead != null) 'num_chapters_read': numChaptersRead,
      if (isRereading != null) 'is_rereading': isRereading,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (startDate != null) 'start_date': startDate!.toIso8601String(),
      if (finishDate != null) 'finish_date': finishDate!.toIso8601String(),
      if (priority != null) 'priority': priority,
      if (numTimesReread != null) 'num_times_reread': numTimesReread,
      if (rereadValue != null) 'reread_value': rereadValue,
      if (tags != null) 'tags': tags,
      if (comments != null) 'comments': comments,
    };
  }
}
