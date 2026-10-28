import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
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

/// The list entries of one AniList answer, as the shared list widgets draw them.
/// [titleLang] is a `TitleLang` name.
@visibleForTesting
List<ListEntryView> parseAnilistEntries(List<dynamic> entries,
    {required String category, required String titleLang}) {
  final isAnime = category == 'anime';
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  int toInt(Object? v) => v is num ? v.toInt() : 0;
  final out = <ListEntryView>[];
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
    final score = item['score'];
    final updated = item['updatedAt'];
    out.add(ListEntryView(
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
      status: anilistStatus(text(item['status'])),
      score: score is num ? score.round().clamp(0, 10).toInt() : 0,
      progress: toInt(item['progress']),
      progressVolumes: isAnime ? 0 : toInt(item['progressVolumes']),
      repeating: item['status'] == 'REPEATING',
      // AniList priority is 0-5 on the entry; the shared view keeps low / medium / high.
      priority: toInt(item['priority']) >= 4
          ? 2
          : toInt(item['priority']) >= 2
              ? 1
              : 0,
      updatedAt: updated is num && updated > 0
          ? DateTime.fromMillisecondsSinceEpoch(updated.toInt() * 1000)
          : null,
      listStartDate: SyncDates.fromFuzzy(item['startedAt']),
      listFinishDate: SyncDates.fromFuzzy(item['completedAt']),
    ));
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

  final Map<String, ({DateTime at, String owner, List<ListEntryView> entries})> _kept = {};
  final Map<String, Future<List<ListEntryView>>> _inFlight = {};

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  String? get owner => _owner();

  static const int _perChunk = 500;

  static const String _entryFields = '''
    id status progress progressVolumes repeat priority updatedAt
    score(format: POINT_10_DECIMAL)
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

  Future<List<ListEntryView>> _load(String category, String who) async {
    final name = who.isNotEmpty ? who : await _viewerName();
    final byMedia = <int, ListEntryView>{};
    var chunk = 1;
    while (true) {
      final data = await _gql.query('''
        query (\$name: String, \$type: MediaType, \$chunk: Int, \$perChunk: Int) {
          MediaListCollection(userName: \$name, type: \$type, chunk: \$chunk,
              perChunk: \$perChunk, forceSingleCompletedList: true) {
            hasNextChunk
            lists { entries { $_entryFields } }
          }
        }
      ''', variables: {
        'name': name,
        'type': category == 'manga' ? 'MANGA' : 'ANIME',
        'chunk': chunk,
        'perChunk': _perChunk,
      }, auth: true);
      final collection = data['MediaListCollection'];
      if (collection is! Map) break;
      for (final list in (collection['lists'] as List? ?? const [])) {
        if (list is! Map || list['entries'] is! List) continue;
        // A custom list repeats entries of the main ones: keyed by media, the last wins.
        for (final e in parseAnilistEntries(list['entries'] as List,
            category: category, titleLang: _titleLang())) {
          byMedia[e.id] = e;
        }
      }
      if (collection['hasNextChunk'] != true || chunk >= 40) break;
      chunk++;
    }
    final entries = List<ListEntryView>.unmodifiable(byMedia.values);
    _kept[category] = (at: _clock(), owner: who, entries: entries);
    return entries;
  }

  Future<String> _viewerName() async {
    final data = await _gql.query('query { Viewer { name } }', auth: true);
    final name = (data['Viewer'] as Map?)?['name'];
    if (name is! String || name.isEmpty) throw const AnilistSessionExpired();
    return name;
  }

  /// Keeps [entry] (saved just now) in the kept list of its category, so the other tabs
  /// see it without another request. [entry] null status = removed.
  void put(ListEntryView entry, {bool removed = false}) {
    final kept = _kept[entry.category];
    if (kept == null) return;
    final next = [
      for (final e in kept.entries)
        if (e.id != entry.id) e else if (!removed) entry,
    ];
    if (!removed && !next.any((e) => e.id == entry.id)) next.insert(0, entry);
    _kept[entry.category] =
        (at: kept.at, owner: kept.owner, entries: List.unmodifiable(next));
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
