import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';

/// JST is UTC+9 all year (Japan has no daylight saving time).
const Duration jstOffset = Duration(hours: 9);

/// [utc] expressed on the wall clock of [pref]: the returned `DateTime` is a
/// UTC value whose fields (`hour`, `weekday`, `day`...) read as that zone's.
DateTime inTimezone(DateTime utc, TimezonePref pref) {
  final u = utc.toUtc();
  return switch (pref) {
    TimezonePref.utc => u,
    TimezonePref.jst => u.add(jstOffset),
    TimezonePref.local => () {
        final local = u.toLocal();
        return DateTime.utc(local.year, local.month, local.day, local.hour, local.minute, local.second);
      }(),
  };
}

/// Short zone label shown next to times: `JST`, `UTC` or the device zone name.
String timezoneLabel(TimezonePref pref, [DateTime? now]) => switch (pref) {
      TimezonePref.jst => 'JST',
      TimezonePref.utc => 'UTC',
      TimezonePref.local => (now ?? DateTime.now()).timeZoneName,
    };

/// List-status filter values of the calendar chips.
class CalendarFilter {
  const CalendarFilter._();
  static const all = 'all';
  static const watching = 'watching';
  static const planToWatch = 'plan_to_watch';

  /// Watching or Plan to Watch: DailyAL's default (both status chips on).
  static const watchingOrPlanned = 'watching_or_planned';
  static const inList = 'in_list';
  static const notInList = 'not_in_list';
}

/// Whether [entry] passes the chip [filter] (null or `all` keeps everything).
/// When the list is unknown (no MAL account) nothing is hidden.
bool matchesFilter(CalendarEntry entry, String? filter, {required bool listKnown}) {
  if (filter == null || filter == CalendarFilter.all || !listKnown) return true;
  return switch (filter) {
    CalendarFilter.watching => entry.listStatus == 'watching',
    CalendarFilter.planToWatch => entry.listStatus == 'plan_to_watch',
    CalendarFilter.watchingOrPlanned => entry.isHighlighted,
    CalendarFilter.inList => entry.listStatus != null,
    CalendarFilter.notInList => entry.listStatus == null,
    _ => true,
  };
}

/// The filter value after tapping a status chip of the calendar (DailyAL's
/// All / Plan to Watch / Watching toggles): All clears the others, a status
/// chip toggles itself, and turning both statuses off falls back to All.
String toggleFilter(String? current, String tapped) {
  if (tapped == CalendarFilter.all) return CalendarFilter.all;
  var watching = current == CalendarFilter.watching || current == CalendarFilter.watchingOrPlanned;
  var planned = current == CalendarFilter.planToWatch || current == CalendarFilter.watchingOrPlanned;
  if (tapped == CalendarFilter.watching) watching = !watching;
  if (tapped == CalendarFilter.planToWatch) planned = !planned;
  if (watching && planned) return CalendarFilter.watchingOrPlanned;
  if (watching) return CalendarFilter.watching;
  if (planned) return CalendarFilter.planToWatch;
  return CalendarFilter.all;
}

/// Whether the chip [chip] is on for the filter value [filter].
bool isChipOn(String? filter, String chip) => switch (chip) {
      CalendarFilter.all => filter == null || filter == CalendarFilter.all,
      CalendarFilter.watching => filter == CalendarFilter.watching || filter == CalendarFilter.watchingOrPlanned,
      CalendarFilter.planToWatch =>
        filter == CalendarFilter.planToWatch || filter == CalendarFilter.watchingOrPlanned,
      _ => filter == chip,
    };

/// [entries] plus, for every anime, the episode before its earliest known one,
/// one week earlier, when that time has already passed at [now].
///
/// LiveChart only lists upcoming episodes, so an episode that aired earlier
/// today would vanish from the calendar; a weekly show's previous episode is
/// its next one minus seven days. A first episode has no previous one, and a
/// show on a break (next episode more than a week away) gets nothing.
List<CalendarEntry> withPreviousEpisodes(List<CalendarEntry> entries, {required DateTime now}) {
  final earliest = <int, CalendarEntry>{};
  for (final e in entries) {
    final known = earliest[e.malId];
    if (known == null || e.airingAt.isBefore(known.airingAt)) earliest[e.malId] = e;
  }
  final at = now.toUtc();
  final previous = [
    for (final e in earliest.values)
      if (e.episode > 1 && e.airingAt.subtract(const Duration(days: 7)).isBefore(at))
        CalendarEntry(
          malId: e.malId,
          title: e.title,
          imageUrl: e.imageUrl,
          episode: e.episode - 1,
          airingAt: e.airingAt.subtract(const Duration(days: 7)),
          numEpisodes: e.numEpisodes,
          listStatus: e.listStatus,
          relatedLinks: e.relatedLinks,
        ),
  ];
  return previous.isEmpty ? entries : [...entries, ...previous];
}

/// One day of the week.
class CalendarDay {
  /// Midnight of the day on the wall clock of the chosen zone (UTC fields).
  final DateTime date;

  /// Entries of the day that pass the filter, earliest first.
  final List<CalendarEntry> entries;

  const CalendarDay(this.date, this.entries);

  bool get isEmpty => entries.isEmpty;
}

/// The seven days starting at the day of [now] in [pref], each with the entries
/// that air that day and pass [filter]. Episodes before today or more than a
/// week ahead are left out.
List<CalendarDay> buildWeek(
  List<CalendarEntry> entries, {
  required DateTime now,
  required TimezonePref pref,
  String? filter,
  required bool listKnown,
}) {
  final today = inTimezone(now, pref);
  final start = DateTime.utc(today.year, today.month, today.day);
  final buckets = List.generate(7, (_) => <CalendarEntry>[]);
  for (final entry in entries) {
    if (!matchesFilter(entry, filter, listKnown: listKnown)) continue;
    final shown = inTimezone(entry.airingAt, pref);
    final day = DateTime.utc(shown.year, shown.month, shown.day);
    final index = day.difference(start).inDays;
    if (index < 0 || index > 6) continue;
    buckets[index].add(entry);
  }
  return [
    for (var i = 0; i < 7; i++)
      CalendarDay(
        DateTime.utc(start.year, start.month, start.day + i),
        buckets[i]..sort((a, b) => a.airingAt.compareTo(b.airingAt)),
      ),
  ];
}

/// How many weekly events to create from [nextEpisode] up to [total] episodes
/// (at least one), or null when the total is unknown.
int? recurrenceCount({required int? total, required int nextEpisode}) {
  if (total == null || total <= 0) return null;
  final count = total - nextEpisode + 1;
  return count < 1 ? 1 : count;
}

/// Splits [delta] into the pieces of the countdown text.
({int days, int hours, int minutes, int seconds}) splitDuration(Duration delta) => (
      days: delta.inDays,
      hours: delta.inHours.remainder(24),
      minutes: delta.inMinutes.remainder(60),
      seconds: delta.inSeconds.remainder(60),
    );
