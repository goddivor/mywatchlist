// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/user.dart';

// import 'package:my_watch_list/user/account_bloc.dart';
// import 'package:my_watch_list/user/account_manager.dart';

// import 'package:path/path.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// enum SeasonType {
//   WINTER,
//   SPRING,
//   SUMMER,
//   FALL,
// }

// enum RankingType {
//   all,
//   airing,
//   upcoming,
//   tv,
//   ova,
//   movie,
//   special,
//   bypopularity,
//   favorite,
// }

enum SeasonalAnimeSortOption {
  score,
  numListUsers,
}

enum AnimeListStatus {
  watching,
  completed,
  onHold,
  dropped,
  planToWatch,
}

enum AnimeListSort {
  listScore,
  listUpdatedAt,
  animeTitle,
  animeStartDate,
  animeId,
}

class MalApi {
  static const String clientId = Constants.malclientId;
  static const String animeEndPoint = Constants.malanimeEndPoint;
  static const String animeRankingEndPoint = Constants.malanimeRankingEndPoint;
  static const String mangaRankingEndPoint = Constants.malmangaRankingEndPoint;
  static const String malApiUrl = Constants.malapiUrl;
  static const String animeSeasonalEndPoint =
      Constants.malanimeSeasonalEndPoint;
  static const String animeSuggestedEndPoint =
      Constants.malanimeSuggestedEndPoint;
  static const String mangaSuggestedEndPoint =
      Constants.malmangaSuggestedEndPoint;
  static const String userBaseEndPoint = Constants.maluserBaseEndPoint;

  AccountType selectedAcc = AccountType.none; // Valeur par défaut

  //implement Get anime details endpoint - https://api.myanimelist.net/v2/anime/{anime_id}
  Future<MalAnime> getAnimeDetails(int animeId) async {
    const fields = Constants.malAnimeFields;

    final url = '$animeEndPoint/$animeId?fields=$fields';

    // Obtenir le type de compte sélectionné et les en-têtes appropriés
    // AccountType selectedAcc = AccountManager().getSelectedAccountType();
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    // print(selectedAcc);
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MalAnime.fromJson(data);
    } else {
      throw Exception('Failed to load anime details');
    }
  }

  //implement Get anime list endpoint - https://api.myanimelist.net/v2/anime
  Future<List<Anime>> searchAnime(String query,
      {int limit = 100, int offset = 0, List<String>? fields}) async {
    // Construire l'URL avec les paramètres appropriés
    String url = '$animeEndPoint?q=$query&limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url +=
          "&fields=${fields.reduce((value, element) => ("$value,$element"))}";
    } else {
      url +=
          "&fields=id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,created_at,updated_at,media_type,status,genres,my_list_status,num_episodes,start_season,broadcast,source,average_episode_duration,rating,pictures,background,related_anime,related_manga,recommendations,studios,statistics";
    }

    // Obtenir le type de compte sélectionné et les en-têtes appropriés
    // AccountType selectedAcc = AccountManager().getSelectedAccountType();
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonData = json.decode(response.body)['data'];
      return jsonData.map((data) => Anime.fromMAlJson(data['node'])).toList();
    } else {
      throw Exception('Failed to search anime');
    }
  }

  //implement Get anime ranking endpoint - https://api.myanimelist.net/v2/anime/ranking
  static Future<List<Anime>> getContentRanking(
    dynamic rankingType, {
    int limit = 100,
    int offset = 0,
    String category = "anime",
    List<String>? fields,
  }) async {
    // Get the raking type name using enum
    // String rankingTypeValue = getRankingTypeValue(rankingType);
    String rankingTypeValue = (category.equals("anime")
        ? rankingMap[rankingType]
        : mangaRankingMap[rankingType])!;

    // Determine the endpoint based on the category
    String endpoint =
        category == "anime" ? animeRankingEndPoint : mangaRankingEndPoint;

    // Construire l'URL avec les paramètres appropriés
    String url =
        '$endpoint?ranking_type=$rankingTypeValue&limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url +=
          "&fields=${fields.reduce((value, element) => ("$value,$element"))}";
    } else {
      url +=
          "&fields=id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,created_at,updated_at,media_type,status,genres,my_list_status,num_episodes,start_season,broadcast,source,average_episode_duration,rating,pictures,background,related_anime,related_manga,recommendations,studios,statistics";
    }

    // Obtenir le type de compte sélectionné et les en-têtes appropriés
    // AccountType selectedAcc = AccountManager().getSelectedAccountType();
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonData = json.decode(response.body)['data'];
      return jsonData.map((data) => Anime.fromMAlJson(data['node'])).toList();
    } else {
      throw Exception('Failed to get anime ranking');
    }
  }

  static Future<List<Anime>> getCurrentSeason({
    SortType? sortType,
    int limit = 100,
    int offset = 0,
    List<String>? fields,
  }) async {
    return await getAnimeSeasonal(
      MalApi.getSeasonType(),
      MalApi.getCurrentSeasonYear(),
      sortType: sortType,
      limit: limit,
      offset: offset,
      fields: fields,
    );
  }

  //implement Get seasonal anime endpoint - https://api.myanimelist.net/v2/anime/season/$year/$season
  static Future<List<Anime>> getAnimeSeasonal(
    SeasonType seasonType,
    int year, {
    SortType? sortType,
    int limit = 100,
    int offset = 0,
    List<String>? fields,
  }) async {
    // Convert the SeasonType enum to a string using the getSeasonName function
    String season = getSeasonName(seasonType).toLowerCase();

    // Get the sort option value using the enum
    String sortValue = sortMap[sortType]!;

    // Construct the URL for the API request
    String url =
        '$animeSeasonalEndPoint/$year/$season?sort=$sortValue&limit=$limit&offset=$offset';

    // Add fields to the URL if specified
    if (fields != null && fields.isNotEmpty) {
      url += "&fields=${fields.join(',')}";
    } else {
      url +=
          "&fields=id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,created_at,updated_at,media_type,status,genres,my_list_status,num_episodes,start_season,broadcast,source,average_episode_duration,rating,pictures,background,related_anime,related_manga,recommendations,studios,statistics";
    }

    // Obtenir le type de compte sélectionné et les en-têtes appropriés
    // AccountType selectedAcc = AccountManager().getSelectedAccountType();
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    // Make the HTTP GET request
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    // Handle the response
    if (response.statusCode == 200) {
      List<dynamic> jsonData = json.decode(response.body)['data'];
      return jsonData.map((data) => Anime.fromMAlJson(data['node'])).toList();
    } else {
      throw Exception('Failed to get seasonal anime');
    }
  }

  //implement Get suggested anime endpoint - https://api.myanimelist.net/v2/anime/suggestions
  static Future<List<Anime>> getContentSuggestions({
    int limit = 100,
    int offset = 0,
    String category = "anime",
    List<String>? fields,
  }) async {
    // Construire l'URL avec les paramètres appropriés
    String endpoint =
        category == "anime" ? animeSuggestedEndPoint : mangaSuggestedEndPoint;
    String url = '$endpoint?limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url +=
          "&fields=${fields.reduce((value, element) => ("$value,$element"))}";
    } else {
      // Définir les champs par défaut si aucun n'est fourni
      url +=
          "&fields=id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,created_at,updated_at,media_type,status,genres,my_list_status,num_episodes,start_season,broadcast,source,average_episode_duration,rating,pictures,background,related_anime,related_manga,recommendations,studios,statistics";
    }

    // Obtenir le type de compte sélectionné et les en-têtes appropriés
    // AccountType selectedAcc = AccountManager().getSelectedAccountType();
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    // Faire la requête HTTP
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    // Vérifier la réponse
    if (response.statusCode == 200) {
      // Analyser les données JSON
      List<dynamic> jsonData = json.decode(response.body)['data'];
      return jsonData.map((data) => Anime.fromMAlJson(data['node'])).toList();
    } else {
      throw Exception('Failed to get suggested anime');
    }
  }

  //implement Get user anime list endpoint - https://api.myanimelist.net/v2/users/{user_name}/animelist
  Future<List<Anime>> getUserAnimeList({
    String userName = '@me',
    AnimeListStatus? status,
    AnimeListSort? sort,
    int limit = 1000,
    int offset = 0,
    List<String>? fields,
  }) async {
    // Construction de l'URL de base
    String url = '$userBaseEndPoint/$userName/animelist';

    // Ajout des paramètres de requête
    List<String> queryParams = [];

    if (status != null) {
      String statusValue = getAnimeListStatusValue(status);
      queryParams.add('status=$statusValue');
    }

    if (sort != null) {
      String sortValue = getAnimeListSortValue(sort);
      queryParams.add('sort=$sortValue');
    }

    queryParams.add('limit=$limit');
    queryParams.add('offset=$offset');

    if (fields != null && fields.isNotEmpty) {
      queryParams.add('fields=${fields.join(",")}');
    } else {
      queryParams.add(
          'fields=id,title,main_picture,mean,num_list_users,status,media_type,num_episodes,start_date,end_date,list_status{is_rewatching,is_rereading,num_times_rewatched,num_times_reread,priority,rewatch_value,reread_value,start_date,finish_date,tags,comments}');
    }

    // Ajout des paramètres à l'URL
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join("&")}';
    }

    // Obtenir le type de compte sélectionné et les en-têtes appropriés
    // AccountType selectedAcc = AccountManager().getSelectedAccountType();
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonData = json.decode(response.body)['data'];
      return jsonData.map((data) => Anime.fromMAlJson(data['node'])).toList();
    } else {
      throw Exception('Failed to get user anime list');
    }
  }

  //fonction a revoir de long en large avec des test
  Future<void> updateMyAnimeListStatus({
    required int animeId,
    required AnimeListStatus status,
    bool? isRewatching,
    int? score,
    int? numWatchedEpisodes,
    int? priority,
    int? numTimesRewatched,
    int? rewatchValue,
    String? tags,
    String? comments,
  }) async {
    // Get the status value from the enum
    String statusValue = getAnimeListStatusValue(status);

    // URL for the API endpoint
    String url = '$animeEndPoint/$animeId/my_list_status';

    // Get the selected account type and headers
    // AccountType selectedAcc = AccountManager().getSelectedAccountType();
    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    // Check if headers contain Authorization
    if (!headers.containsKey('Authorization')) {
      throw 'Access token required for updating list status';
    }

    // Construct the request body
    Map<String, dynamic> requestBody = {
      'status': statusValue,
    };

    if (isRewatching != null) requestBody['is_rewatching'] = isRewatching;
    if (score != null) requestBody['score'] = score;
    if (numWatchedEpisodes != null) {
      requestBody['num_watched_episodes'] = numWatchedEpisodes;
    }
    if (priority != null) requestBody['priority'] = priority;
    if (numTimesRewatched != null) {
      requestBody['num_times_rewatched'] = numTimesRewatched;
    }
    if (rewatchValue != null) requestBody['rewatch_value'] = rewatchValue;
    if (tags != null) requestBody['tags'] = tags;
    if (comments != null) requestBody['comments'] = comments;

    // Make the PUT request to the API
    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    // Check the response status
    if (response.statusCode == 200) {
      // Parse the response data if needed
      final responseData = json.decode(response.body);
      if (kDebugMode) {
        print('List status updated successfully: $responseData');
      }
    } else {
      throw Exception(
          'Failed to update anime list status: ${response.statusCode}');
    }
  }

  //utilities fonctions
  static SeasonType getSeasonType() {
    final date = DateTime.now();
    final month = date.month;
    final day = date.day;
    SeasonType seasonType;

    if ((month == 12 && day >= 28) ||
        (month == 1) ||
        (month == 2) ||
        (month == 3 && day < 28)) {
      seasonType = SeasonType.WINTER;
    } else if ((month == 3 && day >= 28) ||
        (month == 4) ||
        (month == 5) ||
        (month == 6 && day < 28)) {
      seasonType = SeasonType.SPRING;
    } else if ((month == 6 && day >= 28) ||
        (month == 7) ||
        (month == 8) ||
        (month == 9 && day < 28)) {
      seasonType = SeasonType.SUMMER;
    } else {
      seasonType = SeasonType.FALL;
    }
    return seasonType;
  }

  static String getSeasonName(SeasonType seasonType) {
    switch (seasonType) {
      case SeasonType.WINTER:
        return "Winter";
      case SeasonType.SPRING:
        return "Spring";
      case SeasonType.SUMMER:
        return "Summer";
      case SeasonType.FALL:
        return "Fall";
    }
  }

  static String getRankingTypeValue(RankingType rankingType) {
    switch (rankingType) {
      case RankingType.ALL:
        return "all";
      case RankingType.AIRING:
        return "airing";
      case RankingType.UPCOMING:
        return "upcoming";
      case RankingType.TV:
        return "tv";
      case RankingType.OVA:
        return "ova";
      case RankingType.MOVIE:
        return "movie";
      case RankingType.SPECIAL:
        return "special";
      case RankingType.BYPOPULARITY:
        return "bypopularity";
      case RankingType.FAVOURITE:
        return "favorite";
      case RankingType.ONA:
        return "ona";
      // Default case
    }
  }

  static String getSeasonalSortOptionValue(SeasonalAnimeSortOption option) {
    switch (option) {
      case SeasonalAnimeSortOption.score:
        return "anime_score";
      case SeasonalAnimeSortOption.numListUsers:
        return "anime_num_list_users";
      // Default case
    }
  }

  String getAnimeListStatusValue(AnimeListStatus status) {
    switch (status) {
      case AnimeListStatus.watching:
        return 'watching';
      case AnimeListStatus.completed:
        return 'completed';
      case AnimeListStatus.onHold:
        return 'on_hold';
      case AnimeListStatus.dropped:
        return 'dropped';
      case AnimeListStatus.planToWatch:
        return 'plan_to_watch';
    }
  }

  String getAnimeListSortValue(AnimeListSort sort) {
    switch (sort) {
      case AnimeListSort.listScore:
        return 'list_score';
      case AnimeListSort.listUpdatedAt:
        return 'list_updated_at';
      case AnimeListSort.animeTitle:
        return 'anime_title';
      case AnimeListSort.animeStartDate:
        return 'anime_start_date';
      case AnimeListSort.animeId:
        return 'anime_id';
    }
  }

  static int getCurrentSeasonYear() {
    final date = DateTime.now();
    final month = date.month;
    final day = date.day;
    if ((month == 12 && day >= 28) ||
        (month == 1) ||
        (month == 2) ||
        (month == 3 && day < 28)) {
      if (month == 12 && day >= 28) {
        return date.year + 1;
      }
      return date.year;
    } else if ((month == 3 && day >= 28) ||
        (month == 4) ||
        (month == 5) ||
        (month == 6 && day < 28)) {
      return date.year;
    } else if ((month == 6 && day >= 28) ||
        (month == 7) ||
        (month == 8) ||
        (month == 9 && day < 28)) {
      return date.year;
    } else {
      return date.year;
    }
  }

  static Map<String, String> getHeadersForAccountType(AccountType accountType) {
    final Map<String, String> headers = {};

    switch (accountType) {
      case AccountType.myanimelist:
        final accessToken = UserMal.instance.authResponse?.accessToken;
        if (accessToken != null) {
          headers.addAll({
            'Authorization': 'Bearer $accessToken',
          });
        } else {
          throw 'No access token found';
        }
        break;
      // Ajoutez ici des cas pour d'autres types de comptes si nécessaire
      default:
        headers.addAll({
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-MAL-CLIENT-ID': clientId,
        });
    }

    return headers;
  }
}
