import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuMediaKind;
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_entry_editor.dart';

/// The signed-in user's Kitsu library for the tracker-agnostic list widgets (`UserListView`).
///
/// Kitsu sorts by last progress only, so the other sorts load the whole status and sort on the
/// device. Quick +1 / -1 follow the same rules as the MyAnimeList edit sheet (completing at the
/// total, starting a planned entry, automatic dates); the full edit opens the tracker editor of
/// the sync dialog.
class KitsuUserListAdapter extends UserListAdapter {
  KitsuUserListAdapter({
    KitsuLibrary? library,
    String? Function()? owner,
    DateTime Function()? clock,
    Future<SyncEntry?> Function(BuildContext context, ListEntryView entry, SyncEntry initial)?
        editor,
  })  : _library = library ?? KitsuLibrary.instance,
        _owner = owner ?? (() => UserKitsuV2.instance.username),
        _clock = clock ?? DateTime.now,
        _editor = editor ?? _openEditor;

  final KitsuLibrary _library;
  final String? Function() _owner;
  final DateTime Function() _clock;
  final Future<SyncEntry?> Function(BuildContext, ListEntryView, SyncEntry) _editor;

  /// Library-entry id of each loaded media (`anime:12`), filled by [fetch].
  final Map<String, String> _entryIds = {};

  @override
  AccountType get tracker => AccountType.kitsu;

  @override
  String? get owner => _owner();

  @override
  int get maxPageSize => KitsuLibrary.maxPage;

  /// The shared sorts without the MAL-only ones (priority, number of scorers).
  @override
  List<ListSortOption> sortOptions(String category) => [
        for (final o in standardSortOptions(isAnime: category == 'anime'))
          if (o.key != ListSortKeys.priority && o.key != ListSortKeys.scorers) o,
      ];

  @override
  String? apiSort(String category, String sortKey, SortDirection direction) =>
      (sortKey == ListSortKeys.updated && direction == SortDirection.descending)
          ? '-progressedAt'
          : null;

  @override
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  }) async {
    final result = await _library.page(
      isAnime: category == 'anime',
      status: status,
      offset: offset,
      limit: limit,
      sort: apiSort,
    );
    for (final e in result.entryIds.entries) {
      _entryIds['$category:${e.key}'] = e.value;
    }
    return result.page;
  }

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async {
    try {
      return await _library.statusCounts(isAnime: category == 'anime');
    } catch (e) {
      debugPrint('KitsuUserListAdapter.statusCounts failed (${e.runtimeType})');
      return null;
    }
  }

  @override
  void open(BuildContext context, ListEntryView entry) {
    // The native Kitsu page: every title opens, mapped to MyAnimeList or not.
    openKitsuTitle(
      context,
      kind: entry.isAnime ? KitsuMediaKind.anime : KitsuMediaKind.manga,
      id: '${entry.id}',
      title: entry.title,
      posterUrl: entry.largeImageUrl ?? entry.imageUrl,
    );
  }

  Future<String?> _entryIdOf(ListEntryView entry) async {
    final key = '${entry.category}:${entry.id}';
    final known = _entryIds[key];
    if (known != null) return known;
    final found = await _library.entryIdOf(entry.id, isAnime: entry.isAnime);
    if (found != null) _entryIds[key] = found;
    return found;
  }

  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async {
    final entryId = _entryIds['${entry.category}:${entry.id}'];
    final saved = await _editor(
      context,
      entry,
      SyncEntry(
        status: entry.status?.malValue(isAnime: entry.isAnime),
        score: entry.score > 0 ? entry.score.toDouble() : null,
        progress: entry.progress,
        startDate: entry.listStartDate,
        finishDate: entry.listFinishDate,
        entryId: entryId,
      ),
    );
    if (saved == null) return const ListEditUnchanged();
    if (saved.isRemoved) {
      // Deleted from Kitsu: its library-entry id is gone with it.
      _entryIds.remove('${entry.category}:${entry.id}');
      return const ListEditRemoved();
    }
    final id = saved.entryId;
    if (id != null) _entryIds['${entry.category}:${entry.id}'] = id;
    return ListEditUpdated(applySync(entry, saved, _clock()));
  }

  static Future<SyncEntry?> _openEditor(
      BuildContext context, ListEntryView entry, SyncEntry initial) {
    return showTrackerEntryEditor(
      context,
      service: TrackerSyncService.instance,
      tracker: AccountType.kitsu,
      trackerId: '${entry.id}',
      malId: entry.malId ?? 0,
      category: entry.category,
      initial: initial,
    );
  }

  /// [view] with the list fields of [saved] (just written at [now]).
  @visibleForTesting
  static ListEntryView applySync(ListEntryView view, SyncEntry saved, DateTime now) {
    final status = ListEntryStatus.fromMal(saved.status);
    return view.copyWith(
      status: status,
      clearStatus: status == null,
      score: (saved.score ?? 0).round(),
      progress: saved.progress ?? view.progress,
      repeating: (saved.repeat ?? 0) > 0 && status == ListEntryStatus.current,
      updatedAt: now,
      listStartDate: saved.startDate,
      listFinishDate: saved.finishDate,
    );
  }

  @override
  bool canStep(ListEntryView entry) => entry.status != null;

  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) async {
    final plan = planProgressChange(
      content: EditableContent(
        id: entry.id,
        isAnime: entry.isAnime,
        numEpisodes: entry.isAnime ? entry.total : 0,
        numChapters: entry.isAnime ? 0 : entry.total,
        numVolumes: entry.totalVolumes,
      ),
      entry: ListEntry(
        status: entry.status?.malValue(isAnime: entry.isAnime) ?? '',
        score: entry.score,
        progress: entry.progress,
        startDate: entry.listStartDate,
        finishDate: entry.listFinishDate,
      ),
      progress: entry.progress + delta,
      autoDates: Preferences.general.autoAddStartEndDate,
      now: _clock(),
    );
    final patch = plan.patch;
    if (patch == null) throw ArgumentError(plan.error);
    final id = await _entryIdOf(entry);
    if (id == null) throw const KitsuHttpError(404);
    final status = patch.status == null
        ? null
        : StatusMaps.toTracker(patch.status!, AccountType.kitsu);
    await _library.update(id, {
      if (patch.progress != null) 'progress': patch.progress,
      if (status != null) 'status': status,
      if (SyncDates.toTimestamp(patch.startDate) != null)
        'startedAt': SyncDates.toTimestamp(patch.startDate),
      if (SyncDates.toTimestamp(patch.finishDate) != null)
        'finishedAt': SyncDates.toTimestamp(patch.finishDate),
    });
    return entry.copyWith(
      status: patch.status == null ? null : ListEntryStatus.fromMal(patch.status),
      progress: patch.progress,
      updatedAt: _clock(),
      listStartDate: patch.startDate,
      listFinishDate: patch.finishDate,
    );
  }

  @override
  bool isSessionExpired(Object error) => error is KitsuSessionExpired;

  @override
  Future<void> signInAgain(BuildContext context) =>
      AppRoutes.signInAgain(context, AccountType.kitsu);
}
