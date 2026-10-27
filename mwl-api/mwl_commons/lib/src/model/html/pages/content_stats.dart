import 'json_utils.dart';

/// Votes given to one score on MAL's stats page (`/anime/<id>/x/stats`).
class ScoreVotesHtml {
  /// The score, 1 to 10.
  final int score;
  final int votes;

  /// Share of all votes, in percent (34.6 means 34.6 %), as MAL rounds it.
  final double percentage;

  const ScoreVotesHtml({
    required this.score,
    required this.votes,
    required this.percentage,
  });

  factory ScoreVotesHtml.fromJson(Map<String, dynamic> json) => ScoreVotesHtml(
        score: asInt(json['score']) ?? 0,
        votes: asInt(json['votes']) ?? 0,
        percentage: asDouble(json['percentage']) ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'score': score, 'votes': votes, 'percentage': percentage};
}

/// Members per list status on MAL's stats page.
///
/// Manga pages say "Reading" and "Plan to Read": they fill [watching] and
/// [planToWatch].
class StatusCountsHtml {
  final int watching;
  final int completed;
  final int onHold;
  final int dropped;
  final int planToWatch;
  final int total;

  const StatusCountsHtml({
    this.watching = 0,
    this.completed = 0,
    this.onHold = 0,
    this.dropped = 0,
    this.planToWatch = 0,
    this.total = 0,
  });

  factory StatusCountsHtml.fromJson(Map<String, dynamic>? json) =>
      StatusCountsHtml(
        watching: asInt(json?['watching']) ?? 0,
        completed: asInt(json?['completed']) ?? 0,
        onHold: asInt(json?['on_hold']) ?? 0,
        dropped: asInt(json?['dropped']) ?? 0,
        planToWatch: asInt(json?['plan_to_watch']) ?? 0,
        total: asInt(json?['total']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'watching': watching,
        'completed': completed,
        'on_hold': onHold,
        'dropped': dropped,
        'plan_to_watch': planToWatch,
        'total': total,
      };
}

/// Score distribution and status counts of an anime or manga, parsed from
/// MAL's stats page.
class ContentStatsHtml {
  /// One entry per score MAL lists, highest score first (10 to 1). Empty
  /// when nobody has scored the title yet.
  final List<ScoreVotesHtml> scores;
  final StatusCountsHtml statuses;

  const ContentStatsHtml({
    this.scores = const [],
    this.statuses = const StatusCountsHtml(),
  });

  /// Total votes over every score.
  int get totalVotes => scores.fold(0, (sum, e) => sum + e.votes);

  factory ContentStatsHtml.fromJson(Map<String, dynamic> json) =>
      ContentStatsHtml(
        scores: asList(json['scores'], ScoreVotesHtml.fromJson),
        statuses: StatusCountsHtml.fromJson(asMap(json['statuses'])),
      );

  Map<String, dynamic> toJson() => {
        'scores': scores.map((e) => e.toJson()).toList(),
        'statuses': statuses.toJson(),
      };
}
