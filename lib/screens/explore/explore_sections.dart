import 'package:flutter/material.dart';
import 'package:mwl_commons/mwl_commons.dart' show InterestStack, RankedPersonHtml, ReviewHtml;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_screen.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/search/filtermodal.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Search query of a ranking (`#all`, `#bypopularity@manga`…), what the search screen understands.
String rankingQuery(Enum ranking, {required bool isAnime}) => isAnime
    ? '#${rankingMap[ranking]}'
    : '#${mangaRankingMap[ranking]}@manga';

IconData _rankingIcon(Enum ranking) => switch (ranking) {
      RankingType.UPCOMING => Icons.event_available_rounded,
      RankingType.BYPOPULARITY || MangaRanking.bypopularity => Icons.local_fire_department_rounded,
      RankingType.ALL || MangaRanking.all => Icons.emoji_events_rounded,
      RankingType.AIRING => Icons.sensors_rounded,
      RankingType.FAVOURITE || MangaRanking.favorite => Icons.favorite_rounded,
      RankingType.MOVIE => Icons.movie_rounded,
      RankingType.OVA => Icons.album_rounded,
      RankingType.SPECIAL => Icons.auto_awesome_rounded,
      RankingType.TV => Icons.tv_rounded,
      RankingType.ONA => Icons.public_rounded,
      MangaRanking.manga => Icons.menu_book_rounded,
      MangaRanking.lightnovels || MangaRanking.novels => Icons.auto_stories_rounded,
      MangaRanking.manhwa || MangaRanking.manhua => Icons.translate_rounded,
      MangaRanking.oneshots => Icons.bolt_rounded,
      MangaRanking.doujin => Icons.draw_rounded,
      _ => Icons.leaderboard_rounded,
    };

/// Translated rankings of a category, in the order Explore shows them.
List<({Enum ranking, String label})> rankingEntries(bool isAnime) {
  final map = isAnime
      ? desiredTopAnimeOrderSS(S.current)
      : desiredMangaRankingMapSS(S.current);
  return [for (final e in map.entries) (ranking: e.key, label: e.value)];
}

/// Rankings (top by score, popularity, airing…) as a row of tiles that open the search screen.
class RankingsRow extends StatelessWidget {
  final bool isAnime;

  const RankingsRow({super.key, required this.isAnime});

  @override
  Widget build(BuildContext context) {
    final entries = rankingEntries(isAnime);
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = entries[i];
          return ExploreTile(
            icon: _rankingIcon(e.ranking),
            label: e.label,
            hue: 18.0 + i * 34,
            onTap: () => AppRoutes.openSearch(context, query: rankingQuery(e.ranking, isAnime: isAnime)),
          );
        },
      ),
    );
  }
}

/// Every ranking as a grid (the "View all" of the rankings row).
class RankingsScreen extends StatelessWidget {
  final bool isAnime;

  const RankingsScreen({super.key, required this.isAnime});

  @override
  Widget build(BuildContext context) {
    final entries = rankingEntries(isAnime);
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Explore_Rankings)),
      body: GridView.builder(
        padding: const EdgeInsets.all(kExplorePadding),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          mainAxisExtent: 96,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          return ExploreTile(
            icon: _rankingIcon(e.ranking),
            label: e.label,
            hue: 18.0 + i * 34,
            width: double.infinity,
            height: 96,
            onTap: () => AppRoutes.openSearch(context, query: rankingQuery(e.ranking, isAnime: isAnime)),
          );
        },
      ),
    );
  }
}

String _genreGroupLabel(String type) => switch (type) {
      'Genres' => S.current.Genres,
      'Themes' => S.current.Explore_Genre_Themes,
      'Demographics' => S.current.Explore_Genre_Demographics,
      'Explicit Genres' => S.current.Explore_Genre_Explicit,
      _ => type,
    };

IconData _genreGroupIcon(String type) => switch (type) {
      'Themes' => Icons.palette_rounded,
      'Demographics' => Icons.groups_rounded,
      'Explicit Genres' => Icons.eighteen_up_rating_rounded,
      _ => Icons.category_rounded,
    };

/// Genre groups (Genres, Themes, Demographics) as tiles; a tile opens the genres of its group.
class GenresRow extends StatelessWidget {
  final String category;

  const GenresRow({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<GenreGroup>>(
      reloadKey: category,
      load: () => ExploreData.genreGroups(category),
      isEmpty: (groups) => groups.isEmpty,
      skeleton: horizontalSkeleton(height: 92, width: 148),
      builder: (context, groups) => SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final group = groups[i];
            return ExploreTile(
              icon: _genreGroupIcon(group.type),
              label: _genreGroupLabel(group.type),
              caption: '${group.genres.length}',
              hue: 200.0 + i * 55,
              onTap: () => _showGenres(context, group, category),
            );
          },
        ),
      ),
    );
  }

  void _showGenres(BuildContext context, GenreGroup group, String category) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, controller) => CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(kExplorePadding, 0, kExplorePadding, 12),
                child: Text(_genreGroupLabel(group.type),
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(kExplorePadding, 0, kExplorePadding, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 52,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: group.genres.length,
                itemBuilder: (_, i) {
                  final genre = group.genres[i];
                  return _GenreChip(
                    name: genre.name.replaceAll('_', ' '),
                    count: genre.count,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _openGenre(context, genre.name, category);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGenre(BuildContext context, String name, String category) {
    AppRoutes.push<void>(
      context,
      GeneralSearchScreen(
        category: category,
        showBackButton: true,
        filterOutputs: {
          'genres': FilterOption(
            type: FilterType.multiple,
            apiFieldName: 'genres',
            includedOptions: [name],
            excludedOptions: const [],
          ),
        },
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;

  const _GenreChip({required this.name, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              if (count > 0)
                Text(compactCount(context, count),
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current season with a shortcut to browse any season and to the weekly schedule.
class SeasonalCard extends StatelessWidget {
  const SeasonalCard({super.key});

  @override
  Widget build(BuildContext context) {
    final now = SeasonKey.current();
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(20));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: 168,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(seasonImage(now.season), fit: BoxFit.cover, cacheWidth: 900),
              // Static scrim (no blur, no opacity layer) keeps the text readable on any picture.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0xCC000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(seasonIcon(now.season), color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Text(now.label,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => AppRoutes.push<void>(
                                context, SeasonalScreen(initial: now)),
                            icon: const Icon(Icons.grid_view_rounded, size: 18),
                            label: Text(S.current.Search_By_Season,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => AppRoutes.openCalendar(context),
                            icon: const Icon(Icons.calendar_month_rounded, size: 18),
                            label: Text(S.current.WeeklyAnime,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A recommendation card: the liked title, the suggested one, and the reason.
class RecommendationCard extends StatelessWidget {
  final CommunityRecommendation item;
  final String category;
  final double width;

  const RecommendationCard({super.key, required this.item, required this.category, this.width = 300});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget side(String caption, RecoRef ref) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => AppRoutes.openContent(context, id: ref.id, category: category),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                AppImage(
                  url: ref.imageUrl,
                  height: 128,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 4),
                Text(ref.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  side(S.current.If_You_Liked, item.first),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 64, 6, 0),
                    child: Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.primary),
                  ),
                  side(S.current.Then_You_Might, item.second),
                ],
              ),
              if (item.text != null) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: Text(item.text!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                ),
              ] else
                const Spacer(),
              if (item.username != null)
                InkWell(
                  onTap: () => AppRoutes.openUserProfile(context,
                      tracker: AccountType.myanimelist, username: item.username),
                  child: Text(S.current.Explore_Reco_By(item.username!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A review: reviewer, score, the reviewed title and the start of the text.
class ReviewCard extends StatelessWidget {
  final ReviewHtml review;
  final String category;
  final double width;

  const ReviewCard({super.key, required this.review, required this.category, this.width = 300});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final node = review.relatedNode;
    final score = review.overallRating;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: node?.id == null
              ? null
              : () => AppRoutes.openContent(context, id: node!.id!, category: node.category ?? category),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppImage(
                      url: review.userPicture?.best,
                      width: 36,
                      height: 36,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review.username ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (review.timeAdded != null)
                            Text(review.timeAdded!,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (score != null && score.isNotEmpty)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: scheme.onPrimaryContainer),
                              const SizedBox(width: 3),
                              Text(score,
                                  style: TextStyle(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (node?.title != null) ...[
                  const SizedBox(height: 10),
                  Text(node!.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
                ],
                const SizedBox(height: 6),
                Expanded(
                  child: Text(review.reviewText ?? '',
                      overflow: TextOverflow.fade, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An interest stack: a strip of covers, its title, author and size.
class StackCard extends StatelessWidget {
  final InterestStack stack;
  final double width;

  const StackCard({super.key, required this.stack, this.width = 260});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final images = (stack.imageUrls ?? const <String>[]).take(3).toList();
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AppRoutes.push<void>(context, InterestStackDetailScreen(stack: stack)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                child: Row(
                  children: [
                    for (final url in images)
                      Expanded(child: AppImage(url: url, height: 120, width: width / images.length)),
                    if (images.isEmpty)
                      Expanded(child: ColoredBox(color: scheme.surfaceContainerHighest)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stack.title ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (stack.username != null) S.current.Explore_Reco_By(stack.username!),
                        if (stack.entries != null) S.current.Explore_Stack_Entries(stack.entries!),
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ranked character or voice actor with their favorites count.
class PersonTile extends StatelessWidget {
  final RankedPersonHtml person;
  final bool isPerson;

  const PersonTile({super.key, required this.person, required this.isPerson});

  @override
  Widget build(BuildContext context) {
    return PosterTile(
      imageUrl: person.image?.best,
      title: person.name,
      subtitle: isPerson ? person.birthday : person.otherName,
      width: 110,
      imageHeight: 150,
      badge: person.rank == null ? null : CornerBadge('#${person.rank}'),
      onTap: () => AppRoutes.push<void>(
        context,
        CharacterScreen(id: person.id, category: isPerson ? 'person' : 'character'),
      ),
    );
  }
}

/// Horizontal strip of [children] built lazily, with the Explore side margins.
class HorizontalStrip extends StatelessWidget {
  final double height;
  final int count;
  final double gap;
  final IndexedWidgetBuilder itemBuilder;

  const HorizontalStrip({
    super.key,
    required this.height,
    required this.count,
    required this.itemBuilder,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kExplorePadding),
        itemCount: count,
        separatorBuilder: (_, __) => SizedBox(width: gap),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
