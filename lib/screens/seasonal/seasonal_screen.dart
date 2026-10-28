import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_data.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart' show listGridDelegate, listGridGaps, listGridPadding;

/// Every anime of one season with a season/year switcher, sort (score, members, popularity,
/// title, start date, episodes), filter (type, airing state, genres) and grid or list display.
///
/// The whole season is downloaded once (cached ten minutes), then sorted and filtered on the
/// device. With the "global seasonal filter" preference on, one sort/filter/display is shared by
/// every season; otherwise each season remembers its own.
class SeasonalScreen extends StatefulWidget {
  final SeasonKey initial;

  /// Sort key to start with (a [ListSortKeys] value), when the caller wants e.g. most followed.
  final String? initialSortKey;

  const SeasonalScreen({super.key, required this.initial, this.initialSortKey});

  @override
  State<SeasonalScreen> createState() => _SeasonalScreenState();
}

class _SeasonalScreenState extends State<SeasonalScreen> {
  late SeasonKey _season = widget.initial;
  ListViewSettings _settings = SeasonalData.defaults();
  List<ListEntryView>? _entries;
  List<ListEntryView> _visible = const [];
  bool _failed = false;

  /// Bumped on each season change so a slow answer of a previous season is ignored.
  int _generation = 0;

  final ValueNotifier<Set<int>> _busy = ValueNotifier(const {});
  late final EntryActions _actions = EntryActions(
    onOpen: (e) => AppRoutes.openContent(context, id: e.id),
    onEdit: null,
    onStep: null,
    canStep: (_) => false,
    busy: _busy,
  );

  @override
  void initState() {
    super.initState();
    _openSeason(_season, first: true);
  }

  @override
  void dispose() {
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
      final entries = await SeasonalData.load(season, force: force);
      if (!mounted || generation != _generation) return;
      setState(() {
        _settings = saved;
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
    final filtered = filterEntries(entries, _settings.filter);
    _visible = sortEntries(filtered, _settings.sortKey, _settings.direction);
  }

  void _go(int delta) {
    final next = _season.shifted(delta);
    if (next.year < kFirstSeasonYear || next.year > lastSeasonYear()) return;
    _openSeason(next);
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
    setState(() {
      _settings = result;
      _recompute();
    });
    SeasonalData.writeSettings(_season, result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filterCount = _settings.filter.activeCount;
    final iconStyle = IconButton.styleFrom(backgroundColor: scheme.surface.withValues(alpha: 0.65));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _openSeason(_season, force: true),
        edgeOffset: 120,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 190,
              title: Text('${S.current.Seasonal} · ${_season.label}'),
              actions: [
                if (_entries != null)
                  IconButton(
                    style: iconStyle,
                    tooltip: S.current.Filter,
                    onPressed: _openSortFilter,
                    icon: Badge(
                      isLabelVisible: filterCount > 0,
                      label: Text('$filterCount'),
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                IconButton(
                  style: iconStyle,
                  tooltip: S.current.Search,
                  onPressed: () => AppRoutes.openSearch(context),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  style: iconStyle,
                  tooltip: S.current.WeeklyAnime,
                  onPressed: () => AppRoutes.openCalendar(context),
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(seasonImage(_season.season), fit: BoxFit.cover, cacheWidth: 900),
                    // Fades into the page colour under the switcher; a static gradient, no blur.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.4, 1],
                          colors: [scheme.surface.withValues(alpha: 0), scheme.surface],
                        ),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(kExplorePadding, 0, kExplorePadding, 64),
                        child: Row(
                          children: [
                            Icon(seasonIcon(_season.season), size: 30, color: scheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              _season.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _Switcher(season: _season, onGo: _go, onPick: _openSeason),
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
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kExplorePadding, 4, kExplorePadding, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(S.current.Seasonal_Count(visible.length),
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              if (!_settings.filter.isEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _settings = _settings.copyWith(filter: ListFilter.none);
                      _recompute();
                    });
                    SeasonalData.writeSettings(_season, _settings);
                  },
                  child: Text(S.current.Seasonal_Clear_Filters),
                ),
            ],
          ),
        ),
      ),
      if (visible.isEmpty)
        SliverToBoxAdapter(
          child: SectionMessage(icon: Icons.filter_alt_off_rounded, text: S.current.Seasonal_No_Match),
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

  Widget _skeleton() {
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
        itemBuilder: (context, __) => ShimmerColor(
          DecoratedBox(
            decoration: BoxDecoration(
                color: AppColors.of(context).shimmerBase,
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
    );
  }
}

/// Previous / next season buttons around season and year pickers.
class _Switcher extends StatelessWidget {
  final SeasonKey season;
  final ValueChanged<int> onGo;
  final ValueChanged<SeasonKey> onPick;

  const _Switcher({required this.season, required this.onGo, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final years = [
      for (var y = lastSeasonYear(); y >= kFirstSeasonYear; y--) SelectOption<int>(y, '$y'),
    ];
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: S.current.Seasonal_Previous,
            onPressed: () => onGo(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: SelectButton<SeasonType>(
                title: S.current.Seasonal_Season,
                options: [
                  for (final s in SeasonType.values)
                    SelectOption<SeasonType>(s, seasonLabel(s), icon: seasonIcon(s)),
                ],
                selected: season.season,
                onChanged: (s) => onPick(SeasonKey(s, season.year)),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SelectButton<int>(
                title: S.current.Seasonal_Year,
                options: years,
                selected: season.year,
                onChanged: (y) => onPick(SeasonKey(season.season, y)),
              ),
            ),
          ),
          IconButton(
            tooltip: S.current.Seasonal_Next,
            onPressed: () => onGo(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
