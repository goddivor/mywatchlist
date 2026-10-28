import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_entry_editor.dart';

/// The signed-in user's AniList lists for the shared list widgets (`UserListView`).
///
/// AniList sorts nothing the way the shared sorts need and answers a whole category at
/// once, so the list is loaded whole ([AnilistListService] keeps it for a minute), cut by
/// status here and sorted on the device. Edits go through the tracker editor sheet and the
/// quick +1 / -1 through `TrackerSyncService` (the sync unit's AniList client), so every
/// write uses the refreshed session.
class AnilistUserListAdapter extends UserListAdapter {
  AnilistUserListAdapter({
    AnilistListService? service,
    TrackerSyncService? sync,
    DateTime Function()? clock,
    Future<SyncEntry?> Function(BuildContext context, ListEntryView entry, SyncEntry initial)?
        editor,
  })  : _service = service,
        _sync = sync,
        _clock = clock ?? DateTime.now,
        _editor = editor;

  /// Replaced by a fake in tests; null opens the tracker editor sheet.
  final Future<SyncEntry?> Function(BuildContext, ListEntryView, SyncEntry)? _editor;

  final AnilistListService? _service;
  final TrackerSyncService? _sync;
  final DateTime Function() _clock;

  AnilistListService get _lists => _service ?? AnilistListService.instance;
  TrackerSyncService get _tracker => _sync ?? TrackerSyncService.instance;

  @override
  AccountType get tracker => AccountType.anilist;

  @override
  String? get owner => _lists.owner;

  /// The whole list is in memory: pages are free, so ask for big ones.
  @override
  int get maxPageSize => 1000;

  @override
  List<ListSortOption> sortOptions(String category) =>
      standardSortOptions(isAnime: category == 'anime');

  @override
  String? apiSort(String category, String sortKey, SortDirection direction) => null;

  @override
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  }) async {
    // A tab loads once when shown and again only on a pull to refresh: asking for the first
    // page of a status a second time is that refresh, so AniList is asked again then.
    final first = offset == 0 && !_firstPages.add('$category/${status?.name}');
    final all = await _lists.all(category, force: first);
    final inStatus = status == null ? all : [for (final e in all) if (e.status == status) e];
    final end = (offset + limit).clamp(0, inStatus.length);
    final from = offset.clamp(0, inStatus.length);
    return ListPage(inStatus.sublist(from, end), hasMore: end < inStatus.length);
  }

  final Set<String> _firstPages = {};

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async {
    try {
      return AnilistListService.countStatuses(await _lists.all(category));
    } catch (_) {
      return null;
    }
  }

  @override
  void open(BuildContext context, ListEntryView entry) {
    final malId = entry.malId;
    if (malId != null) {
      AppRoutes.openContent(context, id: malId, category: entry.category);
    } else {
      // The detail screen reads MyAnimeList: a title AniList does not link opens on anilist.co.
      openLink(context, 'https://anilist.co/${entry.category}/${entry.id}');
    }
  }

  static SyncEntry _syncEntryOf(ListEntryView e) => SyncEntry(
        status: e.status?.malValue(isAnime: e.isAnime),
        score: e.score > 0 ? e.score.toDouble() : null,
        progress: e.progress,
        volumes: e.isAnime ? null : e.progressVolumes,
        startDate: e.listStartDate,
        finishDate: e.listFinishDate,
      );

  /// [view] with the list fields of [saved] (what AniList answered).
  @visibleForTesting
  ListEntryView applySaved(ListEntryView view, SyncEntry saved) {
    final status = ListEntryStatus.fromMal(saved.status);
    return view.copyWith(
      status: status,
      clearStatus: status == null,
      score: saved.score == null ? 0 : saved.score!.round().clamp(0, 10).toInt(),
      progress: saved.progress ?? view.progress,
      progressVolumes: view.isAnime ? 0 : (saved.volumes ?? view.progressVolumes),
      listStartDate: saved.startDate ?? view.listStartDate,
      listFinishDate: saved.finishDate ?? view.listFinishDate,
      updatedAt: _clock(),
    );
  }

  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async {
    final editor = _editor;
    final saved = editor != null
        ? await editor(context, entry, _syncEntryOf(entry))
        : await showTrackerEntryEditor(
            context,
            service: _tracker,
            tracker: AccountType.anilist,
            trackerId: entry.id.toString(),
            malId: entry.malId ?? 0,
            category: entry.category,
            initial: _syncEntryOf(entry),
          );
    if (saved == null) return const ListEditUnchanged();
    if (saved.isRemoved) {
      // Deleted from AniList: forget the row in the kept list, drop it from the screen.
      _lists.put(entry, removed: true);
      return const ListEditRemoved();
    }
    final updated = applySaved(entry, saved);
    _lists.put(updated);
    return ListEditUpdated(updated);
  }

  @override
  bool canStep(ListEntryView entry) => entry.status != null;

  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) async {
    var progress = entry.progress + delta;
    if (progress < 0) progress = 0;
    if (entry.total > 0 && progress > entry.total) progress = entry.total;
    var status = entry.status?.malValue(isAnime: entry.isAnime);
    var finish = entry.listFinishDate;
    final today = _today();
    if (entry.total > 0 && progress >= entry.total && delta > 0) {
      // The last episode completes the entry, as the edit sheet does.
      status = ListEntryStatus.completed.malValue(isAnime: entry.isAnime);
      if (finish == null || finish.isEmpty) finish = today;
    } else if (entry.status == ListEntryStatus.planned && progress > 0) {
      status = ListEntryStatus.current.malValue(isAnime: entry.isAnime);
    }
    final saved = await _tracker.saveTracker(
      AccountType.anilist,
      entry.id.toString(),
      entry.category,
      SyncEntry(
        status: status,
        progress: progress,
        finishDate: finish,
        score: entry.score > 0 ? entry.score.toDouble() : null,
      ),
      malId: entry.malId,
    );
    final updated = entry.copyWith(
      status: ListEntryStatus.fromMal(saved.status) ?? entry.status,
      progress: saved.progress ?? progress,
      listFinishDate: saved.finishDate ?? finish,
      updatedAt: _clock(),
    );
    _lists.put(updated);
    return updated;
  }

  String _today() {
    final d = _clock();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  @override
  bool isSessionExpired(Object error) => error is AnilistSessionExpired;

  @override
  Future<void> signInAgain(BuildContext context) =>
      AppRoutes.signInAgain(context, AccountType.anilist);
}
