import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/list_view_store.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart'
    show listGridDelegate, listGridPadding;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// Status filters of the List tab, "All" first (DailyAL's order).
const List<ListEntryStatus?> _statuses = [
  null,
  ListEntryStatus.current,
  ListEntryStatus.completed,
  ListEntryStatus.onHold,
  ListEntryStatus.dropped,
  ListEntryStatus.planned,
];

/// Another MyAnimeList user's anime and manga list (DailyAL's "List" tab of a profile): an
/// Anime / Manga switch and the status chips pinned over the cards, sort, filter and
/// display through the shared sheet. Read only: a card opens the title, nothing edits
/// [username]'s list. Their statuses never reach the signed-in user's status cache, and
/// the sort or display chosen here is not saved over the user's own My List settings.
class ListSection extends StatefulWidget {
  final String username;

  /// The profile's numbers, used for the counts of the chips.
  final ListStats anime;
  final ListStats manga;

  /// Overrides for tests.
  final MalUserListAdapter? adapter;

  const ListSection({
    super.key,
    required this.username,
    required this.anime,
    required this.manga,
    this.adapter,
  });

  @override
  State<ListSection> createState() => _ListSectionState();
}

class _ListSectionState extends State<ListSection> with AutomaticKeepAliveClientMixin {
  late final MalUserListAdapter _adapter =
      widget.adapter ?? MalUserListAdapter(username: widget.username);
  final ListStatusCache _cache = _DiscardingStatusCache();
  final Map<String, UserListTabController> _controllers = {};
  final Map<String, ListViewSettings> _settings = {};
  final ValueNotifier<Set<int>> _busy = ValueNotifier(const {});
  late final EntryActions _actions = EntryActions(
    onOpen: (e) => AppRoutes.openContent(context, id: e.id, category: e.category),
    onEdit: null,
    onStep: null,
    canStep: (_) => false,
    busy: _busy,
  );

  String _category = 'anime';
  ListEntryStatus? _status;

  bool get _isAnime => _category == 'anime';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _readDisplays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _current.activate();
    });
  }

  /// The cards look like the user's own My List (display read, never written).
  Future<void> _readDisplays() async {
    const store = ListViewStore();
    for (final category in const ['anime', 'manga']) {
      final saved = await store.readView(AccountType.myanimelist, category);
      if (!mounted) return;
      final display = saved.display.subType == DisplaySubType.custom
          ? saved.display.copyWith(subType: DisplaySubType.comfortable)
          : saved.display;
      _apply(category, _settingsOf(category).copyWith(display: display));
    }
  }

  ListViewSettings _settingsOf(String category) =>
      _settings[category] ?? ListViewStore.defaults(category);

  UserListTabController _controllerFor(String category, ListEntryStatus? status) {
    return _controllers.putIfAbsent(
      '$category:${status?.name ?? 'all'}',
      () => UserListTabController(
        adapter: _adapter,
        category: category,
        status: status,
        settings: _settingsOf(category),
        cache: _cache,
      ),
    );
  }

  UserListTabController get _current => _controllerFor(_category, _status);

  void _select({String? category, ListEntryStatus? status, bool changeStatus = false}) {
    setState(() {
      if (category != null) _category = category;
      if (changeStatus) _status = status;
    });
    _current.activate();
  }

  void _apply(String category, ListViewSettings value) {
    _settings[category] = value;
    final visible = _controllerFor(_category, _status);
    for (final entry in _controllers.entries) {
      if (entry.key.startsWith('$category:')) {
        entry.value.updateSettings(value, visible: identical(entry.value, visible));
      }
    }
    setState(() {});
  }

  Future<void> _openSheet(ListSortFilterTab tab) async {
    final settings = _settingsOf(_category);
    final result = await showListSortFilterSheet(
      context,
      settings: settings,
      initialTab: tab,
      options: ListSortFilterOptions(
        sorts: _adapter.sortOptions(_category),
        facets: facetsFor(_current.loaded, isAnime: _isAnime),
      ),
    );
    if (result != null && mounted && result != settings) _apply(_category, result);
  }

  int? _count(ListEntryStatus? status) {
    final settings = _settingsOf(_category);
    final controller = _controllers['$_category:${status?.name ?? 'all'}'];
    if (!settings.filter.isEmpty) {
      if (controller == null || !controller.isStarted || controller.hasMore) return null;
      return controller.entries.length;
    }
    final known = controller?.totalCount;
    if (known != null) return known;
    final stats = _isAnime ? widget.anime : widget.manga;
    if (stats.isEmpty) return null;
    final counts = MalUserListAdapter.countsOf(stats);
    return status == null ? counts.values.fold<int>(0, (a, b) => a + b) : counts[status];
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _busy.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _current;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ProfileTabScroll(
        storageKey: 'list_${widget.username}_$_category',
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderDelegate(
              child: _header(context),
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
          ..._body(context, controller),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final s = S.of(context);
    final settings = _settingsOf(_category);
    final filterCount = settings.filter.activeCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _HeaderDelegate.rowHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            child: Row(
              children: [
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'anime', label: Text(s.UserList_Anime)),
                    ButtonSegment(value: 'manga', label: Text(s.UserList_Manga)),
                  ],
                  selected: {_category},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onSelectionChanged: (v) => _select(category: v.first),
                ),
                const Spacer(),
                IconButton(
                  tooltip: s.UserList_Sort,
                  icon: Icon(settings.direction == SortDirection.ascending
                      ? Icons.arrow_upward_rounded
                      : Icons.sort_rounded),
                  onPressed: () => _openSheet(ListSortFilterTab.sort),
                ),
                IconButton(
                  tooltip: s.UserList_Filter,
                  onPressed: () => _openSheet(ListSortFilterTab.filter),
                  icon: Badge(
                    isLabelVisible: filterCount > 0,
                    label: Text('$filterCount'),
                    child: Icon(filterCount > 0
                        ? Icons.filter_alt_rounded
                        : Icons.filter_alt_outlined),
                  ),
                ),
                IconButton(
                  tooltip: s.UserList_Display,
                  onPressed: () => _openSheet(ListSortFilterTab.display),
                  icon: Icon(settings.display.isGrid
                      ? Icons.grid_view_rounded
                      : Icons.view_agenda_outlined),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: _HeaderDelegate.chipsHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _statuses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final status = _statuses[i];
              final label = status?.label(isAnime: _isAnime) ?? s.UserList_All;
              final count = _count(status);
              return ChoiceChip(
                label: Text(count == null ? label : s.Pl_Count_Label(label, count)),
                selected: status == _status,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => _select(status: status, changeStatus: true),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _body(BuildContext context, UserListTabController c) {
    final s = S.of(context);
    final entries = c.entries;
    Widget fill(Widget child) => SliverFillRemaining(hasScrollBody: false, child: child);
    if (entries.isEmpty) {
      final error = c.error;
      final filtered = !c.settings.filter.isEmpty;
      if (!c.isStarted || c.isLoading || (filtered && c.hasMore && error == null)) {
        return [fill(ProfileLoading(label: s.Prof_Loading))];
      }
      if (error is MalListError && error.statusCode == 403) {
        return [fill(ProfileMessage(icon: Icons.lock_outline, title: s.Pl_List_Private))];
      }
      if (error != null) {
        return [fill(ProfileErrorView(error: error, onRetry: c.refresh))];
      }
      if (filtered) {
        return [
          fill(ProfileMessage(
            icon: Icons.filter_alt_off_outlined,
            title: s.UserList_No_Match,
            actionLabel: s.UserList_Clear_Filters,
            onAction: () =>
                _apply(_category, _settingsOf(_category).copyWith(filter: ListFilter.none)),
          )),
        ];
      }
      return [fill(ProfileMessage(icon: Icons.inbox_outlined, title: s.Pl_List_Empty))];
    }

    final now = DateTime.now();
    final display = c.settings.display;
    final style = EntryCardStyle.fromPreferences(Preferences.general, showStatus: _status == null);
    final Widget list;
    if (display.isGrid) {
      list = SliverPadding(
        padding: listGridPadding(display.subType, top: 4),
        sliver: SliverGrid.builder(
          gridDelegate: listGridDelegate(display),
          itemCount: entries.length,
          itemBuilder: (context, i) => EntryGridCard(
            key: ValueKey(entries[i].id),
            entry: entries[i],
            subType: display.subType,
            actions: _actions,
            style: style,
            now: now,
          ),
        ),
      );
    } else {
      final subType =
          display.subType == DisplaySubType.custom ? DisplaySubType.comfortable : display.subType;
      final locale = Localizations.localeOf(context).toString();
      list = SliverFixedExtentList.builder(
        itemExtent: listRowExtent(subType),
        itemCount: entries.length,
        itemBuilder: (context, i) => EntryListTile(
          key: ValueKey(entries[i].id),
          entry: entries[i],
          subType: subType,
          actions: _actions,
          style: style,
          now: now,
          locale: locale,
        ),
      );
    }
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 4)),
      list,
      SliverToBoxAdapter(child: _Footer(controller: c)),
    ];
  }
}

/// The Anime / Manga switch, the sort, filter and display buttons, then the status chips.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double rowHeight = 52;
  static const double chipsHeight = 48;

  final Widget child;
  final Color color;

  const _HeaderDelegate({required this.child, required this.color});

  @override
  double get minExtent => rowHeight + chipsHeight;

  @override
  double get maxExtent => rowHeight + chipsHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: child);

  @override
  bool shouldRebuild(_HeaderDelegate oldDelegate) => true;
}

/// End of the list: asks the next page when it nears the viewport, spinner meanwhile, retry
/// after an error.
class _Footer extends StatelessWidget {
  final UserListTabController controller;

  const _Footer({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: TextButton.icon(
            onPressed: c.loadMore,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(S.of(context).UserList_Load_More_Failed),
          ),
        ),
      );
    }
    if (c.hasMore) {
      if (c.isPaged && !c.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => c.loadMore());
      }
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// A status cache that keeps nothing: another user's statuses must never replace the
/// signed-in user's badges (nor be written to disk under their tracker).
class _DiscardingStatusCache extends ListStatusCache {
  @override
  void putAll(Map<int, CachedListStatus> values,
      {String category = 'anime', AccountType tracker = AccountType.myanimelist}) {}

  @override
  void replaceStatuses(Map<int, CachedListStatus> values,
      {required Set<String>? statuses,
      String category = 'anime',
      AccountType tracker = AccountType.myanimelist}) {}
}
