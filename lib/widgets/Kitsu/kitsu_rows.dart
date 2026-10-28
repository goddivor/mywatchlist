import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Anime;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The Kitsu search that fills a home section of the user's home layout, or null when Kitsu has
/// no equivalent (news, features, suggestions, forum) or the section is not a catalogue row
/// (the user's own list).
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
