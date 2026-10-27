import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart'
    as anime_status;
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart'
    as manga_status;

/// The user's list entry for one anime or manga, as the edit sheet shows it.
///
/// Anime and manga share one shape: [progress] is the episodes watched or the
/// chapters read, [isRepeating]/[timesRepeated]/[repeatValue] the rewatch or
/// reread fields. Dates keep MAL's own text (`2024-03-17`, or a partial
/// `2024-03` / `2024`) so a pre-filled date is exactly the one on MAL.
class ListEntry {
  final String status;
  final int score;
  final int progress;
  final int volumes;
  final bool isRepeating;
  final int timesRepeated;
  final int repeatValue;
  final int priority;
  final String? startDate;
  final String? finishDate;
  final List<String> tags;
  final String comments;

  const ListEntry({
    required this.status,
    this.score = 0,
    this.progress = 0,
    this.volumes = 0,
    this.isRepeating = false,
    this.timesRepeated = 0,
    this.repeatValue = 0,
    this.priority = 0,
    this.startDate,
    this.finishDate,
    this.tags = const [],
    this.comments = '',
  });

  /// Parses MAL's `my_list_status` object; null when the entry is not on the list.
  static ListEntry? fromMalJson(Map<String, dynamic>? json,
      {required bool isAnime}) {
    if (json == null) return null;
    final status = json['status'];
    if (status is! String || status.isEmpty) return null;
    return ListEntry(
      status: status,
      score: _int(json['score']),
      progress: _int(isAnime
          ? (json['num_episodes_watched'] ?? json['num_watched_episodes'])
          : json['num_chapters_read']),
      volumes: isAnime ? 0 : _int(json['num_volumes_read']),
      isRepeating:
          (isAnime ? json['is_rewatching'] : json['is_rereading']) == true,
      timesRepeated: _int(
          isAnime ? json['num_times_rewatched'] : json['num_times_reread']),
      repeatValue: _int(isAnime ? json['rewatch_value'] : json['reread_value']),
      priority: _int(json['priority']),
      startDate: _date(json['start_date']),
      finishDate: _date(json['finish_date']),
      tags: _tags(json['tags']),
      comments: json['comments'] is String ? json['comments'] as String : '',
    );
  }

  /// The entry MAL answered after an anime update.
  ///
  /// [sent] is the patch that was sent and [previous] the entry before it:
  /// MalApi parses dates into `DateTime`, which drops partial dates, so a
  /// partial date the update did not touch is kept from [previous].
  factory ListEntry.fromAnimeStatus(anime_status.MyAnimeListStatus s,
      {ListEntry? previous, String? sentStart, String? sentFinish}) {
    return ListEntry(
      status: s.status ?? previous?.status ?? '',
      score: s.score ?? previous?.score ?? 0,
      progress: s.numEpisodesWatched ?? previous?.progress ?? 0,
      isRepeating: s.isRewatching ?? previous?.isRepeating ?? false,
      timesRepeated: s.numTimesRewatched ?? previous?.timesRepeated ?? 0,
      repeatValue: s.rewatchValue ?? previous?.repeatValue ?? 0,
      priority: s.priority ?? previous?.priority ?? 0,
      startDate: _mergeDate(s.startDate, sentStart, previous?.startDate),
      finishDate: _mergeDate(s.finishDate, sentFinish, previous?.finishDate),
      tags: s.tags ?? previous?.tags ?? const [],
      comments: s.comments ?? previous?.comments ?? '',
    );
  }

  /// The entry MAL answered after a manga update (see [ListEntry.fromAnimeStatus]).
  factory ListEntry.fromMangaStatus(manga_status.MyMangaListStatus s,
      {ListEntry? previous, String? sentStart, String? sentFinish}) {
    return ListEntry(
      status: s.status ?? previous?.status ?? '',
      score: s.score ?? previous?.score ?? 0,
      progress: s.numChaptersRead ?? previous?.progress ?? 0,
      volumes: s.numVolumesRead ?? previous?.volumes ?? 0,
      isRepeating: s.isRereading ?? previous?.isRepeating ?? false,
      timesRepeated: s.numTimesReread ?? previous?.timesRepeated ?? 0,
      repeatValue: s.rereadValue ?? previous?.repeatValue ?? 0,
      priority: s.priority ?? previous?.priority ?? 0,
      startDate: _mergeDate(s.startDate, sentStart, previous?.startDate),
      finishDate: _mergeDate(s.finishDate, sentFinish, previous?.finishDate),
      tags: s.tags ?? previous?.tags ?? const [],
      comments: s.comments ?? previous?.comments ?? '',
    );
  }

  static String? _mergeDate(
      DateTime? answered, String? sent, String? previous) {
    if (sent != null) return sent;
    if (answered != null) return formatApiDate(answered);
    // A partial date (`2024-03`) cannot be parsed into a DateTime: keep it.
    if (previous != null && DateTime.tryParse(previous) == null)
      return previous;
    return null;
  }

  static int _int(Object? v) => v is int ? v : (v is num ? v.toInt() : 0);

  static String? _date(Object? v) {
    if (v is! String) return null;
    final s = v.trim();
    return s.isEmpty ? null : s;
  }

  static List<String> _tags(Object? v) {
    if (v is List) {
      return List.unmodifiable(
          v.whereType<String>().where((t) => t.trim().isNotEmpty));
    }
    if (v is String && v.trim().isNotEmpty) {
      return List.unmodifiable(
          v.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
    }
    return const [];
  }
}

/// Date text as MAL's list API expects it.
String formatApiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// What the edit sheet needs about the anime or manga besides the entry.
class EditableContent {
  final int id;
  final bool isAnime;

  /// Known episode / chapter / volume totals; 0 when MAL does not know them.
  final int numEpisodes;
  final int numChapters;
  final int numVolumes;

  /// MAL airing status (`currently_airing`, `finished_airing`, `not_yet_aired`;
  /// `currently_publishing`… for manga).
  final String? airingStatus;

  /// Release start (`2024-04-06`, possibly partial) and start season.
  final String? releaseStart;
  final String? startSeason;
  final int? startSeasonYear;

  /// Null when the content is not on the user's list.
  final ListEntry? entry;

  const EditableContent({
    required this.id,
    required this.isAnime,
    this.numEpisodes = 0,
    this.numChapters = 0,
    this.numVolumes = 0,
    this.airingStatus,
    this.releaseStart,
    this.startSeason,
    this.startSeasonYear,
    this.entry,
  });

  /// Episodes (anime) or chapters (manga) total, 0 when unknown.
  int get progressTotal => isAnime ? numEpisodes : numChapters;

  factory EditableContent.fromMalJson(Map<String, dynamic> json,
      {required bool isAnime}) {
    final season = json['start_season'];
    final mls = json['my_list_status'];
    return EditableContent(
      id: ListEntry._int(json['id']),
      isAnime: isAnime,
      numEpisodes: ListEntry._int(json['num_episodes']),
      numChapters: ListEntry._int(json['num_chapters']),
      numVolumes: ListEntry._int(json['num_volumes']),
      airingStatus: json['status'] is String ? json['status'] as String : null,
      releaseStart: ListEntry._date(json['start_date']),
      startSeason: season is Map && season['season'] is String
          ? season['season'] as String
          : null,
      startSeasonYear:
          season is Map && season['year'] is int ? season['year'] as int : null,
      entry: ListEntry.fromMalJson(mls is Map<String, dynamic> ? mls : null,
          isAnime: isAnime),
    );
  }
}
