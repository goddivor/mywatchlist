import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
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
      final show = raw['show'] is Map ? raw['show'] as Map : (raw['anime'] is Map ? raw['anime'] as Map : null);
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

/// The community score of a title (`GET /ratings/anime`).
class SimklCommunityRating {
  final double rating;
  final int votes;

  const SimklCommunityRating(this.rating, this.votes);

  /// `id` (Simkl id) to rating, from `[{"id":1,"simkl":{"rating":8.4,"votes":120}}]`.
  static Map<int, SimklCommunityRating> parseAll(Object? data) {
    final list = data is Map ? (data['anime'] ?? data['items'] ?? data['ratings']) : data;
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
    SimklClient? client,
    DateTime Function()? clock,
    String? Function()? owner,
    this.ttl = const Duration(minutes: 3),
    this.ratingsTtl = const Duration(hours: 12),
  })  : _client = client ?? SimklClient.instance,
        _clock = clock ?? DateTime.now,
        _owner = owner ?? (() => UserSimklV2.instance.username);

  /// Shared instance; tests build their own with a fake [SimklClient].
  static SimklListService instance = SimklListService();

  final SimklClient _client;
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
    _ratingAsked = const {};
    _ratingsAt = null;
    _ratingsTried = null;
  }

  /// The whole anime list. [force] checks Simkl even inside the [ttl].
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
    final stamp = _animeStamp(activities, 'all');
    final removed = _animeStamp(activities, 'removed_from_list');
    final kept = _items;
    List<ListEntryView> list;
    if (kept != null && _stamp != null && stamp != null && stamp == _stamp && !_dirty) {
      list = kept; // nothing changed
    } else if (kept != null && _stamp != null && stamp != null && removed == _removedStamp) {
      deltaPulls++;
      final data = await _client.getAuth('/sync/all-items/anime', query: {'date_from': _stamp!});
      list = _merge(kept, parseSimklAnimeList(data));
    } else {
      fullPulls++;
      list = parseSimklAnimeList(await _client.getAuth('/sync/all-items/anime'));
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

  static String? _animeStamp(Map<String, dynamic>? activities, String key) {
    final anime = activities?['anime'];
    final v = anime is Map ? anime[key] : null;
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
        final data = await _client.getAuth('/ratings/anime', query: {
          'user_watchlist': 'watching,plantowatch,completed,hold,notinteresting',
          'fields': 'simkl',
        });
        _ratings = SimklCommunityRating.parseAll(data);
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
      SimklPlayback.parseAll(await _client.getAuth('/sync/playback/anime'));

  /// Entries per status of the (kept) list.
  Future<Map<ListEntryStatus, int>> counts() async {
    final stats = SimklListStats.from(await anime());
    return stats.byStatus;
  }

  /// Sets the status and/or the score (1-10, 0 = remove the score) of a title, creating the
  /// entry when it is not on the list. Returns the list entry as it is now.
  Future<ListEntryView> save(ListEntryView entry, {ListEntryStatus? status, int? score}) async {
    final nextStatus = status ?? entry.status ?? ListEntryStatus.planned;
    final item = <String, dynamic>{
      'ids': _ids(entry),
      'to': SimklStatus.api(nextStatus),
      // Same body as the cross-tracker sync: the rating travels with the status.
      if (score != null && score > 0) 'rating': score,
    };
    await _client.postAuth('/sync/add-to-list', {
      'anime': [item],
    });
    if (score == 0 && entry.score > 0) {
      await _client.postAuth('/sync/ratings/remove', {
        'shows': [
          {'ids': _ids(entry)},
        ],
      });
    }
    _wrote();
    return _scored(entry.copyWith(
      status: nextStatus,
      score: score ?? entry.score,
      updatedAt: _clock().toUtc(),
    ));
  }

  /// Takes the title off the list.
  Future<void> remove(ListEntryView entry) async {
    await _client.postAuth('/sync/remove-from-list', {
      'anime': [
        {'ids': _ids(entry)},
      ],
    });
    _wrote(removal: true);
  }

  /// Marks one more (or one fewer) episode watched; see [setProgress].
  Future<ListEntryView> step(ListEntryView entry, int delta) =>
      setProgress(entry, entry.progress + delta);

  /// Sets the watched episodes to [target] (clamped to the known total): the episodes in between
  /// are added to or taken off the watch history. Reaching the known total completes a finished
  /// title; a planned entry starts watching, as Simkl does.
  Future<ListEntryView> setProgress(ListEntryView entry, int target) async {
    final next = target.clamp(0, entry.total > 0 ? entry.total : 100000);
    if (next == entry.progress) return entry;
    final adding = next > entry.progress;
    final from = adding ? entry.progress + 1 : next + 1;
    final to = adding ? next : entry.progress;
    await _client.postAuth(adding ? '/sync/history' : '/sync/history/remove', {
      'shows': [
        {
          'ids': _ids(entry),
          'episodes': [
            for (var n = from; n <= to; n++) {'number': n},
          ],
        },
      ],
    });
    _wrote();
    var status = entry.status;
    if (adding && status == ListEntryStatus.planned) status = ListEntryStatus.current;
    if (adding && entry.total > 0 && next >= entry.total && entry.releaseState != ReleaseState.releasing) {
      status = ListEntryStatus.completed;
    }
    return _scored(entry.copyWith(progress: next, status: status, updatedAt: _clock().toUtc()));
  }

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
