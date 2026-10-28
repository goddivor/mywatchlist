// Generated from Tenrai's OpenAPI document (api.tenrai.org/documentation/openapi.json,
// 103 GET paths) by the tenrai-client unit; edit by hand only with the spec next to you.
import 'package:mywatchlist/services/api/Jikan/jikan_anime.dart' show JikanAnime;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_character.dart' show AnimeCharacter;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_episode.dart' show AnimeEpisodesResponse;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart' show AnimeForumResponse;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart' show AnimeNewsResponse;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_picture.dart' show AnimePicturesResponse;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart' show AnimeReviewsResponse;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_staff.dart' show AnimeStaff;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart' show AnimeStatistics;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_videos.dart' show AnimeVideos;
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_characterfull.dart' show CharacterFull;
import 'package:mywatchlist/services/api/Jikan/jikan_genre.dart' show GenreResponse;
import 'package:mywatchlist/services/api/Jikan/jikan_personfull.dart' show PersonFull;
import 'package:mywatchlist/services/api/Jikan/jikan_producer.dart' show ProducersResponse;
import 'package:mywatchlist/services/api/Jikan/jikan_producerfull.dart' show ProducerFull;
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_params.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_response.dart';

/// Typed access to every endpoint of Tenrai (`https://api.tenrai.org/v1`), the free
/// MyAnimeList API that follows Jikan v4's schema.
///
/// One method per OpenAPI path, one named argument per query parameter (lists are sent
/// comma separated, as the spec's `explode: false`). Answers are parsed with the Jikan
/// models where Tenrai's schema is Jikan's; the other endpoints return the decoded
/// envelope as a [TenraiResponse]. Every call goes through [TenraiClient] (4 requests per
/// second, 120 per minute, `429` back-off); a non-200 answer throws [TenraiHttpError].
///
/// Not offered by Tenrai (Jikan only): `/users`, `/clubs`, `/watch`, `/userupdates`,
/// `/random/users`; `/anime/{id}/forum` and `/manga/{id}/forum` list episode and chapter
/// threads only.
class TenraiApi {
  TenraiApi({TenraiClient? client}) : _client = client;

  final TenraiClient? _client;

  TenraiClient get client => _client ?? TenraiClient.instance;

  /// Every path of the OpenAPI document, as templates (`{id}` is a path parameter).
  static const List<String> paths = [
    '/anime',
    '/anime/{id}',
    '/anime/{id}/full',
    '/anime/{id}/recommendations',
    '/anime/{id}/characters',
    '/anime/{id}/staff',
    '/anime/{id}/episodes',
    '/anime/{id}/news',
    '/anime/{id}/articles',
    '/anime/{id}/forum',
    '/anime/{id}/episodes/{episode_id}',
    '/anime/{id}/videos',
    '/anime/{id}/videos/episodes',
    '/anime/{id}/pictures',
    '/anime/{id}/statistics',
    '/anime/{id}/statistics/history',
    '/anime/{id}/moreinfo',
    '/anime/{id}/relations',
    '/anime/{id}/themes',
    '/anime/{id}/external',
    '/anime/{id}/streaming',
    '/anime/{id}/reviews',
    '/anime/{id}/stacks',
    '/anime/unapproved',
    '/anime/denied',
    '/anime/deleted',
    '/anime/ids',
    '/manga',
    '/manga/{id}',
    '/manga/{id}/full',
    '/manga/{id}/recommendations',
    '/manga/{id}/characters',
    '/manga/{id}/news',
    '/manga/{id}/articles',
    '/manga/{id}/pictures',
    '/manga/{id}/statistics',
    '/manga/{id}/statistics/history',
    '/manga/{id}/moreinfo',
    '/manga/{id}/relations',
    '/manga/{id}/external',
    '/manga/{id}/reviews',
    '/manga/{id}/forum',
    '/manga/{id}/stacks',
    '/manga/unapproved',
    '/manga/denied',
    '/manga/adapted',
    '/manga/deleted',
    '/manga/ids',
    '/characters',
    '/characters/{id}',
    '/characters/{id}/full',
    '/characters/{id}/anime',
    '/characters/{id}/manga',
    '/characters/{id}/voices',
    '/characters/{id}/pictures',
    '/characters/{id}/articles',
    '/characters/ids',
    '/people',
    '/people/{id}',
    '/people/{id}/full',
    '/people/{id}/anime',
    '/people/{id}/manga',
    '/people/{id}/voices',
    '/people/{id}/pictures',
    '/people/{id}/articles',
    '/people/ids',
    '/producers',
    '/producers/{id}',
    '/producers/{id}/full',
    '/producers/{id}/external',
    '/producers/ids',
    '/genres/anime',
    '/genres/manga',
    '/magazines',
    '/random/anime',
    '/random/manga',
    '/random/characters',
    '/random/people',
    '/recommendations/anime',
    '/recommendations/manga',
    '/top/anime',
    '/top/manga',
    '/top/people',
    '/top/characters',
    '/top/reviews',
    '/top/recommendations',
    '/top/episodes',
    '/seasons/{year}/{season}',
    '/seasons/now',
    '/seasons/previous',
    '/seasons/upcoming',
    '/seasons',
    '/reviews/anime',
    '/reviews/manga',
    '/schedules',
    '/news',
    '/news/tags',
    '/news/{id}',
    '/articles',
    '/articles/tags',
    '/articles/{id}',
    '/stacks',
    '/stacks/{id}',
  ];

  /// Paths that need a server key (`security: serverKey` in the spec).
  static const List<String> keyOnlyPaths = [
    '/anime/ids',
    '/manga/ids',
    '/characters/ids',
    '/people/ids',
    '/producers/ids',
  ];

  Future<Map<String, dynamic>> _get(String path, [Map<String, String> query = const {}]) =>
      client.getJson(path, query);

  /// Anime Search: `GET /anime` (`getAnime`).
  Future<TenraiPage<JikanAnime>> searchAnime({String? q, String? letter, List<AnimeSearchQueryType>? type, AnimeSearchQueryStatus? status, List<AnimeSearchQueryRating>? rating, String? source, bool? hasTrailer, String? genres, String? genresExclude, String? producers, double? score, double? minScore, double? maxScore, int? minScoredBy, int? minMembers, int? maxMembers, int? minFavorites, int? maxFavorites, int? minEpisodes, int? maxEpisodes, int? year, TenraiSeason? season, int? minYear, int? maxYear, String? startDate, String? endDate, bool? sfw, bool? sfwStrict, TenraiTriState? unapproved, AnimeSearchQueryOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime', {
      if (q != null) 'q': q,
      if (letter != null) 'letter': letter,
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (source != null) 'source': source,
      if (hasTrailer != null) 'has_trailer': hasTrailer.toString(),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (producers != null) 'producers': producers,
      if (score != null) 'score': score.toString(),
      if (minScore != null) 'min_score': minScore.toString(),
      if (maxScore != null) 'max_score': maxScore.toString(),
      if (minScoredBy != null) 'min_scored_by': minScoredBy.toString(),
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minFavorites != null) 'min_favorites': minFavorites.toString(),
      if (maxFavorites != null) 'max_favorites': maxFavorites.toString(),
      if (minEpisodes != null) 'min_episodes': minEpisodes.toString(),
      if (maxEpisodes != null) 'max_episodes': maxEpisodes.toString(),
      if (year != null) 'year': year.toString(),
      if (season != null) 'season': season.value,
      if (minYear != null) 'min_year': minYear.toString(),
      if (maxYear != null) 'max_year': maxYear.toString(),
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (unapproved != null) 'unapproved': unapproved.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Anime Details: `GET /anime/{id}` (`getAnimeById`).
  Future<JikanAnime> getAnimeById(int id) async {
    final b = await _get('/anime/$id');
    return JikanAnime.fromJson(TenraiResponse.object(b));
  }

  /// Anime Full Details: `GET /anime/{id}/full` (`getAnimeByIdFull`).
  Future<JikanAnime> getAnimeFull(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/anime/$id/full', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return JikanAnime.fromJson(TenraiResponse.object(b));
  }

  /// Anime Recommendations: `GET /anime/{id}/recommendations` (`getAnimeByIdRecommendations`).
  Future<TenraiResponse> getAnimeRecommendations(int id, {String? username, bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/anime/$id/recommendations', {
      if (username != null) 'username': username,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime Characters: `GET /anime/{id}/characters` (`getAnimeByIdCharacters`).
  Future<List<AnimeCharacter>> getAnimeCharacters(int id) async {
    final b = await _get('/anime/$id/characters');
    return TenraiResponse.list(b).map(AnimeCharacter.fromJson).toList();
  }

  /// Anime Staff: `GET /anime/{id}/staff` (`getAnimeByIdStaff`).
  Future<List<AnimeStaff>> getAnimeStaff(int id) async {
    final b = await _get('/anime/$id/staff');
    return TenraiResponse.list(b).map(AnimeStaff.fromJson).toList();
  }

  /// Anime Episodes: `GET /anime/{id}/episodes` (`getAnimeByIdEpisodes`).
  Future<AnimeEpisodesResponse> getAnimeEpisodes(int id, {int? page}) async {
    final b = await _get('/anime/$id/episodes', {
      if (page != null) 'page': page.toString(),
    });
    return AnimeEpisodesResponse.fromJson(b);
  }

  /// Anime News: `GET /anime/{id}/news` (`getAnimeByIdNews`).
  Future<AnimeNewsResponse> getAnimeNews(int id, {String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiNewsOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime/$id/news', {
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return AnimeNewsResponse.fromJson(b);
  }

  /// Anime Articles: `GET /anime/{id}/articles` (`getAnimeByIdArticles`).
  Future<TenraiResponse> getAnimeArticles(int id, {String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiArticleOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime/$id/articles', {
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime Forum Topics: `GET /anime/{id}/forum` (`getAnimeByIdForum`).
  Future<AnimeForumResponse> getAnimeForum(int id, {TenraiForumFilter? filter, TenraiAnimeForumOrderBy? orderBy, SearchQuerySort? sort, int? page}) async {
    final b = await _get('/anime/$id/forum', {
      if (filter != null) 'filter': filter.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
    });
    return AnimeForumResponse.fromJson(b);
  }

  /// Anime Episode by ID: `GET /anime/{id}/episodes/{episode_id}` (`getAnimeByIdEpisodesByEpisodeId`).
  Future<TenraiResponse> getAnimeEpisode(int id, int episodeId) async {
    final b = await _get('/anime/$id/episodes/$episodeId');
    return TenraiResponse(b);
  }

  /// Anime Videos: `GET /anime/{id}/videos` (`getAnimeByIdVideos`).
  Future<AnimeVideos> getAnimeVideos(int id) async {
    final b = await _get('/anime/$id/videos');
    return AnimeVideos.fromJson(TenraiResponse.object(b));
  }

  /// Anime Episode Videos: `GET /anime/{id}/videos/episodes` (`getAnimeByIdVideosEpisodes`).
  Future<TenraiResponse> getAnimeEpisodeVideos(int id, {int? page}) async {
    final b = await _get('/anime/$id/videos/episodes', {
      if (page != null) 'page': page.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime Pictures: `GET /anime/{id}/pictures` (`getAnimeByIdPictures`).
  Future<AnimePicturesResponse> getAnimePictures(int id) async {
    final b = await _get('/anime/$id/pictures');
    return AnimePicturesResponse.fromJson(b);
  }

  /// Anime Statistics: `GET /anime/{id}/statistics` (`getAnimeByIdStatistics`).
  Future<AnimeStatistics> getAnimeStatistics(int id) async {
    final b = await _get('/anime/$id/statistics');
    return AnimeStatistics.fromJson(TenraiResponse.object(b));
  }

  /// Anime Statistics History: `GET /anime/{id}/statistics/history` (`getAnimeByIdStatisticsHistory`).
  Future<TenraiResponse> getAnimeStatisticsHistory(int id, {String? startDate, String? endDate, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime/$id/statistics/history', {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime More Info: `GET /anime/{id}/moreinfo` (`getAnimeByIdMoreinfo`).
  Future<TenraiResponse> getAnimeMoreInfo(int id) async {
    final b = await _get('/anime/$id/moreinfo');
    return TenraiResponse(b);
  }

  /// Anime Relations: `GET /anime/{id}/relations` (`getAnimeByIdRelations`).
  Future<TenraiResponse> getAnimeRelations(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/anime/$id/relations', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime Themes: `GET /anime/{id}/themes` (`getAnimeByIdThemes`).
  Future<TenraiResponse> getAnimeThemes(int id) async {
    final b = await _get('/anime/$id/themes');
    return TenraiResponse(b);
  }

  /// Anime External Links: `GET /anime/{id}/external` (`getAnimeByIdExternal`).
  Future<TenraiResponse> getAnimeExternal(int id) async {
    final b = await _get('/anime/$id/external');
    return TenraiResponse(b);
  }

  /// Anime Streaming Links: `GET /anime/{id}/streaming` (`getAnimeByIdStreaming`).
  Future<TenraiResponse> getAnimeStreaming(int id) async {
    final b = await _get('/anime/$id/streaming');
    return TenraiResponse(b);
  }

  /// Anime Reviews: `GET /anime/{id}/reviews` (`getAnimeByIdReviews`).
  Future<AnimeReviewsResponse> getAnimeReviews(int id, {String? username, TenraiReviewSentiment? sentiment, TenraiTriState? preliminary, TenraiTriState? spoilers, TenraiReviewSort? sort, int? page}) async {
    final b = await _get('/anime/$id/reviews', {
      if (username != null) 'username': username,
      if (sentiment != null) 'sentiment': sentiment.value,
      if (preliminary != null) 'preliminary': preliminary.value,
      if (spoilers != null) 'spoilers': spoilers.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
    });
    return AnimeReviewsResponse.fromJson(b);
  }

  /// Anime Stacks: `GET /anime/{id}/stacks` (`getAnimeByIdStacks`).
  Future<TenraiResponse> getAnimeStacks(int id, {String? q, TenraiTriState? spoilers, TenraiTriState? challenges, TenraiTriState? official, bool? sfw, bool? sfwStrict, TenraiStackOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime/$id/stacks', {
      if (q != null) 'q': q,
      if (spoilers != null) 'spoilers': spoilers.value,
      if (challenges != null) 'challenges': challenges.value,
      if (official != null) 'official': official.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime Unapproved: `GET /anime/unapproved` (`getAnimeUnapproved`).
  Future<TenraiResponse> getAnimeUnapproved({String? q, bool? sfw, bool? sfwStrict, TenraiPendingOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime/unapproved', {
      if (q != null) 'q': q,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime Denied: `GET /anime/denied` (`getAnimeDenied`).
  Future<TenraiResponse> getAnimeDenied({String? q, bool? sfw, bool? sfwStrict, TenraiPendingOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime/denied', {
      if (q != null) 'q': q,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Anime Deleted: `GET /anime/deleted` (`getAnimeDeleted`).
  Future<TenraiResponse> getAnimeDeleted({String? q, bool? sfw, bool? sfwStrict, TenraiDeletedOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/anime/deleted', {
      if (q != null) 'q': q,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Get All Anime IDs: `GET /anime/ids` (`getAnimeIds`).
  ///
  /// Needs a Tenrai server key, which the app never ships: on the public tier it
  /// throws [TenraiHttpError] 401 (listed for completeness, see [keyOnlyPaths]).
  Future<TenraiResponse> getAnimeIds({List<AnimeSearchQueryType>? type, AnimeSearchQueryStatus? status, List<AnimeSearchQueryRating>? rating, String? updatedAt, bool? sfw, bool? sfwStrict, String? include}) async {
    final b = await _get('/anime/ids', {
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (include != null) 'include': include,
    });
    return TenraiResponse(b);
  }

  /// Manga Search: `GET /manga` (`getManga`).
  Future<TenraiPage<JikanAnime>> searchManga({String? q, String? letter, List<TenraiMangaType>? type, TenraiMangaStatus? status, String? genres, String? genresExclude, String? magazines, String? authors, double? score, double? minScore, double? maxScore, int? minScoredBy, int? minMembers, int? maxMembers, int? minFavorites, int? maxFavorites, int? minChapters, int? maxChapters, int? minVolumes, int? maxVolumes, int? year, int? minYear, int? maxYear, String? startDate, String? endDate, bool? sfw, bool? sfwStrict, TenraiTriState? unapproved, TenraiMangaOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga', {
      if (q != null) 'q': q,
      if (letter != null) 'letter': letter,
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (magazines != null) 'magazines': magazines,
      if (authors != null) 'authors': authors,
      if (score != null) 'score': score.toString(),
      if (minScore != null) 'min_score': minScore.toString(),
      if (maxScore != null) 'max_score': maxScore.toString(),
      if (minScoredBy != null) 'min_scored_by': minScoredBy.toString(),
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minFavorites != null) 'min_favorites': minFavorites.toString(),
      if (maxFavorites != null) 'max_favorites': maxFavorites.toString(),
      if (minChapters != null) 'min_chapters': minChapters.toString(),
      if (maxChapters != null) 'max_chapters': maxChapters.toString(),
      if (minVolumes != null) 'min_volumes': minVolumes.toString(),
      if (maxVolumes != null) 'max_volumes': maxVolumes.toString(),
      if (year != null) 'year': year.toString(),
      if (minYear != null) 'min_year': minYear.toString(),
      if (maxYear != null) 'max_year': maxYear.toString(),
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (unapproved != null) 'unapproved': unapproved.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Manga Details: `GET /manga/{id}` (`getMangaById`).
  Future<JikanAnime> getMangaById(int id) async {
    final b = await _get('/manga/$id');
    return JikanAnime.fromJson(TenraiResponse.object(b));
  }

  /// Manga Full Details: `GET /manga/{id}/full` (`getMangaByIdFull`).
  Future<JikanAnime> getMangaFull(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/manga/$id/full', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return JikanAnime.fromJson(TenraiResponse.object(b));
  }

  /// Manga Recommendations: `GET /manga/{id}/recommendations` (`getMangaByIdRecommendations`).
  Future<TenraiResponse> getMangaRecommendations(int id, {String? username, bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/manga/$id/recommendations', {
      if (username != null) 'username': username,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Manga Characters: `GET /manga/{id}/characters` (`getMangaByIdCharacters`).
  Future<TenraiResponse> getMangaCharacters(int id) async {
    final b = await _get('/manga/$id/characters');
    return TenraiResponse(b);
  }

  /// Manga News: `GET /manga/{id}/news` (`getMangaByIdNews`).
  Future<AnimeNewsResponse> getMangaNews(int id, {String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiNewsOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/$id/news', {
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return AnimeNewsResponse.fromJson(b);
  }

  /// Manga Articles: `GET /manga/{id}/articles` (`getMangaByIdArticles`).
  Future<TenraiResponse> getMangaArticles(int id, {String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiArticleOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/$id/articles', {
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Manga Pictures: `GET /manga/{id}/pictures` (`getMangaByIdPictures`).
  Future<AnimePicturesResponse> getMangaPictures(int id) async {
    final b = await _get('/manga/$id/pictures');
    return AnimePicturesResponse.fromJson(b);
  }

  /// Manga Statistics: `GET /manga/{id}/statistics` (`getMangaByIdStatistics`).
  Future<AnimeStatistics> getMangaStatistics(int id) async {
    final b = await _get('/manga/$id/statistics');
    return AnimeStatistics.fromJson(TenraiResponse.object(b));
  }

  /// Manga Statistics History: `GET /manga/{id}/statistics/history` (`getMangaByIdStatisticsHistory`).
  Future<TenraiResponse> getMangaStatisticsHistory(int id, {String? startDate, String? endDate, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/$id/statistics/history', {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Manga More Info: `GET /manga/{id}/moreinfo` (`getMangaByIdMoreinfo`).
  Future<TenraiResponse> getMangaMoreInfo(int id) async {
    final b = await _get('/manga/$id/moreinfo');
    return TenraiResponse(b);
  }

  /// Manga Relations: `GET /manga/{id}/relations` (`getMangaByIdRelations`).
  Future<TenraiResponse> getMangaRelations(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/manga/$id/relations', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Manga External Links: `GET /manga/{id}/external` (`getMangaByIdExternal`).
  Future<TenraiResponse> getMangaExternal(int id) async {
    final b = await _get('/manga/$id/external');
    return TenraiResponse(b);
  }

  /// Manga Reviews: `GET /manga/{id}/reviews` (`getMangaByIdReviews`).
  Future<AnimeReviewsResponse> getMangaReviews(int id, {String? username, TenraiReviewSentiment? sentiment, TenraiTriState? preliminary, TenraiTriState? spoilers, TenraiReviewSort? sort, int? page}) async {
    final b = await _get('/manga/$id/reviews', {
      if (username != null) 'username': username,
      if (sentiment != null) 'sentiment': sentiment.value,
      if (preliminary != null) 'preliminary': preliminary.value,
      if (spoilers != null) 'spoilers': spoilers.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
    });
    return AnimeReviewsResponse.fromJson(b);
  }

  /// Manga Forum Topics: `GET /manga/{id}/forum` (`getMangaByIdForum`).
  Future<AnimeForumResponse> getMangaForum(int id, {TenraiForumFilter? filter, TenraiMangaForumOrderBy? orderBy, SearchQuerySort? sort, int? page}) async {
    final b = await _get('/manga/$id/forum', {
      if (filter != null) 'filter': filter.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
    });
    return AnimeForumResponse.fromJson(b);
  }

  /// Manga Stacks: `GET /manga/{id}/stacks` (`getMangaByIdStacks`).
  Future<TenraiResponse> getMangaStacks(int id, {String? q, TenraiTriState? spoilers, TenraiTriState? challenges, TenraiTriState? official, bool? sfw, bool? sfwStrict, TenraiStackOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/$id/stacks', {
      if (q != null) 'q': q,
      if (spoilers != null) 'spoilers': spoilers.value,
      if (challenges != null) 'challenges': challenges.value,
      if (official != null) 'official': official.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Manga Unapproved: `GET /manga/unapproved` (`getMangaUnapproved`).
  Future<TenraiResponse> getMangaUnapproved({String? q, bool? sfw, bool? sfwStrict, TenraiPendingOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/unapproved', {
      if (q != null) 'q': q,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Manga Denied: `GET /manga/denied` (`getMangaDenied`).
  Future<TenraiResponse> getMangaDenied({String? q, bool? sfw, bool? sfwStrict, TenraiPendingOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/denied', {
      if (q != null) 'q': q,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Manga Adapted to Anime: `GET /manga/adapted` (`getMangaAdapted`).
  Future<TenraiPage<JikanAnime>> getMangaAdapted({TenraiAdaptedFilter? filter, List<TenraiMangaType>? type, TenraiMangaStatus? status, String? genres, double? score, double? minScore, double? maxScore, String? startDate, String? endDate, bool? sfw, bool? sfwStrict, TenraiMangaOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/adapted', {
      if (filter != null) 'filter': filter.value,
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (genres != null) 'genres': genres,
      if (score != null) 'score': score.toString(),
      if (minScore != null) 'min_score': minScore.toString(),
      if (maxScore != null) 'max_score': maxScore.toString(),
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Manga Deleted: `GET /manga/deleted` (`getMangaDeleted`).
  Future<TenraiResponse> getMangaDeleted({String? q, bool? sfw, bool? sfwStrict, TenraiDeletedOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/manga/deleted', {
      if (q != null) 'q': q,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Get All Manga IDs: `GET /manga/ids` (`getMangaIds`).
  ///
  /// Needs a Tenrai server key, which the app never ships: on the public tier it
  /// throws [TenraiHttpError] 401 (listed for completeness, see [keyOnlyPaths]).
  Future<TenraiResponse> getMangaIds({List<TenraiMangaType>? type, TenraiMangaStatus? status, String? updatedAt, bool? sfw, bool? sfwStrict, String? include}) async {
    final b = await _get('/manga/ids', {
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (include != null) 'include': include,
    });
    return TenraiResponse(b);
  }

  /// Character Search: `GET /characters` (`getCharacters`).
  Future<TenraiPage<CharacterFull>> searchCharacters({String? q, String? letter, int? minFavorites, int? maxFavorites, TenraiCharacterOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/characters', {
      if (q != null) 'q': q,
      if (letter != null) 'letter': letter,
      if (minFavorites != null) 'min_favorites': minFavorites.toString(),
      if (maxFavorites != null) 'max_favorites': maxFavorites.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, CharacterFull.fromJson);
  }

  /// Character Details: `GET /characters/{id}` (`getCharactersById`).
  Future<CharacterFull> getCharacterById(int id) async {
    final b = await _get('/characters/$id');
    return CharacterFull.fromJson(TenraiResponse.object(b));
  }

  /// Character Full Details: `GET /characters/{id}/full` (`getCharactersByIdFull`).
  Future<CharacterFull> getCharacterFull(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/characters/$id/full', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return CharacterFull.fromJson(TenraiResponse.object(b));
  }

  /// Character Anime Appearances: `GET /characters/{id}/anime` (`getCharactersByIdAnime`).
  Future<TenraiResponse> getCharacterAnime(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/characters/$id/anime', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Character Manga Appearances: `GET /characters/{id}/manga` (`getCharactersByIdManga`).
  Future<TenraiResponse> getCharacterManga(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/characters/$id/manga', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Character Voice Actors: `GET /characters/{id}/voices` (`getCharactersByIdVoices`).
  Future<TenraiResponse> getCharacterVoices(int id) async {
    final b = await _get('/characters/$id/voices');
    return TenraiResponse(b);
  }

  /// Character Pictures: `GET /characters/{id}/pictures` (`getCharactersByIdPictures`).
  Future<TenraiResponse> getCharacterPictures(int id) async {
    final b = await _get('/characters/$id/pictures');
    return TenraiResponse(b);
  }

  /// Character Articles: `GET /characters/{id}/articles` (`getCharactersByIdArticles`).
  Future<TenraiResponse> getCharacterArticles(int id, {String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiArticleOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/characters/$id/articles', {
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Get All Character IDs: `GET /characters/ids` (`getCharactersIds`).
  ///
  /// Needs a Tenrai server key, which the app never ships: on the public tier it
  /// throws [TenraiHttpError] 401 (listed for completeness, see [keyOnlyPaths]).
  Future<TenraiResponse> getCharacterIds() async {
    final b = await _get('/characters/ids');
    return TenraiResponse(b);
  }

  /// People Search: `GET /people` (`getPeople`).
  Future<TenraiPage<PersonFull>> searchPeople({String? q, String? letter, int? minFavorites, int? maxFavorites, TenraiPersonOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/people', {
      if (q != null) 'q': q,
      if (letter != null) 'letter': letter,
      if (minFavorites != null) 'min_favorites': minFavorites.toString(),
      if (maxFavorites != null) 'max_favorites': maxFavorites.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, PersonFull.fromJson);
  }

  /// Person Details: `GET /people/{id}` (`getPeopleById`).
  Future<PersonFull> getPersonById(int id) async {
    final b = await _get('/people/$id');
    return PersonFull.fromJson(TenraiResponse.object(b));
  }

  /// Person Full Details: `GET /people/{id}/full` (`getPeopleByIdFull`).
  Future<PersonFull> getPersonFull(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/people/$id/full', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return PersonFull.fromJson(TenraiResponse.object(b));
  }

  /// Person Anime Roles: `GET /people/{id}/anime` (`getPeopleByIdAnime`).
  Future<TenraiResponse> getPersonAnime(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/people/$id/anime', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Person Manga Roles: `GET /people/{id}/manga` (`getPeopleByIdManga`).
  Future<TenraiResponse> getPersonManga(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/people/$id/manga', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Person Voice Acting Roles: `GET /people/{id}/voices` (`getPeopleByIdVoices`).
  Future<TenraiResponse> getPersonVoices(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/people/$id/voices', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Person Pictures: `GET /people/{id}/pictures` (`getPeopleByIdPictures`).
  Future<TenraiResponse> getPersonPictures(int id) async {
    final b = await _get('/people/$id/pictures');
    return TenraiResponse(b);
  }

  /// Person Articles: `GET /people/{id}/articles` (`getPeopleByIdArticles`).
  Future<TenraiResponse> getPersonArticles(int id, {String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiArticleOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/people/$id/articles', {
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Get All Person IDs: `GET /people/ids` (`getPeopleIds`).
  ///
  /// Needs a Tenrai server key, which the app never ships: on the public tier it
  /// throws [TenraiHttpError] 401 (listed for completeness, see [keyOnlyPaths]).
  Future<TenraiResponse> getPeopleIds() async {
    final b = await _get('/people/ids');
    return TenraiResponse(b);
  }

  /// Producers Search: `GET /producers` (`getProducers`).
  Future<ProducersResponse> searchProducers({String? q, String? letter, int? minFavorites, int? maxFavorites, ProducersQueryOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/producers', {
      if (q != null) 'q': q,
      if (letter != null) 'letter': letter,
      if (minFavorites != null) 'min_favorites': minFavorites.toString(),
      if (maxFavorites != null) 'max_favorites': maxFavorites.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return ProducersResponse.fromJson(b);
  }

  /// Producer Details: `GET /producers/{id}` (`getProducersById`).
  Future<TenraiResponse> getProducerById(int id) async {
    final b = await _get('/producers/$id');
    return TenraiResponse(b);
  }

  /// Producer Full Details: `GET /producers/{id}/full` (`getProducersByIdFull`).
  Future<ProducerFull> getProducerFull(int id) async {
    final b = await _get('/producers/$id/full');
    return ProducerFull.fromJson(TenraiResponse.object(b));
  }

  /// Producer External Links: `GET /producers/{id}/external` (`getProducersByIdExternal`).
  Future<TenraiResponse> getProducerExternal(int id) async {
    final b = await _get('/producers/$id/external');
    return TenraiResponse(b);
  }

  /// Get All Producer IDs: `GET /producers/ids` (`getProducersIds`).
  ///
  /// Needs a Tenrai server key, which the app never ships: on the public tier it
  /// throws [TenraiHttpError] 401 (listed for completeness, see [keyOnlyPaths]).
  Future<TenraiResponse> getProducerIds() async {
    final b = await _get('/producers/ids');
    return TenraiResponse(b);
  }

  /// Anime Genres: `GET /genres/anime` (`getGenresAnime`).
  Future<GenreResponse> getAnimeGenres({GenreQueryFilter? filter, bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/genres/anime', {
      if (filter != null) 'filter': filter.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return GenreResponse.fromJson(b);
  }

  /// Manga Genres: `GET /genres/manga` (`getGenresManga`).
  Future<GenreResponse> getMangaGenres({GenreQueryFilter? filter, bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/genres/manga', {
      if (filter != null) 'filter': filter.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return GenreResponse.fromJson(b);
  }

  /// Manga Magazines: `GET /magazines` (`getMagazines`).
  Future<TenraiResponse> searchMagazines({String? q, String? letter, TenraiMagazineOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/magazines', {
      if (q != null) 'q': q,
      if (letter != null) 'letter': letter,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Random Anime: `GET /random/anime` (`getRandomAnime`).
  Future<JikanAnime> getRandomAnime({String? type, AnimeSearchQueryStatus? status, List<AnimeSearchQueryRating>? rating, String? source, bool? hasTrailer, String? genres, String? genresExclude, String? producers, double? minScore, double? maxScore, int? year, int? minYear, int? maxYear, bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/random/anime', {
      if (type != null) 'type': type,
      if (status != null) 'status': status.value,
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (source != null) 'source': source,
      if (hasTrailer != null) 'has_trailer': hasTrailer.toString(),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (producers != null) 'producers': producers,
      if (minScore != null) 'min_score': minScore.toString(),
      if (maxScore != null) 'max_score': maxScore.toString(),
      if (year != null) 'year': year.toString(),
      if (minYear != null) 'min_year': minYear.toString(),
      if (maxYear != null) 'max_year': maxYear.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return JikanAnime.fromJson(TenraiResponse.object(b));
  }

  /// Random Manga: `GET /random/manga` (`getRandomManga`).
  Future<JikanAnime> getRandomManga({List<TenraiMangaType>? type, TenraiMangaStatus? status, String? genres, String? genresExclude, String? authors, double? minScore, double? maxScore, int? year, int? minYear, int? maxYear, bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/random/manga', {
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (authors != null) 'authors': authors,
      if (minScore != null) 'min_score': minScore.toString(),
      if (maxScore != null) 'max_score': maxScore.toString(),
      if (year != null) 'year': year.toString(),
      if (minYear != null) 'min_year': minYear.toString(),
      if (maxYear != null) 'max_year': maxYear.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return JikanAnime.fromJson(TenraiResponse.object(b));
  }

  /// Random Character: `GET /random/characters` (`getRandomCharacters`).
  Future<CharacterFull> getRandomCharacter({int? minFavorites, int? maxFavorites}) async {
    final b = await _get('/random/characters', {
      if (minFavorites != null) 'min_favorites': minFavorites.toString(),
      if (maxFavorites != null) 'max_favorites': maxFavorites.toString(),
    });
    return CharacterFull.fromJson(TenraiResponse.object(b));
  }

  /// Random Person: `GET /random/people` (`getRandomPeople`).
  Future<PersonFull> getRandomPerson({int? minFavorites, int? maxFavorites}) async {
    final b = await _get('/random/people', {
      if (minFavorites != null) 'min_favorites': minFavorites.toString(),
      if (maxFavorites != null) 'max_favorites': maxFavorites.toString(),
    });
    return PersonFull.fromJson(TenraiResponse.object(b));
  }

  /// Recent Anime Recommendations: `GET /recommendations/anime` (`getRecommendationsAnime`).
  Future<TenraiResponse> getRecentAnimeRecommendations({String? username, bool? sfw, bool? sfwStrict, int? page, int? limit}) async {
    final b = await _get('/recommendations/anime', {
      if (username != null) 'username': username,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Recent Manga Recommendations: `GET /recommendations/manga` (`getRecommendationsManga`).
  Future<TenraiResponse> getRecentMangaRecommendations({String? username, bool? sfw, bool? sfwStrict, int? page, int? limit}) async {
    final b = await _get('/recommendations/manga', {
      if (username != null) 'username': username,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Top Anime: `GET /top/anime` (`getTopAnime`).
  Future<TenraiPage<JikanAnime>> getTopAnime({TenraiTopAnimeFilter? filter, List<AnimeSearchQueryType>? type, List<AnimeSearchQueryRating>? rating, String? genres, String? genresExclude, int? minMembers, int? maxMembers, int? minEpisodes, int? maxEpisodes, bool? sfw, bool? sfwStrict, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/top/anime', {
      if (filter != null) 'filter': filter.value,
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minEpisodes != null) 'min_episodes': minEpisodes.toString(),
      if (maxEpisodes != null) 'max_episodes': maxEpisodes.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Top Manga: `GET /top/manga` (`getTopManga`).
  Future<TenraiPage<JikanAnime>> getTopManga({TenraiTopMangaFilter? filter, List<TenraiMangaType>? type, String? genres, String? genresExclude, int? minMembers, int? maxMembers, int? minChapters, int? maxChapters, int? minVolumes, int? maxVolumes, bool? sfw, bool? sfwStrict, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/top/manga', {
      if (filter != null) 'filter': filter.value,
      if (type != null) 'type': type.map((e) => e.value).join(','),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minChapters != null) 'min_chapters': minChapters.toString(),
      if (maxChapters != null) 'max_chapters': maxChapters.toString(),
      if (minVolumes != null) 'min_volumes': minVolumes.toString(),
      if (maxVolumes != null) 'max_volumes': maxVolumes.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Top People: `GET /top/people` (`getTopPeople`).
  Future<TenraiPage<PersonFull>> getTopPeople({int? page, int? limit}) async {
    final b = await _get('/top/people', {
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, PersonFull.fromJson);
  }

  /// Top Characters: `GET /top/characters` (`getTopCharacters`).
  Future<TenraiPage<CharacterFull>> getTopCharacters({int? page, int? limit}) async {
    final b = await _get('/top/characters', {
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, CharacterFull.fromJson);
  }

  /// Top Reviews: `GET /top/reviews` (`getTopReviews`).
  Future<TenraiResponse> getTopReviews({GenreCategory? type, String? username, bool? preliminary, bool? spoilers, bool? sfw, bool? sfwStrict, int? page, int? limit}) async {
    final b = await _get('/top/reviews', {
      if (type != null) 'type': type.value,
      if (username != null) 'username': username,
      if (preliminary != null) 'preliminary': preliminary.toString(),
      if (spoilers != null) 'spoilers': spoilers.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Top Recommendations: `GET /top/recommendations` (`getTopRecommendations`).
  Future<TenraiResponse> getTopRecommendations({GenreCategory? type, bool? sfw, bool? sfwStrict, int? page, int? limit}) async {
    final b = await _get('/top/recommendations', {
      if (type != null) 'type': type.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Top Episodes: `GET /top/episodes` (`getTopEpisodes`).
  Future<TenraiResponse> getTopEpisodes({bool? sfw, bool? sfwStrict, TenraiTopEpisodeOrderBy? orderBy, int? page, int? limit}) async {
    final b = await _get('/top/episodes', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Seasonal Anime: `GET /seasons/{year}/{season}` (`getSeasonsByYearBySeason`).
  Future<TenraiPage<JikanAnime>> getSeason(int year, TenraiSeason season, {List<AnimeSearchQueryType>? filter, AnimeSearchQueryStatus? status, List<AnimeSearchQueryRating>? rating, String? genres, String? genresExclude, int? minMembers, int? maxMembers, int? minEpisodes, int? maxEpisodes, bool? sfw, bool? sfwStrict, bool? kids, bool? continuing, TenraiTriState? unapproved, TenraiSeasonOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/seasons/$year/${season.value}', {
      if (filter != null) 'filter': filter.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minEpisodes != null) 'min_episodes': minEpisodes.toString(),
      if (maxEpisodes != null) 'max_episodes': maxEpisodes.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (kids != null) 'kids': kids.toString(),
      if (continuing != null) 'continuing': continuing.toString(),
      if (unapproved != null) 'unapproved': unapproved.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Seasonal Anime Current: `GET /seasons/now` (`getSeasonsNow`).
  Future<TenraiPage<JikanAnime>> getSeasonNow({List<AnimeSearchQueryType>? filter, AnimeSearchQueryStatus? status, List<AnimeSearchQueryRating>? rating, String? genres, String? genresExclude, int? minMembers, int? maxMembers, int? minEpisodes, int? maxEpisodes, bool? sfw, bool? sfwStrict, bool? kids, bool? continuing, TenraiTriState? unapproved, TenraiSeasonOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/seasons/now', {
      if (filter != null) 'filter': filter.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minEpisodes != null) 'min_episodes': minEpisodes.toString(),
      if (maxEpisodes != null) 'max_episodes': maxEpisodes.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (kids != null) 'kids': kids.toString(),
      if (continuing != null) 'continuing': continuing.toString(),
      if (unapproved != null) 'unapproved': unapproved.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Seasonal Anime Previous: `GET /seasons/previous` (`getSeasonsPrevious`).
  Future<TenraiPage<JikanAnime>> getSeasonPrevious({List<AnimeSearchQueryType>? filter, AnimeSearchQueryStatus? status, List<AnimeSearchQueryRating>? rating, String? genres, String? genresExclude, int? minMembers, int? maxMembers, int? minEpisodes, int? maxEpisodes, bool? sfw, bool? sfwStrict, bool? kids, bool? continuing, TenraiTriState? unapproved, TenraiSeasonOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/seasons/previous', {
      if (filter != null) 'filter': filter.map((e) => e.value).join(','),
      if (status != null) 'status': status.value,
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minEpisodes != null) 'min_episodes': minEpisodes.toString(),
      if (maxEpisodes != null) 'max_episodes': maxEpisodes.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (kids != null) 'kids': kids.toString(),
      if (continuing != null) 'continuing': continuing.toString(),
      if (unapproved != null) 'unapproved': unapproved.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Seasonal Anime Upcoming: `GET /seasons/upcoming` (`getSeasonsUpcoming`).
  Future<TenraiPage<JikanAnime>> getSeasonUpcoming({List<AnimeSearchQueryType>? filter, List<AnimeSearchQueryRating>? rating, String? genres, String? genresExclude, int? minMembers, int? maxMembers, int? minEpisodes, int? maxEpisodes, bool? sfw, bool? sfwStrict, bool? kids, bool? continuing, TenraiTriState? unapproved, TenraiSeasonOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/seasons/upcoming', {
      if (filter != null) 'filter': filter.map((e) => e.value).join(','),
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (minMembers != null) 'min_members': minMembers.toString(),
      if (maxMembers != null) 'max_members': maxMembers.toString(),
      if (minEpisodes != null) 'min_episodes': minEpisodes.toString(),
      if (maxEpisodes != null) 'max_episodes': maxEpisodes.toString(),
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (kids != null) 'kids': kids.toString(),
      if (continuing != null) 'continuing': continuing.toString(),
      if (unapproved != null) 'unapproved': unapproved.value,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// Available Seasons: `GET /seasons` (`getSeasons`).
  Future<TenraiResponse> getSeasonsList() async {
    final b = await _get('/seasons');
    return TenraiResponse(b);
  }

  /// Recent Anime Reviews: `GET /reviews/anime` (`getReviewsAnime`).
  Future<AnimeReviewsResponse> getRecentAnimeReviews({String? username, TenraiReviewSentiment? sentiment, TenraiTriState? preliminary, TenraiTriState? spoilers, bool? sfw, bool? sfwStrict, TenraiReviewSort? sort, int? page, int? limit}) async {
    final b = await _get('/reviews/anime', {
      if (username != null) 'username': username,
      if (sentiment != null) 'sentiment': sentiment.value,
      if (preliminary != null) 'preliminary': preliminary.value,
      if (spoilers != null) 'spoilers': spoilers.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return AnimeReviewsResponse.fromJson(b);
  }

  /// Recent Manga Reviews: `GET /reviews/manga` (`getReviewsManga`).
  Future<AnimeReviewsResponse> getRecentMangaReviews({String? username, TenraiReviewSentiment? sentiment, TenraiTriState? preliminary, TenraiTriState? spoilers, bool? sfw, bool? sfwStrict, TenraiReviewSort? sort, int? page, int? limit}) async {
    final b = await _get('/reviews/manga', {
      if (username != null) 'username': username,
      if (sentiment != null) 'sentiment': sentiment.value,
      if (preliminary != null) 'preliminary': preliminary.value,
      if (spoilers != null) 'spoilers': spoilers.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return AnimeReviewsResponse.fromJson(b);
  }

  /// Anime Schedules: `GET /schedules` (`getSchedules`).
  Future<TenraiPage<JikanAnime>> getSchedules({TenraiScheduleDay? filter, String? type, List<AnimeSearchQueryRating>? rating, String? genres, String? genresExclude, bool? sfw, bool? sfwStrict, bool? kids, TenraiTriState? unapproved, int? page, int? limit}) async {
    final b = await _get('/schedules', {
      if (filter != null) 'filter': filter.value,
      if (type != null) 'type': type,
      if (rating != null) 'rating': rating.map((e) => e.value).join(','),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (kids != null) 'kids': kids.toString(),
      if (unapproved != null) 'unapproved': unapproved.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiPage.parse(b, JikanAnime.fromJson);
  }

  /// News: `GET /news` (`getNews`).
  Future<TenraiResponse> searchNews({String? q, String? tag, String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiNewsOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/news', {
      if (q != null) 'q': q,
      if (tag != null) 'tag': tag,
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// News Tags: `GET /news/tags` (`getNewsTags`).
  Future<TenraiResponse> getNewsTags() async {
    final b = await _get('/news/tags');
    return TenraiResponse(b);
  }

  /// News Details: `GET /news/{id}` (`getNewsById`).
  Future<TenraiResponse> getNewsById(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/news/$id', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Articles: `GET /articles` (`getArticles`).
  Future<TenraiResponse> searchArticles({String? q, String? tag, String? authorUsername, String? publishedAfter, String? publishedBefore, bool? sfw, bool? sfwStrict, TenraiArticleOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/articles', {
      if (q != null) 'q': q,
      if (tag != null) 'tag': tag,
      if (authorUsername != null) 'author_username': authorUsername,
      if (publishedAfter != null) 'published_after': publishedAfter,
      if (publishedBefore != null) 'published_before': publishedBefore,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Article Tags: `GET /articles/tags` (`getArticlesTags`).
  Future<TenraiResponse> getArticleTags() async {
    final b = await _get('/articles/tags');
    return TenraiResponse(b);
  }

  /// Article Details: `GET /articles/{id}` (`getArticlesById`).
  Future<TenraiResponse> getArticleById(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/articles/$id', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }

  /// Interest Stacks: `GET /stacks` (`getStacks`).
  Future<TenraiResponse> searchStacks({String? q, GenreCategory? stackType, TenraiTriState? spoilers, TenraiTriState? challenges, TenraiTriState? official, bool? sfw, bool? sfwStrict, TenraiStackOrderBy? orderBy, SearchQuerySort? sort, int? page, int? limit}) async {
    final b = await _get('/stacks', {
      if (q != null) 'q': q,
      if (stackType != null) 'stack_type': stackType.value,
      if (spoilers != null) 'spoilers': spoilers.value,
      if (challenges != null) 'challenges': challenges.value,
      if (official != null) 'official': official.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    });
    return TenraiResponse(b);
  }

  /// Interest Stack Details: `GET /stacks/{id}` (`getStacksById`).
  Future<TenraiResponse> getStackById(int id, {bool? sfw, bool? sfwStrict}) async {
    final b = await _get('/stacks/$id', {
      if (sfw != null) 'sfw': sfw.toString(),
      if (sfwStrict != null) 'sfw-strict': sfwStrict.toString(),
    });
    return TenraiResponse(b);
  }
}
