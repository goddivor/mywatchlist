import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart' show SectionMessage;
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/weekly/weekly_data.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_tab.dart'
    show listGridDelegate, listGridGaps, listGridPadding;

/// DailyAL's "Weekly anime" of one season: a tab per broadcast day (Monday to Sunday in the
/// time zone of the preferences, then "Others"), each with its count, sorted by score,
/// members or scorers and filtered by list status ("Not in list" included) on the device.
class WeeklyScheduleScreen extends StatefulWidget {
  final SeasonKey season;

  const WeeklyScheduleScreen({super.key, required this.season});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: WeeklyData.dayCount,
    vsync: this,
    initialIndex: WeeklyData.todayIndex(Preferences.content.timezone),
  );

  ListViewSettings _settings = WeeklyData.defaults();
  List<List<ListEntryView>>? _days;
  List<List<ListEntryView>> _visible = const [];
  bool _failed = false;

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
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _failed = false);
    final saved = await WeeklyData.readSettings();
    try {
      final days =
          await WeeklyData.load(widget.season, pref: Preferences.content.timezone, force: force);
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _days = days;
        _recompute();
      });
    } catch (e) {
      debugPrint('WeeklyScheduleScreen: $e');
      if (!mounted) return;
      setState(() {
        _settings = saved;
        _failed = true;
      });
    }
  }

  void _recompute() {
    _visible = [
      for (final day in _days ?? const <List<ListEntryView>>[]) WeeklyData.apply(day, _settings)
    ];
  }

  Future<void> _openSortFilter() async {
    final all = [for (final day in _days ?? const <List<ListEntryView>>[]) ...day];
    final result = await showListSortFilterSheet(
      context,
      settings: _settings,
      options: ListSortFilterOptions(
        sorts: WeeklyData.sortOptions(),
        facets: WeeklyData.facets(all, listKnown: WeeklyData.listKnown),
      ),
    );
    if (result == null || !mounted || result == _settings) return;
    setState(() {
      _settings = result;
      _recompute();
    });
    WeeklyData.writeSettings(result);
  }

  @override
  Widget build(BuildContext context) {
    final filterCount = _settings.filter.activeCount;
    final days = _days;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.season.label),
        actions: [
          if (days != null)
            IconButton(
              tooltip: S.current.Filter,
              onPressed: _openSortFilter,
              icon: Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          const SizedBox(width: 4),
        ],
        bottom: days == null
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final (i, name)
                      in WeeklyData.dayNames(Localizations.localeOf(context).toString()).indexed)
                    Tab(text: S.current.Wk_Day_Tab(name, _visible[i].length)),
                ],
              ),
      ),
      body: _failed
          ? Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Align(
                alignment: Alignment.topCenter,
                child: SectionMessage(
                  icon: Icons.cloud_off_rounded,
                  text: S.current.Wk_Failed,
                  onRetry: () => _load(force: true),
                ),
              ),
            )
          : days == null
              ? _skeleton(context)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    for (var i = 0; i < WeeklyData.dayCount; i++)
                      _DayList(
                        key: PageStorageKey('weekly-day-$i'),
                        entries: _visible[i],
                        filtered: days[i].isNotEmpty && !_settings.filter.isEmpty,
                        display: _settings.display,
                        actions: _actions,
                        onRefresh: () => _load(force: true),
                      ),
                  ],
                ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final gaps = listGridGaps(DisplaySubType.comfortable);
    final base = AppColors.of(context).shimmerBase;
    return GridView.builder(
      padding: listGridPadding(DisplaySubType.comfortable, top: 12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 220,
        crossAxisSpacing: gaps.column,
        mainAxisSpacing: gaps.row,
      ),
      itemCount: 9,
      itemBuilder: (context, __) => ShimmerColor(
        DecoratedBox(
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

/// One day of the schedule: grid or list of cards with the airing time, or an empty state.
class _DayList extends StatelessWidget {
  final List<ListEntryView> entries;

  /// The day has anime but the filter hides them all.
  final bool filtered;
  final ListDisplay display;
  final EntryActions actions;
  final Future<void> Function() onRefresh;

  const _DayList({
    super.key,
    required this.entries,
    required this.filtered,
    required this.display,
    required this.actions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final general = Preferences.general;
    final style = EntryCardStyle(
      showStatus: true,
      showPriority: general.showPriority,
      showAiringInfo: true,
      cardBackground: general.showAnimeMangaCard,
    );
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();
    final subType =
        display.subType == DisplaySubType.custom ? DisplaySubType.comfortable : display.subType;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (entries.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: SectionMessage(
                  icon: filtered ? Icons.filter_alt_off_rounded : Icons.inbox_outlined,
                  text: filtered ? S.current.Seasonal_No_Match : S.current.No_Content,
                ),
              ),
            )
          else if (display.isGrid)
            SliverPadding(
              padding: listGridPadding(display.subType, top: 12),
              sliver: SliverGrid.builder(
                gridDelegate: listGridDelegate(display),
                itemCount: entries.length,
                itemBuilder: (context, i) => EntryGridCard(
                  key: ValueKey(entries[i].id),
                  entry: entries[i],
                  subType: display.subType,
                  actions: actions,
                  style: style,
                  now: now,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 8),
              sliver: SliverFixedExtentList.builder(
                itemExtent: listRowExtent(subType),
                itemCount: entries.length,
                itemBuilder: (context, i) => EntryListTile(
                  key: ValueKey(entries[i].id),
                  entry: entries[i],
                  subType: subType,
                  actions: actions,
                  style: style,
                  now: now,
                  locale: locale,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
