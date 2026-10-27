import 'package:mywatchlist/constants/constants.dart';

/// One list entry in the shape every tracker converts to and from.
///
/// Statuses are MyAnimeList keys (`watching`, `plan_to_read`...), the score is
/// on a 0-10 scale and may be decimal (AniList POINT_10_DECIMAL, Kitsu half
/// points), dates are `yyyy-MM-dd` text (a partial `yyyy-MM` / `yyyy` is kept).
/// A null field means "not known / not sent": syncing never erases a value on
/// the target because the source has none.
class SyncEntry {
  final String? status;
  final double? score;
  final int? progress;
  final int? volumes;
  final String? startDate;
  final String? finishDate;
  final int? repeat;
  final String? notes;

  /// Id of the entry on the tracker (AniList list entry id, Kitsu library
  /// entry id); null when unknown or not applicable.
  final String? entryId;

  const SyncEntry({
    this.status,
    this.score,
    this.progress,
    this.volumes,
    this.startDate,
    this.finishDate,
    this.repeat,
    this.notes,
    this.entryId,
  });

  bool get hasScore => score != null && score! > 0;

  /// The fields worth sending: empty values are dropped.
  SyncEntry compact() => SyncEntry(
        status: (status?.isEmpty ?? true) ? null : status,
        score: hasScore ? score : null,
        progress: progress,
        volumes: (volumes ?? 0) > 0 ? volumes : null,
        startDate: (startDate?.isEmpty ?? true) ? null : startDate,
        finishDate: (finishDate?.isEmpty ?? true) ? null : finishDate,
        repeat: (repeat ?? 0) > 0 ? repeat : null,
        notes: (notes?.trim().isEmpty ?? true) ? null : notes!.trim(),
        entryId: entryId,
      );

  SyncEntry copyWith({
    String? status,
    double? score,
    int? progress,
    int? volumes,
    String? startDate,
    String? finishDate,
    int? repeat,
    String? notes,
    String? entryId,
    bool clearScore = false,
    bool clearStartDate = false,
    bool clearFinishDate = false,
  }) =>
      SyncEntry(
        status: status ?? this.status,
        score: clearScore ? null : (score ?? this.score),
        progress: progress ?? this.progress,
        volumes: volumes ?? this.volumes,
        startDate: clearStartDate ? null : (startDate ?? this.startDate),
        finishDate: clearFinishDate ? null : (finishDate ?? this.finishDate),
        repeat: repeat ?? this.repeat,
        notes: notes ?? this.notes,
        entryId: entryId ?? this.entryId,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncEntry &&
      other.status == status &&
      other.score == score &&
      other.progress == progress &&
      other.volumes == volumes &&
      other.startDate == startDate &&
      other.finishDate == finishDate &&
      other.repeat == repeat &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
      status, score, progress, volumes, startDate, finishDate, repeat, notes);

  @override
  String toString() => 'SyncEntry($status, score: $score, progress: $progress, '
      'volumes: $volumes, $startDate -> $finishDate, repeat: $repeat)';
}

/// Status words of each tracker against MyAnimeList's.
class StatusMaps {
  const StatusMaps._();

  static const _anilist = {
    'watching': 'CURRENT',
    'reading': 'CURRENT',
    'completed': 'COMPLETED',
    'on_hold': 'PAUSED',
    'dropped': 'DROPPED',
    'plan_to_watch': 'PLANNING',
    'plan_to_read': 'PLANNING',
  };

  static const _kitsu = {
    'watching': 'current',
    'reading': 'current',
    'completed': 'completed',
    'on_hold': 'on_hold',
    'dropped': 'dropped',
    'plan_to_watch': 'planned',
    'plan_to_read': 'planned',
  };

  static const _simkl = {
    'watching': 'watching',
    'reading': 'watching',
    'completed': 'completed',
    'on_hold': 'hold',
    'dropped': 'dropped',
    'plan_to_watch': 'plantowatch',
    'plan_to_read': 'plantowatch',
  };

  static Map<String, String>? _forward(AccountType t) => switch (t) {
        AccountType.anilist => _anilist,
        AccountType.kitsu => _kitsu,
        AccountType.simkl => _simkl,
        _ => null,
      };

  /// MAL key -> tracker word; null when the tracker has none for it.
  static String? toTracker(String malStatus, AccountType tracker) =>
      _forward(tracker)?[malStatus];

  /// Tracker word -> MAL key for an anime or a manga (the "current" and
  /// "planned" words are shared by both, MAL's differ).
  static String? fromTracker(
      String trackerStatus, AccountType tracker, bool isAnime) {
    final map = _forward(tracker);
    if (map == null) return null;
    for (final e in map.entries) {
      if (e.value != trackerStatus) continue;
      final k = e.key;
      final animeKey = k == 'watching' || k == 'plan_to_watch';
      final mangaKey = k == 'reading' || k == 'plan_to_read';
      if (isAnime ? mangaKey : animeKey) continue;
      return k;
    }
    return null;
  }
}

/// Score and date conversions between MAL (0-10 integers) and the trackers.
class SyncScores {
  const SyncScores._();

  /// AniList `scoreRaw` (0-100) of a 0-10 score; decimals survive (7.5 -> 75).
  static int toAnilistRaw(double score) =>
      (score * 10).round().clamp(0, 100).toInt();

  /// Kitsu `ratingTwenty`: 2-20, in 0.5 point steps; null when unscored.
  static int? toKitsuTwenty(double score) {
    if (score <= 0) return null;
    return (score * 2).round().clamp(2, 20).toInt();
  }

  static double fromKitsuTwenty(num twenty) => twenty / 2;

  /// MAL only stores whole points: 7.5 becomes 8.
  static int toMal(double score) => score.round().clamp(0, 10).toInt();

  /// "7" or "7.5": decimals only when there is one.
  static String format(double score) => score == score.roundToDouble()
      ? score.toInt().toString()
      : score.toStringAsFixed(1);
}

/// Dates as `yyyy-MM-dd` text, possibly partial, against each tracker's form.
class SyncDates {
  const SyncDates._();

  /// `{year, month, day}` for AniList's FuzzyDateInput; null for an empty or
  /// unreadable date. A partial MAL date keeps its missing parts null.
  static Map<String, int?>? toFuzzy(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final parts = text.trim().split('-');
    final y = int.tryParse(parts[0]);
    if (y == null || y <= 0) return null;
    final m = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final d = parts.length > 2 ? int.tryParse(parts[2]) : null;
    return {
      'year': y,
      'month': (m != null && m >= 1 && m <= 12) ? m : null,
      'day': (m != null && m >= 1 && m <= 12 && d != null && d >= 1 && d <= 31)
          ? d
          : null,
    };
  }

  static String? fromFuzzy(Object? fuzzy) {
    if (fuzzy is! Map) return null;
    final y = fuzzy['year'];
    if (y is! int) return null;
    final m = fuzzy['month'];
    final d = fuzzy['day'];
    final b = StringBuffer(y.toString().padLeft(4, '0'));
    if (m is int) {
      b.write('-${m.toString().padLeft(2, '0')}');
      if (d is int) b.write('-${d.toString().padLeft(2, '0')}');
    }
    return b.toString();
  }

  /// Kitsu timestamp (midnight UTC) of a complete date; null when partial.
  static String? toTimestamp(String? text) {
    if (text == null) return null;
    final d = DateTime.tryParse(text.trim());
    if (d == null || text.trim().length < 10) return null;
    return '${text.trim().substring(0, 10)}T00:00:00.000Z';
  }

  static String? fromTimestamp(Object? stamp) {
    if (stamp is! String || stamp.length < 10) return null;
    final head = stamp.substring(0, 10);
    return DateTime.tryParse(head) == null ? null : head;
  }
}
