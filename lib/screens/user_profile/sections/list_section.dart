import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/preferences/preferences_bloc.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/list/bulk/list_bulk.dart';
import 'package:mywatchlist/widgets/user/list/cards/my_list_mark.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/list_view_store.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_controller.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart'
    show listGridDelegate, listGridPadding;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// What the List tab shows next to the signed-in user's own list.
enum _Compare { all, common, missing }

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
  final ListStatusCache? myList;

  const ListSection({
    super.key,
    required this.username,
    required this.anime,
    required this.manga,
    this.adapter,
    this.myList,
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
  _Compare _compare = _Compare.all;

  /// Titles picked to add to (or remove from) the signed-in user's list.
  final ListSelection _selection = ListSelection();

  /// The entries shown last (after the compare filter), for "select all".
  List<ListEntryView> _shown = const [];

  /// Whether the signed-in user can write a MAL list (bulk add needs it).
  bool get _canWrite => const MalListEntryService().canEdit && UserMalV2.instance.username != null;

  /// The signed-in user's own statuses (the whole list is kept there).
  ListStatusCache get _mine => widget.myList ?? ListStatusCache.instance;

  /// Whether the signed-in user's list shows here: the setting is on and the profile is not
  /// theirs.
  bool _comparing(BuildContext context) {
    final on = context.select<PreferencesBloc, bool>((b) => b.state.general.showMyListOnProfiles);
    final me = UserMalV2.instance.username;
    return on && (me == null || me.toLowerCase() != widget.username.toLowerCase());
  }

  bool _inMine(ListEntryView e) => _mine.entryOf(e.id, category: e.category) != null;

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
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = _current;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, _selection]),
      builder: (context, _) => Stack(
        children: [
          ProfileTabScroll(
        storageKey: 'list_${widget.username}_$_category',
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderDelegate(
              child: _header(context, comparing: _comparing(context)),
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
          ..._body(context, controller, comparing: _comparing(context)),
          if (_selection.active) const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
          if (_selection.active)
            PositionedDirectional(start: 0, end: 0, bottom: 0, child: _bulkBar(context)),
        ],
      ),
    );
  }

  List<ListEntryView> _picked() => [for (final e in _shown) if (_selection.contains(e.id)) e];

  Widget _bulkBar(BuildContext context) {
    final s = S.of(context);
    final picked = _picked();
    final inMine = [for (final e in picked) if (_inMine(e)) e];
    return BulkActionBar(
      selection: _selection,
      shown: [for (final e in _shown) e.id],
      actions: [
        BulkAction(
          icon: Icons.playlist_add_rounded,
          label: s.Bulk_Add_Mine,
          onPressed: picked.isEmpty ? null : () => _addToMine(picked),
        ),
        BulkAction(
          icon: Icons.playlist_remove_rounded,
          label: s.Bulk_Remove_Mine,
          destructive: true,
          onPressed: inMine.isEmpty ? null : () => _removeFromMine(inMine),
        ),
      ],
    );
  }

  Future<void> _addToMine(List<ListEntryView> picked) async {
    final s = S.of(context);
    final status = await pickBulkStatus(
      context,
      isAnime: _isAnime,
      count: picked.length,
      title: s.Bulk_Add_Title(picked.length),
    );
    if (status == null || !mounted) return;
    final writer = MalBulkWriter(cache: _mine);
    await runBulkWithProgress(
      context,
      total: picked.length,
      work: (onProgress) => writer.setStatus(picked, status, onProgress: onProgress),
    );
    if (mounted) _selection.stop();
  }

  Future<void> _removeFromMine(List<ListEntryView> picked) async {
    if (!await confirmBulkRemove(context, picked.length) || !mounted) return;
    final writer = MalBulkWriter(cache: _mine);
    await runBulkWithProgress(
      context,
      total: picked.length,
      work: (onProgress) => writer.remove(picked, onProgress: onProgress),
    );
    if (mounted) _selection.stop();
  }

  Widget _header(BuildContext context, {required bool comparing}) {
    final s = S.of(context);
    final settings = _settingsOf(_category);
    final filterCount = settings.filter.activeCount;
    final loaded = _current.entries;
    final common = comparing ? loaded.where(_inMine).length : 0;
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
                if (_canWrite)
                  IconButton(
                    tooltip: s.Bulk_Select,
                    isSelected: _selection.active,
                    icon: const Icon(Icons.checklist_rounded),
                    selectedIcon: Icon(Icons.checklist_rounded, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => _selection.active ? _selection.stop() : _selection.start(),
                  ),
                if (comparing)
                  _CompareButton(
                    value: _compare,
                    common: common,
                    missing: loaded.length - common,
                    onChanged: (v) => setState(() => _compare = v),
                  ),
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

  List<Widget> _body(BuildContext context, UserListTabController c, {required bool comparing}) {
    final s = S.of(context);
    final compare = comparing ? _compare : _Compare.all;
    final entries = switch (compare) {
      _Compare.all => c.entries,
      _Compare.common => c.entries.where(_inMine).toList(),
      _Compare.missing => c.entries.where((e) => !_inMine(e)).toList(),
    };
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
      if (compare != _Compare.all && c.entries.isNotEmpty) {
        return [
          fill(ProfileMessage(
            icon: compare == _Compare.common ? Icons.compare_arrows_rounded : Icons.playlist_add_check_rounded,
            title: compare == _Compare.common ? s.Mlp_None_Common : s.Mlp_None_Missing,
            actionLabel: s.Mlp_Show_All,
            onAction: () => setState(() => _compare = _Compare.all),
          )),
          SliverToBoxAdapter(child: _Footer(controller: c)),
        ];
      }
      return [fill(ProfileMessage(icon: Icons.inbox_outlined, title: s.Pl_List_Empty))];
    }

    _shown = entries;
    if (_selection.active) _selection.retain(entries.map((e) => e.id));
    Widget pickable(ListEntryView e, Widget card) =>
        SelectableEntry(selection: _selection, id: e.id, child: card);

    Widget? mark(ListEntryView e, {bool dense = false}) => comparing
        ? MyListMark(id: e.id, category: e.category, dense: dense, onImage: dense, cache: _mine)
        : null;

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
          itemBuilder: (context, i) => pickable(entries[i], EntryGridCard(
            key: ValueKey(entries[i].id),
            entry: entries[i],
            subType: display.subType,
            actions: _actions,
            style: style,
            now: now,
            mark: mark(entries[i], dense: true),
          )),
        ),
      );
    } else {
      final subType =
          display.subType == DisplaySubType.custom ? DisplaySubType.comfortable : display.subType;
      final locale = Localizations.localeOf(context).toString();
      list = SliverFixedExtentList.builder(
        itemExtent: listRowExtent(subType),
        itemCount: entries.length,
        itemBuilder: (context, i) => pickable(entries[i], EntryListTile(
          key: ValueKey(entries[i].id),
          entry: entries[i],
          subType: subType,
          actions: _actions,
          style: style,
          now: now,
          locale: locale,
          mark: mark(entries[i], dense: subType == DisplaySubType.compact),
        )),
      );
    }
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 4)),
      list,
      SliverToBoxAdapter(child: _Footer(controller: c)),
    ];
  }
}

/// Compare with the signed-in user's list: all the titles, the ones both lists hold, or the
/// ones the user does not have. The counts cover the titles loaded so far.
class _CompareButton extends StatelessWidget {
  const _CompareButton({required this.value, required this.common, required this.missing, required this.onChanged});

  final _Compare value;
  final int common;
  final int missing;
  final ValueChanged<_Compare> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    PopupMenuEntry<_Compare> item(_Compare v, IconData icon, String label, int? count) => CheckedPopupMenuItem(
          value: v,
          checked: v == value,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(count == null ? label : s.Mlp_Count(label, count))),
            ],
          ),
        );
    return PopupMenuButton<_Compare>(
      tooltip: s.Mlp_Compare,
      onSelected: onChanged,
      icon: Badge(
        isLabelVisible: value != _Compare.all,
        smallSize: 8,
        backgroundColor: scheme.primary,
        child: Icon(Icons.compare_arrows_rounded, color: value == _Compare.all ? null : scheme.primary),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<_Compare>(
          enabled: false,
          height: 36,
          child: Text(s.Mlp_Compare, style: Theme.of(context).textTheme.labelLarge),
        ),
        item(_Compare.all, Icons.list_rounded, s.Mlp_All, null),
        item(_Compare.common, Icons.person_rounded, s.Mlp_Common, common),
        item(_Compare.missing, Icons.person_off_outlined, s.Mlp_Missing, missing),
        PopupMenuItem<_Compare>(
          enabled: false,
          height: 32,
          child: Text(
            s.Mlp_Loaded_Hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
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
