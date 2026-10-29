import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';
import 'package:mywatchlist/widgets/user/list/card_layout_editor.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/list_view_store.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart';

const double _timeLineHeight = 24;

/// Status tabs in display order; null = "All".
const List<ListEntryStatus?> userListTabs = [
  null,
  ListEntryStatus.current,
  ListEntryStatus.completed,
  ListEntryStatus.onHold,
  ListEntryStatus.dropped,
  ListEntryStatus.planned,
];

/// The user's anime / manga list of one tracker (DailyAL user page, list
/// part): category switch, status tabs with counts, search in the list,
/// sort / filter / display sheet, grid and list layouts, custom cards, pull to
/// refresh, pagination and quick edit.
///
/// Tracker-agnostic: everything tracker-specific comes from [adapter]. The
/// page around it gives the app bar title through [titleBuilder], which
/// receives the category switch to place in it.
class UserListView extends StatefulWidget {
  final UserListAdapter adapter;
  final Widget Function(BuildContext context, Widget categorySwitch) titleBuilder;
  final ListViewStore store;
  final ListStatusCache? cache;

  /// The categories the tracker has, in switch order. With a single one (Simkl has no manga)
  /// the Anime/Manga switch is not built: [titleBuilder] receives an empty widget and the list
  /// always opens on that category, whatever the "default category" preference says.
  final List<String> categories;

  const UserListView({
    super.key,
    required this.adapter,
    required this.titleBuilder,
    this.store = const ListViewStore(),
    this.cache,
    this.categories = const ['anime', 'manga'],
  }) : assert(categories.length > 0);

  @override
  State<UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends State<UserListView> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: userListTabs.length, vsync: this);
  late final ListStatusCache _cache = widget.cache ?? ListStatusCache.instance;
  final Map<String, ListViewSettings> _settings = {};
  final Map<String, Map<ListEntryStatus?, UserListTabController>> _controllers = {};
  final Map<String, Map<ListEntryStatus, int>?> _counts = {};
  final Set<String> _countsAsked = {};
  final ValueNotifier<Set<int>> _busy = ValueNotifier(const {});
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searching = false;
  bool _ready = false;
  String _category = 'anime';
  ListPlace _place = const ListPlace();

  UserListAdapter get _adapter => widget.adapter;
  bool get _isAnime => _category == 'anime';

  /// Whether the header carries the "time left" line: anime lists of a tracker whose adapter
  /// fills `ListEntryView.episodeSeconds` (MyAnimeList's `average_episode_duration`).
  bool get _showsTime => _isAnime && _adapter.tracker == AccountType.myanimelist;
  ListViewSettings get _current => _settings[_category] ?? ListViewStore.defaults(_category);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    _init();
  }

  Future<void> _init() async {
    _cache.ensureLoaded();
    _cache.bindOwner(_adapter.tracker, _adapter.owner);
    final tracker = _adapter.tracker;
    final results = await Future.wait([
      widget.store.readView(tracker, 'anime'),
      widget.store.readView(tracker, 'manga'),
    ]);
    final place = await widget.store.readPlace(tracker);
    if (!mounted) return;
    final prefs = Preferences.list;
    _settings['anime'] = results[0];
    _settings['manga'] = results[1];
    _place = place;
    final wanted = switch (prefs.defaultCategory) {
      ListCategory.anime => 'anime',
      ListCategory.manga => 'manga',
      ListCategory.none => place.category,
    };
    _category = widget.categories.contains(wanted) ? wanted : widget.categories.first;
    _tabs.index = _initialTab(_category);
    setState(() => _ready = true);
    _loadCounts(_category);
  }

  /// Tab of [category] at opening: the preference when set, else the last one.
  int _initialTab(String category) {
    final prefs = Preferences.list;
    final forced = category == 'anime' ? prefs.defaultAnimeTab : prefs.defaultMangaTab;
    final value = forced != ListPreferences.noDefaultTab ? forced : _place.tabs[category];
    if (value == null || value == 'all') return 0;
    final status = ListEntryStatus.fromMal(value) ??
        ListEntryStatus.values.where((s) => s.name == value).firstOrNull;
    return status == null ? 0 : userListTabs.indexOf(status);
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final status = userListTabs[_tabs.index];
    _controllerFor(_category, status).activate();
    _place = _place.copyWith(tabCategory: _category, tab: status?.name ?? 'all');
    widget.store.writePlace(_adapter.tracker, _place);
  }

  UserListTabController _controllerFor(String category, ListEntryStatus? status) {
    final map = _controllers.putIfAbsent(category, () => {});
    return map.putIfAbsent(
      status,
      () => UserListTabController(
        adapter: _adapter,
        category: category,
        status: status,
        settings: _settings[category] ?? ListViewStore.defaults(category),
        query: _search.text,
        cache: _cache,
      ),
    );
  }

  Future<void> _loadCounts(String category) async {
    if (!_countsAsked.add(category)) return;
    final counts = await _adapter.statusCounts(category);
    if (!mounted) return;
    setState(() => _counts[category] = counts);
  }

  void _changeCategory(String category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      _tabs.index = _initialTabAfterSwitch(category);
    });
    _place = _place.copyWith(category: category);
    widget.store.writePlace(_adapter.tracker, _place);
    _loadCounts(category);
    _applyQuery();
  }

  int _initialTabAfterSwitch(String category) {
    final saved = _place.tabs[category];
    if (saved == null || saved == 'all') return 0;
    final status = ListEntryStatus.values.where((s) => s.name == saved).firstOrNull;
    return status == null ? 0 : userListTabs.indexOf(status);
  }

  void _applySettings(ListViewSettings value) {
    _settings[_category] = value;
    widget.store.writeView(_adapter.tracker, _category, value);
    final visible = userListTabs[_tabs.index];
    for (final entry in (_controllers[_category] ?? const {}).entries) {
      entry.value.updateSettings(value, visible: entry.key == visible);
    }
    setState(() {});
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _applyQuery);
  }

  void _applyQuery() {
    final visible = userListTabs[_tabs.index];
    for (final entry in (_controllers[_category] ?? const {}).entries) {
      entry.value.updateQuery(_search.text, visible: entry.key == visible);
    }
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (_searching) {
      _searchFocus.requestFocus();
    } else {
      _searchFocus.unfocus();
      if (_search.text.isNotEmpty) {
        _search.clear();
        _applyQuery();
      }
    }
  }

  void _clearFilters() {
    if (_search.text.isNotEmpty) {
      _search.clear();
      _applyQuery();
    }
    if (!_current.filter.isEmpty) _applySettings(_current.copyWith(filter: ListFilter.none));
  }

  Future<void> _openSheet(ListSortFilterTab tab) async {
    final visible = _controllerFor(_category, userListTabs[_tabs.index]);
    final result = await showListSortFilterSheet(
      context,
      settings: _current,
      initialTab: tab,
      options: ListSortFilterOptions(
        sorts: _adapter.sortOptions(_category),
        facets: facetsFor(visible.loaded, isAnime: _isAnime),
        cardProfiles: () => [
          for (final p in Preferences.list.cardProfiles)
            SelectOption(p.id, p.profileName.isEmpty ? S.current.UserList_Untitled_Card : p.profileName),
        ],
        onManageCards: (context) => openCardLayouts(context,
            sample: visible.entries.isEmpty ? null : visible.entries.first),
      ),
    );
    if (result != null && mounted && result != _current) _applySettings(result);
  }

  // Entry actions -----------------------------------------------------------

  late final EntryActions _actions = EntryActions(
    onOpen: (e) => _adapter.open(context, e),
    onEdit: _edit,
    onStep: _step,
    canStep: _adapter.canStep,
    busy: _busy,
  );

  Future<void> _edit(ListEntryView entry) async {
    final result = await _adapter.edit(context, entry);
    if (!mounted) return;
    switch (result) {
      case ListEditUpdated(entry: final saved):
        _applyChange(saved, old: entry);
      case ListEditRemoved():
        _removeEverywhere(entry);
      case ListEditUnchanged():
        break;
    }
  }

  Future<void> _step(ListEntryView entry, int delta) async {
    if (_busy.value.contains(entry.id)) return;
    _busy.value = {..._busy.value, entry.id};
    try {
      final saved = await _adapter.step(entry, delta);
      if (mounted) _applyChange(saved, old: entry);
    } catch (e) {
      if (!mounted) return;
      final expired = _adapter.isSessionExpired(e);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(expired ? S.current.UserList_Session_Expired : S.current.UserList_Update_Failed),
        action: expired
            ? SnackBarAction(
                label: S.current.UserList_Sign_In_Again,
                onPressed: () => _adapter.signInAgain(context))
            : null,
      ));
    } finally {
      _busy.value = {..._busy.value}..remove(entry.id);
    }
  }

  void _applyChange(ListEntryView entry, {ListEntryView? old}) {
    final category = entry.category;
    for (final c in (_controllers[category] ?? const {}).values) {
      c.applyChange(entry);
    }
    final status = entry.status;
    if (status != null) {
      _cache.put(
        entry.id,
        CachedListStatus(
            status: status.malValue(isAnime: entry.isAnime),
            score: entry.score,
            progress: entry.progress),
        category: category,
        tracker: _adapter.tracker,
      );
    }
    _moveCount(category, old?.status, status);
  }

  void _removeEverywhere(ListEntryView entry) {
    for (final c in (_controllers[entry.category] ?? const {}).values) {
      c.removeEntry(entry.id);
    }
    _cache.remove(entry.id, category: entry.category, tracker: _adapter.tracker);
    _moveCount(entry.category, entry.status, null);
  }

  void _moveCount(String category, ListEntryStatus? from, ListEntryStatus? to) {
    final counts = _counts[category];
    if (counts == null || from == to) return;
    final next = {...counts};
    if (from != null && (next[from] ?? 0) > 0) next[from] = next[from]! - 1;
    if (to != null) next[to] = (next[to] ?? 0) + 1;
    setState(() => _counts[category] = next);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _busy.dispose();
    for (final map in _controllers.values) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // Build -------------------------------------------------------------------

  EntryCardStyle _style(BuildContext context, {required bool showStatus}) {
    GeneralPreferences general;
    try {
      general = context.select((PreferencesBloc b) => b.state.general);
    } on ProviderNotFoundException {
      general = Preferences.general;
    }
    return EntryCardStyle.fromPreferences(general, showStatus: showStatus);
  }

  ContentCardProps? _cardProfile(BuildContext context, String? id) {
    if (id == null) return null;
    ListPreferences list;
    try {
      list = context.select((PreferencesBloc b) => b.state.list);
    } on ProviderNotFoundException {
      list = Preferences.list;
    }
    return list.cardProfile(id);
  }

  Widget _categorySwitch() {
    if (widget.categories.length < 2) return const SizedBox.shrink();
    return SegmentedButton<String>(
      segments: [
        for (final c in widget.categories)
          ButtonSegment(
            value: c,
            label: Text(c == 'anime' ? S.current.UserList_Anime : S.current.UserList_Manga),
          ),
      ],
      selected: {_category},
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelectionChanged: (s) => _changeCategory(s.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NestedScrollView(
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          automaticallyImplyLeading: false,
          pinned: true,
          floating: true,
          forceElevated: innerBoxIsScrolled,
          titleSpacing: 0,
          toolbarHeight: kToolbarHeight + 8,
          title: widget.titleBuilder(context, _categorySwitch()),
          // The home shell's sidebar is an end drawer: without a non-empty
          // actions list Flutter adds its own ☰ next to the header's avatar.
          actions: const [SizedBox.shrink()],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(46 + 48 + (_showsTime ? _timeLineHeight : 0)),
            child: _ready
                ? _header(theme)
                : SizedBox(height: 94 + (_showsTime ? _timeLineHeight : 0)),
          ),
        ),
      ],
      body: !_ready
          ? const SizedBox.shrink()
          : TabBarView(
              key: ValueKey('tabs-$_category'),
              controller: _tabs,
              children: [
                for (final status in userListTabs) _tab(context, status),
              ],
            ),
    );
  }

  Widget _tab(BuildContext context, ListEntryStatus? status) {
    final settings = _current;
    final display = settings.display;
    return UserListTab(
      key: PageStorageKey('tab-$_category-${status?.name ?? 'all'}'),
      controller: _controllerFor(_category, status),
      adapter: _adapter,
      display: display,
      cardProfile: display.subType == DisplaySubType.custom
          ? _cardProfile(context, display.cardProfileId)
          : null,
      actions: _actions,
      style: _style(context, showStatus: status == null),
      onClearFilters: _clearFilters,
    );
  }

  Widget _header(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final status in userListTabs) Tab(child: _TabLabel(
                key: ValueKey('label-$_category-${status?.name ?? 'all'}'),
                controller: _controllerFor(_category, status),
                label: status?.label(isAnime: _isAnime) ?? S.current.UserList_All,
                countFromProfile: _profileCount(status),
              )),
            ],
          ),
        ),
        SizedBox(height: 48, child: _toolbar(theme)),
        if (_showsTime)
          SizedBox(
            height: _timeLineHeight,
            child: _TimeLine(
              tabs: _tabs,
              controllerOf: (status) => _controllerFor(_category, status),
            ),
          ),
      ],
    );
  }

  int? _profileCount(ListEntryStatus? status) {
    final counts = _counts[_category];
    if (counts == null) return null;
    if (status == null) return counts.values.fold<int>(0, (a, b) => a + b);
    return counts[status];
  }

  Widget _toolbar(ThemeData theme) {
    final settings = _current;
    final sort = _adapter
        .sortOptions(_category)
        .where((o) => o.key == settings.sortKey)
        .firstOrNull;
    final filterCount = settings.filter.activeCount;
    final asc = settings.direction == SortDirection.ascending;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: _searching ? S.current.UserList_Close_Search : S.current.UserList_Search_In_List,
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: _toggleSearch,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: const Cubic(0.23, 1, 0.32, 1),
              child: _searching
                  ? TextField(
                      key: const ValueKey('search'),
                      controller: _search,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: S.current.UserList_Search_Hint,
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    )
                  : Align(
                      key: const ValueKey('sort'),
                      alignment: AlignmentDirectional.centerStart,
                      child: ActionChip(
                        avatar: Icon(asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 16),
                        label: Text(sort?.label ?? S.current.UserList_Sort,
                            overflow: TextOverflow.ellipsis),
                        tooltip: S.current.UserList_Sort,
                        onPressed: () => _openSheet(ListSortFilterTab.sort),
                      ),
                    ),
            ),
          ),
          IconButton(
            tooltip: S.current.UserList_Filter,
            onPressed: () => _openSheet(ListSortFilterTab.filter),
            icon: Badge(
              isLabelVisible: filterCount > 0,
              label: Text('$filterCount'),
              child: Icon(filterCount > 0 ? Icons.filter_alt_rounded : Icons.filter_alt_outlined),
            ),
          ),
          IconButton(
            tooltip: S.current.UserList_Display,
            onPressed: () => _openSheet(ListSortFilterTab.display),
            icon: Icon(settings.display.isGrid ? Icons.grid_view_rounded : Icons.view_agenda_outlined),
          ),
        ],
      ),
    );
  }
}

/// "Watching · 12": follows its tab's controller for the exact count.
class _TabLabel extends StatelessWidget {
  final UserListTabController controller;
  final String label;
  final int? countFromProfile;

  const _TabLabel({
    super.key,
    required this.controller,
    required this.label,
    required this.countFromProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final filtered =
            !controller.settings.filter.isEmpty || controller.query.trim().isNotEmpty;
        final int? count = filtered
            ? (controller.hasMore || !controller.isStarted ? null : controller.entries.length)
            : (controller.totalCount ?? countFromProfile);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count != null) ...[
              const SizedBox(width: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  child: Text('$count', style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// "Time left: 41 d 3 h" under the toolbar: follows the visible tab and its controller.
class _TimeLine extends StatelessWidget {
  final TabController tabs;
  final UserListTabController Function(ListEntryStatus? status) controllerOf;

  const _TimeLine({required this.tabs, required this.controllerOf});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabs,
      builder: (context, _) {
        final status = userListTabs[tabs.index];
        return ListenableBuilder(
          listenable: controllerOf(status),
          builder: (context, _) {
            final c = controllerOf(status);
            final summary = c.isStarted
                ? ListTimeSummary.of(c.entries, status, partial: c.hasMore)
                : null;
            if (summary == null) return const SizedBox.shrink();
            final theme = Theme.of(context);
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 16),
                child: Text(
                  summary.label(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
