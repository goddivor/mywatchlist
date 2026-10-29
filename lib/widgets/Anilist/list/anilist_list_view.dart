import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_bulk_edit.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_sections.dart';
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

/// The signed-in user's AniList list as anilist.co draws it: All, then the account's
/// sections in its own order (Watching, Rewatching, Completed or Completed split by format,
/// Paused, Dropped, Planning, custom lists), with the shared list cards, sort / filter /
/// display sheet, search, pull to refresh, quick +1 and the AniList editor; a select action
/// edits several entries at once.
///
/// Built from the shared list pieces (`UserListTab`, `UserListTabController`, the sort sheet,
/// `ListViewStore`); the sections come from the list itself, so the tabs appear once it is
/// loaded.
class AnilistListView extends StatefulWidget {
  final AnilistUserListAdapter adapter;
  final Widget Function(BuildContext context, Widget categorySwitch) titleBuilder;
  final ListViewStore store;
  final ListStatusCache? cache;

  const AnilistListView({
    super.key,
    required this.adapter,
    required this.titleBuilder,
    this.store = const ListViewStore(),
    this.cache,
  });

  @override
  State<AnilistListView> createState() => _AnilistListViewState();
}

class _AnilistListViewState extends State<AnilistListView> with TickerProviderStateMixin {
  static const _categories = ['anime', 'manga'];

  late final ListStatusCache _cache = widget.cache ?? ListStatusCache.instance;
  final Map<String, ListViewSettings> _settings = {};
  final Map<String, List<AnilistSection>> _sections = {};
  final Map<String, Map<AnilistSection, int>> _counts = {};
  final Map<String, Map<String, _SectionTab>> _tabsOf = {};
  final Map<String, Object> _loadErrors = {};
  final ValueNotifier<Set<int>> _busy = ValueNotifier(const {});
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  TabController? _tabs;
  Timer? _searchDebounce;
  bool _searching = false;
  bool _ready = false;
  String _category = 'anime';
  ListPlace _place = const ListPlace();

  AnilistUserListAdapter get _adapter => widget.adapter;
  AnilistListService get _lists => _adapter.lists;
  bool get _isAnime => _category == 'anime';
  ListViewSettings get _current => _settings[_category] ?? ListViewStore.defaults(_category);
  List<AnilistSection> get _currentSections => _sections[_category] ?? const [];
  AnilistSection? get _visibleSection {
    final tabs = _tabs;
    final sections = _currentSections;
    if (tabs == null || tabs.index >= sections.length) return null;
    return sections[tabs.index];
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _cache.ensureLoaded();
    _cache.bindOwner(AccountType.anilist, _adapter.owner);
    final results = await Future.wait([
      widget.store.readView(AccountType.anilist, 'anime'),
      widget.store.readView(AccountType.anilist, 'manga'),
    ]);
    final place = await widget.store.readPlace(AccountType.anilist);
    if (!mounted) return;
    _settings['anime'] = results[0];
    _settings['manga'] = results[1];
    _place = place;
    _category = switch (Preferences.list.defaultCategory) {
      ListCategory.anime => 'anime',
      ListCategory.manga => 'manga',
      ListCategory.none => place.category,
    };
    setState(() => _ready = true);
    _loadSections(_category);
  }

  // Sections ------------------------------------------------------------------

  /// Loads the category's list (kept a minute by the service) and builds its tabs.
  Future<void> _loadSections(String category, {bool force = false}) async {
    setState(() => _loadErrors.remove(category));
    try {
      await _lists.all(category, force: force);
      if (!mounted) return;
      _rebuildSections(category);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadErrors[category] = e);
    }
  }

  /// Rows of [category] as last loaded (the service's kept list).
  final Map<String, List<ListEntryView>> _keptRows = {};

  Iterable<AnilistListEntry> _details(String category) sync* {
    for (final e in _keptRows[category] ?? const <ListEntryView>[]) {
      final d = _lists.detailOf(category, e.id);
      if (d != null) yield d;
    }
  }

  /// Rebuilds the tabs of [category] from the kept list (after a load, an edit, a +1); never
  /// asks AniList.
  void _rebuildSections(String category) {
    final kept = _lists.keptEntries(category);
    if (kept == null || !mounted) return;
    _keptRows[category] = kept;
    final options = _lists.optionsOf(category) ?? const AnilistListOptions();
    final details = _details(category).toList();
    final sections = anilistSections(options, details, isAnime: category == 'anime');
    final counts = anilistSectionCounts(sections, details);
    final old = _sections[category];
    final changed = old == null ||
        old.length != sections.length ||
        [for (var i = 0; i < old.length; i++) old[i] != sections[i]].any((x) => x);
    // The tab on screen, read before the sections change under its index.
    final keep = category == _category ? _visibleSection : null;
    setState(() {
      _sections[category] = sections;
      _counts[category] = counts;
      if (changed && category == _category) _resetTabs(keep: keep);
    });
  }

  void _resetTabs({AnilistSection? keep}) {
    final sections = _currentSections;
    final old = _tabs;
    old?.removeListener(_onTabChanged);
    var index = keep == null ? _initialIndex(sections) : sections.indexOf(keep);
    if (index < 0) index = 0;
    final next = TabController(length: sections.length, vsync: this, initialIndex: index);
    next.addListener(_onTabChanged);
    _tabs = next;
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  /// Tab at opening: the default tab preference when set, else the last one opened.
  int _initialIndex(List<AnilistSection> sections) {
    final prefs = Preferences.list;
    final forced = _isAnime ? prefs.defaultAnimeTab : prefs.defaultMangaTab;
    if (forced != ListPreferences.noDefaultTab) {
      if (forced == 'all') return 0;
      final status = ListEntryStatus.fromMal(forced) ??
          ListEntryStatus.values.where((s) => s.name == forced).firstOrNull;
      final i = sections.indexWhere((s) => s.isStatus && s.listStatus == status);
      if (i >= 0) return i;
    }
    final saved = _place.tabs[_category];
    final i = sections.indexWhere((s) => s.key == saved);
    return i < 0 ? 0 : i;
  }

  void _onTabChanged() {
    final tabs = _tabs;
    if (tabs == null || tabs.indexIsChanging) return;
    final section = _visibleSection;
    if (section == null) return;
    _tabFor(_category, section).controller.activate();
    _place = _place.copyWith(tabCategory: _category, tab: section.key);
    widget.store.writePlace(AccountType.anilist, _place);
    setState(() {});
  }

  _SectionTab _tabFor(String category, AnilistSection section) {
    final map = _tabsOf.putIfAbsent(category, () => {});
    return map.putIfAbsent(section.key, () {
      final adapter = _SectionAdapter(
        base: _adapter,
        section: section,
        settings: () => _settings[category] ?? ListViewStore.defaults(category),
        onLoaded: () => _onSectionLoaded(category, section),
      );
      final controller = UserListTabController(
        adapter: adapter,
        category: category,
        status: null,
        settings: _settings[category] ?? ListViewStore.defaults(category),
        query: _search.text,
        cache: _cache,
      );
      return _SectionTab(adapter, controller);
    });
  }

  /// A section answered: the tabs follow the list and the status cache gets the whole list
  /// back (a section writes only its own rows, which would drop the others).
  void _onSectionLoaded(String category, AnilistSection section) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rebuildSections(category);
      _restoreCache(category);
    });
  }

  void _restoreCache(String category) {
    final rows = _keptRows[category];
    if (rows == null) return;
    _cache.replaceStatuses(
      {
        for (final e in rows)
          if (e.status != null)
            e.id: CachedListStatus(
                status: e.status!.malValue(isAnime: e.isAnime),
                score: e.score,
                progress: e.progress),
      },
      statuses: null,
      category: category,
      tracker: AccountType.anilist,
    );
  }

  // Category, settings, search -----------------------------------------------

  void _changeCategory(String category) {
    if (category == _category) return;
    setState(() {
      _category = category;
      if (_sections[category] != null) _resetTabs();
    });
    _place = _place.copyWith(category: category);
    widget.store.writePlace(AccountType.anilist, _place);
    if (_sections[category] == null) _loadSections(category);
    _applyQuery();
  }

  void _applySettings(ListViewSettings value) {
    final old = _current;
    _settings[_category] = value;
    widget.store.writeView(AccountType.anilist, _category, value);
    final visible = _visibleSection?.key;
    // An AniList sort is applied by the sections themselves: they sort again from memory.
    final resort = old.sortKey != value.sortKey || old.direction != value.direction
        ? AnilistSortKeys.all.contains(old.sortKey) || AnilistSortKeys.all.contains(value.sortKey)
        : false;
    for (final entry in (_tabsOf[_category] ?? const <String, _SectionTab>{}).entries) {
      entry.value.controller.updateSettings(value, visible: entry.key == visible);
      if (resort && entry.value.controller.isStarted) {
        entry.value.adapter.resortOnce = true;
        entry.value.controller.refresh();
      }
    }
    setState(() {});
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _applyQuery);
  }

  void _applyQuery() {
    final visible = _visibleSection?.key;
    for (final entry in (_tabsOf[_category] ?? const <String, _SectionTab>{}).entries) {
      entry.value.controller.updateQuery(_search.text, visible: entry.key == visible);
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
    final section = _visibleSection;
    final visible = section == null ? null : _tabFor(_category, section).controller;
    final result = await showListSortFilterSheet(
      context,
      settings: _current,
      initialTab: tab,
      options: ListSortFilterOptions(
        sorts: _adapter.sortOptions(_category),
        facets: facetsFor(visible?.loaded ?? const [], isAnime: _isAnime),
        cardProfiles: () => [
          for (final p in Preferences.list.cardProfiles)
            SelectOption(
                p.id, p.profileName.isEmpty ? S.current.UserList_Untitled_Card : p.profileName),
        ],
        onManageCards: (context) => openCardLayouts(context,
            sample: visible == null || visible.entries.isEmpty ? null : visible.entries.first),
      ),
    );
    if (result != null && mounted && result != _current) _applySettings(result);
  }

  Future<void> _openBulk() async {
    final section = _visibleSection;
    if (section == null) return;
    final entries = _tabFor(_category, section).controller.entries;
    if (entries.isEmpty) return;
    final changed = await openAnilistBulkEdit(
      context,
      adapter: _adapter,
      category: _category,
      entries: entries,
      title: section.label(isAnime: _isAnime),
    );
    if (changed == null || changed.isEmpty || !mounted) return;
    for (final e in changed) {
      _applyChange(e);
    }
  }

  // Entry actions -------------------------------------------------------------

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
        _applyChange(saved);
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
      if (mounted) _applyChange(saved);
    } catch (e) {
      if (!mounted) return;
      final expired = _adapter.isSessionExpired(e);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(
            expired ? S.current.UserList_Session_Expired : S.current.UserList_Update_Failed),
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

  /// [entry] was saved: it moves in or out of each section by its AniList fields.
  void _applyChange(ListEntryView entry) {
    final category = entry.category;
    final detail = _lists.detailOf(category, entry.id);
    for (final tab in (_tabsOf[category] ?? const <String, _SectionTab>{}).values) {
      final belongs = detail == null
          ? tab.adapter.section.kind == AnilistSectionKind.all
          : tab.adapter.section.contains(detail);
      if (belongs) {
        tab.controller.applyChange(entry);
      } else {
        tab.controller.removeEntry(entry.id);
      }
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
        tracker: AccountType.anilist,
      );
    }
    _rebuildSections(category);
  }

  void _removeEverywhere(ListEntryView entry) {
    for (final tab in (_tabsOf[entry.category] ?? const <String, _SectionTab>{}).values) {
      tab.controller.removeEntry(entry.id);
    }
    _cache.remove(entry.id, category: entry.category, tracker: AccountType.anilist);
    _rebuildSections(entry.category);
  }

  @override
  void dispose() {
    _tabs?.removeListener(_onTabChanged);
    _tabs?.dispose();
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _busy.dispose();
    for (final map in _tabsOf.values) {
      for (final t in map.values) {
        t.controller.dispose();
      }
    }
    super.dispose();
  }

  // Build ---------------------------------------------------------------------

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

  Widget _categorySwitch() => SegmentedButton<String>(
        segments: [
          for (final c in _categories)
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _sections[_category];
    final tabs = _tabs;
    final ready = _ready && sections != null && tabs != null;
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
          title: widget.titleBuilder(context, _ready ? _categorySwitch() : const SizedBox.shrink()),
          // The home shell's sidebar is an end drawer: without a non-empty
          // actions list Flutter adds its own ☰ next to the header's avatar.
          actions: const [SizedBox.shrink()],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(46 + 48),
            child: ready ? _header(theme, sections, tabs) : const SizedBox(height: 94),
          ),
        ),
      ],
      body: ready ? _body(context, sections, tabs) : _pending(context),
    );
  }

  /// Before the tabs exist: the shared skeleton, or the load error with Retry.
  Widget _pending(BuildContext context) {
    final error = _loadErrors[_category];
    if (!_ready || error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    final expired = _adapter.isSessionExpired(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(expired ? Icons.lock_clock_outlined : Icons.cloud_off_rounded,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(expired ? S.current.UserList_Session_Expired : S.current.UserList_Load_Error,
                textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: expired
                  ? () => _adapter.signInAgain(context)
                  : () => _loadSections(_category, force: true),
              child: Text(expired ? S.current.UserList_Sign_In_Again : S.current.UserList_Retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<AnilistSection> sections, TabController tabs) {
    final settings = _current;
    final display = settings.display;
    final profile = display.subType == DisplaySubType.custom
        ? _cardProfile(context, display.cardProfileId)
        : null;
    return TabBarView(
      key: ValueKey('al-tabs-$_category-${sections.length}'),
      controller: tabs,
      children: [
        for (final section in sections)
          UserListTab(
            key: PageStorageKey('al-tab-$_category-${section.key}'),
            controller: _tabFor(_category, section).controller,
            adapter: _tabFor(_category, section).adapter,
            display: display,
            cardProfile: profile,
            actions: _actions,
            style: _style(context, showStatus: !section.isStatus),
            onClearFilters: _clearFilters,
          ),
      ],
    );
  }

  Widget _header(ThemeData theme, List<AnilistSection> sections, TabController tabs) {
    final counts = _counts[_category] ?? const {};
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          child: TabBar(
            key: ValueKey('al-bar-$_category-${sections.length}'),
            controller: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final section in sections)
                Tab(
                  child: _SectionLabel(
                    key: ValueKey('al-label-$_category-${section.key}'),
                    controller: _tabFor(_category, section).controller,
                    label: section.label(isAnime: _isAnime),
                    count: counts[section],
                    icon: section.kind == AnilistSectionKind.custom
                        ? Icons.bookmarks_outlined
                        : null,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 48, child: _toolbar(theme)),
      ],
    );
  }

  Widget _toolbar(ThemeData theme) {
    final settings = _current;
    final sort =
        _adapter.sortOptions(_category).where((o) => o.key == settings.sortKey).firstOrNull;
    final filterCount = settings.filter.activeCount;
    final asc = settings.direction == SortDirection.ascending;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip:
                _searching ? S.current.UserList_Close_Search : S.current.UserList_Search_In_List,
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
                        avatar: Icon(
                            asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
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
            tooltip: S.current.Alf_Select_Entries,
            onPressed: _openBulk,
            icon: const Icon(Icons.checklist_rounded),
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
            icon: Icon(
                settings.display.isGrid ? Icons.grid_view_rounded : Icons.view_agenda_outlined),
          ),
        ],
      ),
    );
  }
}

/// One tab's adapter and controller.
class _SectionTab {
  final _SectionAdapter adapter;
  final UserListTabController controller;
  _SectionTab(this.adapter, this.controller);
}

/// The AniList adapter seen from one section: its rows only, AniList sorts applied.
class _SectionAdapter extends UserListAdapter {
  _SectionAdapter({
    required this.base,
    required this.section,
    required this.settings,
    required this.onLoaded,
  });

  final AnilistUserListAdapter base;
  final AnilistSection section;
  final ListViewSettings Function() settings;
  final VoidCallback onLoaded;

  /// The next first page sorts again from memory instead of asking AniList (sort changed).
  bool resortOnce = false;
  bool _started = false;

  @override
  AccountType get tracker => base.tracker;
  @override
  String? get owner => base.owner;
  @override
  int get maxPageSize => base.maxPageSize;
  @override
  List<ListSortOption> sortOptions(String category) => base.sortOptions(category);
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
    // The first page asked again is a pull to refresh: AniList is asked again then.
    final force = offset == 0 && _started && !resortOnce;
    if (offset == 0) {
      _started = true;
      resortOnce = false;
    }
    final all = await base.lists.all(category, force: force);
    final rows = [
      for (final e in all)
        if (_belongs(category, e)) e,
    ];
    final s = settings();
    final sorted = base.sortByAnilist(rows, category, s.sortKey, s.direction);
    final end = (offset + limit).clamp(0, sorted.length);
    final from = offset.clamp(0, sorted.length);
    if (offset == 0) onLoaded();
    return ListPage(sorted.sublist(from, end), hasMore: end < sorted.length);
  }

  bool _belongs(String category, ListEntryView e) {
    final d = base.lists.detailOf(category, e.id);
    return d == null ? section.kind == AnilistSectionKind.all : section.contains(d);
  }

  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) =>
      base.statusCounts(category);
  @override
  void open(BuildContext context, ListEntryView entry) => base.open(context, entry);
  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) =>
      base.edit(context, entry);
  @override
  bool canStep(ListEntryView entry) => base.canStep(entry);
  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) => base.step(entry, delta);
  @override
  bool isSessionExpired(Object error) => base.isSessionExpired(error);
  @override
  Future<void> signInAgain(BuildContext context) => base.signInAgain(context);
}

/// "Watching · 12": the section's count, or the visible rows while a search or filter runs.
class _SectionLabel extends StatelessWidget {
  final UserListTabController controller;
  final String label;
  final int? count;
  final IconData? icon;

  const _SectionLabel({
    super.key,
    required this.controller,
    required this.label,
    required this.count,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final filtered =
            !controller.settings.filter.isEmpty || controller.query.trim().isNotEmpty;
        final int? shown = filtered
            ? (controller.hasMore || !controller.isStarted ? null : controller.entries.length)
            : count;
        final theme = Theme.of(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
            Text(label),
            if (shown != null) ...[
              const SizedBox(width: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  child: Text('$shown', style: theme.textTheme.labelSmall),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
