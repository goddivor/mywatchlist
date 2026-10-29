import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart' show mediaTypeLabel;

/// Locale-aware wording of the Simkl title page. Simkl's own words (English day names, status
/// codes, relation types, dates printed by the site) are translated here, never shown raw.
abstract final class SimklFormat {
  static String get _locale => Intl.getCurrentLocale();

  static String count(int value) => NumberFormat.decimalPattern(_locale).format(value);

  static String compact(int value) =>
      value < 10000 ? count(value) : NumberFormat.compact(locale: _locale).format(value);

  static String score(double value) => NumberFormat('0.0#', _locale).format(value);

  /// 24 → "24 %" / "24%" as the locale writes it.
  static String percent(double value) =>
      NumberFormat.decimalPercentPattern(locale: _locale, decimalDigits: value % 1 == 0 ? 0 : 1).format(value / 100);

  static String votes(int votes) => S.current.Smp_Votes(votes, compact(votes));

  static const _days = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  /// "Sunday" → "dimanche" (2024-01-01 was a Monday).
  static String? weekday(String? english) {
    final d = _days[english?.trim().toLowerCase()];
    if (d == null) return english;
    return DateFormat.EEEE(_locale).format(DateTime(2024, 1, d));
  }

  /// UTC offset, in minutes, of the zones Simkl prints for airing slots that never change with
  /// daylight saving time. Other zones are shown as Simkl gives them.
  static const _fixedOffsets = {
    'asia/tokyo': 540,
    'japan': 540,
    'asia/seoul': 540,
    'asia/shanghai': 480,
    'asia/hong_kong': 480,
    'asia/taipei': 480,
    'asia/singapore': 480,
    'asia/bangkok': 420,
    'asia/jakarta': 420,
    'asia/manila': 480,
    'asia/kolkata': 330,
    'utc': 0,
    'gmt': 0,
    'etc/utc': 0,
  };

  /// "Sunday at 23:15 (JST)": the airing slot Simkl prints in its own zone (`Asia/Tokyo`),
  /// moved to the time zone setting ([zone]; [localOffset] is the device offset, a test seam).
  /// A zone this app cannot convert exactly is shown as Simkl gives it.
  static String? airs(SimklAirs? airs, {TimezonePref? zone, Duration Function()? localOffset}) {
    if (airs == null || airs.isEmpty) return null;
    var day = airs.day;
    var time = airs.time;
    var label = airs.timezone;
    final from = _fixedOffsets[airs.timezone?.trim().toLowerCase()];
    final clock = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time ?? '');
    final dayNumber = _days[day?.trim().toLowerCase()];
    if (from != null && clock != null) {
      final preference = zone ?? Preferences.content.timezone;
      final to = switch (preference) {
        TimezonePref.utc => 0,
        TimezonePref.jst => 540,
        TimezonePref.local => (localOffset ?? () => DateTime.now().timeZoneOffset)().inMinutes,
      };
      var minutes = int.parse(clock.group(1)!) * 60 + int.parse(clock.group(2)!) + to - from;
      var shift = 0;
      while (minutes < 0) {
        minutes += 1440;
        shift--;
      }
      while (minutes >= 1440) {
        minutes -= 1440;
        shift++;
      }
      time = '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
      if (dayNumber != null) day = _dayName((dayNumber - 1 + shift) % 7 + 1);
      label = switch (preference) {
        TimezonePref.utc => 'UTC',
        TimezonePref.jst => 'JST',
        TimezonePref.local => null,
      };
    }
    final dayText = weekday(day);
    final base = dayText != null && time != null
        ? S.current.Smp_Airs_Value(dayText, time)
        : (dayText ?? time ?? '');
    return label == null ? base : '$base ($label)';
  }

  static String _dayName(int weekday) => _days.entries.firstWhere((e) => e.value == weekday).key;

  /// "2019-04-06" → "6 avr. 2019".
  static String? isoDate(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    return d == null ? null : DateFormat.yMMMd(_locale).format(d);
  }

  static String? aired(SimklTitle t) {
    final from = isoDate(t.firstAired);
    final to = isoDate(t.lastAired);
    if (from == null) return null;
    return to == null || to == from ? from : '$from – $to';
  }

  /// A date Simkl printed in English ("March 13, 2024", "23:49 July 1, 2024") in the locale.
  static String? siteDate(String? text) {
    final s = text?.trim();
    if (s == null || s.isEmpty) return null;
    for (final pattern in ['MMMM d, y', 'HH:mm MMMM d, y', 'MMM d, y']) {
      try {
        final d = DateFormat(pattern, 'en_US').parseStrict(s);
        return pattern.startsWith('HH')
            ? '${DateFormat.yMMMd(_locale).format(d)} ${DateFormat.Hm(_locale).format(d)}'
            : DateFormat.yMMMd(_locale).format(d);
      } catch (_) {}
    }
    return null;
  }

  static String episodeDate(DateTime date) => DateFormat.yMMMd(_locale).format(date.toLocal());

  static String? status(String? code) => switch (code?.toLowerCase()) {
        'ended' || 'finished' => S.current.Smp_Status_Ended,
        'ongoing' || 'airing' || 'returning series' => S.current.Smp_Status_Airing,
        'tba' || 'upcoming' || 'planned' || 'in production' => S.current.Smp_Status_Upcoming,
        _ => null,
      };

  /// `tv`, `movie`, `ova`, `music video`… in the locale (the list's media type labels).
  static String? type(String? code) {
    final c = code?.trim().toLowerCase();
    if (c == null || c.isEmpty) return null;
    return mediaTypeLabel(c == 'music video' ? 'music' : c.replaceAll(' ', '_'));
  }

  static String relation(String? type) => switch (type?.toLowerCase().replaceAll(RegExp(r'[\s-]'), '_')) {
        'sequel' => S.current.Smp_Rel_Sequel,
        'prequel' => S.current.Smp_Rel_Prequel,
        'side_story' => S.current.Smp_Rel_Side_Story,
        'parent_story' => S.current.Smp_Rel_Parent_Story,
        'summary' => S.current.Smp_Rel_Summary,
        'full_story' => S.current.Smp_Rel_Full_Story,
        'alternative_version' || 'alternative' => S.current.Smp_Rel_Alternative,
        'alternative_setting' => S.current.Smp_Rel_Alt_Setting,
        'spin_off' || 'spinoff' => S.current.Smp_Rel_Spin_Off,
        'character' => S.current.Smp_Rel_Character,
        _ => S.current.Smp_Rel_Other,
      };

  static String watcherStatus(SimklWatcherStatus s) => switch (s) {
        SimklWatcherStatus.watching => S.current.Smp_Watching,
        SimklWatcherStatus.planToWatch => S.current.Smp_Plan_To_Watch,
        SimklWatcherStatus.completed => S.current.Smp_Completed,
        SimklWatcherStatus.onHold => S.current.Smp_On_Hold,
        SimklWatcherStatus.dropped => S.current.Smp_Dropped,
      };

  static String aspect(SimklReviewAspect a) => switch (a) {
        SimklReviewAspect.story => S.current.Smp_Story,
        SimklReviewAspect.animation => S.current.Smp_Animation,
        SimklReviewAspect.sound => S.current.Smp_Sound,
        SimklReviewAspect.character => S.current.Smp_Character,
        SimklReviewAspect.enjoyment => S.current.Smp_Enjoyment,
      };

  /// [utc] in the time zone setting (local, JST or UTC); [zone] is a test seam.
  static DateTime inZone(DateTime utc, {TimezonePref? zone}) => switch (zone ?? Preferences.content.timezone) {
        TimezonePref.utc => utc.toUtc(),
        TimezonePref.jst => utc.toUtc().add(const Duration(hours: 9)),
        TimezonePref.local => utc.toLocal(),
      };

  /// "23:15" in the time zone setting.
  static String clock(DateTime utc, {TimezonePref? zone}) => DateFormat.Hm(_locale).format(inZone(utc, zone: zone));

  /// "Sun 23:15" in the time zone setting.
  static String dayClock(DateTime utc, {TimezonePref? zone}) =>
      DateFormat('E HH:mm', _locale).format(inZone(utc, zone: zone));

  /// "6 avr. 2019 23:30" in the time zone setting.
  static String dateClock(DateTime utc, {TimezonePref? zone}) {
    final t = inZone(utc, zone: zone);
    return '${DateFormat.yMMMd(_locale).format(t)} ${DateFormat.Hm(_locale).format(t)}';
  }

  /// "in 2 d 4 h", "in 3 h 10 min", "in 5 min" from [now] to [at]; null once [at] is past.
  static String? countdown(DateTime at, DateTime now) {
    final wait = at.toUtc().difference(now.toUtc());
    if (wait.isNegative) return null;
    if (wait.inDays > 0) return S.current.UserList_In_Days_Hours(wait.inDays, wait.inHours % 24);
    if (wait.inHours > 0) return S.current.UserList_In_Hours_Minutes(wait.inHours, wait.inMinutes % 60);
    return S.current.UserList_In_Minutes(wait.inMinutes < 1 ? 1 : wait.inMinutes);
  }

  /// "1d 22h" / "11h 0m" / "25m" for a number of minutes.
  static String minutes(int mins) {
    final s = S.current;
    if (mins >= 1440) return s.Skp_Dur_Days_Hours(mins ~/ 1440, (mins % 1440) ~/ 60);
    if (mins >= 60) return s.Skp_Dur_Hours_Mins(mins ~/ 60, mins % 60);
    return s.Skp_Dur_Mins(mins);
  }
}
