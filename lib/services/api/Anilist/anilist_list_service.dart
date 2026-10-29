import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/services/notifications/notification_models.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart' show SyncDates;

/// MyAnimeList list status words of an AniList `MediaListStatus`.
ListEntryStatus? anilistStatus(String? value) => switch (value) {
      'CURRENT' || 'REPEATING' => ListEntryStatus.current,
      'COMPLETED' => ListEntryStatus.completed,
      'PAUSED' => ListEntryStatus.onHold,
      'DROPPED' => ListEntryStatus.dropped,
      'PLANNING' => ListEntryStatus.planned,
      _ => null,
    };

/// AniList `MediaListStatus` of [status].
String anilistStatusValue(ListEntryStatus status) => switch (status) {
      ListEntryStatus.current => 'CURRENT',
      ListEntryStatus.completed => 'COMPLETED',
      ListEntryStatus.onHold => 'PAUSED',
      ListEntryStatus.dropped => 'DROPPED',
      ListEntryStatus.planned => 'PLANNING',
    };

ReleaseState _release(String? status) => switch (status) {
      'RELEASING' => ReleaseState.releasing,
      'FINISHED' => ReleaseState.finished,
      'NOT_YET_RELEASED' => ReleaseState.notYetReleased,
      'HIATUS' => ReleaseState.onHiatus,
      _ => ReleaseState.unknown,
    };

/// The raw `format` as the list filters know it (MAL's media type words).
String? anilistMediaType(String? format) => switch (format) {
      'TV' || 'TV_SHORT' => 'tv',
      'MOVIE' => 'movie',
      'SPECIAL' => 'special',
      'OVA' => 'ova',
      'ONA' => 'ona',
      'MUSIC' => 'music',
      'MANGA' => 'manga',
      'NOVEL' => 'light_novel',
      'ONE_SHOT' => 'one_shot',
      _ => format?.toLowerCase(),
    };

/// AniList's own list fields of one entry, beyond what the shared [ListEntryView] carries:
/// the exact score, Rewatching, notes, priority 0-5, private, hidden, custom lists, advanced
/// scores and the list dates. Kept by [AnilistListService] next to each row; the AniList
/// editor reads and writes these.
@immutable
class AnilistListEntry {
  /// The list entry id (DeleteMediaListEntry, UpdateMediaListEntries) and the media id.
  final int entryId;
  final int mediaId;

  /// `anime` or `manga`.
  final String category;

  /// Raw `MediaListStatus` (CURRENT, REPEATING, COMPLETED, PAUSED, DROPPED, PLANNING).
  final String? status;

  /// Score on AniList's raw 0-100 scale (0 = not scored), whatever the user's format.
  final int scoreRaw;
  final int progress;
  final int progressVolumes;
  final int repeat;

  /// AniList's priority, 0 (none) to 5.
  final int priority;
  final bool private;
  final bool hiddenFromStatusLists;
  final String notes;

  /// Names of the custom lists the entry is on.
  final List<String> customLists;

  /// Advanced score per category name (the user's own categories).
  final Map<String, double> advancedScores;
  final String? startedAt;
  final String? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Raw media `format` (TV, MOVIE, MANGA…), for the completed sections split by format.
  final String? format;

  const AnilistListEntry({
    required this.entryId,
    required this.mediaId,
    required this.category,
    this.status,
    this.scoreRaw = 0,
    this.progress = 0,
    this.progressVolumes = 0,
    this.repeat = 0,
    this.priority = 0,
    this.private = false,
    this.hiddenFromStatusLists = false,
    this.notes = '',
    this.customLists = const [],
    this.advancedScores = const {},
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.format,
  });

  bool get isAnime => category == 'anime';
  bool get isRepeating => status == 'REPEATING';

  /// Reads one `MediaList` of AniList (the list read or a write's answer). The raw score is
  /// `scoreRaw` (`score(format: POINT_100)`), else the 0-10 `score` times ten.
  static AnilistListEntry fromJson(Map<dynamic, dynamic> json,
      {required String category, int? mediaId, String? format}) {
    int toInt(Object? v) => v is num ? v.toInt() : 0;
    DateTime? time(Object? v) =>
        v is num && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000) : null;
    final raw = json['scoreRaw'];
    final score = json['score'];
    final media = json['media'];
    return AnilistListEntry(
      entryId: toInt(json['id']),
      mediaId: mediaId ??
          (json['mediaId'] is num
              ? toInt(json['mediaId'])
              : media is Map
                  ? toInt(media['id'])
                  : 0),
      category: category,
      status: json['status'] is String ? json['status'] as String : null,
      scoreRaw: raw is num
          ? raw.round().clamp(0, 100)
          : score is num
              ? (score * 10).round().clamp(0, 100)
              : 0,
      progress: toInt(json['progress']),
      progressVolumes: toInt(json['progressVolumes']),
      repeat: toInt(json['repeat']),
      priority: toInt(json['priority']).clamp(0, 5),
      private: json['private'] == true,
      hiddenFromStatusLists: json['hiddenFromStatusLists'] == true,
      notes: json['notes'] is String ? json['notes'] as String : '',
      customLists: customListsOf(json['customLists']),
      advancedScores: advancedScoresOf(json['advancedScores']),
      startedAt: SyncDates.fromFuzzy(json['startedAt']),
      completedAt: SyncDates.fromFuzzy(json['completedAt']),
      createdAt: time(json['createdAt']),
      updatedAt: time(json['updatedAt']),
      format: format ?? (media is Map && media['format'] is String ? media['format'] as String : null),
    );
  }

  /// The custom lists an entry is on: `customLists(asArray: true)` answers
  /// `[{name, enabled}]`, without `asArray` it is `{name: enabled}`.
  static List<String> customListsOf(Object? value) => [
        if (value is List)
          for (final e in value)
            if (e is Map && e['enabled'] == true && e['name'] is String) e['name'] as String,
        if (value is Map)
          for (final e in value.entries)
            if (e.value == true && e.key is String) e.key as String,
      ];

  static Map<String, double> advancedScoresOf(Object? value) => {
        if (value is Map)
          for (final e in value.entries)
            if (e.key is String && e.value is num) e.key as String: (e.value as num).toDouble(),
      };

  /// The entry after a write: the fields AniList answered, the media format kept.
  AnilistListEntry merge(Map<String, dynamic> saved) =>
      AnilistListEntry.fromJson(saved, category: category, mediaId: mediaId, format: format);
}

/// The list settings of the account for one category (`MediaListOptions`).
@immutable
class AnilistListOptions {
  final AnilistScoreFormat scoreFormat;

  /// Default row order of the account (`score`, `title`, `updatedAt`, `id`).
  final String? rowOrder;

  /// Section names in the user's order (status sections and custom lists).
  final List<String> sectionOrder;
  final bool splitCompletedSectionByFormat;
  final List<String> customLists;
  final List<String> advancedScoring;
  final bool advancedScoringEnabled;

  const AnilistListOptions({
    this.scoreFormat = AnilistScoreFormat.point10,
    this.rowOrder,
    this.sectionOrder = const [],
    this.splitCompletedSectionByFormat = false,
    this.customLists = const [],
    this.advancedScoring = const [],
    this.advancedScoringEnabled = false,
  });

  /// Advanced scores are shown: enabled, with categories, in a format that has them.
  bool get showsAdvanced =>
      advancedScoringEnabled && advancedScoring.isNotEmpty && scoreFormat.allowsAdvanced;

  /// Reads `mediaListOptions` for [isAnime] (`animeList` / `mangaList`).
  static AnilistListOptions fromJson(Object? json, {required bool isAnime}) {
    if (json is! Map) return const AnilistListOptions();
    final type = json[isAnime ? 'animeList' : 'mangaList'];
    List<String> names(Object? v) => [
          if (v is List)
            for (final s in v)
              if (s is String && s.trim().isNotEmpty) s,
        ];
    return AnilistListOptions(
      scoreFormat: AnilistScoreFormat.parse(json['scoreFormat']),
      rowOrder: json['rowOrder'] is String ? json['rowOrder'] as String : null,
      sectionOrder: type is Map ? names(type['sectionOrder']) : const [],
      splitCompletedSectionByFormat:
          type is Map && type['splitCompletedSectionByFormat'] == true,
      customLists: type is Map ? names(type['customLists']) : const [],
      advancedScoring: type is Map ? names(type['advancedScoring']) : const [],
      advancedScoringEnabled: type is Map && type['advancedScoringEnabled'] == true,
    );
  }
}

/// [detail]'s list fields on the shared row [view]: status (Rewatching = Watching with the
/// repeat badge), score on 0-10, progress, priority folded to three levels, dates.
ListEntryView anilistApplyDetail(ListEntryView view, AnilistListEntry detail) => ListEntryView(
      id: view.id,
      malId: view.malId,
      category: view.category,
      title: view.title,
      otherTitles: view.otherTitles,
      imageUrl: view.imageUrl,
      largeImageUrl: view.largeImageUrl,
      mediaType: view.mediaType,
      releaseState: view.releaseState,
      meanScore: view.meanScore,
      members: view.members,
      scoringUsers: view.scoringUsers,
      popularity: view.popularity,
      total: view.total,
      totalVolumes: view.totalVolumes,
      genres: view.genres,
      releaseStart: view.releaseStart,
      releaseEnd: view.releaseEnd,
      broadcast: view.broadcast,
      tags: view.tags,
      // Built anew rather than copied: a date or a status cleared on AniList is cleared here.
      status: anilistStatus(detail.status),
      score: (detail.scoreRaw / 10).round().clamp(0, 10),
      progress: detail.progress,
      progressVolumes: view.isAnime ? 0 : detail.progressVolumes,
      repeating: detail.isRepeating,
      priority: anilistPriorityLevel(detail.priority),
      listStartDate: detail.startedAt,
      listFinishDate: detail.completedAt,
      updatedAt: detail.updatedAt ?? view.updatedAt,
    );

/// AniList's priority 0-5 as the shared low / medium / high.
int anilistPriorityLevel(int priority) => priority >= 4
    ? 2
    : priority >= 2
        ? 1
        : 0;

/// One row of an AniList list: the shared view and AniList's own fields.
typedef AnilistRow = ({ListEntryView view, AnilistListEntry detail});

/// The list entries of one AniList answer, as the shared list widgets draw them.
/// [titleLang] is a `TitleLang` name.
@visibleForTesting
List<ListEntryView> parseAnilistEntries(List<dynamic> entries,
        {required String category, required String titleLang}) =>
    [for (final r in parseAnilistRows(entries, category: category, titleLang: titleLang)) r.view];

/// The rows of one AniList answer: shared view and AniList fields.
List<AnilistRow> parseAnilistRows(List<dynamic> entries,
    {required String category, required String titleLang}) {
  final isAnime = category == 'anime';
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  int toInt(Object? v) => v is num ? v.toInt() : 0;
  final out = <AnilistRow>[];
  for (final item in entries) {
    if (item is! Map) continue;
    final mediaRaw = item['media'];
    if (mediaRaw is! Map<String, dynamic> || mediaRaw['id'] is! num) continue;
    final media = AnilistMedia.fromJson(mediaRaw, titleLang: titleLang);
    final titles = mediaRaw['title'];
    final synonyms = mediaRaw['synonyms'];
    final cover = mediaRaw['coverImage'];
    final nextAt = media.nextAiringAt;
    // AniList gives the next airing moment: the weekly slot in Japan time follows from it.
    BroadcastSlot? slot;
    if (isAnime && nextAt != null) {
      final jst = nextAt.add(const Duration(hours: 9));
      slot = BroadcastSlot(jst.weekday, jst.hour * 60 + jst.minute);
    }
    final all = <String>[
      if (titles is Map)
        for (final k in ['romaji', 'english', 'native'])
          if (text(titles[k]) != null) text(titles[k])!,
      if (synonyms is List)
        for (final s in synonyms)
          if (text(s) != null) text(s)!,
    ];
    final detail = AnilistListEntry.fromJson(item,
        category: category, mediaId: media.id, format: media.format);
    final base = ListEntryView(
      id: media.id,
      malId: media.malId,
      category: category,
      title: media.title,
      otherTitles: [
        for (final t in all.toSet())
          if (t != media.title) t,
      ],
      imageUrl: media.coverUrl,
      largeImageUrl: cover is Map ? text(cover['extraLarge']) ?? media.coverUrl : media.coverUrl,
      mediaType: anilistMediaType(media.format),
      releaseState: _release(media.status),
      meanScore: media.score,
      members: media.popularity,
      total: isAnime ? (media.episodes ?? 0) : (media.chapters ?? 0),
      totalVolumes: isAnime ? 0 : toInt(mediaRaw['volumes']),
      genres: media.genres,
      releaseStart: SyncDates.fromFuzzy(mediaRaw['startDate']),
      releaseEnd: SyncDates.fromFuzzy(mediaRaw['endDate']),
      broadcast: slot,
    );
    out.add((view: anilistApplyDetail(base, detail), detail: detail));
  }
  return out;
}

/// The signed-in user's AniList lists. One request (in chunks) brings a whole category;
/// the status tabs, counts and pages are cut from it in memory and it is kept for a minute,
/// so switching tabs does not hit AniList again.
class AnilistListService {
  AnilistListService({
    AnilistGraphql? client,
    String? Function()? owner,
    DateTime Function()? clock,
    String Function()? titleLang,
    this.keepFor = const Duration(minutes: 1),
  })  : _client = client,
        _owner = owner ?? (() => UserAnilistV2.instance.username),
        _clock = clock ?? DateTime.now,
        _titleLang = titleLang ?? (() => Preferences.general.preferredTitle.name);

  static AnilistListService instance = AnilistListService();

  final AnilistGraphql? _client;
  final String? Function() _owner;
  final DateTime Function() _clock;
  final String Function() _titleLang;
  final Duration keepFor;

  final Map<String, _KeptList> _kept = {};
  final Map<String, Future<List<ListEntryView>>> _inFlight = {};

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  String? get owner => _owner();

  static const int _perChunk = 500;

  static const String _optionFields =
      'advancedScoring advancedScoringEnabled customLists sectionOrder '
      'splitCompletedSectionByFormat';

  /// The account's list settings, asked with the first chunk only.
  static const String _userFields = 'user { mediaListOptions { scoreFormat rowOrder '
      'animeList { $_optionFields } mangaList { $_optionFields } } }';

  static const String _entryFields = '''
    id status progress progressVolumes repeat priority private notes hiddenFromStatusLists
    updatedAt createdAt
    scoreRaw: score(format: POINT_100)
    score(format: POINT_10_DECIMAL)
    customLists(asArray: true) advancedScores
    startedAt { year month day }
    completedAt { year month day }
    media { ${AnilistMedia.fields} volumes synonyms
      startDate { year month day } endDate { year month day } }
  ''';

  /// Every entry of [category] (`anime` | `manga`), any status.
  Future<List<ListEntryView>> all(String category, {bool force = false}) {
    final who = owner ?? '';
    final kept = _kept[category];
    if (!force &&
        kept != null &&
        kept.owner == who &&
        _clock().difference(kept.at) < keepFor) {
      return Future.value(kept.entries);
    }
    return _inFlight[category] ??= _load(category, who).whenComplete(() {
      // A block body: returning the removed future would make it wait for itself.
      _inFlight.remove(category);
    });
  }

  /// AniList's own fields of the row [mediaId] of [category], once the list is loaded.
  AnilistListEntry? detailOf(String category, int mediaId) =>
      _kept[category]?.details[mediaId];

  /// The account's list settings for [category] (score format, sections, custom lists,
  /// advanced scoring), once the list is loaded.
  AnilistListOptions? optionsOf(String category) => _kept[category]?.options;

  Future<List<ListEntryView>> _load(String category, String who) async {
    final name = who.isNotEmpty ? who : await _viewerName();
    final isAnime = category != 'manga';
    final byMedia = <int, AnilistRow>{};
    var options = const AnilistListOptions();
    var chunk = 1;
    while (true) {
      final data = await _gql.query('''
        query (\$name: String, \$type: MediaType, \$chunk: Int, \$perChunk: Int) {
          MediaListCollection(userName: \$name, type: \$type, chunk: \$chunk,
              perChunk: \$perChunk, forceSingleCompletedList: true) {
            hasNextChunk
            ${chunk == 1 ? _userFields : ''}
            lists { entries { $_entryFields } }
          }
        }
      ''', variables: {
        'name': name,
        'type': isAnime ? 'ANIME' : 'MANGA',
        'chunk': chunk,
        'perChunk': _perChunk,
      }, auth: true);
      final collection = data['MediaListCollection'];
      if (collection is! Map) break;
      final user = collection['user'];
      if (user is Map && user['mediaListOptions'] != null) {
        options = AnilistListOptions.fromJson(user['mediaListOptions'], isAnime: isAnime);
      }
      for (final list in (collection['lists'] as List? ?? const [])) {
        if (list is! Map || list['entries'] is! List) continue;
        // A custom list repeats entries of the main ones: keyed by media, the last wins.
        for (final row in parseAnilistRows(list['entries'] as List,
            category: category, titleLang: _titleLang())) {
          byMedia[row.view.id] = row;
        }
      }
      if (collection['hasNextChunk'] != true || chunk >= 40) break;
      chunk++;
    }
    final kept = _KeptList(
      at: _clock(),
      owner: who,
      entries: List.unmodifiable([for (final r in byMedia.values) r.view]),
      details: {for (final r in byMedia.values) r.view.id: r.detail},
      options: options,
    );
    _kept[category] = kept;
    return kept.entries;
  }

  Future<String> _viewerName() async {
    final data = await _gql.query('query { Viewer { name } }', auth: true);
    final name = (data['Viewer'] as Map?)?['name'];
    if (name is! String || name.isEmpty) throw const AnilistSessionExpired();
    return name;
  }

  /// Keeps [entry] (saved just now) in the kept list of its category, so the other tabs
  /// see it without another request; [detail] replaces its AniList fields when given.
  void put(ListEntryView entry, {bool removed = false, AnilistListEntry? detail}) {
    final kept = _kept[entry.category];
    if (kept == null) return;
    final next = [
      for (final e in kept.entries)
        if (e.id != entry.id) e else if (!removed) entry,
    ];
    if (!removed && !next.any((e) => e.id == entry.id)) next.insert(0, entry);
    final details = {...kept.details};
    if (removed) {
      details.remove(entry.id);
    } else if (detail != null) {
      details[entry.id] = detail;
    }
    _kept[entry.category] = _KeptList(
      at: kept.at,
      owner: kept.owner,
      entries: List.unmodifiable(next),
      details: details,
      options: kept.options,
    );
  }

  /// Forgets the kept lists (after an edit or a sign out).
  void invalidate([String? category]) {
    if (category == null) {
      _kept.clear();
    } else {
      _kept.remove(category);
    }
  }

  /// Entries per status of [entries].
  static Map<ListEntryStatus, int> countStatuses(List<ListEntryView> entries) {
    final counts = {for (final s in ListEntryStatus.values) s: 0};
    for (final e in entries) {
      final s = e.status;
      if (s != null) counts[s] = counts[s]! + 1;
    }
    return counts;
  }

  /// The airing anime of the user's Watching and Plan to watch lists, keyed by their MAL
  /// id, for the airing notifications. Titles AniList does not link to MAL are skipped
  /// (the schedule and the notifications work on MAL ids).
  Future<List<AiringCandidate>> airingCandidates() async {
    final entries = await all('anime', force: true);
    return airingCandidatesOf(entries);
  }

  @visibleForTesting
  static List<AiringCandidate> airingCandidatesOf(List<ListEntryView> entries) {
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    return [
      for (final e in entries)
        if (e.malId != null &&
            (e.status == ListEntryStatus.current || e.status == ListEntryStatus.planned) &&
            e.releaseState != ReleaseState.finished)
          AiringCandidate(
            malId: e.malId!,
            title: e.title,
            status: e.status == ListEntryStatus.current ? 'watching' : 'plan_to_watch',
            imageUrl: e.imageUrl,
            numEpisodes: e.total > 0 ? e.total : null,
            airingStatus: switch (e.releaseState) {
              ReleaseState.releasing => 'currently_airing',
              ReleaseState.notYetReleased => 'not_yet_aired',
              _ => null,
            },
            broadcastDay: e.broadcast == null ? null : days[e.broadcast!.weekday - 1],
            broadcastTime: e.broadcast == null
                ? null
                : '${two(e.broadcast!.minutes ~/ 60)}:${two(e.broadcast!.minutes % 60)}',
          ),
    ];
  }
}

/// One category's list as loaded: rows, AniList fields per media id, list settings.
class _KeptList {
  final DateTime at;
  final String owner;
  final List<ListEntryView> entries;
  final Map<int, AnilistListEntry> details;
  final AnilistListOptions options;

  const _KeptList({
    required this.at,
    required this.owner,
    required this.entries,
    required this.details,
    required this.options,
  });
}
