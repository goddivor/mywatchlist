import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_data.dart';
import 'package:mywatchlist/screens/weekly/weekly_schedule_screen.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart' show listGridDelegate, listGridGaps, listGridPadding;

/// Downloads every anime of a season ([SeasonalData.load] by default).
typedef SeasonLoader = Future<List<ListEntryView>> Function(SeasonKey season, {bool force});

/// Every anime of one season (DailyAL's seasonal screen): "Seasonal" with a faded season picture
/// and a scrollable tab per season, newest first; sort (score, members, popularity, title, start
/// date, episodes), filter (type, airing state, genres) and list or grid display.
///
/// The list rows are DailyAL's: the user's MyAnimeList progress with quick +1 / -1 and a long
/// press for the edit sheet. The seasons and list statuses come from MyAnimeList, so the writes
/// go to MyAnimeList too, and only while a MyAnimeList account is signed in (whatever tracker
/// is active); otherwise the rows only open the detail page.
///
/// The whole season is downloaded once (cached ten minutes), then sorted and filtered on the
/// device. With the "global seasonal filter" preference on, one sort/filter/display is shared by
/// every season; otherwise each season remembers its own.
class SeasonalScreen extends StatefulWidget {
  final SeasonKey initial;

  /// Sort key to start with (a [ListSortKeys] value), when the caller wants e.g. most followed.
  final String? initialSortKey;

  /// Season download, list writes, MyAnimeList sign-in and status cache; tests pass fakes.
  final SeasonLoader? loader;
  final UserListAdapter? adapter;
  final bool Function()? malSignedIn;
  final ListStatusCache? cache;

  const SeasonalScreen({
    super.key,
    required this.initial,
    this.initialSortKey,
    @visibleForTesting this.loader,
    @visibleForTesting this.adapter,
    @visibleForTesting this.malSignedIn,
    @visibleForTesting this.cache,
  });

  @override
  State<SeasonalScreen> createState() => _SeasonalScreenState();
}

class _SeasonalScreenState extends State<SeasonalScreen> with SingleTickerProviderStateMixin {
  late SeasonKey _season = widget.initial;
  late final List<SeasonKey> _tabs = _tabsWith(widget.initial);
  late final TabController _tabController = TabController(
    length: _tabs.length,
    initialIndex: _tabs.indexOf(widget.initial),
    vsync: this,
  );
  ListViewSettings _settings = SeasonalData.defaults();
  SeasonGroup _group = SeasonGroup.all;
  Set<int> _continuing = const {};
  List<ListEntryView>? _entries;
  List<ListEntryView> _visible = const [];
  bool _failed = false;

  /// Bumped on each season change so a slow answer of a previous season is ignored.
  int _generation = 0;

  late final UserListAdapter _adapter = widget.adapter ?? MalUserListAdapter();
  late final ListStatusCache _cache = widget.cache ?? ListStatusCache.instance;
  final ValueNotifier<Set<int>> _busy = ValueNotifier(const {});
  late final EntryActions _actions = _signedIn()
      ? EntryActions(
          onOpen: (e) => _adapter.open(context, e),
          onEdit: _edit,
          onStep: _step,
          canStep: _adapter.canStep,
          busy: _busy,
        )
      : EntryActions(
          onOpen: (e) => _adapter.open(context, e),
          onEdit: null,
          onStep: null,
          canStep: (_) => false,
          busy: _busy,
        );

  bool _signedIn() =>
      (widget.malSignedIn ?? () => UserMalV2.instance.accessToken != null)();

  /// The tabs, plus [season] at its place when it is outside the usual range.
  static List<SeasonKey> _tabsWith(SeasonKey season) {
    final tabs = seasonTabs();
    if (tabs.contains(season)) return tabs;
    final order = season.year * 4 + season.season.index;
    final at = tabs.indexWhere((t) => t.year * 4 + t.season.index < order);
    return tabs..insert(at < 0 ? tabs.length : at, season);
  }

  @override
  void initState() {
    super.initState();
    _openSeason(_season, first: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _openSeason(SeasonKey season, {bool first = false, bool force = false}) async {
    final generation = ++_generation;
    setState(() {
      _season = season;
      _entries = null;
      _failed = false;
    });
    var saved = await SeasonalData.readSettings(season);
    if (first && widget.initialSortKey != null && SeasonalData.sortKeys.contains(widget.initialSortKey)) {
      saved = saved.copyWith(sortKey: widget.initialSortKey);
    }
    try {
      final load = widget.loader ?? SeasonalData.load;
      final group = await SeasonalData.readGroup();
      final entries = await load(season, force: force);
      if (!mounted || generation != _generation) return;
      setState(() {
        _settings = saved;
        _group = group;
        _continuing = SeasonalData.continuingIds(season);
        _entries = entries;
        _recompute();
      });
    } catch (e) {
      debugPrint('SeasonalScreen: $e');
      if (!mounted || generation != _generation) return;
      setState(() {
        _settings = saved;
        _failed = true;
      });
    }
  }

  void _recompute() {
    final entries = _entries ?? const [];
    final grouped = switch (_group) {
      SeasonGroup.all => entries,
      SeasonGroup.fresh => [for (final e in entries) if (!_continuing.contains(e.id)) e],
      SeasonGroup.continuing => [for (final e in entries) if (_continuing.contains(e.id)) e],
    };
    final filtered = filterEntries(grouped, _settings.filter);
    _visible = sortEntries(filtered, _settings.sortKey, _settings.direction);
  }

  void _onTab(int index) {
    final season = _tabs[index];
    if (season != _season) _openSeason(season);
  }

  Future<void> _openSortFilter() async {
    final result = await showListSortFilterSheet(
      context,
      settings: _settings,
      options: ListSortFilterOptions(
        sorts: SeasonalData.sortOptions(),
        facets: SeasonalData.facets(_entries ?? const []),
      ),
    );
    if (result == null || !mounted || result == _settings) return;
    _applySettings(result);
  }

  void _setGroup(SeasonGroup value) {
    if (value == _group) return;
    setState(() {
      _group = value;
      _recompute();
    });
    SeasonalData.writeGroup(value);
  }

  Widget _groupChips() {
    final total = _entries?.length ?? 0;
    final extra = _continuing.length;
    String label(SeasonGroup g) => switch (g) {
          SeasonGroup.all => S.current.Seasonal_Group_All(total),
          SeasonGroup.fresh => S.current.Seasonal_Group_New(total - extra),
          SeasonGroup.continuing => S.current.Seasonal_Group_Continuing(extra),
        };
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final g in SeasonGroup.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label(g)),
                  selected: _group == g,
                  onSelected: (_) => _setGroup(g),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _applySettings(ListViewSettings value) {
    setState(() {
      _settings = value;
      _recompute();
    });
    SeasonalData.writeSettings(_season, value);
  }

  // List writes (MyAnimeList) -------------------------------------------------

  Future<void> _edit(ListEntryView entry) async {
    final result = await _adapter.edit(context, entry);
    if (!mounted) return;
    switch (result) {
      case ListEditUpdated(entry: final saved):
        _replace(saved);
      case ListEditRemoved():
        _replace(entry.copyWith(clearStatus: true, score: 0, progress: 0));
      case ListEditUnchanged():
        break;
    }
  }

  Future<void> _step(ListEntryView entry, int delta) async {
    if (_busy.value.contains(entry.id)) return;
    _busy.value = {..._busy.value, entry.id};
    try {
      final saved = await _adapter.step(entry, delta);
      if (mounted) _replace(saved);
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

  /// Puts the saved [entry] in place of the old one. The season list is the one held by the
  /// season cache, so a later visit within ten minutes shows the change too.
  void _replace(ListEntryView entry) {
    final entries = _entries;
    if (entries == null) return;
    final i = entries.indexWhere((e) => e.id == entry.id);
    if (i < 0) return;
    setState(() {
      entries[i] = entry;
      _recompute();
    });
    final status = entry.status;
    if (status == null) {
      _cache.remove(entry.id, category: entry.category, tracker: _adapter.tracker);
    } else {
      _cache.put(
        entry.id,
        CachedListStatus(
            status: status.malValue(isAnime: entry.isAnime),
            score: entry.score,
            progress: entry.progress),
        category: entry.category,
        tracker: _adapter.tracker,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterCount = _settings.filter.activeCount;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _openSeason(_season, force: true),
        edgeOffset: top + kToolbarHeight + kTextTabBarHeight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(S.current.Seasonal),
              actions: [
                if (_entries != null)
                  IconButton(
                    tooltip: S.current.Filter,
                    onPressed: _openSortFilter,
                    icon: Badge(
                      isLabelVisible: filterCount > 0,
                      label: Text('$filterCount'),
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                IconButton(
                  tooltip: S.current.Search,
                  onPressed: () => AppRoutes.openSearch(context),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  tooltip: S.current.WeeklyAnime,
                  onPressed: () =>
                      AppRoutes.push<void>(context, WeeklyScheduleScreen(season: _season)),
                  icon: const Icon(Icons.calendar_view_week_rounded),
                ),
                const SizedBox(width: 4),
              ],
              // DailyAL's faded season picture, drawn at 20 % through the image paint (no layer).
              flexibleSpace: Image.asset(
                seasonImage(_season.season),
                key: ValueKey(_season.season),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 900,
                opacity: const AlwaysStoppedAnimation(0.2),
                excludeFromSemantics: true,
              ),
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                onTap: _onTab,
                tabs: [for (final s in _tabs) Tab(text: s.label)],
              ),
            ),
            ..._body(context),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (_failed) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: SectionMessage(
              icon: Icons.cloud_off_rounded,
              text: S.current.Seasonal_Failed,
              onRetry: () => _openSeason(_season, force: true),
            ),
          ),
        ),
      ];
    }
    if (_entries == null) return [_skeleton()];
    if (_entries!.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 48),
            child: SectionMessage(icon: Icons.inbox_outlined, text: S.current.Seasonal_Empty),
          ),
        ),
      ];
    }
    final display = _settings.display;
    final style = EntryCardStyle.fromPreferences(Preferences.general, showStatus: true);
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final visible = _visible;
    return [
      if (_continuing.isNotEmpty) _groupChips() else const SliverToBoxAdapter(child: SizedBox(height: 4)),
      if (visible.isEmpty)
        SliverToBoxAdapter(
          child: Column(
            children: [
              SectionMessage(icon: Icons.filter_alt_off_rounded, text: S.current.Seasonal_No_Match),
              TextButton(
                onPressed: () => _applySettings(_settings.copyWith(filter: ListFilter.none)),
                child: Text(S.current.Seasonal_Clear_Filters),
              ),
            ],
          ),
        )
      else if (display.isGrid)
        SliverPadding(
          // My List's grid: DailyAL's gaps (#143).
          padding: listGridPadding(display.subType),
          sliver: SliverGrid.builder(
            gridDelegate: listGridDelegate(display),
            itemCount: visible.length,
            itemBuilder: (context, i) => EntryGridCard(
              key: ValueKey(visible[i].id),
              entry: visible[i],
              subType: display.subType,
              actions: _actions,
              style: style,
              now: now,
            ),
          ),
        )
      else
        SliverFixedExtentList.builder(
          itemExtent: listRowExtent(
              display.subType == DisplaySubType.custom ? DisplaySubType.comfortable : display.subType),
          itemCount: visible.length,
          itemBuilder: (context, i) => EntryListTile(
            key: ValueKey(visible[i].id),
            entry: visible[i],
            subType: display.subType == DisplaySubType.custom
                ? DisplaySubType.comfortable
                : display.subType,
            actions: _actions,
            style: style,
            now: now,
            locale: locale,
          ),
        ),
    ];
  }

  /// Placeholders in the layout the season will be shown in.
  Widget _skeleton() {
    final shimmer = ShimmerColor(
      DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.of(context).shimmerBase, borderRadius: BorderRadius.circular(10)),
      ),
    );
    if (!_settings.display.isGrid) {
      final subType = _settings.display.subType == DisplaySubType.custom
          ? DisplaySubType.comfortable
          : _settings.display.subType;
      return SliverFixedExtentList.builder(
        itemExtent: listRowExtent(subType),
        itemCount: 6,
        itemBuilder: (context, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: shimmer,
        ),
      );
    }
    final gaps = listGridGaps(DisplaySubType.comfortable);
    return SliverPadding(
      padding: listGridPadding(DisplaySubType.comfortable, top: 8),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 220,
          crossAxisSpacing: gaps.column,
          mainAxisSpacing: gaps.row,
        ),
        itemCount: 9,
        itemBuilder: (context, _) => shimmer,
      ),
    );
  }
}
