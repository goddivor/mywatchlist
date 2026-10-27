import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart';

export 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;

/// Reads the `statistics` block of a Jikan `users/{name}/full` payload.
({ListStats anime, ListStats manga}) parseJikanStatistics(Map<String, dynamic>? full) {
  final stats = full?['statistics'];
  final map = stats is Map ? Map<String, dynamic>.from(stats) : null;
  Map<String, dynamic>? part(String key) {
    final v = map?[key];
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  return (
    anime: ListStats.fromJikan(part('anime'), manga: false),
    manga: ListStats.fromJikan(part('manga'), manga: true),
  );
}
