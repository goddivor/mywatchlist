import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import 'notification_models.dart';

/// The translated strings of the Simkl show and movie notifications.
class SimklReleaseTexts {
  const SimklReleaseTexts({
    required this.episodeTitle,
    required this.movieTitle,
    required this.watchingBody,
    required this.planShowBody,
    required this.planMovieBody,
  });

  /// "Reacher · S2E5" ([code] is `S2E5`, or the episode number without a season).
  final String Function(String title, String code) episodeTitle;

  /// "Inception is out".
  final String Function(String title) movieTitle;
  final String watchingBody;
  final String planShowBody;
  final String planMovieBody;
}

/// Pure rules that turn the signed-in user's Simkl show and movie lists, and Simkl's calendars,
/// into notifications: a show's episode when it airs (Watching and Plan to watch), a movie's
/// release (Plan to watch). Simkl's anime keep the MAL-keyed airing schedule
/// (`NotificationPlanner`).
abstract final class SimklReleasePlanner {
  /// Notification ids of Simkl shows and movies: far from the anime reminders
  /// (`malId * 8 + slot`) and the MAL hub ids (`0x40000000` and up).
  static const int idBase = 0x20000000;

  /// Episodes notified per show (Simkl's calendar covers about a month).
  static const int slotsPerTitle = 8;

  /// The id of slot [slot] of Simkl title [simklId].
  static int idOf(int simklId, int slot) => idBase + simklId * slotsPerTitle + slot;

  /// The key of the cover kept for Simkl title [simklId], apart from the MAL ids.
  static int coverIdOf(int simklId) => idBase + simklId;

  /// The payload that opens the Simkl page of a show or a movie: `simkl:tv:<id>`,
  /// `simkl:movie:<id>` (read by [parseSimklTitlePayload]).
  static String payloadOf(int simklId, {required bool movie}) =>
      'simkl:${movie ? 'movie' : 'tv'}:$simklId';

  static List<PlannedNotification> plan({
    required List<ListEntryView> shows,
    required List<SimklMedia> showCalendar,
    required List<ListEntryView> movies,
    required List<SimklMedia> movieCalendar,
    required NotificationPreferences prefs,
    required SimklReleaseTexts texts,
    required DateTime now,
  }) {
    final at = now.toUtc();
    final out = <PlannedNotification>[];

    final airings = <int, List<SimklMedia>>{};
    for (final m in showCalendar) {
      final date = m.airDate;
      if (date != null && date.isAfter(at)) (airings[m.simklId] ??= []).add(m);
    }
    for (final e in shows) {
      final kind = _kindOf(e, prefs);
      if (kind == null || e.releaseState == ReleaseState.finished) continue;
      final list = airings[e.id];
      if (list == null) continue;
      list.sort((a, b) => a.airDate!.compareTo(b.airDate!));
      for (var slot = 0; slot < list.length && slot < slotsPerTitle; slot++) {
        final m = list[slot];
        final n = m.episode;
        final code = m.season != null && m.season! > 0 && n != null ? 'S${m.season}E$n' : '${n ?? ''}';
        out.add(PlannedNotification(
          id: idOf(e.id, slot),
          kind: kind,
          at: m.airDate!,
          title: code.isEmpty ? e.title : texts.episodeTitle(e.title, code),
          body: kind == NotificationKind.watching ? texts.watchingBody : texts.planShowBody,
          payload: payloadOf(e.id, movie: false),
          episode: n,
          imageUrl: e.imageUrl,
          coverId: coverIdOf(e.id),
        ));
      }
    }

    if (prefs.planToWatchList) {
      final releases = <int, DateTime>{};
      for (final m in movieCalendar) {
        final date = m.airDate;
        if (date == null || !date.isAfter(at)) continue;
        final known = releases[m.simklId];
        if (known == null || date.isBefore(known)) releases[m.simklId] = date;
      }
      for (final e in movies) {
        if (e.status != ListEntryStatus.planned) continue;
        final date = releases[e.id];
        if (date == null) continue;
        out.add(PlannedNotification(
          id: idOf(e.id, 0),
          kind: NotificationKind.planToWatch,
          at: date,
          title: texts.movieTitle(e.title),
          body: texts.planMovieBody,
          payload: payloadOf(e.id, movie: true),
          imageUrl: e.imageUrl,
          coverId: coverIdOf(e.id),
        ));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  static NotificationKind? _kindOf(ListEntryView e, NotificationPreferences prefs) =>
      switch (e.status) {
        ListEntryStatus.current when prefs.watchingList => NotificationKind.watching,
        ListEntryStatus.planned when prefs.planToWatchList => NotificationKind.planToWatch,
        _ => null,
      };
}

/// A tapped Simkl show or movie notification: its Simkl id and whether it is a movie.
typedef SimklTitlePayload = ({int simklId, bool movie});

/// Reads `simkl:tv:<id>` / `simkl:movie:<id>` ([SimklReleasePlanner.payloadOf]); null for
/// any other payload.
SimklTitlePayload? parseSimklTitlePayload(String? payload) {
  final parts = payload?.trim().split(':');
  if (parts == null || parts.length != 3 || parts[0] != 'simkl') return null;
  final movie = switch (parts[1]) { 'tv' => false, 'movie' => true, _ => null };
  final id = int.tryParse(parts[2]);
  if (movie == null || id == null || id <= 0) return null;
  return (simklId: id, movie: movie);
}
