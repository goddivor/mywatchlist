import 'package:flutter/foundation.dart';
import 'package:mwl_commons/mwl_commons.dart' show ContentStatsHtml;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

/// Where the statistics of a title came from.
enum StatsSource { jikan, myAnimeList }

/// Score distribution and list status counts of a title, whatever answered.
@immutable
class ContentStats {
  final AnimeStatistics stats;
  final StatsSource source;

  const ContentStats(this.stats, this.source);

  /// Scores 1 to 10 in ascending order, entries without a score dropped.
  List<ScoreStatistics> get sortedScores => (stats.scores ?? const <ScoreStatistics>[])
      .where((s) => s.score != null)
      .toList()
    ..sort((a, b) => a.score!.compareTo(b.score!));

  int get totalVotes => sortedScores.fold<int>(0, (sum, s) => sum + (s.votes ?? 0));

  /// MAL's stats page mapped to the Jikan model, so both sources draw the same bars.
  factory ContentStats.fromMal(ContentStatsHtml html) => ContentStats(
        AnimeStatistics(
          watching: html.statuses.watching,
          completed: html.statuses.completed,
          onHold: html.statuses.onHold,
          dropped: html.statuses.dropped,
          planToWatch: html.statuses.planToWatch,
          total: html.statuses.total,
          scores: [
            for (final s in html.scores)
              ScoreStatistics(score: s.score, votes: s.votes, percentage: s.percentage),
          ],
        ),
        StatsSource.myAnimeList,
      );
}

/// Loads [ContentStats]: Jikan first (its client times out after 12 s and then
/// skips Jikan for 30 s), then MAL's stats page through the mwl-api
/// (`MwlApi.getContentStats`, null after 15 s). Throws when neither answered,
/// so the caller shows MAL's score figures. A running load is shared.
class ContentStatsSource {
  ContentStatsSource._();

  /// Jikan `statistics`; replaceable in tests.
  static Future<AnimeStatistics> Function(int id, String category) jikan = _jikan;

  /// MAL's stats page; replaceable in tests. Never throws, null on failure.
  static Future<ContentStatsHtml?> Function(int id, String category) mal = _mal;

  static final Map<String, Future<ContentStats>> _inFlight = {};

  static Future<AnimeStatistics> _jikan(int id, String category) =>
      JikanApi.getAnimeStatistics(id, category: category);

  static Future<ContentStatsHtml?> _mal(int id, String category) =>
      MwlApi.i.getContentStats(id, category);

  /// Load of one title, shared while it runs (the sources keep their own
  /// caches afterwards), so a Retry always asks again.
  static Future<ContentStats> load(int id, String category) {
    final key = '$category:$id';
    final pending = _inFlight[key];
    if (pending != null) return pending;
    final future = _load(id, category);
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key)).ignore();
    return future;
  }

  static Future<ContentStats> _load(int id, String category) async {
    Object? jikanError;
    try {
      return ContentStats(await jikan(id, category), StatsSource.jikan);
    } catch (e) {
      jikanError = e;
    }
    ContentStatsHtml? html;
    try {
      html = await mal(id, category);
    } catch (_) {
      html = null;
    }
    if (html == null) throw StateError('No statistics source answered: $jikanError');
    return ContentStats.fromMal(html);
  }

  /// Forgets the loads and restores the real sources (tests).
  @visibleForTesting
  static void reset() {
    _inFlight.clear();
    jikan = _jikan;
    mal = _mal;
  }
}
