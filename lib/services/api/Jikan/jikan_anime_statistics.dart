class AnimeStatistics {
  final int? watching;
  final int? completed;
  final int? onHold;
  final int? dropped;
  final int? planToWatch;
  final int? total;
  final List<ScoreStatistics>? scores;

  AnimeStatistics({
    this.watching,
    this.completed,
    this.onHold,
    this.dropped,
    this.planToWatch,
    this.total,
    this.scores,
  });

  factory AnimeStatistics.fromJson(Map<String, dynamic> json) {
    return AnimeStatistics(
      watching: json['watching'],
      completed: json['completed'],
      onHold: json['on_hold'],
      dropped: json['dropped'],
      planToWatch: json['plan_to_watch'],
      total: json['total'],
      scores: json['scores'] != null
          ? (json['scores'] as List).map((e) => ScoreStatistics.fromJson(e)).toList()
          : null,
    );
  }
}

class ScoreStatistics {
  final int? score;
  final int? votes;
  final double? percentage;

  ScoreStatistics({
    this.score,
    this.votes,
    this.percentage,
  });

  factory ScoreStatistics.fromJson(Map<String, dynamic> json) {
    return ScoreStatistics(
      score: json['score'],
      votes: json['votes'],
      percentage: (json['percentage'] as num?)?.toDouble(),
    );
  }
}
