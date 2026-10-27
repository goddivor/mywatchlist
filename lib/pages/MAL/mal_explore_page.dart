import 'package:flutter/material.dart';
import 'package:mwl_commons/mwl_commons.dart' show InterestStack, RankedPersonHtml, ReviewHtml;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/explore/explore_list_screen.dart';
import 'package:mywatchlist/screens/explore/explore_sections.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/explore/random_picker.dart';
import 'package:mywatchlist/utils/app_routes.dart';

/// The Explore tab: random picks, rankings, genres, the current season, and what the MyAnimeList
/// community is recommending, reviewing, stacking and loving.
///
/// Every data section below the first screen loads only when it scrolls near the viewport
/// ([AsyncSection]) and its answer is cached for ten minutes, so switching between Anime and
/// Manga or coming back to the tab is instant. Searching lives in the search screen, opened from
/// the bar at the top.
class MalExplorePage extends StatefulWidget {
  const MalExplorePage({super.key});

  @override
  State<MalExplorePage> createState() => _MalExplorePageState();
}

class _MalExplorePageState extends State<MalExplorePage> {
  String _category = 'anime';

  bool get _isAnime => _category == 'anime';

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final isAnime = _isAnime;
    return CustomScrollView(
      key: PageStorageKey('explore-$category'),
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          title: Text(S.current.Explore_Title),
          actions: [
            IconButton(
              tooltip: S.current.WeeklyAnime,
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () => AppRoutes.openCalendar(context),
            ),
            IconButton(
              tooltip: S.current.Search,
              icon: const Icon(Icons.search_rounded),
              onPressed: () => AppRoutes.openSearch(context),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverToBoxAdapter(child: _SearchBarTile(onTap: () => AppRoutes.openSearch(context))),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kExplorePadding, 14, kExplorePadding, 14),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: 'anime',
                    icon: const Icon(Icons.tv_rounded, size: 18),
                    label: Text(S.current.Explore_Anime)),
                ButtonSegment(
                    value: 'manga',
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text(S.current.Explore_Manga)),
              ],
              selected: {category},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
          ),
        ),
        SliverToBoxAdapter(child: RandomPickerRow(isAnime: isAnime)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Explore_Rankings,
            onViewAll: () => AppRoutes.push<void>(context, RankingsScreen(isAnime: isAnime)),
          ),
        ),
        SliverToBoxAdapter(child: RankingsRow(isAnime: isAnime)),
        SliverToBoxAdapter(child: ExploreSectionHeader(title: S.current.Genres)),
        SliverToBoxAdapter(child: GenresRow(category: category)),
        if (isAnime) ...[
          SliverToBoxAdapter(child: ExploreSectionHeader(title: S.current.Seasonal)),
          const SliverToBoxAdapter(child: SeasonalCard()),
        ],
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Recommendations,
            onViewAll: () => AppRoutes.push<void>(
              context,
              ExploreListScreen<CommunityRecommendation>(
                title: S.current.Recommendations,
                paged: false,
                itemExtent: 372,
                loadPage: (_) => ExploreData.recommendations(category, limit: 100),
                itemBuilder: (_, item) => RecommendationCard(
                    item: item, category: category, width: double.infinity),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _RecommendationsStrip(category: category)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Reviews,
            onViewAll: () => AppRoutes.push<void>(
              context,
              ExploreListScreen<ReviewHtml>(
                title: S.current.Reviews,
                itemExtent: 272,
                loadPage: (page) => ExploreData.reviews(category, page: page),
                itemBuilder: (_, review) =>
                    ReviewCard(review: review, category: category, width: double.infinity),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _ReviewsStrip(category: category)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Interest_Stacks,
            onViewAll: () => AppRoutes.push<void>(
              context,
              ExploreListScreen<InterestStack>(
                title: S.current.Interest_Stacks,
                itemExtent: 268,
                loadPage: (page) => ExploreData.interestStacks(category, page: page),
                itemBuilder: (_, stack) => StackCard(stack: stack, width: double.infinity),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _StacksStrip(category: category)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Characters,
            onViewAll: () => AppRoutes.push<void>(context, _peopleScreen(isPerson: false)),
          ),
        ),
        const SliverToBoxAdapter(child: _PeopleStrip(isPerson: false)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Seiyuu,
            onViewAll: () => AppRoutes.push<void>(context, _peopleScreen(isPerson: true)),
          ),
        ),
        const SliverToBoxAdapter(child: _PeopleStrip(isPerson: true)),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _peopleScreen({required bool isPerson}) => ExploreListScreen<RankedPersonHtml>(
        title: isPerson ? S.current.Seiyuu : S.current.Characters,
        grid: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 124,
          mainAxisExtent: 236,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
        ),
        loadPage: (page) =>
            isPerson ? ExploreData.topPeople(page: page) : ExploreData.topCharacters(page: page),
        itemBuilder: (_, p) => PersonTile(person: p, isPerson: isPerson),
      );
}

/// Fake search field: tapping it opens the search screen.
class _SearchBarTile extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBarTile({required this.onTap});

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
                    S.current.Explore_Search_Hint,
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

class _RecommendationsStrip extends StatelessWidget {
  final String category;

  const _RecommendationsStrip({required this.category});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<CommunityRecommendation>>(
      reloadKey: category,
      load: () => ExploreData.recommendations(category),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 320, width: 290),
      builder: (context, list) => HorizontalStrip(
        height: 340,
        count: list.length,
        itemBuilder: (context, i) => RecommendationCard(item: list[i], category: category),
      ),
    );
  }
}

class _ReviewsStrip extends StatelessWidget {
  final String category;

  const _ReviewsStrip({required this.category});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<ReviewHtml>>(
      reloadKey: category,
      load: () => ExploreData.reviews(category),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 240, width: 290),
      builder: (context, list) => HorizontalStrip(
        height: 260,
        count: list.length,
        itemBuilder: (context, i) => ReviewCard(review: list[i], category: category),
      ),
    );
  }
}

class _StacksStrip extends StatelessWidget {
  final String category;

  const _StacksStrip({required this.category});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<InterestStack>>(
      reloadKey: category,
      load: () => ExploreData.interestStacks(category),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 230, width: 250),
      builder: (context, list) => HorizontalStrip(
        height: 250,
        count: list.length,
        itemBuilder: (context, i) => StackCard(stack: list[i]),
      ),
    );
  }
}

class _PeopleStrip extends StatelessWidget {
  final bool isPerson;

  const _PeopleStrip({required this.isPerson});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<RankedPersonHtml>>(
      reloadKey: isPerson ? 'people' : 'characters',
      load: () => isPerson ? ExploreData.topPeople() : ExploreData.topCharacters(),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 200, width: 110),
      builder: (context, list) {
        final shown = list.take(20).toList();
        return HorizontalStrip(
          height: 236,
          count: shown.length,
          itemBuilder: (context, i) => PersonTile(person: shown[i], isPerson: isPerson),
        );
      },
    );
  }
}
