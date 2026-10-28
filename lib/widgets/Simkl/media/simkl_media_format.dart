import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
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

  /// "Sunday at 23:15 (Asia/Tokyo)".
  static String? airs(SimklAirs? airs) {
    if (airs == null || airs.isEmpty) return null;
    final day = weekday(airs.day);
    final time = airs.time;
    final base = day != null && time != null
        ? S.current.Smp_Airs_Value(day, time)
        : (day ?? time ?? '');
    final zone = airs.timezone;
    return zone == null ? base : '$base ($zone)';
  }

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
}
