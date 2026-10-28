import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/notifications/notification_models.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The signed-in user's Simkl anime list: one fetch of the whole list (Simkl has no paging and
/// no per-status server sort), kept for [ttl] and shared by the list tab, the home sections,
/// the profile and the notifications. Simkl has no manga.
class SimklListService {
  SimklListService({
    SimklClient? client,
    DateTime Function()? clock,
    String? Function()? owner,
    this.ttl = const Duration(minutes: 3),
  })  : _client = client ?? SimklClient.instance,
        _clock = clock ?? DateTime.now,
        _owner = owner ?? (() => UserSimklV2.instance.username);

  /// Shared instance; tests build their own with a fake [SimklClient].
  static SimklListService instance = SimklListService();

  final SimklClient _client;
  final DateTime Function() _clock;
  final String? Function() _owner;
  final Duration ttl;

  List<ListEntryView>? _items;
  DateTime? _at;
  String? _cachedFor;
  Future<List<ListEntryView>>? _inflight;

  /// Drops the kept list (after a write elsewhere, a sign out or a pull to refresh).
  void invalidate() {
    _items = null;
    _at = null;
  }

  /// The whole anime list. [force] skips the kept copy.
  Future<List<ListEntryView>> anime({bool force = false}) {
    final who = _owner();
    final items = _items;
    final at = _at;
    if (!force && items != null && at != null && who == _cachedFor && _clock().difference(at) < ttl) {
      return Future.value(items);
    }
    return _inflight ??= _fetch(who).whenComplete(() => _inflight = null);
  }

  Future<List<ListEntryView>> _fetch(String? who) async {
    final data = await _client.getAuth('/sync/all-items/anime');
    final parsed = parseSimklAnimeList(data);
    _items = parsed;
    _at = _clock();
    _cachedFor = who;
    return parsed;
  }

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
    invalidate();
    return entry.copyWith(
      status: nextStatus,
      score: score ?? entry.score,
      updatedAt: _clock().toUtc(),
    );
  }

  /// Takes the title off the list.
  Future<void> remove(ListEntryView entry) async {
    await _client.postAuth('/sync/remove-from-list', {
      'anime': [
        {'ids': _ids(entry)},
      ],
    });
    invalidate();
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
    invalidate();
    var status = entry.status;
    if (adding && status == ListEntryStatus.planned) status = ListEntryStatus.current;
    if (adding && entry.total > 0 && next >= entry.total && entry.releaseState != ReleaseState.releasing) {
      status = ListEntryStatus.completed;
    }
    return entry.copyWith(progress: next, status: status, updatedAt: _clock().toUtc());
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
