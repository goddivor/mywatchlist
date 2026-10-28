import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show HomePageTileSize, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart'
    show AsyncSection, ExploreSectionHeader, kExplorePadding;
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_media_card.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';

/// One row of the AniList Explore tab.
class _Row {
  final String Function() title;

  /// Null = the episodes airing in the next 24 hours.
  final AnilistMediaQuery? query;
  const _Row(this.title, this.query);
}

/// The Explore tab for AniList: search, an Anime / Manga switch and rows of what is airing,
/// trending, new, upcoming, best rated and most popular, then the genres. Every row loads when
/// it scrolls near and is kept for ten minutes, so switching Anime / Manga or coming back to the
/// tab is instant.
class AnilistExplorePage extends StatefulWidget {
  const AnilistExplorePage({super.key});

  @override
  State<AnilistExplorePage> createState() => _AnilistExplorePageState();
}

class _AnilistExplorePageState extends State<AnilistExplorePage> {
  String _category = 'anime';

  List<_Row> _rows() {
    final (season, year) = AnilistDiscoverService.seasonOf(DateTime.now());
    if (_category == 'manga') {
      return [
        _Row(() => S.current.Al_Sec_Trending,
            const AnilistMediaQuery(category: 'manga', sort: 'TRENDING_DESC')),
        _Row(() => S.current.Al_Sec_Publishing,
            const AnilistMediaQuery(category: 'manga', sort: 'POPULARITY_DESC', status: 'RELEASING')),
        _Row(() => S.current.Hw_Sec_Top_Manga,
            const AnilistMediaQuery(category: 'manga', sort: 'SCORE_DESC')),
        _Row(() => S.current.Hw_Sec_Popular_Manga,
            const AnilistMediaQuery(category: 'manga', sort: 'POPULARITY_DESC')),
      ];
    }
    return [
      _Row(() => S.current.Al_Sec_Airing_Soon, null),
      _Row(() => S.current.Al_Sec_Trending,
          const AnilistMediaQuery(category: 'anime', sort: 'TRENDING_DESC')),
      _Row(
          () => S.current.Hw_Sec_Season(_seasonLabel(season), '$year'),
          AnilistMediaQuery(
              category: 'anime', sort: 'POPULARITY_DESC', season: season, seasonYear: year)),
      _Row(() => S.current.Hw_Sec_Upcoming,
          const AnilistMediaQuery(category: 'anime', sort: 'POPULARITY_DESC', status: 'NOT_YET_RELEASED')),
      _Row(() => S.current.Hw_Sec_Top_Score,
          const AnilistMediaQuery(category: 'anime', sort: 'SCORE_DESC')),
      _Row(() => S.current.Hw_Sec_Popular,
          const AnilistMediaQuery(category: 'anime', sort: 'POPULARITY_DESC')),
    ];
  }

  static String _seasonLabel(String season) {
    final s = S.current;
    return switch (season) {
      'WINTER' => s.Explore_Season_Winter,
      'SPRING' => s.Explore_Season_Spring,
      'SUMMER' => s.Explore_Season_Summer,
      _ => s.Explore_Season_Fall,
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
                    value: 'anime',
                    icon: const Icon(Icons.tv_rounded, size: 18),
                    label: Text(s.Explore_Anime)),
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
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];
            final query = row.query;
            return RepaintBoundary(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExploreSectionHeader(
                    title: row.title(),
                    onViewAll: query == null
                        ? null
                        : () => openAnilistBrowse(context, row.title(), query),
                  ),
                  AsyncSection<List<AnilistMedia>>(
                    reloadKey: '$category#$i',
                    load: () => query == null
                        ? AnilistDiscoverService.instance.airingSoon()
                        : AnilistDiscoverService.instance.row(query),
                    isEmpty: (items) => items.isEmpty,
                    skeleton: loadingCardList(
                      containerHeight: cardHeight,
                      height: cardHeight,
                      width: cardWidth,
                      itemCount: 6,
                      listPadding: const EdgeInsets.all(8),
                    ),
                    builder: (context, items) => AnilistMediaRow(
                        items: items, cardWidth: cardWidth, cardHeight: cardHeight),
                  ),
                ],
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(title: s.Hw_Chip_Genres),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final genre in AnilistDiscoverService.genres)
                  ActionChip(
                    label: Text(genre),
                    onPressed: () => openAnilistBrowse(
                      context,
                      genre,
                      AnilistMediaQuery(
                          category: category, sort: 'POPULARITY_DESC', genre: genre),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
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
