import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// Status of an entry in a user list, the same for every tracker.
///
/// [current] is "watching" for anime and "reading" for manga, [planned] is
/// "plan to watch" / "plan to read". Each tracker adapter maps its own values
/// (MAL `watching`, AniList `CURRENT`, Kitsu `current`, Simkl `watching`…).
enum ListEntryStatus {
  current,
  completed,
  onHold,
  dropped,
  planned;

  /// MAL list status of this value for [isAnime].
  String malValue({required bool isAnime}) => switch (this) {
        ListEntryStatus.current => isAnime ? 'watching' : 'reading',
        ListEntryStatus.completed => 'completed',
        ListEntryStatus.onHold => 'on_hold',
        ListEntryStatus.dropped => 'dropped',
        ListEntryStatus.planned => isAnime ? 'plan_to_watch' : 'plan_to_read',
      };

  /// The value of a MAL list status (`watching`, `plan_to_read`…), or null.
  static ListEntryStatus? fromMal(String? value) => switch (value) {
        'watching' || 'reading' => ListEntryStatus.current,
        'completed' => ListEntryStatus.completed,
        'on_hold' => ListEntryStatus.onHold,
        'dropped' => ListEntryStatus.dropped,
        'plan_to_watch' || 'plan_to_read' => ListEntryStatus.planned,
        _ => null,
      };

  /// Translated label ("Watching" / "Reading" for [current]).
  String label({required bool isAnime}) => switch (this) {
        ListEntryStatus.current =>
          isAnime ? S.current.Edit_Watching : S.current.Edit_Reading,
        ListEntryStatus.completed => S.current.Edit_Completed,
        ListEntryStatus.onHold => S.current.Edit_On_Hold,
        ListEntryStatus.dropped => S.current.Edit_Dropped,
        ListEntryStatus.planned =>
          isAnime ? S.current.Edit_Plan_To_Watch : S.current.Edit_Plan_To_Read,
      };

  /// Short code of the status chip of grid cards ("CW", "CMP"… / "EC", "FIN"…).
  String shortLabel({required bool isAnime}) => switch (this) {
        ListEntryStatus.current =>
          isAnime ? S.current.Card_Short_Watching : S.current.Card_Short_Reading,
        ListEntryStatus.completed => S.current.Card_Short_Completed,
        ListEntryStatus.onHold => S.current.Card_Short_On_Hold,
        ListEntryStatus.dropped => S.current.Card_Short_Dropped,
        ListEntryStatus.planned =>
          isAnime ? S.current.Card_Short_Plan_Watch : S.current.Card_Short_Plan_Read,
      };

  /// Colour token of the status (theme-colors `AppColors` list statuses).
  ListStatusTone get tone => switch (this) {
        ListEntryStatus.current => ListStatusTone.watching,
        ListEntryStatus.completed => ListStatusTone.completed,
        ListEntryStatus.onHold => ListStatusTone.onHold,
        ListEntryStatus.dropped => ListStatusTone.dropped,
        ListEntryStatus.planned => ListStatusTone.planned,
      };

  /// The colour role of the status in the current theme (readable in light, dark and black).
  AppColorRole colors(BuildContext context) => AppColors.of(context).status(tone);

  IconData get icon => switch (this) {
        ListEntryStatus.current => Icons.play_circle_outline_rounded,
        ListEntryStatus.completed => Icons.check_circle_outline_rounded,
        ListEntryStatus.onHold => Icons.pause_circle_outline_rounded,
        ListEntryStatus.dropped => Icons.cancel_outlined,
        ListEntryStatus.planned => Icons.schedule_rounded,
      };
}

/// Release state of the anime or manga itself.
enum ReleaseState {
  /// Airing (anime) or publishing (manga).
  releasing,
  finished,
  notYetReleased,
  onHiatus,
  unknown;

  /// From MAL's `status` field.
  static ReleaseState fromMal(String? value) => switch (value) {
        'currently_airing' || 'currently_publishing' => ReleaseState.releasing,
        'finished_airing' || 'finished' => ReleaseState.finished,
        'not_yet_aired' || 'not_yet_published' => ReleaseState.notYetReleased,
        'on_hiatus' || 'discontinued' => ReleaseState.onHiatus,
        _ => ReleaseState.unknown,
      };
}

/// Weekly broadcast slot in Japan time (MAL `broadcast`): [weekday] is
/// `DateTime.monday`…`DateTime.sunday`, [minutes] the minutes after midnight.
@immutable
class BroadcastSlot {
  final int weekday;
  final int minutes;

  const BroadcastSlot(this.weekday, this.minutes);

  /// From MAL's `day_of_the_week` (`monday`…) and `start_time` (`23:30`).
  static BroadcastSlot? fromMal(String? day, String? time) {
    const days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    final weekday = days[day?.toLowerCase()];
    final parts = time?.split(':');
    if (weekday == null || parts == null || parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return BroadcastSlot(weekday, h * 60 + m);
  }

  /// Next airing moment after [now] (UTC), Japan being UTC+9 all year.
  DateTime nextAiring(DateTime now) {
    final utcNow = now.toUtc();
    // Broadcast time expressed in UTC: JST minus 9 hours, possibly the day before.
    var utcMinutes = minutes - 9 * 60;
    var utcWeekday = weekday;
    if (utcMinutes < 0) {
      utcMinutes += 24 * 60;
      utcWeekday = utcWeekday == DateTime.monday ? DateTime.sunday : utcWeekday - 1;
    }
    var day = DateTime.utc(utcNow.year, utcNow.month, utcNow.day);
    final shift = (utcWeekday - day.weekday) % 7;
    var candidate = day.add(Duration(days: shift, minutes: utcMinutes));
    if (!candidate.isAfter(utcNow)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  Map<String, dynamic> toJson() => {'d': weekday, 'm': minutes};

  static BroadcastSlot? fromJson(Object? json) {
    if (json is! Map) return null;
    final d = json['d'];
    final m = json['m'];
    return d is int && m is int ? BroadcastSlot(d, m) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is BroadcastSlot && other.weekday == weekday && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(weekday, minutes);
}

/// One entry of a user list, ready to be drawn: what every list card needs,
/// whatever the tracker.
///
/// This is the shared shape of the list widgets (`lib/widgets/user/list/`):
/// the MAL adapter builds it from `users/@me/animelist`, the AniList, Kitsu and
/// Simkl units build it from their own list answers. Scores are on a 0-10
/// scale ([score] 0 = not scored), totals are 0 when unknown, [id] is the
/// tracker's own id and [malId] the MyAnimeList id when known (cards elsewhere
/// and the status cache use it).
@immutable
class ListEntryView {
  final int id;
  final int? malId;

  /// `anime` or `manga`.
  final String category;

  /// Title in the user's preferred language, and every known title (search).
  final String title;
  final List<String> otherTitles;
  final String? imageUrl;
  final String? largeImageUrl;

  /// Raw media type of the tracker (`tv`, `movie`, `manga`, `light_novel`…).
  final String? mediaType;
  final ReleaseState releaseState;

  /// Mean score of all users (0-10), number of members and of scorers, rank by popularity.
  final double? meanScore;
  final int? members;
  final int? scoringUsers;
  final int? popularity;

  /// Total episodes (anime) or chapters (manga); [totalVolumes] for manga.
  final int total;
  final int totalVolumes;
  final List<String> genres;

  /// Release dates of the content as the tracker gives them (`2024-04-06`, `2024`).
  final String? releaseStart;
  final String? releaseEnd;
  final BroadcastSlot? broadcast;

  /// The user's list fields.
  final ListEntryStatus? status;
  final int score;
  final int progress;
  final int progressVolumes;
  final bool repeating;

  /// 0 low, 1 medium, 2 high (MAL priority).
  final int priority;
  final DateTime? updatedAt;
  final String? listStartDate;
  final String? listFinishDate;
  final List<String> tags;

  /// How many times the user rewatched (reread) it.
  final int timesRewatched;

  /// Average length of one episode in seconds (0 = unknown, always 0 for manga).
  final int episodeSeconds;

  /// First season of the anime (`winter`…`fall`) and its year, from MAL `start_season`.
  final String? startSeason;
  final int? startSeasonYear;

  /// MAL age rating (`g`, `pg`, `pg_13`, `r`, `r+`, `rx`) and original material (`manga`…).
  final String? ageRating;
  final String? source;

  /// Studio names (anime) and author names (manga).
  final List<String> studios;
  final List<String> authors;

  const ListEntryView({
    required this.id,
    this.malId,
    required this.category,
    required this.title,
    this.otherTitles = const [],
    this.imageUrl,
    this.largeImageUrl,
    this.mediaType,
    this.releaseState = ReleaseState.unknown,
    this.meanScore,
    this.members,
    this.scoringUsers,
    this.popularity,
    this.total = 0,
    this.totalVolumes = 0,
    this.genres = const [],
    this.releaseStart,
    this.releaseEnd,
    this.broadcast,
    this.status,
    this.score = 0,
    this.progress = 0,
    this.progressVolumes = 0,
    this.repeating = false,
    this.priority = 0,
    this.updatedAt,
    this.listStartDate,
    this.listFinishDate,
    this.tags = const [],
    this.timesRewatched = 0,
    this.episodeSeconds = 0,
    this.startSeason,
    this.startSeasonYear,
    this.ageRating,
    this.source,
    this.studios = const [],
    this.authors = const [],
  });

  bool get isAnime => category == 'anime';

  /// Episodes (or chapters) released so far, or null when unknown:
  /// 1. airing anime: the real schedule ([AiringSchedule.nextEpisode] of
  ///    [malId], next episode − 1), when it is loaded and lists the anime;
  /// 2. airing tv/ona anime with a known total and a full start date: one
  ///    episode per week from the premiere (null when that would exceed the
  ///    total, i.e. the season had a break);
  /// 3. finished anime or manga: [total] when known.
  int? releasedCount(DateTime now) {
    if (releaseState == ReleaseState.finished) return total > 0 ? total : null;
    if (!isAnime || releaseState != ReleaseState.releasing) return null;
    final next = AiringSchedule.instance.nextEpisode(malId, now: now);
    if (next != null) {
      final aired = next.episode - 1;
      return aired < 0 ? 0 : aired;
    }
    final type = mediaType?.toLowerCase();
    if (type != null && type != 'tv' && type != 'ona') return null;
    if (total <= 0) return null;
    final start = DateTime.tryParse(releaseStart ?? '');
    if (start == null || (releaseStart?.length ?? 0) < 10) return null;
    final days = now.difference(start).inDays;
    if (days < 0) return 0;
    final aired = days ~/ 7 + 1;
    return aired > total ? null : aired;
  }

  /// Released episodes (chapters) the user has not watched yet (0 when none or unknown).
  int unseenCount(DateTime now) {
    final released = releasedCount(now);
    if (released == null || status == null) return 0;
    final unseen = released - progress;
    return unseen > 0 ? unseen : 0;
  }

  /// Time still to watch: the episodes after [progress] at the average length, or null
  /// when the entry is not on the "to watch" side of the list (completed, dropped, no
  /// status) or its length or episode total is unknown.
  Duration? get timeLeft {
    if (!isAnime || episodeSeconds <= 0 || total <= 0) return null;
    return switch (status) {
      ListEntryStatus.current ||
      ListEntryStatus.onHold ||
      ListEntryStatus.planned =>
        Duration(seconds: (total - progress).clamp(0, total) * episodeSeconds),
      _ => null,
    };
  }

  /// True for an entry on the "to watch" side whose episode total is still unknown (an airing
  /// show with `num_episodes` = 0): its time left cannot be counted, so a time line that leaves
  /// it out is only a lower bound.
  bool get hasUnknownTimeLeft =>
      isAnime &&
      episodeSeconds > 0 &&
      total <= 0 &&
      (status == ListEntryStatus.current ||
          status == ListEntryStatus.onHold ||
          status == ListEntryStatus.planned);

  /// Time already watched: [progress] episodes at the average length, or null when unknown.
  Duration? get timeWatched {
    if (!isAnime || episodeSeconds <= 0 || status == null) return null;
    return Duration(seconds: progress * episodeSeconds);
  }

  ListEntryView copyWith({
    ListEntryStatus? status,
    bool clearStatus = false,
    int? score,
    int? progress,
    int? progressVolumes,
    bool? repeating,
    int? priority,
    DateTime? updatedAt,
    String? listStartDate,
    String? listFinishDate,
    List<String>? tags,
    int? timesRewatched,
  }) =>
      ListEntryView(
        id: id,
        malId: malId,
        category: category,
        title: title,
        otherTitles: otherTitles,
        imageUrl: imageUrl,
        largeImageUrl: largeImageUrl,
        mediaType: mediaType,
        releaseState: releaseState,
        meanScore: meanScore,
        members: members,
        scoringUsers: scoringUsers,
        popularity: popularity,
        total: total,
        totalVolumes: totalVolumes,
        genres: genres,
        releaseStart: releaseStart,
        releaseEnd: releaseEnd,
        broadcast: broadcast,
        status: clearStatus ? null : (status ?? this.status),
        score: score ?? this.score,
        progress: progress ?? this.progress,
        progressVolumes: progressVolumes ?? this.progressVolumes,
        repeating: repeating ?? this.repeating,
        priority: priority ?? this.priority,
        updatedAt: updatedAt ?? this.updatedAt,
        listStartDate: listStartDate ?? this.listStartDate,
        listFinishDate: listFinishDate ?? this.listFinishDate,
        tags: tags ?? this.tags,
        timesRewatched: timesRewatched ?? this.timesRewatched,
        episodeSeconds: episodeSeconds,
        startSeason: startSeason,
        startSeasonYear: startSeasonYear,
        ageRating: ageRating,
        source: source,
        studios: studios,
        authors: authors,
      );

  @override
  bool operator ==(Object other) =>
      other is ListEntryView &&
      other.id == id &&
      other.category == category &&
      other.status == status &&
      other.score == score &&
      other.progress == progress &&
      other.progressVolumes == progressVolumes &&
      other.repeating == repeating &&
      other.priority == priority &&
      other.updatedAt == updatedAt &&
      other.timesRewatched == timesRewatched &&
      other.title == title &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(id, category, status, score, progress,
      progressVolumes, repeating, priority, updatedAt, timesRewatched, title, imageUrl);
}

/// Which time a list header shows: what is left to watch, or what was watched.
enum ListTimeKind { left, watched }

/// The time line of a list tab ("Plan to watch: 41 days").
@immutable
class ListTimeSummary {
  final ListTimeKind kind;
  final Duration total;

  /// True when more entries are still to load, so [total] can only grow.
  final bool partial;

  const ListTimeSummary(this.kind, this.total, {this.partial = false});

  /// Time of [entries] of the tab [status]: the time left for the tabs of titles still to
  /// watch (watching, on hold, plan to watch), the time watched for the others and for "All".
  /// Null for manga, or when no entry has a known length.
  ///
  /// Superseded by `listTimeSummary` (rewatches counted in the time watched), which My List
  /// uses; kept, rewatches not counted, for the AniList list view and its tests until they
  /// move to `listTimeSummary`.
  static ListTimeSummary? of(
    Iterable<ListEntryView> entries,
    ListEntryStatus? status, {
    bool partial = false,
  }) {
    final kind = switch (status) {
      ListEntryStatus.current ||
      ListEntryStatus.onHold ||
      ListEntryStatus.planned =>
        ListTimeKind.left,
      _ => ListTimeKind.watched,
    };
    var seconds = 0;
    var unknown = false;
    for (final e in entries) {
      final d = kind == ListTimeKind.left ? e.timeLeft : e.timeWatched;
      if (d != null) seconds += d.inSeconds;
      if (kind == ListTimeKind.left && e.hasUnknownTimeLeft) unknown = true;
    }
    if (seconds <= 0) return null;
    return ListTimeSummary(kind, Duration(seconds: seconds), partial: partial || unknown);
  }

  /// The translated line ("Time left: 41 d 3 h").
  String label() {
    final time = formatListDuration(total) + (partial ? '+' : '');
    return kind == ListTimeKind.left
        ? S.current.ListTime_Left(time)
        : S.current.ListTime_Watched(time);
  }
}

/// "41 d 3 h", "5 h 20 min" or "12 min": the two largest units of [d].
String formatListDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days > 0) return S.current.ListTime_Days_Hours(days, hours);
  if (d.inHours > 0) return S.current.ListTime_Hours_Minutes(d.inHours, minutes);
  return S.current.ListTime_Minutes(d.inMinutes < 1 ? 1 : d.inMinutes);
}
