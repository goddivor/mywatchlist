import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show HomePageTileSize, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart' show ExploreSectionHeader, kExplorePadding;
import 'package:mywatchlist/services/api/Anilist/anilist_catalog.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_feeds_service.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart';
import 'package:mywatchlist/widgets/Anilist/home/anilist_home_cards.dart';
import 'package:mywatchlist/widgets/Anilist/home/anilist_season_screen.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_tag_explorer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_reviews_feed.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';

/// What a row of the Explore tab draws.
enum _Kind { media, airing, trends, reviews, recommendations, characters, staff }

/// One row of the AniList Explore tab: its alias in the request, title, kind and "View all".
class _Row {
  final String alias;
  final String Function() title;
  final _Kind kind;
  final AnilistMediaQuery? query;
  const _Row(this.alias, this.title, this.kind, [this.query]);
}

/// The Explore tab for AniList (AniHyou / anilist.co's Discover): search, Anime / Manga, the
/// Season view and Tags entries, then the rows: today's trends with the episode behind them,
/// what airs in the next 24 hours, trending, this and next season (manga: publishing and
/// manhwa), best rated, most popular, the latest reviews and recommendations, the most loved
/// characters and staff, and AniList's live genre list. Every row of a type comes in one
/// request kept ten minutes, so switching Anime / Manga or coming back costs nothing.
class AnilistExplorePage extends StatefulWidget {
  const AnilistExplorePage({super.key, this.service, this.catalog});

  /// Replaced in tests.
  final AnilistFeedsService? service;
  final AnilistCatalog? catalog;

  @override
  State<AnilistExplorePage> createState() => _AnilistExplorePageState();
}

class _AnilistExplorePageState extends State<AnilistExplorePage> {
  String _category = 'anime';
  final Map<String, Future<AnilistFeed>> _feeds = {};
  late final Future<(AnilistCatalogData, bool)> _genres = _loadGenres();

  AnilistFeedsService get _service => widget.service ?? AnilistFeedsService.instance;

  Future<AnilistFeed> _feed({bool force = false}) {
    if (force) _feeds.remove(_category);
    return _feeds.putIfAbsent(_category, () => _service.explore(_category, force: force));
  }

  Future<(AnilistCatalogData, bool)> _loadGenres() async {
    final catalog = await (widget.catalog ?? AnilistCatalog.instance).load();
    final adult = await _service.discover.adultAllowed().catchError((_) => false);
    return (catalog, adult);
  }

  List<_Row> _rows() {
    final s = S.current;
    final (season, year) = AnilistDiscoverService.seasonOf(DateTime.now());
    final (next, nextYear) = AnilistFeedsService.nextSeason(season, year);
    final c = _category;
    final common = [
      _Row(AnilistExploreRows.top, () => c == 'manga' ? s.Hw_Sec_Top_Manga : s.Hw_Sec_Top_Score, _Kind.media,
          AnilistMediaQuery(category: c, sort: 'SCORE_DESC')),
      _Row(AnilistExploreRows.popular, () => c == 'manga' ? s.Hw_Sec_Popular_Manga : s.Hw_Sec_Popular,
          _Kind.media, AnilistMediaQuery(category: c, sort: 'POPULARITY_DESC')),
      _Row(AnilistExploreRows.reviews, () => s.Ahx_Sec_Latest_Reviews, _Kind.reviews),
      _Row(AnilistExploreRows.recommendations, () => s.Ahx_Sec_Latest_Recommendations, _Kind.recommendations),
      _Row(AnilistExploreRows.topCharacters, () => s.Ahx_Sec_Top_Characters, _Kind.characters),
      _Row(AnilistExploreRows.topStaff, () => s.Ahx_Sec_Top_Staff, _Kind.staff),
    ];
    if (c == 'manga') {
      return [
        _Row(AnilistExploreRows.trending, () => s.Al_Sec_Trending, _Kind.media,
            const AnilistMediaQuery(category: 'manga', sort: 'TRENDING_DESC')),
        _Row(AnilistExploreRows.publishing, () => s.Al_Sec_Publishing, _Kind.media,
            const AnilistMediaQuery(category: 'manga', sort: 'POPULARITY_DESC', status: 'RELEASING')),
        _Row(AnilistExploreRows.manhwa, () => s.Ahx_Sec_Manhwa, _Kind.media,
            const AnilistMediaQuery(category: 'manga', sort: 'POPULARITY_DESC', country: 'KR')),
        ...common,
      ];
    }
    return [
      _Row(AnilistExploreRows.trendsToday, () => s.Ahx_Sec_Trends_Today, _Kind.trends),
      _Row(AnilistExploreRows.airing, () => s.Al_Sec_Airing_Soon, _Kind.airing),
      _Row(AnilistExploreRows.trending, () => s.Al_Sec_Trending, _Kind.media,
          const AnilistMediaQuery(category: 'anime', sort: 'TRENDING_DESC')),
      _Row(AnilistExploreRows.season, () => s.Hw_Sec_Season(anilistSeasonLabel(season), '$year'), _Kind.media,
          AnilistMediaQuery(category: 'anime', sort: 'POPULARITY_DESC', season: season, seasonYear: year)),
      _Row(AnilistExploreRows.nextSeason, () => s.Hw_Sec_Season(anilistSeasonLabel(next), '$nextYear'),
          _Kind.media,
          AnilistMediaQuery(category: 'anime', sort: 'POPULARITY_DESC', season: next, seasonYear: nextYear)),
      ...common,
    ];
  }

  VoidCallback? _viewAll(_Row row) {
    final query = row.query;
    return switch (row.kind) {
      _Kind.media when query != null => () => openAnilistBrowse(context, row.title(), query),
      _Kind.reviews => () => openAnilistReviews(context, title: row.title()),
      _Kind.characters => () => openAnilistSearch(context, kind: AnilistSearchKind.characters),
      _Kind.staff => () => openAnilistSearch(context, kind: AnilistSearchKind.staff),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final s = S.of(context);
    final tile = getTileSizeValues(HomePageTileSize.m);
    final cardHeight = tile.containerHeight;
    final cardWidth = cardHeight * (2 / 3);
    final rows = _rows();
    final category = _category;

    return CustomScrollView(
      key: PageStorageKey('al-explore-$category'),
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          // Empty list does not suppress the automatic endDrawer button; a placeholder does.
          actions: const [SizedBox.shrink()],
          floating: true,
          snap: true,
          titleSpacing: 0,
          toolbarHeight: kToolbarHeight,
          title: AppBarHome(title: s.Explore_Title, transparent: true, showSettings: true),
        ),
        SliverToBoxAdapter(
          child: _SearchTile(onTap: () => openAnilistSearch(context, category: category)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kExplorePadding, 14, kExplorePadding, 4),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: 'anime', icon: const Icon(Icons.tv_rounded, size: 18), label: Text(s.Explore_Anime)),
                ButtonSegment(
                    value: 'manga',
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text(s.Explore_Manga)),
              ],
              selected: {category},
              onSelectionChanged: (v) => setState(() => _category = v.first),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kExplorePadding, 8, kExplorePadding, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (category == 'anime')
                  ActionChip(
                    avatar: const Icon(Icons.calendar_view_month_rounded, size: 18),
                    label: Text(s.Ahx_Entry_Season),
                    onPressed: () => openAnilistSeason(context),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.sell_outlined, size: 18),
                  label: Text(s.Ahx_Entry_Tags),
                  onPressed: () => openAnilistTagExplorer(context, category: category),
                ),
              ],
            ),
          ),
        ),
        FutureBuilder<AnilistFeed>(
          key: ValueKey('al-explore-feed-$category'),
          future: _feed(),
          builder: (context, snapshot) => SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              return RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExploreSectionHeader(title: row.title(), onViewAll: _viewAll(row)),
                    _body(row, snapshot, cardWidth, cardHeight),
                  ],
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: ExploreSectionHeader(title: s.Hw_Chip_Genres)),
        SliverToBoxAdapter(
          child: FutureBuilder<(AnilistCatalogData, bool)>(
            future: _genres,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final genres = data == null ? AnilistDiscoverService.genres : data.$1.genresFor(adult: data.$2);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final genre in genres)
                      ActionChip(
                        label: Text(genre),
                        onPressed: () => openAnilistBrowse(
                          context,
                          genre,
                          AnilistMediaQuery(category: category, sort: 'POPULARITY_DESC', genre: genre),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _body(_Row row, AsyncSnapshot<AnilistFeed> snapshot, double cardWidth, double cardHeight) {
    void retry() => setState(() => _feed(force: true));
    if (snapshot.hasError) return AnilistRowMessage(failed: true, onRetry: retry);
    final feed = snapshot.data;
    if (feed == null) {
      return switch (row.kind) {
        _Kind.reviews => const SizedBox(height: AnilistReviewCardRow.height),
        _Kind.recommendations => const SizedBox(height: AnilistRecommendationPairRow.height),
        _Kind.characters || _Kind.staff => const SizedBox(height: AnilistPeopleRow.height),
        _ => anilistRowSkeleton(cardWidth: cardWidth, cardHeight: cardHeight),
      };
    }
    Widget orMessage<T>(List<T>? items, Widget Function(List<T> items) builder) {
      if (items == null || items.isEmpty) return AnilistRowMessage(failed: items == null, onRetry: retry);
      return builder(items);
    }

    return switch (row.kind) {
      _Kind.media => orMessage(feed.media(row.alias),
          (items) => AnilistMediaCardRow(items: items, cardWidth: cardWidth, cardHeight: cardHeight)),
      _Kind.airing => orMessage(feed.airing(row.alias),
          (items) => AnilistMediaCardRow(items: items, cardWidth: cardWidth, cardHeight: cardHeight)),
      _Kind.trends => orMessage(feed.trends(row.alias),
          (items) => AnilistTrendRow(items: items, cardWidth: cardWidth, cardHeight: cardHeight)),
      _Kind.reviews => orMessage(feed.reviews(row.alias), (items) => AnilistReviewCardRow(items: items)),
      _Kind.recommendations => orMessage(
          feed.recommendations(row.alias), (items) => AnilistRecommendationPairRow(items: items)),
      _Kind.characters =>
        orMessage(feed.people(row.alias, isStaff: false), (items) => AnilistPeopleRow(items: items)),
      _Kind.staff => orMessage(feed.people(row.alias, isStaff: true), (items) => AnilistPeopleRow(items: items)),
    };
  }
}

class _SearchTile extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 18),
                Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    S.current.Al_Search_Hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
