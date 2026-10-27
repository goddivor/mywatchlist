import 'package:flutter/foundation.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/services/api/mwl_api.dart';

/// The next episode of an airing anime: its number and air time (UTC).
@immutable
class NextEpisode {
  final int episode;
  final DateTime airingAt;

  const NextEpisode(this.episode, this.airingAt);

  @override
  bool operator ==(Object other) =>
      other is NextEpisode && other.episode == episode && other.airingAt == airingAt;

  @override
  int get hashCode => Object.hash(episode, airingAt);
}

/// Finds the next episode of an anime in the LiveChart schedule of the
/// current season (through the backend). The season is requested once per
/// session and shared by every detail page.
abstract final class NextEpisodes {
  static Future<List<LiveChartEpisode>>? _season;

  /// The schedule source; tests replace it.
  @visibleForTesting
  static Future<List<LiveChartEpisode>> Function() source =
      () => MwlApi.i.getLiveChartSchedule();

  /// The first episode of [malId] airing after [now], or null when it is not
  /// on the schedule, has nothing left to air, or the request failed (a
  /// failure is retried on the next call).
  static Future<NextEpisode?> forMalId(int malId, {DateTime? now}) async {
    try {
      final episodes = await (_season ??= source());
      return pick(episodes, malId, now ?? DateTime.now());
    } catch (_) {
      _season = null;
      return null;
    }
  }

  /// Earliest episode of [malId] that airs after [now].
  @visibleForTesting
  static NextEpisode? pick(List<LiveChartEpisode> episodes, int malId, DateTime now) {
    NextEpisode? best;
    for (final e in episodes) {
      if (e.malId != malId || e.timestamp <= 0) continue;
      final at = e.airingAt;
      if (!at.isAfter(now)) continue;
      if (best == null || at.isBefore(best.airingAt)) best = NextEpisode(e.episode, at);
    }
    return best;
  }

  @visibleForTesting
  static void reset() => _season = null;
}
