import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_feeds_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/home/anilist_home_cards.dart';

/// Opens AniList's season view (the current season unless [season] and [year] are given).
Future<void> openAnilistSeason(BuildContext context, {String? season, int? year}) {
  final (s, y) = AnilistDiscoverService.seasonOf(DateTime.now());
  return AppRoutes.push<void>(
    context,
    AnilistSeasonScreen(season: season ?? s, year: year ?? y),
  );
}

/// The season name of [season] (`WINTER`…`FALL`) in the app language.
String anilistSeasonLabel(String season) {
  final s = S.current;
  return switch (season) {
    'WINTER' => s.Explore_Season_Winter,
    'SPRING' => s.Explore_Season_Spring,
    'SUMMER' => s.Explore_Season_Summer,
    _ => s.Explore_Season_Fall,
  };
}

String _tabLabel(AnilistSeasonTab tab) {
  final s = S.current;
  return switch (tab) {
    AnilistSeasonTab.tv => s.Ahx_Tab_Tv,
    AnilistSeasonTab.short => s.Ahx_Tab_Short,
    AnilistSeasonTab.movie => s.Ahx_Tab_Movie,
    AnilistSeasonTab.other => s.Ahx_Tab_Other,
    AnilistSeasonTab.leftovers => s.Ahx_Tab_Leftovers,
  };
}

/// A whole AniList season as AniList and AniChart lay it out: one tab per format (TV, TV
/// short, movies, OVA / ONA / specials) and the leftovers still airing from earlier seasons,
/// most popular first; arrows move to the previous or next season. The first page of every
/// tab comes in one request, the next pages load at the end of the grid.
class AnilistSeasonScreen extends StatefulWidget {
  const AnilistSeasonScreen({super.key, required this.season, required this.year, this.service});

  final String season;
  final int year;
  final AnilistFeedsService? service;

  @override
  State<AnilistSeasonScreen> createState() => _AnilistSeasonScreenState();
}

class _AnilistSeasonScreenState extends State<AnilistSeasonScreen> {
  late String _season = widget.season;
  late int _year = widget.year;
  late Future<AnilistFeed> _feed = _load();

  AnilistFeedsService get _service => widget.service ?? AnilistFeedsService.instance;

  Future<AnilistFeed> _load({bool force = false}) => _service.season(_season, _year, force: force);

  void _move((String, int) to) => setState(() {
        _season = to.$1;
        _year = to.$2;
        _feed = _load();
      });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DefaultTabController(
      length: AnilistSeasonTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.Ahx_Season_Title(anilistSeasonLabel(_season), '$_year')),
          actions: [
            IconButton(
              tooltip: s.Ahx_Season_Previous,
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => _move(AnilistFeedsService.previousSeason(_season, _year)),
            ),
            IconButton(
              tooltip: s.Ahx_Season_Next,
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _move(AnilistFeedsService.nextSeason(_season, _year)),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in AnilistSeasonTab.values) Tab(text: _tabLabel(t))],
          ),
        ),
        body: FutureBuilder<AnilistFeed>(
          future: _feed,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: AnilistRowMessage(
                  failed: true,
                  onRetry: () => setState(() => _feed = _load(force: true)),
                ),
              );
            }
            final feed = snapshot.data;
            if (feed == null) return const Center(child: CircularProgressIndicator());
            return TabBarView(
              children: [
                for (final tab in AnilistSeasonTab.values)
                  _SeasonGrid(
                    key: PageStorageKey('al-season-$_season$_year-${tab.name}'),
                    first: feed.media(tab.name),
                    hasNext: feed.hasNext(tab.name),
                    loadMore: (page) => _service.seasonPage(tab, _season, _year, page),
                    onRetry: () => setState(() => _feed = _load(force: true)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SeasonGrid extends StatefulWidget {
  const _SeasonGrid({
    super.key,
    required this.first,
    required this.hasNext,
    required this.loadMore,
    required this.onRetry,
  });

  /// Null when this tab's part of the request failed.
  final List<AnilistMedia>? first;
  final bool hasNext;
  final Future<AnilistMediaPage> Function(int page) loadMore;
  final VoidCallback onRetry;

  @override
  State<_SeasonGrid> createState() => _SeasonGridState();
}

class _SeasonGridState extends State<_SeasonGrid> with AutomaticKeepAliveClientMixin {
  late final List<AnilistMedia> _items = [...?widget.first];
  late bool _hasNext = widget.hasNext;
  int _page = 1;
  bool _loading = false;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _more() async {
    if (_loading || !_hasNext) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final next = await widget.loadMore(_page + 1);
      if (!mounted) return;
      final seen = {for (final m in _items) m.id};
      setState(() {
        _page++;
        _items.addAll(next.items.where((m) => seen.add(m.id)));
        _hasNext = next.hasNext;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.first == null) {
      return Center(child: AnilistRowMessage(failed: true, onRetry: widget.onRetry));
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(S.current.Ahx_Season_Empty,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) _more();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                childAspectRatio: 0.52,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) => RepaintBoundary(
                child: LayoutBuilder(
                  builder: (context, c) => AnilistHomeCard(
                    media: _items[i],
                    width: c.maxWidth,
                    height: c.maxHeight,
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_failed)
            SliverToBoxAdapter(child: AnilistRowMessage(failed: true, onRetry: _more)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}
