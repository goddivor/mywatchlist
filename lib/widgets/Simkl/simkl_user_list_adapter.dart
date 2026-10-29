import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_edit_sheet.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart' show openSimklTitle;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';

/// The signed-in user's Simkl anime list for the tracker-agnostic list widgets
/// (`UserListView`, the list and grid cards with their episode badges).
///
/// Simkl answers the whole list in one request and has no manga: the list is fetched once
/// (kept by [SimklListService]), cut by status here, and every sort, filter and search runs on the
/// device.
class SimklUserListAdapter extends UserListAdapter {
  SimklUserListAdapter({SimklListService? service, String? Function()? owner})
      : _service = service ?? SimklListService.instance,
        _owner = owner ?? (() => UserSimklV2.instance.username);

  final SimklListService _service;
  final String? Function() _owner;

  @override
  AccountType get tracker => AccountType.simkl;

  @override
  String? get owner => _owner();

  /// One request carries the whole list, so a "page" is as big as the list can be.
  @override
  int get maxPageSize => 100000;

  @override
  List<ListSortOption> sortOptions(String category) => [
        for (final option in standardSortOptions(isAnime: true))
          // Simkl has no priority, members, popularity or air dates by day.
          if (const {
            ListSortKeys.updated,
            ListSortKeys.score,
            ListSortKeys.mean,
            ListSortKeys.title,
            ListSortKeys.progress,
            ListSortKeys.unseen,
            ListSortKeys.nextAiring,
            ListSortKeys.total,
            ListSortKeys.releaseStart,
          }.contains(option.key))
            option,
      ];

  /// Nothing is sorted by the server.
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
    // Simkl has no manga: that category is an empty list, never an error.
    if (category != 'anime') return const ListPage([], hasMore: false);
    final all = await _service.anime();
    final matching = [
      for (final e in all)
        if (status == null || e.status == status) e,
    ]..sort(_byUpdated);
    final end = (offset + limit).clamp(0, matching.length);
    final start = offset.clamp(0, end);
    return ListPage(matching.sublist(start, end), hasMore: end < matching.length);
  }

  static int _byUpdated(ListEntryView a, ListEntryView b) {
    final x = a.updatedAt;
    final y = b.updatedAt;
    if (x == null && y == null) return a.title.compareTo(b.title);
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  }

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async {
    if (category != 'anime') return {for (final s in ListEntryStatus.values) s: 0};
    try {
      return await _service.counts();
    } catch (_) {
      return null;
    }
  }

  @override
  void open(BuildContext context, ListEntryView entry) {
    // The native Simkl page, whatever the title's other ids are.
    openSimklTitle(context, simklId: entry.id, title: entry.title, posterUrl: entry.imageUrl);
  }

  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) =>
      showSimklEditSheet(context, entry, service: _service);

  @override
  bool canStep(ListEntryView entry) => entry.status != null;

  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) => _service.step(entry, delta);

  @override
  bool isSessionExpired(Object error) => error is SimklSessionExpired;

  @override
  Future<void> signInAgain(BuildContext context) =>
      AppRoutes.signInAgain(context, AccountType.simkl);
}
