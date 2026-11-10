class UserAnimeStatistics {
  final double? numItemsWatching;
  final double? numItemsCompleted;
  final double? numItemsOnHold;
  final double? numItemsDropped;
  final double? numItemsPlanToWatch;
  final double? numItems;
  final double? numDaysWatched;
  final double? numDaysWatching;
  final double? numDaysCompleted;
  final double? numDaysOnHold;
  final double? numDaysDropped;
  final double? numDays;
  final double? numEpisodes;
  final double? numTimesRewatched;
  final double? meanScore;

  UserAnimeStatistics({
    this.numItemsWatching,
    this.numItemsCompleted,
    this.numItemsOnHold,
    this.numItemsDropped,
    this.numItemsPlanToWatch,
    this.numItems,
    this.numDaysWatched,
    this.numDaysWatching,
    this.numDaysCompleted,
    this.numDaysOnHold,
    this.numDaysDropped,
    this.numDays,
    this.numEpisodes,
    this.numTimesRewatched,
    this.meanScore,
  });

  factory UserAnimeStatistics.fromJson(Map<String, dynamic>? json) {
    return json != null
        ? UserAnimeStatistics(
            meanScore: double.tryParse(json["mean_score"].toString()),
            numDays: double.tryParse(json["num_days"].toString()),
            numDaysCompleted: double.tryParse(json["num_days_completed"].toString()),
            numDaysDropped: double.tryParse(json["num_days_dropped"].toString()),
            numDaysOnHold: double.tryParse(json["num_days_on_hold"].toString()),
            numDaysWatched: double.tryParse(json["num_days_watched"].toString()),
            numDaysWatching: double.tryParse(json["num_days_watching"].toString()),
            numEpisodes: double.tryParse(json["num_episodes"].toString()),
            numItems: double.tryParse(json["num_items"].toString()),
            numItemsCompleted: double.tryParse(json["num_items_completed"].toString()),
            numItemsDropped: double.tryParse(json["num_items_dropped"].toString()),
            numItemsOnHold: double.tryParse(json["num_items_on_hold"].toString()),
            numItemsPlanToWatch: double.tryParse(json["num_items_plan_to_watch"].toString()),
            numItemsWatching: double.tryParse(json["num_items_watching"].toString()),
            numTimesRewatched: double.tryParse(json["num_times_rewatched"].toString()))
        : UserAnimeStatistics();
  }

  Map<String, dynamic> toJson() {
    return {
      "num_items_watching": numItemsWatching,
      "num_items_completed": numItemsCompleted,
      "num_items_on_hold": numItemsOnHold,
      "num_items_dropped": numItemsDropped,
      "num_items_plan_to_watch": numItemsPlanToWatch,
      "num_items": numItems,
      "num_days_watched": numDaysWatched,
      "num_days_watching": numDaysWatching,
      "num_days_completed": numDaysCompleted,
      "num_days_on_hold": numDaysOnHold,
      "num_days_dropped": numDaysDropped,
      "num_days": numDays,
      "num_episodes": numEpisodes,
      "num_times_rewatched": numTimesRewatched,
      "mean_score": meanScore
    };
  }
}

/// One list category (anime or manga) of a profile, as the Jikan `statistics` block gives it.
/// The same shape serves both: [progress] is episodes watched or chapters read, [volumes]
/// only exists for manga, and [planned] is "plan to watch" or "plan to read".
class ListStats {
  final double? meanScore;
  final int totalEntries;
  final double? days;
  final int progress;
  final int volumes;
  final int current;
  final int completed;
  final int onHold;
  final int dropped;
  final int planned;

  const ListStats({
    this.meanScore,
    this.totalEntries = 0,
    this.days,
    this.progress = 0,
    this.volumes = 0,
    this.current = 0,
    this.completed = 0,
    this.onHold = 0,
    this.dropped = 0,
    this.planned = 0,
  });

  /// Entry counts per status, in the order the charts use: current, completed, on hold,
  /// dropped, planned.
  List<int> get statusCounts => [current, completed, onHold, dropped, planned];

  bool get isEmpty => totalEntries == 0 && statusCounts.every((e) => e == 0);

  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;

  factory ListStats.fromJikan(Map<String, dynamic>? json, {required bool manga}) {
    if (json == null) return const ListStats();
    return ListStats(
      meanScore: (json['mean_score'] as num?)?.toDouble(),
      totalEntries: _int(json['total_entries']),
      days: (json[manga ? 'days_read' : 'days_watched'] as num?)?.toDouble(),
      progress: _int(json[manga ? 'chapters_read' : 'episodes_watched']),
      volumes: manga ? _int(json['volumes_read']) : 0,
      current: _int(json[manga ? 'reading' : 'watching']),
      completed: _int(json['completed']),
      onHold: _int(json['on_hold']),
      dropped: _int(json['dropped']),
      planned: _int(json[manga ? 'plan_to_read' : 'plan_to_watch']),
    );
  }

  /// Official MAL numbers (own profile only), which are fresher than Jikan's.
  factory ListStats.fromMalAnime(UserAnimeStatistics s) => ListStats(
        meanScore: s.meanScore,
        totalEntries: s.numItems?.toInt() ?? 0,
        days: s.numDaysWatched ?? s.numDays,
        progress: s.numEpisodes?.toInt() ?? 0,
        current: s.numItemsWatching?.toInt() ?? 0,
        completed: s.numItemsCompleted?.toInt() ?? 0,
        onHold: s.numItemsOnHold?.toInt() ?? 0,
        dropped: s.numItemsDropped?.toInt() ?? 0,
        planned: s.numItemsPlanToWatch?.toInt() ?? 0,
      );

  factory ListStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ListStats();
    return ListStats(
      meanScore: (json['meanScore'] as num?)?.toDouble(),
      totalEntries: _int(json['totalEntries']),
      days: (json['days'] as num?)?.toDouble(),
      progress: _int(json['progress']),
      volumes: _int(json['volumes']),
      current: _int(json['current']),
      completed: _int(json['completed']),
      onHold: _int(json['onHold']),
      dropped: _int(json['dropped']),
      planned: _int(json['planned']),
    );
  }

  Map<String, dynamic> toJson() => {
        'meanScore': meanScore,
        'totalEntries': totalEntries,
        'days': days,
        'progress': progress,
        'volumes': volumes,
        'current': current,
        'completed': completed,
        'onHold': onHold,
        'dropped': dropped,
        'planned': planned,
      };
}
