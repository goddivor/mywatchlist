import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuFeedPost;
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_parts.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Anime;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Whether the Kitsu home can draw [section]: a catalogue row, the user's list or the Kitsu news.
bool kitsuSectionSupported(HomeSectionPreference section) =>
    kitsuQueryForSection(section) != null ||
    section.type == SectionType.userList ||
    section.type == SectionType.news;

/// The Kitsu search that fills a home section of the user's home layout, or null when Kitsu has
/// no equivalent (features, suggestions, forum) or the section is not a catalogue row (the user's own list,
/// the news, which come from the Kitsu News Network group).
KitsuMediaQuery? kitsuQueryForSection(HomeSectionPreference section) {
  KitsuMediaQuery anime(
          {Map<String, String> filters = const {}, String? sort}) =>
      KitsuMediaQuery(isAnime: true, filters: filters, sort: sort);
  KitsuMediaQuery manga(
          {Map<String, String> filters = const {}, String? sort}) =>
      KitsuMediaQuery(isAnime: false, filters: filters, sort: sort);

  switch (section.type) {
    case SectionType.seasonNow:
      return anime(filters: {
        'season': section.effectiveSeason.name.toLowerCase(),
        'seasonYear': '${section.effectiveYear}',
      }, sort: '-userCount');
    case SectionType.upcoming:
      return anime(filters: {'status': 'upcoming'}, sort: '-userCount');
    case SectionType.topScore:
      return anime(sort: 'ratingRank');
    case SectionType.topFavorites:
      return anime(sort: '-favoritesCount');
    case SectionType.topPopular:
      return anime(sort: 'popularityRank');
    case SectionType.topAnimeAiring:
      return anime(filters: {'status': 'current'}, sort: '-userCount');
    case SectionType.topAnimeTV:
      return anime(filters: {'subtype': 'TV'}, sort: 'ratingRank');
    case SectionType.topAnimeMovie:
      return anime(filters: {'subtype': 'movie'}, sort: 'ratingRank');
    case SectionType.topAnimeSpecial:
      return anime(filters: {'subtype': 'special'}, sort: 'ratingRank');
    case SectionType.topManga:
      return manga(sort: 'ratingRank');
    case SectionType.topMangaPopular:
      return manga(sort: 'popularityRank');
    case SectionType.topAnimeOva:
      return anime(filters: {'subtype': 'OVA'}, sort: 'ratingRank');
    case SectionType.topAnimeOna:
      return anime(filters: {'subtype': 'ONA'}, sort: 'ratingRank');
    case SectionType.topMangaOnly:
      return manga(filters: {'subtype': 'manga'}, sort: 'ratingRank');
    case SectionType.topMangaFavorites:
      return manga(sort: '-favoritesCount');
    case SectionType.topOneshots:
      return manga(filters: {'subtype': 'oneshot'}, sort: 'ratingRank');
    case SectionType.topDoujin:
      return manga(filters: {'subtype': 'doujin'}, sort: 'ratingRank');
    // Kitsu has one `novel` subtype for light novels and novels alike.
    case SectionType.topLightNovels:
    case SectionType.topNovels:
      return manga(filters: {'subtype': 'novel'}, sort: 'ratingRank');
    case SectionType.topManhwa:
      return manga(filters: {'subtype': 'manhwa'}, sort: 'ratingRank');
    case SectionType.topManhua:
      return manga(filters: {'subtype': 'manhua'}, sort: 'ratingRank');
    case SectionType.news:
    case SectionType.suggested:
    case SectionType.features:
    case SectionType.userList:
    case SectionType.forum:
      return null;
  }
}

/// The home-card model of a list entry; null when Kitsu maps its title to no MyAnimeList page.
Anime? kitsuEntryToAnime(ListEntryView entry) {
  final mal = entry.malId;
  if (mal == null) return null;
  return Anime(
    id: mal,
    title: entry.title,
    imageUrl: entry.largeImageUrl ?? entry.imageUrl ?? '',
    score: entry.meanScore ?? 0,
    members: entry.members ?? 0,
    popularity: entry.popularity,
    numEpisodes: entry.isAnime ? entry.total : null,
    numVolumes: entry.totalVolumes == 0 ? null : entry.totalVolumes,
    startDate: entry.releaseStart,
    endDate: entry.releaseEnd,
    mediaType: entry.mediaType,
  );
}

/// The "News" row of the home: the latest posts of the Kitsu News Network group as cards, each
/// opening its thread. Draws nothing when the group answers nothing, since a failing bonus row
/// would only be noise; "View all" opens the whole news feed.
class KitsuNewsRow extends StatelessWidget {
  final String title;
  final int limit;
  final Duration maxAge;
  final int refresh;
  final KitsuFeed? feed;
  final void Function(KitsuFeedPost post) onOpenPost;
  final VoidCallback? onViewAll;

  const KitsuNewsRow({
    super.key,
    required this.title,
    required this.onOpenPost,
    this.limit = 10,
    this.maxAge = const Duration(hours: 1),
    this.refresh = 0,
    this.feed,
    this.onViewAll,
  });

  static const double cardWidth = 290;
  static const double cardHeight = 150;

  @override
  Widget build(BuildContext context) {
    Widget section(Widget body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SectionHeader(title: title, onTap: onViewAll), body],
          ),
        );
    final count = limit.clamp(1, 20);
    return HomeAsync<List<KitsuFeedPost>>(
      cacheKey: 'kitsu:news:$count',
      maxAge: maxAge,
      refresh: refresh,
      load: () async {
        try {
          return await (feed ?? KitsuFeed()).newsPosts(limit: count);
        } catch (_) {
          return const <KitsuFeedPost>[];
        }
      },
      loading: section(const SizedBox(height: cardHeight)),
      builder: (context, posts) => posts.isEmpty
          ? const SizedBox.shrink()
          : section(SizedBox(
              height: cardHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: posts.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    KitsuNewsCard(post: posts[i], onTap: () => onOpenPost(posts[i])),
              ),
            )),
    );
  }
}

/// One news post in the home row: author and time, then the first lines of text.
class KitsuNewsCard extends StatelessWidget {
  final KitsuFeedPost post;
  final VoidCallback onTap;

  const KitsuNewsCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = post.user;
    return SizedBox(
      width: KitsuNewsRow.cardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KitsuByline(
                  name: user?.name ?? '?',
                  avatarUrl: user?.avatarUrl,
                  at: post.createdAt,
                  nsfw: post.isNsfw,
                  avatarSize: 30,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ClipRect(
                    child: KitsuGuardedBody(
                      text: post.content,
                      isSpoiler: post.isSpoiler,
                      isNsfw: post.isNsfw,
                      maxLines: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
