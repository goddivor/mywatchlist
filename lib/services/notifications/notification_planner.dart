import 'package:mywatchlist/user/preferences/notification_preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart' show AiringEpisode;

import 'notification_models.dart';

/// Pure rules that turn the user's lists and the airing schedule into notifications.
///
/// Source of airing times, in order: the real schedule ([AiringEpisode], LiveChart through
/// the calendar unit's `AiringSchedule`), then the weekly MAL broadcast slot when the anime
/// is not in the schedule.
abstract final class NotificationPlanner {
  /// Weeks projected after the last scheduled episode (one episode per week), so the user
  /// is still notified if they do not open the app for a few weeks.
  static const int projectedWeeks = 3;

  /// Android keeps all pending alarms; stay far below any vendor limit.
  static const int maxNotifications = 200;

  static const int slotsPerAnime = 8;

  static List<PlannedNotification> plan({
    required List<AiringCandidate> candidates,
    required List<AiringEpisode> schedule,
    required NotificationPreferences prefs,
    required NotificationTexts texts,
    required DateTime now,
  }) {
    final at = now.toUtc();
    final byId = <int, List<AiringEpisode>>{};
    for (final e in schedule) {
      if (e.airingAt.isAfter(at)) (byId[e.malId] ??= []).add(e);
    }
    for (final list in byId.values) {
      list.sort((a, b) => a.airingAt.compareTo(b.airingAt));
    }

    final out = <PlannedNotification>[];
    for (final c in candidates) {
      final kind = switch (c.status) {
        'watching' when prefs.watchingList => NotificationKind.watching,
        'plan_to_watch' when prefs.planToWatchList => NotificationKind.planToWatch,
        _ => null,
      };
      if (kind == null || c.airingStatus == 'finished_airing') continue;
      final body = kind == NotificationKind.watching ? texts.watchingBody : texts.planToWatchBody;
      final payload = animePayload(c.malId);

      final real = byId[c.malId];
      if (real != null && real.isNotEmpty) {
        final entries = _episodesOf(real, c.numEpisodes);
        for (var slot = 0; slot < entries.length && slot < slotsPerAnime; slot++) {
          final e = entries[slot];
          out.add(PlannedNotification(
            id: c.malId * slotsPerAnime + slot,
            kind: kind,
            at: e.$2,
            title: texts.episodeTitle(c.title, e.$1),
            body: body,
            payload: payload,
            malId: c.malId,
            episode: e.$1,
            imageUrl: c.imageUrl,
          ));
        }
        continue;
      }

      // Not in the schedule: repeat the weekly MAL broadcast slot, only for a series that is
      // on air (before the premiere the slot would fire weeks too early).
      if (c.airingStatus != 'currently_airing') continue;
      final next = nextBroadcast(c.broadcastDay, c.broadcastTime, at);
      if (next == null) continue;
      out.add(PlannedNotification(
        id: c.malId * slotsPerAnime,
        kind: kind,
        at: next,
        title: texts.newEpisodeTitle(c.title),
        body: body,
        payload: payload,
        malId: c.malId,
        repeatsWeekly: true,
        imageUrl: c.imageUrl,
      ));
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out.length > maxNotifications ? out.sublist(0, maxNotifications) : out;
  }

  /// The scheduled episodes plus [projectedWeeks] weekly projections, capped by [total].
  static List<(int, DateTime)> _episodesOf(List<AiringEpisode> real, int? total) {
    final cap = total != null && total > 0 ? total : null;
    final list = <(int, DateTime)>[];
    for (final e in real) {
      if (cap != null && e.episode > cap) continue;
      list.add((e.episode, e.airingAt));
    }
    if (list.isEmpty) return list;
    var last = list.last;
    for (var i = 0; i < projectedWeeks; i++) {
      final next = (last.$1 + 1, last.$2.add(const Duration(days: 7)));
      if (cap != null && next.$1 > cap) break;
      list.add(next);
      last = next;
    }
    return list;
  }

  static const _days = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  /// The next UTC instant of a MAL broadcast slot (day name + `HH:mm`, Japan time, UTC+9),
  /// strictly after [now]; null when the slot is missing or malformed.
  static DateTime? nextBroadcast(String? day, String? time, DateTime now) {
    final weekday = _days[day?.trim().toLowerCase()];
    final parts = time?.split(':');
    if (weekday == null || parts == null || parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;

    const jst = Duration(hours: 9);
    final nowJst = now.toUtc().add(jst);
    var slot = DateTime.utc(nowJst.year, nowJst.month, nowJst.day, hour, minute);
    slot = slot.add(Duration(days: (weekday - slot.weekday) % 7));
    var result = slot.subtract(jst);
    while (!result.isAfter(now.toUtc())) {
      result = result.add(const Duration(days: 7));
    }
    return result;
  }
}
