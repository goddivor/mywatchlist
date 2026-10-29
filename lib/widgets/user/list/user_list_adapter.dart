import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// One page of a user list.
class ListPage {
  final List<ListEntryView> entries;

  /// True when the tracker has more entries after this page.
  final bool hasMore;

  const ListPage(this.entries, {required this.hasMore});
}

/// Outcome of the edit sheet for one entry.
sealed class ListEditResult {
  const ListEditResult();
}

/// Nothing was saved.
class ListEditUnchanged extends ListEditResult {
  const ListEditUnchanged();
}

/// The entry was saved; [entry] is its new state.
class ListEditUpdated extends ListEditResult {
  final ListEntryView entry;
  const ListEditUpdated(this.entry);
}

/// The entry was removed from the list.
class ListEditRemoved extends ListEditResult {
  const ListEditRemoved();
}

/// Everything the tracker-agnostic list widgets need from one tracker.
///
/// `MalUserListAdapter` is the MyAnimeList one; the AniList, Kitsu and Simkl
/// user list units implement the same class and reuse `UserListView`.
abstract class UserListAdapter {
  const UserListAdapter();

  AccountType get tracker;

  /// Signed-in username, used to bind the status cache to the account.
  String? get owner;

  /// Largest page [fetch] accepts.
  int get maxPageSize;

  /// Sort options of [category] (`anime` | `manga`), first = default.
  List<ListSortOption> sortOptions(String category);

  /// The tracker's own sort for [sortKey] in [direction], or null when the
  /// list must be loaded whole and sorted on the device.
  String? apiSort(String category, String sortKey, SortDirection direction);

  /// One page of the user's [category] list, [status] null = every status,
  /// sorted by [apiSort] (null = the tracker's default order).
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  });

  /// Entries per status as the tracker's profile counts them, or null when
  /// unknown (the tabs then show the loaded counts).
  Future<Map<ListEntryStatus, int>?> statusCounts(String category);

  /// Opens the detail page of [entry].
  void open(BuildContext context, ListEntryView entry);

  /// Opens the edit sheet of [entry] and reports what was saved.
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry);

  /// Whether this tracker's entries carry the episode length
  /// ([ListEntryView.episodeSeconds]), so the anime list shows its "time left / watched" line.
  ///
  /// Each adapter declares its own value. Until the MyAnimeList adapter overrides it, the
  /// default keeps the line MyAnimeList already had; other adapters opt in.
  bool get fillsEpisodeLength => tracker == AccountType.myanimelist;

  /// Whether the quick +1 / -1 buttons can change [entry].
  bool canStep(ListEntryView entry) => false;

  /// Adds [delta] episodes (chapters) to [entry] and returns the saved entry.
  /// Reaching the total completes it, as the edit sheet does.
  Future<ListEntryView> step(ListEntryView entry, int delta) =>
      throw UnsupportedError('step');

  /// True when [error] means the session is dead (show "sign in again").
  bool isSessionExpired(Object error) => false;

  /// Restarts the sign-in flow after [isSessionExpired].
  Future<void> signInAgain(BuildContext context);
}
