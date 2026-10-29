import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_entry_editor.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart' show openAnilistTitle;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';

/// Sort keys only AniList has (sorted on the device from the AniList fields of each row).
abstract final class AnilistSortKeys {
  static const added = 'al_added';
  static const finished = 'al_finished';
  static const repeat = 'al_repeat';
  static const exactScore = 'al_score';
  static const exactPriority = 'al_priority';

  static const all = {added, finished, repeat, exactScore, exactPriority};
}

/// The signed-in user's AniList lists for the list widgets.
///
/// AniList answers a whole category at once, so the list is loaded whole
/// ([AnilistListService] keeps it for a minute with AniList's own fields of each row), cut
/// into sections by `AnilistListView` and sorted on the device. Edits go through the AniList
/// editor (`showAnilistEntryEditor`: all 16 fields of `SaveMediaListEntry`); the quick +1 / -1
/// sends the progress alone (never the score, never a Rewatching status turned into Watching).
class AnilistUserListAdapter extends UserListAdapter {
  AnilistUserListAdapter({
    AnilistListService? service,
    TrackerSyncService? sync,
    AnilistListWrite? write,
    DateTime Function()? clock,
    Future<SyncEntry?> Function(BuildContext context, ListEntryView entry, SyncEntry initial)?
        editor,
    Future<AnilistEditResult?> Function(
            BuildContext context, ListEntryView entry, AnilistListEntry? detail)?
        anilistEditor,
    Future<void> Function(BuildContext context, {required String category, required int id})?
        opener,
  })  : _service = service,
        _sync = sync,
        _write = write,
        _clock = clock ?? DateTime.now,
        _editor = editor,
        _anilistEditor = anilistEditor,
        _opener = opener ?? openAnilistTitle;

  /// Opens a row's title (tests replace it). Owner rule: an AniList row opens the AniList
  /// title ([openAnilistTitle]), never the MyAnimeList page, even when AniList knows its MAL id.
  final Future<void> Function(BuildContext context, {required String category, required int id})
      _opener;

  /// Test hook in the shared editor's terms (status, score, progress, dates).
  final Future<SyncEntry?> Function(BuildContext, ListEntryView, SyncEntry)? _editor;

  /// Replaces the AniList editor sheet (tests); null opens `showAnilistEntryEditor`.
  final Future<AnilistEditResult?> Function(BuildContext, ListEntryView, AnilistListEntry?)?
      _anilistEditor;

  final AnilistListService? _service;
  final TrackerSyncService? _sync;
  final AnilistListWrite? _write;
  final DateTime Function() _clock;

  AnilistListService get lists => _service ?? AnilistListService.instance;
  AnilistListWrite get writer => _write ?? AnilistListWrite.instance;
  TrackerSyncService get _tracker => _sync ?? TrackerSyncService.instance;

  @override
  AccountType get tracker => AccountType.anilist;

  @override
  String? get owner => lists.owner;

  /// The whole list is in memory: pages are free, so ask for big ones.
  @override
  int get maxPageSize => 1000;

  @override
  List<ListSortOption> sortOptions(String category) {
    final isAnime = category == 'anime';
    final standard = standardSortOptions(isAnime: isAnime);
    return [
      for (final o in standard)
        // AniList keeps the exact score and a 0-5 priority: sort on those.
        if (o.key == ListSortKeys.score)
          ListSortOption(AnilistSortKeys.exactScore, o.label)
        else if (o.key == ListSortKeys.priority)
          ListSortOption(AnilistSortKeys.exactPriority, o.label)
        else
          o,
      ListSortOption(AnilistSortKeys.added, S.current.Alf_Sort_Added),
      ListSortOption(AnilistSortKeys.finished, S.current.Alf_Sort_Finished),
      ListSortOption(AnilistSortKeys.repeat,
          isAnime ? S.current.Edit_Times_Rewatched : S.current.Edit_Times_Reread),
    ];
  }

  @override
  String? apiSort(String category, String sortKey, SortDirection direction) => null;

  /// [entries] sorted by an [AnilistSortKeys] key from their AniList fields; other keys are
  /// left to the shared sort. Entries without a value go last whatever the direction.
  List<ListEntryView> sortByAnilist(
      List<ListEntryView> entries, String category, String key, SortDirection direction) {
    if (!AnilistSortKeys.all.contains(key)) return entries;
    Comparable<dynamic>? value(ListEntryView e) {
      final d = lists.detailOf(category, e.id);
      if (d == null) return null;
      return switch (key) {
        AnilistSortKeys.added => d.createdAt?.millisecondsSinceEpoch,
        AnilistSortKeys.finished => _dateKey(d.completedAt),
        AnilistSortKeys.repeat => d.repeat == 0 ? null : d.repeat,
        AnilistSortKeys.exactScore => d.scoreRaw == 0 ? null : d.scoreRaw,
        AnilistSortKeys.exactPriority => d.priority == 0 ? null : d.priority,
        _ => null,
      };
    }

    final keyed = [for (var i = 0; i < entries.length; i++) (entries[i], value(entries[i]), i)];
    final asc = direction == SortDirection.ascending;
    keyed.sort((a, b) {
      final va = a.$2, vb = b.$2;
      if (va == null && vb == null) return a.$3.compareTo(b.$3);
      if (va == null) return 1;
      if (vb == null) return -1;
      final c = va.compareTo(vb);
      if (c != 0) return asc ? c : -c;
      final t = a.$1.title.toLowerCase().compareTo(b.$1.title.toLowerCase());
      return t != 0 ? t : a.$3.compareTo(b.$3);
    });
    return [for (final k in keyed) k.$1];
  }

  static String? _dateKey(String? date) {
    if (date == null || date.isEmpty) return null;
    final parts = date.split('-');
    while (parts.length < 3) {
      parts.add('00');
    }
    return parts.take(3).map((p) => p.padLeft(2, '0')).join('-');
  }

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
    final all = await lists.all(category, force: first);
    final inStatus = status == null ? all : [for (final e in all) if (e.status == status) e];
    final end = (offset + limit).clamp(0, inStatus.length);
    final from = offset.clamp(0, inStatus.length);
    return ListPage(inStatus.sublist(from, end), hasMore: end < inStatus.length);
  }

  final Set<String> _firstPages = {};

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async {
    try {
      return AnilistListService.countStatuses(await lists.all(category));
    } catch (_) {
      return null;
    }
  }

  @override
  void open(BuildContext context, ListEntryView entry) =>
      _opener(context, category: entry.category, id: entry.id);

  static SyncEntry _syncEntryOf(ListEntryView e, AnilistListEntry? d) => SyncEntry(
        status: e.status?.malValue(isAnime: e.isAnime),
        score: d != null
            ? (d.scoreRaw > 0 ? d.scoreRaw / 10 : null)
            : (e.score > 0 ? e.score.toDouble() : null),
        progress: e.progress,
        volumes: e.isAnime ? null : e.progressVolumes,
        startDate: e.listStartDate,
        finishDate: e.listFinishDate,
        repeat: d?.repeat,
        notes: d?.notes,
        entryId: d?.entryId.toString(),
      );

  /// [view] with the list fields of [saved] (what the shared editor answered).
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

  /// [view] after AniList saved [detail]: the row and the kept list follow it.
  ListEntryView applyDetail(ListEntryView view, AnilistListEntry detail) {
    // AniList answers `updatedAt`; a test fake may not: the row still sorts as just edited.
    final d = detail.updatedAt == null ? _stamped(detail) : detail;
    final updated = anilistApplyDetail(view, d);
    lists.put(updated, detail: d);
    return updated;
  }

  AnilistListEntry _stamped(AnilistListEntry d) => AnilistListEntry(
        entryId: d.entryId,
        mediaId: d.mediaId,
        category: d.category,
        status: d.status,
        scoreRaw: d.scoreRaw,
        progress: d.progress,
        progressVolumes: d.progressVolumes,
        repeat: d.repeat,
        priority: d.priority,
        private: d.private,
        hiddenFromStatusLists: d.hiddenFromStatusLists,
        notes: d.notes,
        customLists: d.customLists,
        advancedScores: d.advancedScores,
        startedAt: d.startedAt,
        completedAt: d.completedAt,
        createdAt: d.createdAt,
        updatedAt: _clock(),
        format: d.format,
      );

  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async {
    final detail = lists.detailOf(entry.category, entry.id);
    final legacy = _editor;
    if (legacy != null) {
      final saved = await legacy(context, entry, _syncEntryOf(entry, detail));
      if (saved == null) return const ListEditUnchanged();
      if (saved.isRemoved) {
        lists.put(entry, removed: true);
        return const ListEditRemoved();
      }
      final updated = applySaved(entry, saved);
      lists.put(updated);
      return ListEditUpdated(updated);
    }
    final result = _anilistEditor != null
        ? await _anilistEditor(context, entry, detail)
        : await showAnilistEntryEditor(
            context,
            entry: entry,
            detail: detail,
            options: lists.optionsOf(entry.category) ?? const AnilistListOptions(),
            write: writer,
          );
    switch (result) {
      case null:
        return const ListEditUnchanged();
      case AnilistEditRemoved():
        // Deleted from AniList: forget the row in the kept list, drop it from the screen.
        lists.put(entry, removed: true);
        return const ListEditRemoved();
      case AnilistEditSaved(detail: final saved):
        return ListEditUpdated(applyDetail(entry, saved));
    }
  }

  @override
  bool canStep(ListEntryView entry) => entry.status != null;

  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) async {
    final detail = lists.detailOf(entry.category, entry.id);
    final repeating = entry.repeating || (detail?.isRepeating ?? false);
    var progress = entry.progress + delta;
    if (progress < 0) progress = 0;
    if (entry.total > 0 && progress > entry.total) progress = entry.total;
    // A null status is not sent: a Rewatching entry stays Rewatching.
    String? status = repeating ? null : entry.status?.malValue(isAnime: entry.isAnime);
    int? repeat;
    var finish = entry.listFinishDate;
    final today = _today();
    final completes = entry.total > 0 && progress >= entry.total && delta > 0;
    if (completes) {
      // The last episode completes the entry, as the edit sheet does; a rewatch counts.
      status = ListEntryStatus.completed.malValue(isAnime: entry.isAnime);
      if (repeating) repeat = (detail?.repeat ?? 0) + 1;
      if (finish == null || finish.isEmpty) finish = today;
    } else if (entry.status == ListEntryStatus.planned && progress > 0) {
      status = ListEntryStatus.current.malValue(isAnime: entry.isAnime);
    }
    // No score: the shared row holds a rounded one, sending it would destroy 7.5 or 73.
    final saved = await _tracker.saveTracker(
      AccountType.anilist,
      entry.id.toString(),
      entry.category,
      SyncEntry(status: status, progress: progress, finishDate: finish, repeat: repeat),
      malId: entry.malId,
    );
    final newStatus = ListEntryStatus.fromMal(saved.status) ??
        (status == null ? entry.status : ListEntryStatus.fromMal(status));
    final stillRepeating = repeating && !completes;
    final updated = entry.copyWith(
      status: newStatus,
      progress: saved.progress ?? progress,
      repeating: stillRepeating,
      listFinishDate: saved.finishDate ?? finish,
      updatedAt: _clock(),
    );
    lists.put(
      updated,
      detail: detail == null
          ? null
          : _stamped(AnilistListEntry(
              entryId: detail.entryId,
              mediaId: detail.mediaId,
              category: detail.category,
              status: stillRepeating ? 'REPEATING' : anilistStatusValueOf(newStatus, detail),
              scoreRaw: detail.scoreRaw,
              progress: updated.progress,
              progressVolumes: detail.progressVolumes,
              repeat: saved.repeat ?? repeat ?? detail.repeat,
              priority: detail.priority,
              private: detail.private,
              hiddenFromStatusLists: detail.hiddenFromStatusLists,
              notes: detail.notes,
              customLists: detail.customLists,
              advancedScores: detail.advancedScores,
              startedAt: detail.startedAt,
              completedAt: updated.listFinishDate,
              createdAt: detail.createdAt,
              format: detail.format,
            )),
    );
    return updated;
  }

  /// AniList status of [status], [detail]'s own when the shared status did not change it.
  static String? anilistStatusValueOf(ListEntryStatus? status, AnilistListEntry detail) =>
      status == null ? detail.status : anilistStatusValue(status);

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
