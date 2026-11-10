import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
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
  SimklUserListAdapter({
    SimklListService? service,
    String? Function()? owner,
    this.schedule,
    DateTime Function()? now,
  })  : _service = service ?? SimklListService.instance,
        _owner = owner ?? (() => UserSimklV2.instance.username),
        _now = now ?? DateTime.now;

  final SimklListService _service;
  final String? Function() _owner;
  final DateTime Function() _now;

  /// Simkl's airing calendar (the CDN file, free); null = rows without airing times. Its next
  /// episode of each title gives the row's airing line ("Ep. 8 · Sat 23:30 · in 2 d 4 h").
  final Future<List<SimklMedia>> Function()? schedule;

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
    final all = await _withSchedule(await _service.anime());
    final matching = [
      for (final e in all)
        if (status == null || e.status == status) e,
    ]..sort(_byUpdated);
    final end = (offset + limit).clamp(0, matching.length);
    final start = offset.clamp(0, end);
    return ListPage(matching.sublist(start, end), hasMore: end < matching.length);
  }

  /// Puts the next airing of Simkl's calendar on the titles it lists. A calendar failure leaves
  /// the list as it is.
  Future<List<ListEntryView>> _withSchedule(List<ListEntryView> list) async {
    final load = schedule;
    if (load == null || list.isEmpty) return list;
    List<SimklMedia> calendar;
    try {
      calendar = await load();
    } catch (_) {
      return list;
    }
    return simklWithAiring(list, calendar, _now());
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

  /// Simkl rates out of 10 everywhere: "8/10" for the user, "8.2/10" for the community.
  @override
  ListScoreText? userScore(ListEntryView entry) => entry.score > 0
      ? ListScoreText(S.current.Tlh_Score_Of_Ten('${entry.score}'),
          spoken: S.current.UserList_My_Score_Value(entry.score))
      : null;

  @override
  ListScoreText? meanScore(ListEntryView entry) {
    final mean = entry.meanScore;
    if (mean == null || mean <= 0) return null;
    return ListScoreText(S.current.Tlh_Score_Of_Ten(SimklFormat.score(mean)));
  }

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

/// [list] with the next airing of each title found in [calendar] (Simkl id, air time after
/// [now]) as its weekly slot, and marked as airing. Titles absent from the calendar are kept
/// as they are.
List<ListEntryView> simklWithAiring(List<ListEntryView> list, List<SimklMedia> calendar, DateTime now) {
  final utcNow = now.toUtc();
  final next = <int, DateTime>{};
  for (final m in calendar) {
    final at = m.airDate;
    if (at == null || !at.isAfter(utcNow)) continue;
    final kept = next[m.simklId];
    if (kept == null || at.isBefore(kept)) next[m.simklId] = at;
  }
  if (next.isEmpty) return list;
  return [
    for (final e in list)
      if (next[e.id] case final at?) _airing(e, at) else e,
  ];
}

/// [e] airing at [utc]: `BroadcastSlot` is a weekly slot in Japan time (UTC+9 all year).
ListEntryView _airing(ListEntryView e, DateTime utc) {
  final jst = utc.toUtc().add(const Duration(hours: 9));
  return ListEntryView(
    id: e.id,
    malId: e.malId,
    category: e.category,
    title: e.title,
    otherTitles: e.otherTitles,
    imageUrl: e.imageUrl,
    largeImageUrl: e.largeImageUrl,
    mediaType: e.mediaType,
    releaseState: ReleaseState.releasing,
    meanScore: e.meanScore,
    members: e.members,
    scoringUsers: e.scoringUsers,
    popularity: e.popularity,
    total: e.total,
    totalVolumes: e.totalVolumes,
    genres: e.genres,
    releaseStart: e.releaseStart,
    releaseEnd: e.releaseEnd,
    broadcast: BroadcastSlot(jst.weekday, jst.hour * 60 + jst.minute),
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
    timesRewatched: e.timesRewatched,
    episodeSeconds: e.episodeSeconds,
    startSeason: e.startSeason,
    startSeasonYear: e.startSeasonYear,
    ageRating: e.ageRating,
    source: e.source,
    studios: e.studios,
    authors: e.authors,
  );
}
