import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart' show SimklEpisode;
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/notifications/notification_models.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// A paused viewing session reported by a scrobbler (`GET /sync/playback/anime`): the title, the
/// episode and how far the viewer got.
class SimklPlayback {
  final int simklId;
  final int? malId;
  final String title;
  final String? posterUrl;
  final int? episode;

  /// 0-100.
  final double progress;
  final DateTime? pausedAt;

  const SimklPlayback({
    required this.simklId,
    this.malId,
    required this.title,
    this.posterUrl,
    this.episode,
    required this.progress,
    this.pausedAt,
  });

  /// The sessions of a playback answer, latest first; items without a Simkl id or a title are skipped.
  static List<SimklPlayback> parseAll(Object? data) {
    if (data is! List) return const [];
    final out = <SimklPlayback>[];
    for (final raw in data) {
      if (raw is! Map) continue;
      final show = raw['show'] is Map
          ? raw['show'] as Map
          : (raw['anime'] is Map ? raw['anime'] as Map : (raw['movie'] is Map ? raw['movie'] as Map : null));
      if (show == null) continue;
      final ids = show['ids'] is Map ? show['ids'] as Map : const {};
      final id = _int(ids['simkl'] ?? ids['simkl_id']);
      final title = show['title'];
      if (id == null || title is! String || title.isEmpty) continue;
      final episode = raw['episode'];
      final poster = show['poster'];
      out.add(SimklPlayback(
        simklId: id,
        malId: _int(ids['mal']),
        title: title,
        posterUrl: poster is String && poster.isNotEmpty ? SimklImages.poster(poster) : null,
        episode: episode is Map ? _int(episode['episode'] ?? episode['number']) : _int(episode),
        progress: ((raw['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100).toDouble(),
        pausedAt: DateTime.tryParse(raw['paused_at'] as String? ?? '')?.toUtc(),
      ));
    }
    out.sort((a, b) {
      final x = a.pausedAt;
      final y = b.pausedAt;
      if (x == null) return y == null ? 0 : 1;
      return y == null ? -1 : y.compareTo(x);
    });
    return out;
  }

  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
}

/// What Simkl says the viewer should watch next (`next_to_watch_info` of a `watching` item,
/// asked with `next_watch_info=yes`): the episode, its title and when it aired or airs.
class SimklNextToWatch {
  /// Shows only: the season of [episode] (anime count episodes from 1 without seasons).
  final int? season;
  final int episode;
  final String? title;
  final DateTime? date;

  const SimklNextToWatch({this.season, required this.episode, this.title, this.date});

  /// Simkl id to next episode, for the items of a list answer that carry the field.
  static Map<int, SimklNextToWatch> parseAll(Object? data, [SimklKind kind = SimklKind.anime]) {
    final list = data is Map ? data[kind.syncKey] : null;
    if (list is! List) return const {};
    final out = <int, SimklNextToWatch>{};
    for (final raw in list) {
      if (raw is! Map) continue;
      final show = raw['show'];
      final ids = show is Map && show['ids'] is Map ? show['ids'] as Map : const {};
      final id = SimklPlayback._int(ids['simkl'] ?? ids['simkl_id']);
      final info = raw['next_to_watch_info'];
      if (id == null || info is! Map) continue;
      final episode = SimklPlayback._int(info['episode']);
      if (episode == null) continue;
      final title = info['title'];
      out[id] = SimklNextToWatch(
        season: kind == SimklKind.tv ? SimklPlayback._int(info['season']) : null,
        episode: episode,
        title: title is String && title.trim().isNotEmpty ? title.trim() : null,
        date: DateTime.tryParse(info['date'] is String ? info['date'] as String : '')?.toUtc(),
      );
    }
    return out;
  }
}

/// A second check-in came before Simkl's 20 second per-user lock expired (Simkl answers that
/// with a 400 `RATE_LIMIT`); nothing was sent.
class SimklCheckInTooSoon implements Exception {
  final Duration wait;
  const SimklCheckInTooSoon(this.wait);

  @override
  String toString() => 'SimklCheckInTooSoon(${wait.inSeconds}s)';
}

/// The community score of a title (`GET /ratings/anime`).
class SimklCommunityRating {
  final double rating;
  final int votes;

  const SimklCommunityRating(this.rating, this.votes);

  /// `id` (Simkl id) to rating, from `[{"id":1,"simkl":{"rating":8.4,"votes":120}}]`.
  static Map<int, SimklCommunityRating> parseAll(Object? data, [SimklKind kind = SimklKind.anime]) {
    final list = data is Map ? (data[kind.api] ?? data[kind.syncKey] ?? data['items'] ?? data['ratings']) : data;
    if (list is! List) return const {};
    final out = <int, SimklCommunityRating>{};
    for (final raw in list) {
      if (raw is! Map) continue;
      final rating = raw['simkl'];
      final id = raw['id'] ?? (raw['ids'] is Map ? (raw['ids'] as Map)['simkl'] : null);
      if (rating is! Map || id is! num) continue;
      final value = rating['rating'];
      if (value is! num || value <= 0) continue;
      final votes = rating['votes'];
      out[id.toInt()] = SimklCommunityRating(value.toDouble(), votes is num ? votes.toInt() : 0);
    }
    return out;
  }
}

/// The signed-in user's Simkl anime list: kept for [ttl] and shared by the list tab, the home
/// sections, the profile and the notifications. Simkl has no manga, no paging and no per-status
/// server sort.
///
/// The list is not downloaded again each time: `GET /sync/activities` (the cheapest call) says
/// whether anything changed. Nothing changed: the kept list stays. Only entries changed or added:
/// `GET /sync/all-items/anime?date_from=` brings those and they are merged in. A removal (or a
/// first load, or another account) downloads the whole list. The community score of each title
/// comes from one `GET /ratings/anime` call, kept longer than the list.
class SimklListService {
  SimklListService({
    this.kind = SimklKind.anime,
    SimklClient? client,
    DateTime Function()? clock,
    String? Function()? owner,
    this.ttl = const Duration(minutes: 3),
    this.ratingsTtl = const Duration(hours: 12),
    Future<List<SimklEpisode>> Function(int simklId)? episodes,
  })  : _episodes = episodes,
        _client = client ?? SimklClient.instance,
        _clock = clock ?? DateTime.now,
        _owner = owner ?? (() => UserSimklV2.instance.username);

  /// Shared instance of the anime list; tests build their own with a fake [SimklClient].
  static SimklListService instance = SimklListService();

  static final Map<SimklKind, SimklListService> _others = {};

  /// The shared list of [kind] ([instance] for anime).
  static SimklListService of(SimklKind kind) =>
      kind == SimklKind.anime ? instance : _others.putIfAbsent(kind, () => SimklListService(kind: kind));

  /// Replaces the shared list of [kind] (tests).
  static void setFor(SimklKind kind, SimklListService service) {
    if (kind == SimklKind.anime) {
      instance = service;
    } else {
      _others[kind] = service;
    }
  }

  /// Calls [action] on the shared list of every kind (sign out, pull to refresh).
  static void forEach(void Function(SimklListService service) action) {
    for (final k in SimklKind.values) {
      action(of(k));
    }
  }

  /// The catalogue this list holds (shows, anime or movies).
  final SimklKind kind;

  final SimklClient _client;
  final Future<List<SimklEpisode>> Function(int simklId)? _episodes;
  final DateTime Function() _clock;
  final String? Function() _owner;
  final Duration ttl;
  final Duration ratingsTtl;

  List<ListEntryView>? _items;
  DateTime? _at;
  String? _cachedFor;
  Future<List<ListEntryView>>? _inflight;

  /// `anime.all` and `anime.removed_from_list` of the activities the kept list matches.
  String? _stamp;
  String? _removedStamp;

  Map<int, SimklCommunityRating> _ratings = const {};

  /// `next_to_watch_info` of the kept list by Simkl id (only `watching` items have one).
  Map<int, SimklNextToWatch> _next = const {};

  /// Titles the last ratings call was made for (a title nobody rated is not asked again).
  Set<int> _ratingAsked = const {};
  DateTime? _ratingsAt;
  DateTime? _ratingsTried;

  /// Requests the service has made, by kind (tests and diagnostics).
  int fullPulls = 0;
  int deltaPulls = 0;

  /// Marks the kept list as out of date (after a write elsewhere or a pull to refresh): the next
  /// read asks Simkl what changed instead of downloading everything.
  void invalidate() {
    _at = null;
  }

  /// After a write of ours: Simkl's timestamps have a one second grain, so the next read pulls
  /// the entries changed since the kept stamp even if the stamp looks the same.
  bool _dirty = false;

  void _wrote({bool removal = false}) {
    _dirty = true;
    if (removal) _stamp = null; // a removal cannot be merged: download the list again
    invalidate();
  }

  /// Forgets everything kept (sign out, another account).
  void reset() {
    _items = null;
    _at = null;
    _stamp = null;
    _removedStamp = null;
    _dirty = false;
    _ratings = const {};
    _next = const {};
    _ratingAsked = const {};
    _ratingsAt = null;
    _ratingsTried = null;
  }

  /// The whole list. [force] checks Simkl even inside the [ttl].
  Future<List<ListEntryView>> entries({bool force = false}) => anime(force: force);

  /// The whole list of [kind] (named after the first catalogue it held). [force] checks Simkl
  /// even inside the [ttl].
  Future<List<ListEntryView>> anime({bool force = false}) {
    final who = _owner();
    final items = _items;
    final at = _at;
    if (!force && items != null && at != null && who == _cachedFor && _clock().difference(at) < ttl) {
      return Future.value(items);
    }
    return _inflight ??= _refresh(who).whenComplete(() => _inflight = null);
  }

  Future<List<ListEntryView>> _refresh(String? who) async {
    if (who != _cachedFor) reset();
    // Read first: a change made while the list downloads is then seen by the next check.
    final activities = await _activities();
    final stamp = _kindStamp(activities, 'all');
    final removed = _kindStamp(activities, 'removed_from_list');
    final kept = _items;
    List<ListEntryView> list;
    if (kept != null && _stamp != null && stamp != null && stamp == _stamp && !_dirty) {
      list = kept; // nothing changed
    } else if (kept != null && _stamp != null && stamp != null && removed == _removedStamp) {
      deltaPulls++;
      final data = await _client.getAuth('/sync/all-items/${kind.syncKey}', query: {'date_from': _stamp!, ..._nextQuery});
      final changed = parseSimklList(data, kind);
      // A changed item is read again: the one it had no longer holds.
      _next = {
        for (final e in _next.entries)
          if (!changed.any((c) => c.id == e.key)) e.key: e.value,
        ...SimklNextToWatch.parseAll(data, kind),
      };
      list = _merge(kept, changed);
    } else {
      fullPulls++;
      final data = await _client.getAuth('/sync/all-items/${kind.syncKey}', query: _nextQuery);
      _next = SimklNextToWatch.parseAll(data, kind);
      list = parseSimklList(data, kind);
    }
    _stamp = stamp;
    _removedStamp = removed;
    _dirty = false;
    _cachedFor = who;
    list = await _withCommunity(list);
    _items = list;
    _at = _clock();
    return list;
  }

  /// `GET /sync/activities`; null when Simkl cannot say (the list is then downloaded whole). A
  /// dead session or a back-off still reaches the caller.
  Future<Map<String, dynamic>?> _activities() async {
    try {
      final data = await _client.getAuth('/sync/activities');
      return data is Map<String, dynamic> ? data : null;
    } on SimklSessionExpired {
      rethrow;
    } on SimklRateLimited {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> get _nextQuery => kind.hasEpisodes ? const {'next_watch_info': 'yes'} : const {};

  /// Simkl's own "next to watch" of [simklId] from the last list pull; null when it has none (not
  /// watching, or nothing aired left to watch).
  SimklNextToWatch? nextToWatch(int simklId) => _next[simklId];

  String? _kindStamp(Map<String, dynamic>? activities, String key) {
    final block = activities?[kind.activitiesKey];
    final v = block is Map ? block[key] : null;
    return v is String && v.isNotEmpty ? v : null;
  }

  /// [changed] replaces the entries of [kept] with the same id; new ones come first.
  List<ListEntryView> _merge(List<ListEntryView> kept, List<ListEntryView> changed) {
    if (changed.isEmpty) return kept;
    final byId = {for (final e in changed) e.id: e};
    return [
      ...changed.where((e) => !kept.any((k) => k.id == e.id)),
      for (final e in kept) byId[e.id] ?? e,
    ];
  }

  /// Puts the community score on every title. A failure leaves the list without scores, never
  /// without the list.
  Future<List<ListEntryView>> _withCommunity(List<ListEntryView> list) async {
    final now = _clock();
    final fetched = _ratingsAt;
    final tried = _ratingsTried;
    final missing = list.any((e) => !_ratingAsked.contains(e.id));
    final stale = fetched == null || now.difference(fetched) >= ratingsTtl;
    final cooled = tried == null || now.difference(tried) >= const Duration(minutes: 10);
    if (list.isNotEmpty && (stale || missing) && cooled) {
      _ratingsTried = now;
      try {
        final data = await _client.getAuth('/ratings/${kind.api}', query: {
          'user_watchlist': kind.hasEpisodes
              ? 'watching,plantowatch,completed,hold,notinteresting'
              : 'plantowatch,completed,notinteresting',
          'fields': 'simkl',
        });
        _ratings = SimklCommunityRating.parseAll(data, kind);
        _ratingAsked = {for (final e in list) e.id};
        _ratingsAt = now;
      } on SimklSessionExpired {
        rethrow;
      } catch (_) {
        // no community score this time
      }
    }
    return [for (final e in list) _scored(e)];
  }

  ListEntryView _scored(ListEntryView e) {
    final r = _ratings[e.id];
    if (r == null) return e;
    return ListEntryView(
      id: e.id,
      malId: e.malId,
      category: e.category,
      title: e.title,
      otherTitles: e.otherTitles,
      imageUrl: e.imageUrl,
      largeImageUrl: e.largeImageUrl,
      mediaType: e.mediaType,
      releaseState: e.releaseState,
      meanScore: r.rating,
      members: e.members,
      scoringUsers: r.votes > 0 ? r.votes : e.scoringUsers,
      popularity: e.popularity,
      total: e.total,
      totalVolumes: e.totalVolumes,
      genres: e.genres,
      releaseStart: e.releaseStart,
      releaseEnd: e.releaseEnd,
      broadcast: e.broadcast,
      status: e.status,
      score: e.score,
      progress: e.progress,
      progressVolumes: e.progressVolumes,
      repeating: e.repeating,
      priority: e.priority,
      updatedAt: e.updatedAt,
      listStartDate: e.listStartDate,
      listFinishDate: e.listFinishDate,
      tags: e.tags,
    );
  }

  /// The user's paused viewing sessions (`GET /sync/playback/anime`), latest first. Not kept:
  /// the caller decides when to ask.
  Future<List<SimklPlayback>> playback() async =>
      SimklPlayback.parseAll(await _client.getAuth('/sync/playback/${kind.syncKey}'));

  /// Entries per status of the (kept) list.
  Future<Map<ListEntryStatus, int>> counts() async {
    final stats = SimklListStats.from(await anime());
    return stats.byStatus;
  }

  /// Sets the status and/or the score (1-10, 0 = remove the score) of a title, creating the
  /// entry when it is not on the list. Returns the list entry as it is now.
  Future<ListEntryView> save(ListEntryView entry, {ListEntryStatus? status, int? score}) async {
    var nextStatus = status ?? entry.status ?? ListEntryStatus.planned;
    // A movie is planned, completed or dropped.
    if (!kind.hasEpisodes && !simklMovieStatuses.contains(nextStatus)) nextStatus = ListEntryStatus.completed;
    final item = <String, dynamic>{
      'ids': _ids(entry),
      'to': SimklStatus.api(nextStatus),
      // Same body as the cross-tracker sync: the rating travels with the status.
      if (score != null && score > 0) 'rating': score,
    };
    await _client.postAuth('/sync/add-to-list', {
      kind.syncKey: [item],
    });
    if (score == 0 && entry.score > 0) {
      await _client.postAuth('/sync/ratings/remove', {
        (kind == SimklKind.movie ? 'movies' : 'shows'): [
          {'ids': _ids(entry)},
        ],
      });
    }
    _wrote();
    return _scored(entry.copyWith(
      status: nextStatus,
      score: score ?? entry.score,
      progress: !kind.hasEpisodes ? (nextStatus == ListEntryStatus.completed ? 1 : 0) : null,
      updatedAt: _clock().toUtc(),
    ));
  }

  /// Takes the title off the list.
  Future<void> remove(ListEntryView entry) async {
    await _client.postAuth('/sync/remove-from-list', {
      kind.syncKey: [
        {'ids': _ids(entry)},
      ],
    });
    _wrote(removal: true);
  }

  static const Duration checkInLock = Duration(seconds: 20);
  DateTime? _checkedInAt;

  /// "Watching now" (`POST /scrobble/checkin`): Simkl shows the episode on the viewer's dashboard
  /// and marks it watched itself when its runtime has elapsed (no pause or stop call follows).
  /// The list is read again afterwards through the activities check, not by this call.
  ///
  /// [ids] are the external ids of the title (`SimklTitle.externalIds`), sent next to the Simkl
  /// id because Simkl resolves the first one it knows. Throws [SimklCheckInTooSoon] inside the
  /// 20 second lock.
  Future<void> checkIn({
    required int simklId,
    required String title,
    required int episode,
    int? season,
    int? year,
    int? malId,
    Map<String, String> ids = const {},
  }) async {
    final at = _checkedInAt;
    final now = _clock();
    if (at != null && now.difference(at) < checkInLock) {
      throw SimklCheckInTooSoon(checkInLock - now.difference(at));
    }
    _checkedInAt = now;
    try {
      final item = {
        'title': title,
        if (year != null) 'year': year,
        'ids': {
          ...ids,
          'simkl': simklId,
          if (malId != null) 'mal': malId,
        },
      };
      await _client.postAuth('/scrobble/checkin', switch (kind) {
        SimklKind.movie => {'movie': item},
        SimklKind.tv => {
            'show': item,
            'episode': {'season': season ?? 1, 'number': episode},
          },
        // AniDB numbering is single-season: season 1 and the absolute episode number.
        SimklKind.anime => {
            'anime': item,
            'episode': {'season': 1, 'number': episode},
          },
      });
    } catch (_) {
      _checkedInAt = null; // nothing was recorded: the viewer may try again
      rethrow;
    }
  }

  /// Marks one more (or one fewer) episode watched; see [setProgress].
  Future<ListEntryView> step(ListEntryView entry, int delta) =>
      setProgress(entry, entry.progress + delta);

  /// Sets the watched episodes to [target] (clamped to the known total): the episodes in between
  /// are added to or taken off the watch history. Reaching the known total completes a finished
  /// title; a planned entry starts watching, as Simkl does.
  Future<ListEntryView> setProgress(ListEntryView entry, int target) async {
    final total = kind.hasEpisodes ? entry.total : 1;
    final next = target.clamp(0, total > 0 ? total : 100000);
    if (next == entry.progress) return entry;
    final adding = next > entry.progress;
    final from = adding ? entry.progress + 1 : next + 1;
    final to = adding ? next : entry.progress;
    final Map<String, dynamic> body;
    switch (kind) {
      case SimklKind.movie:
        body = {
          'movies': [
            {'ids': _ids(entry)},
          ],
        };
      case SimklKind.tv:
        // Shows count episodes per season: the n-th regular episode in Simkl's order is the
        // n-th one watched (Simkl's own count skips the specials too).
        final episodes = regularEpisodes(await _episodesOf(entry.id));
        final picked = [
          for (var n = from; n <= to && n <= episodes.length; n++) episodes[n - 1],
        ];
        final bySeason = <int, List<int>>{};
        for (final e in picked) {
          bySeason.putIfAbsent(e.season ?? 1, () => []).add(e.number!);
        }
        body = {
          'shows': [
            {
              'ids': _ids(entry),
              'seasons': [
                for (final s in bySeason.entries)
                  {
                    'number': s.key,
                    'episodes': [
                      for (final n in s.value) {'number': n},
                    ],
                  },
              ],
            },
          ],
        };
      case SimklKind.anime:
        body = {
          'shows': [
            {
              'ids': _ids(entry),
              'episodes': [
                for (var n = from; n <= to; n++) {'number': n},
              ],
            },
          ],
        };
    }
    await _client.postAuth(adding ? '/sync/history' : '/sync/history/remove', body);
    _wrote();
    var status = entry.status;
    if (adding && status == ListEntryStatus.planned) {
      status = kind.hasEpisodes ? ListEntryStatus.current : ListEntryStatus.completed;
    }
    if (adding && total > 0 && next >= total && entry.releaseState != ReleaseState.releasing) {
      status = ListEntryStatus.completed;
    }
    if (!adding && !kind.hasEpisodes) status = ListEntryStatus.planned;
    return _scored(entry.copyWith(progress: next, status: status, updatedAt: _clock().toUtc()));
  }

  /// The episodes of a show, by default from the shared title service (`/tv/episodes/{id}`).
  Future<List<SimklEpisode>> _episodesOf(int id) =>
      (_episodes ?? (int id) => SimklDetailService.instance.episodes(id, kind: kind))(id);

  Map<String, dynamic> _ids(ListEntryView e) => {
        'simkl': e.id,
        if (e.malId != null) 'mal': e.malId,
      };

  /// Watching and Plan to watch titles that can still air, keyed by MyAnimeList id, in the shape
  /// of `NotificationPlanner` (entries without a MAL id are skipped: the schedule is keyed by it).
  Future<List<AiringCandidate>> airingCandidates() async {
    final list = await anime();
    return [
      for (final e in list)
        if (e.malId != null &&
            e.releaseState != ReleaseState.finished &&
            (e.status == ListEntryStatus.current || e.status == ListEntryStatus.planned))
          AiringCandidate(
            malId: e.malId!,
            title: e.title,
            status: e.status == ListEntryStatus.current ? 'watching' : 'plan_to_watch',
            imageUrl: e.imageUrl,
            numEpisodes: e.total > 0 ? e.total : null,
            airingStatus: e.releaseState == ReleaseState.releasing ? 'currently_airing' : null,
          ),
    ];
  }
}

/// The statuses a movie can have on Simkl.
const Set<ListEntryStatus> simklMovieStatuses = {
  ListEntryStatus.planned,
  ListEntryStatus.completed,
  ListEntryStatus.dropped,
};

/// The regular episodes in watch order: by season (shows), then number; no specials, no
/// unnumbered rows. The n-th one is the n-th watched.
List<SimklEpisode> regularEpisodes(List<SimklEpisode> episodes) => [
      for (final e in episodes)
        if (!e.isSpecial && e.number != null) e,
    ]..sort((a, b) {
        final s = (a.season ?? 0).compareTo(b.season ?? 0);
        return s != 0 ? s : a.number!.compareTo(b.number!);
      });
