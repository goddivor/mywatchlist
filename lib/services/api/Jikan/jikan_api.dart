import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_character.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_episode.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_picture.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_staff.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_videos.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_animeuserupdate.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_characterfull.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_genre.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_personfull.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_producer.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_producerfull.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

enum AnimeForumFilter {
  all,
  episode,
  other,
}

String getAnimeForumFilterValue(AnimeForumFilter filter) {
  switch (filter) {
    case AnimeForumFilter.all:
      return 'all';
    case AnimeForumFilter.episode:
      return 'episode';
    case AnimeForumFilter.other:
      return 'other';
  }
}

enum AnimeSearchQueryType {
  tv,
  movie,
  ova,
  special,
  ona,
  music,
  cm,
  pv,
  tvSpecial
}

extension AnimeSearchQueryTypeExtension on AnimeSearchQueryType {
  String get value {
    switch (this) {
      case AnimeSearchQueryType.tv:
        return "tv";
      case AnimeSearchQueryType.movie:
        return "movie";
      case AnimeSearchQueryType.ova:
        return "ova";
      case AnimeSearchQueryType.special:
        return "special";
      case AnimeSearchQueryType.ona:
        return "ona";
      case AnimeSearchQueryType.music:
        return "music";
      case AnimeSearchQueryType.cm:
        return "cm";
      case AnimeSearchQueryType.pv:
        return "pv";
      case AnimeSearchQueryType.tvSpecial:
        return "tv_special";
    }
  }
}

enum AnimeSearchQueryStatus { airing, complete, upcoming }

extension AnimeSearchQueryStatusExtension on AnimeSearchQueryStatus {
  String get value {
    switch (this) {
      case AnimeSearchQueryStatus.airing:
        return "airing";
      case AnimeSearchQueryStatus.complete:
        return "complete";
      case AnimeSearchQueryStatus.upcoming:
        return "upcoming";
    }
  }
}

enum AnimeSearchQueryRating { g, pg, pg13, r17, r, rx }

extension AnimeSearchQueryRatingExtension on AnimeSearchQueryRating {
  String get value {
    switch (this) {
      case AnimeSearchQueryRating.g:
        return "g";
      case AnimeSearchQueryRating.pg:
        return "pg";
      case AnimeSearchQueryRating.pg13:
        return "pg13";
      case AnimeSearchQueryRating.r17:
        return "r17";
      case AnimeSearchQueryRating.r:
        return "r";
      case AnimeSearchQueryRating.rx:
        return "rx";
    }
  }
}

enum AnimeSearchQueryOrderBy {
  malId,
  title,
  startDate,
  endDate,
  episodes,
  score,
  scoredBy,
  rank,
  popularity,
  members,
  favorites
}

extension AnimeSearchQueryOrderByExtension on AnimeSearchQueryOrderBy {
  String get value {
    switch (this) {
      case AnimeSearchQueryOrderBy.malId:
        return "mal_id";
      case AnimeSearchQueryOrderBy.title:
        return "title";
      case AnimeSearchQueryOrderBy.startDate:
        return "start_date";
      case AnimeSearchQueryOrderBy.endDate:
        return "end_date";
      case AnimeSearchQueryOrderBy.episodes:
        return "episodes";
      case AnimeSearchQueryOrderBy.score:
        return "score";
      case AnimeSearchQueryOrderBy.scoredBy:
        return "scored_by";
      case AnimeSearchQueryOrderBy.rank:
        return "rank";
      case AnimeSearchQueryOrderBy.popularity:
        return "popularity";
      case AnimeSearchQueryOrderBy.members:
        return "members";
      case AnimeSearchQueryOrderBy.favorites:
        return "favorites";
    }
  }
}

enum SearchQuerySort { desc, asc }

extension SearchQuerySortExtension on SearchQuerySort {
  String get value {
    switch (this) {
      case SearchQuerySort.desc:
        return "desc";
      case SearchQuerySort.asc:
        return "asc";
    }
  }
}

enum GenreCategory { anime, manga }

extension GenreCategoryExtension on GenreCategory {
  String get value {
    switch (this) {
      case GenreCategory.anime:
        return "anime";
      case GenreCategory.manga:
        return "manga";
    }
  }
}

enum GenreQueryFilter { genres, explicitGenres, themes, demographics }

extension GenreQueryFilterExtension on GenreQueryFilter {
  String get value {
    switch (this) {
      case GenreQueryFilter.genres:
        return "genres";
      case GenreQueryFilter.explicitGenres:
        return "explicit_genres";
      case GenreQueryFilter.themes:
        return "themes";
      case GenreQueryFilter.demographics:
        return "demographics";
    }
  }
}

enum ProducersQueryOrderBy { malId, count, favorites, established }

extension ProducersQueryOrderByExtension on ProducersQueryOrderBy {
  String get value {
    switch (this) {
      case ProducersQueryOrderBy.malId:
        return "mal_id";
      case ProducersQueryOrderBy.count:
        return "count";
      case ProducersQueryOrderBy.favorites:
        return "favorites";
      case ProducersQueryOrderBy.established:
        return "established";
    }
  }
}

class JikanApi {
  static const String _baseUrl = Constants.jikanV4anime;
  static const String _jikanv4 = Constants.jikanV4;
  Future<List<Anime>> getSeasonNow(
      {String filter = 'tv', int limit = 25}) async {
    const String baseUrl = Constants.jikanSeasonGetNow;
    final response =
        await http.get(Uri.parse('$baseUrl?filter=$filter&limit=$limit'));

    if (response.statusCode == 200) {
      var data = json.decode(response.body)['data'] as List<dynamic>;
      return data.map((anime) => Anime.fromJikanJson(anime)).toList();
    } else {
      throw Exception('Failed to load current season data');
    }
  }

  Future<List<Anime>> getSeasonUpcoming(
      {String filter = 'tv', int limit = 25}) async {
    const String baseUrl = Constants.jikanSeasonUpcoming;
    final response =
        await http.get(Uri.parse('$baseUrl?filter=$filter&limit=$limit'));

    if (response.statusCode == 200) {
      var data = json.decode(response.body)['data'] as List<dynamic>;
      return data.map((anime) => Anime.fromJikanJson(anime)).toList();
    } else {
      throw Exception('Failed to load current season data');
    }
  }

  Future<List<Anime>> getTopAnime(
      {String type = 'tv', required String filter, int limit = 25}) async {
    const String baseUrl = Constants.jikanTopAnime;
    final response = await http
        .get(Uri.parse('$baseUrl?type=$type&filter=$filter&limit=$limit'));

    if (response.statusCode == 200) {
      var data = json.decode(response.body)['data'] as List<dynamic>;
      return data.map((anime) => Anime.fromJikanJson(anime)).toList();
    } else {
      throw Exception('Failed to load current season data');
    }
  }

  Future<List<Anime>> getTopManga(
      {String type = 'manga',
      String filter = 'favorite',
      int limit = 25}) async {
    const String baseUrl = Constants.jikanTopManga;
    final response = await http
        .get(Uri.parse('$baseUrl?type=$type&filter=$filter&limit=$limit'));

    if (response.statusCode == 200) {
      var data = json.decode(response.body)['data'] as List<dynamic>;
      return data.map((anime) => Anime.fromJikanJson(anime)).toList();
    } else {
      throw Exception('Failed to load current season data');
    }
  }

  Future<JikanAnime> getAnimeFullById(int malId) async {
    final response = await http.get(Uri.parse('$_baseUrl/$malId/full'));

    if (response.statusCode == 200) {
      var data = json.decode(response.body)['data'] as Map<String, dynamic>;
      return JikanAnime.fromJson(data);
    } else {
      throw Exception('Failed to load anime data');
    }
  }

  Future<List<AnimeCharacter>> getAnimeCharacters(int animeId) async {
    final url = Uri.parse('$_baseUrl/$animeId/characters');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final List charactersJson = jsonData['data'];
      return charactersJson.map((e) => AnimeCharacter.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load anime characters');
    }
  }

  Future<List<AnimeStaff>> getAnimeStaff(int animeId) async {
    final url = Uri.parse('$_baseUrl/$animeId/staff');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final List staffJson = jsonData['data'];
      return staffJson.map((e) => AnimeStaff.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load anime staff');
    }
  }

  Future<AnimeEpisodesResponse> getAnimeEpisodes(int animeId,
      {int page = 1}) async {
    final url = Uri.parse('$_baseUrl/$animeId/episodes?page=$page');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimeEpisodesResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load anime episodes');
    }
  }

  Future<AnimeNewsResponse> getAnimeNews(int animeId, {int page = 1}) async {
    final url = Uri.parse('$_baseUrl/$animeId/news?page=$page');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimeNewsResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load anime news');
    }
  }

  Future<AnimeForumResponse> getAnimeForum(
      int animeId, AnimeForumFilter filter) async {
    final filterValue = getAnimeForumFilterValue(filter);
    final url = Uri.parse('$_baseUrl/$animeId/forum?filter=$filterValue');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimeForumResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load anime forum');
    }
  }

  Future<AnimeVideos> getAnimeVideos(int animeId) async {
    final url = Uri.parse('$_baseUrl/$animeId/videos');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimeVideos.fromJson(jsonData['data']);
    } else {
      throw Exception('Failed to load anime videos');
    }
  }

  Future<AnimePicturesResponse> getAnimePictures(int animeId) async {
    final url = Uri.parse('$_baseUrl/$animeId/pictures');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimePicturesResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load anime pictures');
    }
  }

  static Future<AnimeStatistics> getAnimeStatistics(int animeId) async {
    final url = Uri.parse('$_baseUrl/$animeId/statistics');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimeStatistics.fromJson(jsonData['data']);
    } else {
      throw Exception('Failed to load anime statistics');
    }
  }

  static Future<AnimeUserUpdatesResponse> getAnimeUserUpdates(int animeId,
      {int page = 1}) async {
    final url = Uri.parse('$_baseUrl/$animeId/userupdates?page=$page');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimeUserUpdatesResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load anime user updates');
    }
  }

  Future<AnimeReviewsResponse> getAnimeReviews(int animeId,
      {int page = 1, bool? preliminary, bool? spoilers}) async {
    final queryParameters = {
      'page': page.toString(),
      if (preliminary != null) 'preliminary': preliminary.toString(),
      if (spoilers != null) 'spoilers': spoilers.toString(),
    };

    final url = Uri.parse('$_baseUrl/$animeId/reviews')
        .replace(queryParameters: queryParameters);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return AnimeReviewsResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load anime reviews');
    }
  }

  //a revoir en long et en large
  Future<List<JikanAnime>> getAnimeSearch({
    bool? unapproved,
    int? page,
    int? limit,
    String? q,
    AnimeSearchQueryType? type,
    double? score,
    double? minScore,
    double? maxScore,
    AnimeSearchQueryStatus? status,
    AnimeSearchQueryRating? rating,
    bool? sfw,
    String? genres,
    String? genresExclude,
    AnimeSearchQueryOrderBy? orderBy,
    SearchQuerySort? sort,
    String? letter,
    String? producers,
    String? startDate,
    String? endDate,
  }) async {
    final queryParameters = {
      if (unapproved != null) 'unapproved': unapproved.toString(),
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
      if (q != null) 'q': q,
      if (type != null) 'type': type.value,
      if (score != null) 'score': score.toString(),
      if (minScore != null) 'min_score': minScore.toString(),
      if (maxScore != null) 'max_score': maxScore.toString(),
      if (status != null) 'status': status.value,
      if (rating != null) 'rating': rating.value,
      if (sfw != null) 'sfw': sfw.toString(),
      if (genres != null) 'genres': genres,
      if (genresExclude != null) 'genres_exclude': genresExclude,
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (letter != null) 'letter': letter,
      if (producers != null) 'producers': producers,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    };

    final url = Uri.parse(_baseUrl).replace(queryParameters: queryParameters);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return (jsonData['data'] as List)
          .map((e) => JikanAnime.fromJson(e))
          .toList();
    } else {
      throw Exception('Failed to search anime');
    }
  }

  Future<GenreResponse> getGenre(GenreCategory category,
      {GenreQueryFilter? filter}) async {
    final queryParameters = {
      if (filter != null) 'filter': filter.value,
    };

    final url = Uri.parse('$_jikanv4/genres/${category.value}')
        .replace(queryParameters: queryParameters);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return GenreResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load genres');
    }
  }

  Future<CharacterFull> getCharacterFullById(int id) async {
    final url = Uri.parse('$_jikanv4/characters/$id/full');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return CharacterFull.fromJson(jsonData['data']);
    } else {
      throw Exception('Failed to load character details');
    }
  }

  // i have to add getcharactersearch when i'll fix getanimeSearch

  Future<PersonFull> getPersonFullById(int id) async {
    final url = Uri.parse('$_jikanv4/people/$id/full');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return PersonFull.fromJson(jsonData['data']);
    } else {
      throw Exception('Failed to load person details');
    }
  }

  // i have to add getPeopleSearch when i'll fix getanimeSearch

  Future<ProducerFull> getProducerFullById(int id) async {
    final url = Uri.parse('$_jikanv4/producers/$id/full');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return ProducerFull.fromJson(jsonData['data']);
    } else {
      throw Exception('Failed to load producer details');
    }
  }

  Future<ProducersResponse> getProducers({
    int? page,
    int? limit,
    String? q,
    ProducersQueryOrderBy? orderBy,
    SearchQuerySort? sort,
    String? letter,
  }) async {
    final queryParameters = {
      if (q != null) 'q': q,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
      if (orderBy != null) 'order_by': orderBy.value,
      if (sort != null) 'sort': sort.value,
      if (letter != null) 'letter': letter,
    };

    final url = Uri.parse('$_jikanv4/producers')
        .replace(queryParameters: queryParameters);
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return ProducersResponse.fromJson(jsonData);
    } else {
      throw Exception('Failed to load producers');
    }
  }
}
