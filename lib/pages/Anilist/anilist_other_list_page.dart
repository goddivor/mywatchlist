import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/profile/other_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart' show anilistErrorText;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_look.dart' show ListEntryLookScope;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/list_view_store.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart'
    show listGridDelegate, listGridPadding;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

const List<ListEntryStatus?> _statuses = [
  null,
  ListEntryStatus.current,
  ListEntryStatus.completed,
  ListEntryStatus.onHold,
  ListEntryStatus.dropped,
  ListEntryStatus.planned,
];

/// Another AniList user's anime and manga list, read only: the same cards as My List, sort,
/// filter and display from the shared sheet, and "Compare with mine" (your score or "Not on
/// your list" on every card, narrowing to the titles you share or only they have). A card
/// opens the AniList title; nothing here writes to either list.
class AnilistOtherListPage extends StatefulWidget {
  final String username;
  final String initialCategory;

  /// Replaces the list source (tests).
  final AnilistOtherListSource? source;

  const AnilistOtherListPage({
    super.key,
    required this.username,
    this.initialCategory = 'anime',
    this.source,
  });

  @override
  State<AnilistOtherListPage> createState() => _AnilistOtherListPageState();
}

class _AnilistOtherListPageState extends State<AnilistOtherListPage> {
  late final AnilistOtherListSource _source =
      widget.source ?? AnilistOtherListSource(username: widget.username);
  late final AnilistReadOnlyListAdapter _adapter = AnilistReadOnlyListAdapter(source: _source);
  final ListStatusCache _cache = _DiscardingStatusCache();
  final Map<String, UserListTabController> _controllers = {};
  final Map<String, ListViewSettings> _settings = {};
  final ValueNotifier<Set<int>> _busy = ValueNotifier(const {});
  late final EntryActions _actions = EntryActions(
    onOpen: (e) => _adapter.open(context, e),
    onEdit: null,
    onStep: null,
    canStep: (_) => false,
    busy: _busy,
  );

  late String _category = widget.initialCategory == 'manga' ? 'manga' : 'anime';
  ListEntryStatus? _status;
  bool _compare = false;
  Map<int, AnilistMine> _mine = const {};
  Object? _compareError;

  bool get _isAnime => _category == 'anime';

  @override
  void initState() {
    super.initState();
    _readDisplays();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _current.activate();
    });
  }

  /// The cards look like the viewer's own My List (display read, never written).
  Future<void> _readDisplays() async {
    const store = ListViewStore();
    for (final category in const ['anime', 'manga']) {
      final saved = await store.readView(AccountType.anilist, category);
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
    if (_compare) _loadMine();
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

  Future<void> _loadMine() async {
    final category = _category;
    try {
      final mine = await _source.mine(category);
      if (!mounted) return;
      setState(() {
        _mine = {..._mine, ...mine};
        _compareError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _compareError = e);
    }
  }

  void _toggleCompare() {
    setState(() => _compare = !_compare);
    if (_compare) {
      _loadMine();
    } else {
      _setFilter(AnilistCompareFilter.all);
    }
  }

  void _setFilter(AnilistCompareFilter filter) {
    if (_adapter.compareFilter == filter) return;
    _adapter.compareFilter = filter;
    // The tabs hold what the old filter let through: start them again. The old controllers
    // are still listened to by this frame's builder, so they go once it is rebuilt.
    final old = _controllers.values.toList();
    _controllers.clear();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in old) {
        c.dispose();
      }
    });
    _current.activate();
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
    final s = S.of(context);
    final controller = _current;
    final signedIn = _source.signedIn;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.Alpp_List_Of(widget.username)),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: s.Alpp_Compare,
              isSelected: _compare,
              icon: const Icon(Icons.compare_arrows),
              selectedIcon: const Icon(Icons.compare_arrows, fill: 1),
              onPressed: _toggleCompare,
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListEntryLookScope(
          look: _compare ? AnilistCompareLook(_mine, base: _adapter) : _adapter,
          child: CustomScrollView(
            key: PageStorageKey<String>('al_other_${widget.username}_$_category'),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(
                  height: _headerHeight,
                  color: Theme.of(context).colorScheme.surface,
                  child: _header(context),
                ),
              ),
              ..._body(context, controller),
            ],
          ),
        ),
      ),
    );
  }

  double get _headerHeight => 52 + 48 + (_compare ? 48 : 0);

  Widget _header(BuildContext context) {
    final s = S.of(context);
    final settings = _settingsOf(_category);
    final filterCount = settings.filter.activeCount;
    return Column(
      children: [
        SizedBox(
          height: 52,
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
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _statuses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final status = _statuses[i];
              final controller = _controllers['$_category:${status?.name ?? 'all'}'];
              final count = controller?.totalCount;
              final label = status?.label(isAnime: _isAnime) ?? s.UserList_All;
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
        if (_compare)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final (filter, label) in [
                  (AnilistCompareFilter.all, s.Alpp_Compare_All),
                  (AnilistCompareFilter.onMine, s.Alpp_Compare_On_Mine),
                  (AnilistCompareFilter.notOnMine, s.Alpp_Compare_Not_On_Mine),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _adapter.compareFilter == filter,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _setFilter(filter),
                    ),
                  ),
              ],
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
      if (error != null) {
        return [
          fill(ProfileMessage(
            icon: Icons.cloud_off_outlined,
            title: anilistErrorText(error),
            actionLabel: s.Prof_Retry,
            onAction: c.refresh,
          )),
        ];
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
      if (_compareError != null)
        SliverToBoxAdapter(
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: Text(anilistErrorText(_compareError!)),
            trailing: TextButton(onPressed: _loadMine, child: Text(s.Prof_Retry)),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 4)),
      list,
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  final Color color;

  const _HeaderDelegate({required this.height, required this.child, required this.color});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: child);

  @override
  bool shouldRebuild(_HeaderDelegate old) => true;
}

/// A status cache that keeps nothing: another user's statuses must never replace the
/// signed-in user's badges.
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
