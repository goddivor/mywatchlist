import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuMediaKind;
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart' show KitsuRatingSystem;
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_entry_sheet.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_library_box.dart' show kitsuWriteFailed;
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_rating.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart' show kitsuStatusLabel;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';

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
    KitsuRatingSystem Function()? ratingSystem,
    Future<int?> Function(BuildContext context, ListEntryView entry)? askRating,
  })  : _library = library ?? KitsuLibrary.instance,
        _owner = owner ?? (() => UserKitsuV2.instance.username),
        _clock = clock ?? DateTime.now,
        _editor = editor ?? _openEditor,
        _ratingSystem = ratingSystem ?? (() => KitsuRating.current),
        _askRating = askRating ?? _showRatingSheet;

  final KitsuLibrary _library;
  final String? Function() _owner;
  final DateTime Function() _clock;
  final Future<SyncEntry?> Function(BuildContext, ListEntryView, SyncEntry) _editor;
  final KitsuRatingSystem Function() _ratingSystem;
  final Future<int?> Function(BuildContext, ListEntryView) _askRating;

  /// Kitsu's own rating (`ratingTwenty`, 2 to 20) and reaction of each loaded entry
  /// (`anime:12`), read from the same library request as the page: the shared card model keeps
  /// the rating on 0-10 only.
  final Map<String, KitsuListExtras> _extras = {};

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
      reactions: true,
    );
    for (final e in result.entryIds.entries) {
      _entryIds['$category:${e.key}'] = e.value;
    }
    for (final e in result.extras.entries) {
      _extras['$category:${e.key}'] = e.value;
    }
    return result.page;
  }

  /// The five counts in one request, as the site's library sidebar reads them
  /// (`meta.statusCounts`); one request per status only when Kitsu leaves that object out.
  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async {
    try {
      final json = await _library.http.getJson('/library-entries',
          query: {
            'filter[userId]': await _library.userId(),
            'filter[kind]': category == 'anime' ? 'anime' : 'manga',
            'page[limit]': '1',
            'fields[libraryEntries]': 'status',
          },
          auth: true);
      return parseStatusCounts(json) ?? await _library.statusCounts(isAnime: category == 'anime');
    } catch (e) {
      debugPrint('KitsuUserListAdapter.statusCounts failed (${e.runtimeType})');
      return null;
    }
  }

  /// The counts of a library answer's `meta.statusCounts`, null when it has none. A status
  /// Kitsu leaves out counts 0.
  @visibleForTesting
  static Map<ListEntryStatus, int>? parseStatusCounts(Map<String, dynamic> json) {
    final counts = (json['meta'] as Map?)?['statusCounts'];
    if (counts is! Map) return null;
    int n(String key) => (counts[key] as num?)?.toInt() ?? 0;
    return {
      ListEntryStatus.current: n('current'),
      ListEntryStatus.planned: n('planned'),
      ListEntryStatus.completed: n('completed'),
      ListEntryStatus.onHold: n('onHold'),
      ListEntryStatus.dropped: n('dropped'),
    };
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
      _extras.remove('${entry.category}:${entry.id}');
      return const ListEditRemoved();
    }
    final id = saved.entryId;
    final key = '${entry.category}:${entry.id}';
    if (id != null) _entryIds[key] = id;
    final score = saved.score;
    _extras[key] = KitsuListExtras(
      twenty: score == null || score <= 0 ? null : (score * 2).round(),
      reaction: _extras[key]?.reaction,
    );
    return ListEditUpdated(applySync(entry, saved, _clock()));
  }

  /// Kitsu's own edit sheet (Kitsu wording, the account's rating system, rewatches, notes,
  /// private), its answer turned into the [SyncEntry] the list applies.
  static Future<SyncEntry?> _openEditor(
      BuildContext context, ListEntryView entry, SyncEntry initial) async {
    final result = await showKitsuEntrySheet(
      context,
      kind: entry.isAnime ? KitsuMediaKind.anime : KitsuMediaKind.manga,
      mediaId: '${entry.id}',
      title: entry.title,
      total: entry.total,
    );
    return switch (result) {
      null => null,
      KitsuEntryRemoved() => SyncEntry.removed,
      KitsuEntrySaved(entry: final saved) => syncOf(saved, isAnime: entry.isAnime),
    };
  }

  /// [entry] as the list's [SyncEntry] (score on 0-10, dates as `yyyy-mm-dd`).
  @visibleForTesting
  static SyncEntry syncOf(KitsuMyEntry entry, {required bool isAnime}) {
    String? day(DateTime? d) => d == null ? null : d.toIso8601String().substring(0, 10);
    return SyncEntry(
      status: entry.status.malValue(isAnime: isAnime),
      score: entry.isRated ? entry.rating! / 2 : null,
      progress: entry.progress,
      startDate: day(entry.startedAt),
      finishDate: day(entry.finishedAt),
      repeat: entry.reconsuming ? 1 : 0,
      notes: entry.notes,
      entryId: entry.id,
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

  /// The extras of [entry], its 0-10 score doubled when the page did not carry them.
  KitsuListExtras _extrasOf(ListEntryView entry) =>
      _extras['${entry.category}:${entry.id}'] ??
      KitsuListExtras(twenty: entry.score > 0 ? entry.score * 2 : null);

  /// The exact rating of [entry] as the list last saw it (`ratingTwenty`), null when unrated.
  @visibleForTesting
  int? ratingTwentyOf(ListEntryView entry) => _extrasOf(entry).twenty;

  /// Kitsu's short words for the grid chip ("Watching", "Want to read"…), not MyAnimeList's codes.
  @override
  String statusShortLabel(ListEntryStatus status, {required bool isAnime}) =>
      kitsuStatusShortLabel(status, isAnime: isAnime);

  /// Kitsu's words: "Currently watching", "Want to watch"…
  @override
  String statusLabel(ListEntryStatus status, {required bool isAnime}) =>
      kitsuStatusLabel(status, isAnime: isAnime);

  /// The user's rating in the account's system: a face and its word (Simple), stars out of 5
  /// (Regular) or points out of 10 (Advanced).
  @override
  ListScoreText? userScore(ListEntryView entry) {
    final twenty = _extrasOf(entry).twenty;
    if (twenty == null || twenty <= 0) return null;
    final system = _ratingSystem();
    return ListScoreText(
      KitsuRating.text(twenty, system),
      icon: switch (system) {
        KitsuRatingSystem.simple => KitsuRating.simpleIcon(KitsuRating.simpleIndex(twenty)),
        KitsuRatingSystem.regular => Icons.star_rounded,
        KitsuRatingSystem.advanced => null,
      },
      spoken: KitsuRating.spoken(twenty, system),
    );
  }

  /// The community score as Kitsu writes it: a percentage ("88%"), no star.
  @override
  ListScoreText? meanScore(ListEntryView entry) {
    final mean = entry.meanScore;
    if (mean == null || mean <= 0) return null;
    final percent = NumberFormat.percentPattern(Intl.getCurrentLocale()).format(mean / 10);
    return ListScoreText(percent,
        icon: Icons.favorite_rounded, spoken: S.current.Tlh_Community_Approval(percent));
  }

  /// The user's reaction to the title (Kitsu's 140-character review).
  @override
  List<ListCardBadge> cardBadges(ListEntryView entry) {
    final reaction = _extras['${entry.category}:${entry.id}']?.reaction;
    if (reaction == null) return const [];
    return [
      ListCardBadge(
        icon: Icons.chat_bubble_rounded,
        label: reaction,
        detail: S.current.Tlh_Your_Reaction(reaction),
      ),
    ];
  }

  /// After the +1 that completes an unrated title, asks for the rating in the account's system,
  /// as Kitsu does, and writes it only when the viewer picks one.
  @override
  Future<ListEntryView?> afterStep(BuildContext context, ListEntryView saved,
      {required ListEntryView before}) async {
    final completed =
        saved.status == ListEntryStatus.completed && before.status != ListEntryStatus.completed;
    if (!completed || (_extrasOf(saved).twenty ?? 0) > 0) return null;
    final picked = await _askRating(context, saved);
    if (picked == null || picked <= 0) return null;
    try {
      final id = await _entryIdOf(saved);
      if (id == null) throw const KitsuHttpError(404);
      await _library.update(id, {'ratingTwenty': picked});
    } catch (e) {
      debugPrint('KitsuUserListAdapter.afterStep failed (${e.runtimeType})');
      if (context.mounted) kitsuWriteFailed(context);
      return null;
    }
    final key = '${saved.category}:${saved.id}';
    _extras[key] = KitsuListExtras(twenty: picked, reaction: _extras[key]?.reaction);
    return saved.copyWith(score: KitsuLibrary.scoreOfTwenty(picked), updatedAt: _clock());
  }

  static Future<int?> _showRatingSheet(BuildContext context, ListEntryView entry) =>
      showKitsuRatingSheet(context, title: S.current.Kr_Completed_Rate);

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

/// A list status in the few letters of the grid card's chip, in Kitsu's own words.
String kitsuStatusShortLabel(ListEntryStatus status, {required bool isAnime}) {
  final s = S.current;
  return switch (status) {
    ListEntryStatus.current => isAnime ? s.Kpl_Short_Watching : s.Kpl_Short_Reading,
    ListEntryStatus.planned => s.Kpl_Short_Planned,
    ListEntryStatus.completed => s.Kpl_Short_Completed,
    ListEntryStatus.onHold => s.Kpl_Short_On_Hold,
    ListEntryStatus.dropped => s.Kpl_Short_Dropped,
  };
}
