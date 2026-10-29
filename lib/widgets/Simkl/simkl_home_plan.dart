import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';

/// What one Simkl home row shows: the user's titles in progress, or a Simkl catalogue list.
class SimklHomeBlock {
  /// Null = "Continue watching" (the user's list).
  final SimklFeed? feed;

  /// Titles in the row ([HomeSectionPreference.itemCount]).
  final int limit;

  const SimklHomeBlock(this.feed, this.limit);

  String get key => feed?.name ?? 'continue';

  @override
  bool operator ==(Object other) =>
      other is SimklHomeBlock && other.feed == feed && other.limit == limit;

  @override
  int get hashCode => Object.hash(feed, limit);
}

/// The Simkl home rows for the shared home preferences (the sections the user enabled, in their
/// order): MyAnimeList-only kinds (news, features, manga rankings, forum) have no Simkl
/// counterpart and are skipped, the anime rankings become the closest Simkl list (top score is
/// Simkl's Best anime), and each Simkl list shows once.
///
/// "Continue watching" follows the user list section; preferences saved without one show it
/// first, so the row exists out of the box.
List<SimklHomeBlock> simklHomePlan(List<HomeSectionPreference> sections) {
  final blocks = <SimklHomeBlock>[];
  final seen = <SimklFeed?>{};
  void add(SimklFeed? feed, HomeSectionPreference section) {
    if (seen.add(feed)) blocks.add(SimklHomeBlock(feed, section.itemCount));
  }

  final hasUserList = sections.any((s) => s.type == SectionType.userList);
  if (!hasUserList) {
    blocks.add(const SimklHomeBlock(null, 20));
    seen.add(null);
  }
  for (final section in sections) {
    if (!section.enabled) continue;
    switch (section.type) {
      case SectionType.userList:
        add(null, section);
      case SectionType.seasonNow:
      case SectionType.upcoming:
        add(SimklFeed.premieres, section);
      case SectionType.topAnimeAiring:
        add(SimklFeed.airing, section);
      case SectionType.topScore:
        add(SimklFeed.best, section);
      case SectionType.suggested:
      case SectionType.topFavorites:
      case SectionType.topPopular:
      case SectionType.topAnimeTV:
      case SectionType.topAnimeMovie:
      case SectionType.topAnimeSpecial:
        add(SimklFeed.trending, section);
      case SectionType.news:
      case SectionType.features:
      case SectionType.topManga:
      case SectionType.topMangaPopular:
      case SectionType.topAnimeOva:
      case SectionType.topAnimeOna:
      case SectionType.topMangaOnly:
      case SectionType.topMangaFavorites:
      case SectionType.topOneshots:
      case SectionType.topDoujin:
      case SectionType.topLightNovels:
      case SectionType.topNovels:
      case SectionType.topManhwa:
      case SectionType.topManhua:
      case SectionType.forum:
        break;
    }
  }
  return blocks;
}
