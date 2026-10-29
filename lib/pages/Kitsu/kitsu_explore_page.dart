import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, HomePageTileSize, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_browse_screen.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuCategory;
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart' show KitsuMedia;
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_open.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_row.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';

/// The Kitsu Explore tab in the order of kitsu.app's explore page: a search bar (the Kitsu
/// catalogue), an Anime / Manga switch, "Surprise me" (any title, or one of the user's own
/// "Want to watch" when signed in), then trending this week, airing now, upcoming, highest
/// rated, most popular and the biggest categories. Each row has its own "View all" grid.
class KitsuExplorePage extends StatefulWidget {
  const KitsuExplorePage({super.key});

  @override
  State<KitsuExplorePage> createState() => _KitsuExplorePageState();
}

class _KitsuExplorePageState extends State<KitsuExplorePage> {
  bool _isAnime = true;
  int _refresh = 0;
  bool _picking = false;

  /// Opens a random title of the current kind: any title of the catalogue, or with [planned]
  /// one of the user's own "Want to watch" (or "Want to read") list.
  Future<void> _surprise({bool planned = false}) async {
    if (_picking) return;
    setState(() => _picking = true);
    final isAnime = _isAnime;
    KitsuMedia? pick;
    var failed = false;
    try {
      pick = planned
          ? await KitsuCatalog.instance.randomPlanned(await KitsuLibrary.instance.userId(), isAnime: isAnime)
          : await KitsuCatalog.instance.randomMedia(isAnime: isAnime, needsMalPage: false);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _picking = false);
    if (pick != null) {
      openKitsuMedia(context, pick);
      return;
    }
    final s = S.current;
    final message = planned && !failed
        ? (isAnime ? s.Kr_Planned_Empty : s.Kr_Planned_Empty_Manga)
        : s.Kitsu_Surprise_Failed;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onRefresh() async {
    HomeSectionCache.clear();
    setState(() => _refresh++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tile = getTileSizeValues(HomePageTileSize.m);
    final h = tile.containerHeight;
    final w = h * (2 / 3);
    final isAnime = _isAnime;

    Widget row(String id, String title, KitsuMediaQuery query) => KitsuMediaRow.query(
          key: ValueKey('$id:${query.key}'),
          title: title,
          query: query,
          cardWidth: w,
          cardHeight: h,
          refresh: _refresh,
          onViewAll: () =>
              AppRoutes.push<void>(context, KitsuBrowseScreen(title: title, query: query)),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              // Empty list does not suppress the automatic endDrawer button; a placeholder does.
              actions: const [SizedBox.shrink()],
              floating: true,
              snap: true,
              titleSpacing: 0,
              toolbarHeight: kToolbarHeight,
              backgroundColor: Colors.transparent,
              title: AppBarHome(title: s.Explore_Title, transparent: true, showSettings: true),
            ),
            SliverToBoxAdapter(
              child: _SearchTile(
                onTap: () => AppRoutes.push<void>(
                    context, KitsuBrowseScreen.search(isAnime: isAnime)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.tv_rounded, size: 18),
                        label: Text(s.Explore_Anime)),
                    ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: Text(s.Explore_Manga)),
                  ],
                  selected: {isAnime},
                  onSelectionChanged: (v) => setState(() => _isAnime = v.first),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: ListenableBuilder(
                  listenable: UserManager.instance,
                  builder: (context, _) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _picking ? null : () => _surprise(),
                        icon: _picking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.casino_outlined, size: 18),
                        label: Text(s.Kitsu_Surprise_Me),
                      ),
                      if (UserManager.instance.isAuthenticated(AccountType.kitsu))
                        OutlinedButton.icon(
                          onPressed: _picking ? null : () => _surprise(planned: true),
                          icon: const Icon(Icons.bookmark_outline_rounded, size: 18),
                          label: Text(isAnime ? s.Kr_Surprise_Planned : s.Kr_Surprise_Planned_Manga),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: KitsuMediaRow(
                key: ValueKey('trending:$isAnime'),
                cacheKey: 'kitsu:trending:${isAnime ? 'anime' : 'manga'}',
                title: isAnime ? s.Kitsu_Trending : s.Kitsu_Trending_Manga,
                isAnime: isAnime,
                load: () => KitsuCatalog.instance.trending(isAnime: isAnime),
                cardWidth: w,
                cardHeight: h,
                refresh: _refresh,
              ),
            ),
            SliverToBoxAdapter(
              child: row(
                  'now',
                  isAnime ? s.Kitsu_Row_Airing : s.Kitsu_Row_Publishing,
                  KitsuMediaQuery(
                      isAnime: isAnime, filters: const {'status': 'current'}, sort: '-userCount')),
            ),
            SliverToBoxAdapter(
              child: row(
                  'soon',
                  s.Kitsu_Row_Upcoming,
                  KitsuMediaQuery(
                      isAnime: isAnime,
                      filters: const {'status': 'upcoming'},
                      sort: '-userCount')),
            ),
            SliverToBoxAdapter(
              child: row('top', s.Kitsu_Row_Top_Rated,
                  KitsuMediaQuery(isAnime: isAnime, sort: 'ratingRank')),
            ),
            SliverToBoxAdapter(
              child: row('popular', s.Kitsu_Row_Popular,
                  KitsuMediaQuery(isAnime: isAnime, sort: 'popularityRank')),
            ),
            SliverToBoxAdapter(child: SectionHeader(title: s.Kitsu_Categories)),
            SliverToBoxAdapter(
              child: HomeAsync<List<KitsuCategory>>(
                cacheKey: 'kitsu:categories',
                maxAge: const Duration(hours: 24),
                refresh: _refresh,
                load: () => KitsuCatalog.instance.categories(),
                loading: const SizedBox(height: 96),
                builder: (context, categories) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categories)
                        ActionChip(
                          label: Text(c.title),
                          onPressed: () => AppRoutes.push<void>(
                            context,
                            KitsuBrowseScreen(
                              title: c.title,
                              trendingCategoryId: c.id,
                              query: KitsuMediaQuery(
                                isAnime: isAnime,
                                filters: {'categories': c.slug},
                                sort: 'popularityRank',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    S.current.Kitsu_Search_Hint,
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
