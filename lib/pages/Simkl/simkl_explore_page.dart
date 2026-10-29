import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Explore tab for Simkl: a search bar over the Simkl anime catalogue, then one list at a time
/// (a poster grid, or Simkl's calendar rows for the schedule): trending (today, week, month) and the airing schedule from Simkl's CDN, new
/// premieres, coming soon, best anime and the genre browse from the API. Each list has its own
/// options row (period, day, bucket, genre, sort, format). Simkl has no manga, so there is no
/// anime / manga switch.
class SimklExplorePage extends StatefulWidget {
  const SimklExplorePage({super.key, this.service});

  /// Test hook; defaults to the shared Simkl discover service.
  final SimklDiscoverService? service;

  @override
  State<SimklExplorePage> createState() => _SimklExplorePageState();
}

enum _Load { loading, ready, failed }

/// The loaded pages of one query.
class _Pages {
  final List<SimklMedia> items;
  final int page;
  final bool hasMore;

  const _Pages(this.items, this.page, this.hasMore);
}

class _SimklExplorePageState extends State<SimklExplorePage> {
  final TextEditingController _controller = TextEditingController();
  final Map<SimklFeedQuery, _Pages> _loaded = {};

  /// The options last picked per feed, so switching feeds keeps them.
  final Map<SimklFeed, SimklFeedQuery> _perFeed = {};
  Timer? _debounce;
  SimklFeedQuery _query = const SimklFeedQuery(SimklFeed.trending);
  _Load _feedState = _Load.loading;
  bool _loadingMore = false;
  bool _moreFailed = false;
  String _text = '';
  List<SimklMedia> _results = const [];
  _Load _searchState = _Load.ready;
  int _token = 0;

  /// The user's list by Simkl id, for the schedule (My shows, status dots, finale badges).
  Map<int, ListEntryView> _list = const {};
  bool _mine = false;

  SimklDiscoverService get _service => widget.service ?? SimklDiscoverService.instance;
  bool get _searching => _text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    if (simklSignedIn) {
      simklListById().then((list) {
        if (mounted) setState(() => _list = list);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool force = false}) async {
    final query = _query;
    if (!force) {
      final kept = _loaded[query];
      final cached = kept == null ? HomeSectionCache.fresh<List<SimklMedia>>(query.cacheKey, const Duration(minutes: 30)) : null;
      if (kept != null || cached != null) {
        _loaded[query] ??= _Pages(cached!, 1, query.paged && cached.length >= SimklDiscoverService.pageSize);
        setState(() => _feedState = _Load.ready);
        return;
      }
    } else {
      _service.cdn.invalidate();
    }
    final token = ++_token;
    setState(() {
      _feedState = _Load.loading;
      _moreFailed = false;
    });
    try {
      final page = await query.load(_service);
      HomeSectionCache.put(query.cacheKey, page.items);
      if (!mounted || token != _token) return;
      setState(() {
        _loaded[query] = _Pages(page.items, 1, page.hasMore);
        _feedState = _Load.ready;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _feedState = _Load.failed);
    }
  }

  /// Next page of the genre browse; started when the end of the grid is built.
  Future<void> _loadMore() async {
    final query = _query;
    final current = _loaded[query];
    if (_loadingMore || current == null || !current.hasMore) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final next = await query.load(_service, page: current.page + 1);
      if (!mounted) return;
      final seen = {for (final m in current.items) m.simklId};
      setState(() {
        _loaded[query] = _Pages(
          [...current.items, for (final m in next.items) if (seen.add(m.simklId)) m],
          current.page + 1,
          next.hasMore,
        );
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _moreFailed = true;
      });
    }
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final text = value.trim();
    if (text.isEmpty) {
      _token++;
      setState(() {
        _text = '';
        _results = const [];
        _searchState = _Load.ready;
      });
      // A feed request cancelled by the search is started again.
      if (_feedState == _Load.loading || _loaded[_query] == null) _loadFeed();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String text) async {
    final token = ++_token;
    setState(() {
      _text = text;
      _searchState = _Load.loading;
    });
    try {
      final items = await _service.search(text);
      if (!mounted || token != _token) return;
      setState(() {
        _results = items;
        _searchState = _Load.ready;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _searchState = _Load.failed);
    }
  }

  void _pick(SimklFeedQuery query) {
    if (query == _query) return;
    _perFeed[_query.feed] = _query;
    _query = query;
    _loadFeed();
  }

  void _pickFeed(SimklFeed feed) {
    if (feed == _query.feed) return;
    _pick(_perFeed[feed] ?? SimklFeedQuery(feed));
  }

  Future<void> _onRefresh() => _searching ? _search(_text) : _loadFeed(force: true);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = _searching ? _searchState : _feedState;
    final pages = _loaded[_query];
    final items = _searching ? _results : (pages?.items ?? const <SimklMedia>[]);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              // Empty list does not suppress the automatic endDrawer button; a placeholder does.
              actions: const [SizedBox.shrink()],
              floating: true,
              snap: true,
              titleSpacing: 0,
              toolbarHeight: kToolbarHeight,
              title: AppBarHome(title: s.Hw_Tab_Explore, transparent: true, showSettings: true),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 4, 15, 8),
                child: SearchBar(
                  controller: _controller,
                  hintText: s.Sk_Search_Hint,
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
                  onChanged: _onQuery,
                  trailing: [
                    if (_searching || _controller.text.isNotEmpty)
                      IconButton(
                        tooltip: s.UserList_Clear,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onQuery('');
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (!_searching) ...[
              SliverToBoxAdapter(
                child: _ChipRow(children: [
                  for (final feed in SimklFeed.values)
                    ChoiceChip(
                      label: Text(feed.exploreTitle),
                      selected: feed == _query.feed,
                      onSelected: (_) => _pickFeed(feed),
                    ),
                ]),
              ),
              SliverToBoxAdapter(child: _OptionsRow(query: _query, onPick: _pick)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ..._content(context, state, items, _searching ? null : pages),
            SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  /// The schedule of the picked day as Simkl's calendar rows: exact time, Premiere / Finale
  /// badges, the user's status; My shows / All anime once the list is known.
  List<Widget> _schedule(BuildContext context, List<SimklMedia> items) {
    final rows = [
      for (final m in items)
        if (!_mine || _list.containsKey(m.simklId)) SimklAiring(m, _list[m.simklId]),
    ];
    return [
      if (_list.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 8),
            child: SimklMineSwitch(mine: _mine, onChanged: (v) => setState(() => _mine = v)),
          ),
        ),
      if (rows.isEmpty)
        SliverToBoxAdapter(
          child: HomeMessage(icon: Icons.event_busy_outlined, text: S.of(context).Sk_Feed_Empty),
        )
      else
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => SimklAiringTile(
            airing: rows[i],
            onTap: () => openSimklMedia(context, rows[i].media, service: _service),
          ),
        ),
    ];
  }

  List<Widget> _content(BuildContext context, _Load state, List<SimklMedia> items, _Pages? pages) {
    final s = S.of(context);
    switch (state) {
      case _Load.loading:
        return const [
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 24), child: SimklRowSkeleton())),
        ];
      case _Load.failed:
        return [
          SliverToBoxAdapter(
            child: HomeMessage(
              icon: Icons.cloud_off_outlined,
              text: s.Sk_Load_Failed,
              actionLabel: s.Hw_Retry,
              onAction: () => _searching ? _search(_text) : _loadFeed(force: true),
            ),
          ),
        ];
      case _Load.ready:
        if (items.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: HomeMessage(
                icon: _searching ? Icons.search_off_rounded : Icons.movie_filter_outlined,
                text: _searching ? s.Sk_Search_Empty(_text) : s.Sk_Feed_Empty,
              ),
            ),
          ];
        }
        if (!_searching && _query.feed == SimklFeed.airing) return _schedule(context, items);
        return [
          SimklMediaGrid(items: items, onTap: (media) => openSimklMedia(context, media, service: _service)),
          if (pages != null && pages.hasMore)
            SliverToBoxAdapter(
              child: _moreFailed
                  ? HomeMessage(
                      icon: Icons.cloud_off_outlined,
                      text: s.Sk_Load_Failed,
                      actionLabel: s.Hw_Retry,
                      onAction: _loadMore,
                    )
                  : _LoadMore(key: ValueKey('${_query.cacheKey}:${pages.page}'), onShown: _loadMore),
            ),
        ];
    }
  }
}

/// Spinner at the end of a paged grid; asks for the next page once it is built (slivers are
/// built only near the viewport, so this runs when the user nears the end).
class _LoadMore extends StatefulWidget {
  const _LoadMore({super.key, required this.onShown});

  final VoidCallback onShown;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown();
    });
  }

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))),
      );
}

/// A horizontal row of chips, padded like the rest of the page.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: children.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Center(child: children[i]),
        ),
      );
}

/// The options of the selected list: format first (API lists), then period (trending), day
/// (schedule), bucket (best), or genre and sort (genres).
class _OptionsRow extends StatelessWidget {
  const _OptionsRow({required this.query, required this.onPick});

  final SimklFeedQuery query;
  final ValueChanged<SimklFeedQuery> onPick;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (query.hasFormat)
        _MenuChip<SimklFormat>(
          label: SimklFeedLabels.format(query.format),
          values: SimklFormat.values,
          selected: query.format,
          labelOf: SimklFeedLabels.format,
          onPick: (f) => onPick(query.copyWith(format: f)),
        ),
      ...switch (query.feed) {
        SimklFeed.trending => [
            for (final w in SimklTrendingWindow.values)
              _option(SimklFeedLabels.window(w), query.window == w, () => onPick(query.copyWith(window: w))),
          ],
        SimklFeed.airing => [
            for (var d = 0; d < simklScheduleDays; d++)
              _option(SimklFeedLabels.day(d), query.dayOffset == d, () => onPick(query.copyWith(dayOffset: d))),
            ActionChip(
              avatar: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(S.current.Skr_Calendar),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SimklCalendarPage()),
              ),
            ),
          ],
        SimklFeed.best => [
            for (final b in SimklBest.values)
              _option(SimklFeedLabels.best(b), query.best == b, () => onPick(query.copyWith(best: b))),
          ],
        SimklFeed.genres => [
            _MenuChip<String>(
              label: SimklFeedLabels.genre(query.genre),
              values: simklGenres,
              selected: query.genre,
              labelOf: SimklFeedLabels.genre,
              onPick: (g) => onPick(query.copyWith(genre: g)),
            ),
            _MenuChip<SimklGenreSort>(
              label: SimklFeedLabels.sort(query.sort),
              values: SimklGenreSort.values,
              selected: query.sort,
              labelOf: SimklFeedLabels.sort,
              onPick: (v) => onPick(query.copyWith(sort: v)),
            ),
          ],
        SimklFeed.premieres || SimklFeed.soon => const <Widget>[],
      },
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return _ChipRow(children: chips);
  }

  static Widget _option(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => onTap(),
      );
}

/// A chip that opens a menu of [values]; a long list (genres) scrolls inside the menu.
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onPick,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      style: MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(280, MediaQuery.sizeOf(context).height * 0.6)),
      ),
      menuChildren: [
        for (final value in values)
          MenuItemButton(
            leadingIcon: Icon(
              value == selected ? Icons.check_rounded : null,
              size: 20,
              color: scheme.primary,
            ),
            onPressed: () => onPick(value),
            child: Text(labelOf(value)),
          ),
      ],
      builder: (context, controller, _) => ActionChip(
        label: Text(label),
        avatar: Icon(Icons.arrow_drop_down_rounded, color: scheme.onSurfaceVariant),
        visualDensity: VisualDensity.compact,
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
