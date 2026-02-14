// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/services/api/MAL/models/paging.dart';
import 'package:mywatchlist/services/api/MAL/models/search_result.dart';
import 'package:mywatchlist/services/api/MAL/models/all_search_result.dart';
import 'package:mywatchlist/services/api/MAL/models/my_anime_list_status.dart' as mal_status;
import 'package:mywatchlist/services/api/MAL/models/my_manga_list_status.dart' as manga_status;
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/user/user_preference.dart';

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

enum MangaListStatus {
  reading,
  completed,
  onHold,
  dropped,
  planToRead,
}

enum MangaListSort {
  listScore,
  listUpdatedAt,
  mangaTitle,
  mangaStartDate,
  mangaId,
}

class MalApi {
  static String clientId = Constants.malclientId;
  static const String animeEndPoint = Constants.malanimeEndPoint;
  static const String mangaEndPoint = Constants.malmangaEndPoint;
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
  static const String forumEndPoint = Constants.malforumEndPoint;

  AccountType selectedAcc = AccountType.none;

  // Get anime details - GET /anime/{anime_id}
  Future<MalAnime> getAnimeDetails(int animeId) async {
    const fields = Constants.malAnimeFields;

    final url = '$animeEndPoint/$animeId?fields=$fields';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return MalAnime.fromJson(data);
    } else {
      debugPrint('MAL API error: ${response.statusCode} for $url');
      throw Exception('Failed to load anime details (${response.statusCode})');
    }
  }

  // Get manga details - GET /manga/{manga_id}
  Future<MalAnime> getMangaDetails(int mangaId) async {
    const fields = Constants.malMangaFields;

    final url = '$mangaEndPoint/$mangaId?fields=$fields';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return MalAnime.fromJson(data);
    } else {
      debugPrint('MAL API error: ${response.statusCode} for $url');
      throw Exception('Failed to load manga details (${response.statusCode})');
    }
  }

  // Search anime - GET /anime
  Future<SearchResult> searchAnimeResult(String query,
      {int limit = 100, int offset = 0, List<String>? fields}) async {
    String url = '$animeEndPoint?q=$query&limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url +=
          "&fields=${fields.reduce((value, element) => ("$value,$element"))}";
    } else {
      url += "&fields=${Constants.malDefaultAnimeListFields}";
    }

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final fullResponse = json.decode(response.body) as Map<String, dynamic>;
      return SearchResult.fromJson(fullResponse);
    } else {
      throw Exception('Failed to search anime');
    }
  }

  Future<List<Anime>> searchAnime(String query,
      {int limit = 100, int offset = 0, List<String>? fields}) async {
    return (await searchAnimeResult(query,
            limit: limit, offset: offset, fields: fields))
        .data;
  }

  // Search manga - GET /manga
  Future<SearchResult> searchMangaResult(String query,
      {int limit = 100, int offset = 0, List<String>? fields}) async {
    String url = '$mangaEndPoint?q=$query&limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url +=
          "&fields=${fields.reduce((value, element) => ("$value,$element"))}";
    } else {
      url +=
          "&fields=id,title,main_picture,alternative_titles,start_date,end_date,synopsis,mean,rank,popularity,num_list_users,num_scoring_users,nsfw,media_type,status,genres,my_list_status,num_volumes,num_chapters";
    }

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final fullResponse = json.decode(response.body) as Map<String, dynamic>;
      return SearchResult.fromJson(fullResponse);
    } else {
      throw Exception('Failed to search manga');
    }
  }

  Future<List<Anime>> searchManga(String query,
      {int limit = 100, int offset = 0, List<String>? fields}) async {
    return (await searchMangaResult(query,
            limit: limit, offset: offset, fields: fields))
        .data;
  }

  // Get anime/manga ranking - GET /anime/ranking or /manga/ranking
  static Future<SearchResult> getContentRankingResult(
    dynamic rankingType, {
    int limit = 100,
    int offset = 0,
    String category = "anime",
    List<String>? fields,
  }) async {
    // Get the ranking type name using enum
    String rankingTypeValue = (category == "anime"
        ? rankingMap[rankingType]
        : mangaRankingMap[rankingType])!;

    // Determine the endpoint based on the category
    String endpoint =
        category == "anime" ? animeRankingEndPoint : mangaRankingEndPoint;

    String url =
        '$endpoint?ranking_type=$rankingTypeValue&limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url +=
          "&fields=${fields.reduce((value, element) => ("$value,$element"))}";
    } else {
      url += "&fields=${Constants.malDefaultAnimeListFields}";
    }

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final fullResponse = json.decode(response.body) as Map<String, dynamic>;
      return SearchResult.fromJson(fullResponse);
    } else {
      throw Exception('Failed to get anime ranking');
    }
  }

  static Future<List<Anime>> getContentRanking(
    dynamic rankingType, {
    int limit = 100,
    int offset = 0,
    String category = "anime",
    List<String>? fields,
  }) async {
    return (await getContentRankingResult(rankingType,
            limit: limit, offset: offset, category: category, fields: fields))
        .data;
  }

  static Future<SearchResult> getCurrentSeasonResult({
    SortType? sortType,
    int limit = 100,
    int offset = 0,
    List<String>? fields,
  }) async {
    return await getAnimeSeasonalResult(
      MalApi.getSeasonType(),
      MalApi.getCurrentSeasonYear(),
      sortType: sortType,
      limit: limit,
      offset: offset,
      fields: fields,
    );
  }

  static Future<List<Anime>> getCurrentSeason({
    SortType? sortType,
    int limit = 100,
    int offset = 0,
    List<String>? fields,
  }) async {
    return (await getCurrentSeasonResult(
            sortType: sortType, limit: limit, offset: offset, fields: fields))
        .data;
  }

  // Get seasonal anime - GET /anime/season/{year}/{season}
  static Future<SearchResult> getAnimeSeasonalResult(
    SeasonType seasonType,
    int year, {
    SortType? sortType,
    int limit = 100,
    int offset = 0,
    List<String>? fields,
  }) async {
    String season = getSeasonName(seasonType).toLowerCase();
    String sortValue = sortMap[sortType]!;

    String url =
        '$animeSeasonalEndPoint/$year/$season?sort=$sortValue&limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url += "&fields=${fields.join(',')}";
    } else {
      url += "&fields=${Constants.malDefaultAnimeListFields}";
    }

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final fullResponse = json.decode(response.body) as Map<String, dynamic>;
      return SearchResult.fromJson(fullResponse);
    } else {
      throw Exception('Failed to get seasonal anime');
    }
  }

  static Future<List<Anime>> getAnimeSeasonal(
    SeasonType seasonType,
    int year, {
    SortType? sortType,
    int limit = 100,
    int offset = 0,
    List<String>? fields,
  }) async {
    return (await getAnimeSeasonalResult(seasonType, year,
            sortType: sortType, limit: limit, offset: offset, fields: fields))
        .data;
  }

  // Get suggested anime/manga - GET /anime/suggestions or /manga/suggestions
  static Future<SearchResult> getContentSuggestionsResult({
    int limit = 100,
    int offset = 0,
    String category = "anime",
    List<String>? fields,
  }) async {
    String endpoint =
        category == "anime" ? animeSuggestedEndPoint : mangaSuggestedEndPoint;
    String url = '$endpoint?limit=$limit&offset=$offset';

    if (fields != null && fields.isNotEmpty) {
      url +=
          "&fields=${fields.reduce((value, element) => ("$value,$element"))}";
    } else {
      url += "&fields=${Constants.malDefaultAnimeListFields}";
    }

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final fullResponse = json.decode(response.body) as Map<String, dynamic>;
      return SearchResult.fromJson(fullResponse);
    } else {
      throw Exception('Failed to get suggested anime');
    }
  }

  static Future<List<Anime>> getContentSuggestions({
    int limit = 100,
    int offset = 0,
    String category = "anime",
    List<String>? fields,
  }) async {
    return (await getContentSuggestionsResult(
            limit: limit, offset: offset, category: category, fields: fields))
        .data;
  }

  // Get user anime list - GET /users/{user_name}/animelist
  Future<SearchResult> getUserAnimeListResult({
    String userName = '@me',
    AnimeListStatus? status,
    AnimeListSort? sort,
    int limit = 1000,
    int offset = 0,
    List<String>? fields,
  }) async {
    String url = '$userBaseEndPoint/$userName/animelist';

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

    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join("&")}';
    }

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final fullResponse = json.decode(response.body) as Map<String, dynamic>;
      return SearchResult.fromJson(fullResponse);
    } else {
      throw Exception('Failed to get user anime list');
    }
  }

  Future<List<Anime>> getUserAnimeList({
    String userName = '@me',
    AnimeListStatus? status,
    AnimeListSort? sort,
    int limit = 1000,
    int offset = 0,
    List<String>? fields,
  }) async {
    return (await getUserAnimeListResult(
            userName: userName,
            status: status,
            sort: sort,
            limit: limit,
            offset: offset,
            fields: fields))
        .data;
  }

  // Update anime list status - PUT /anime/{anime_id}/my_list_status
  // MAL requires application/x-www-form-urlencoded format
  Future<mal_status.MyAnimeListStatus?> updateMyAnimeListStatus({
    required int animeId,
    String? status,
    bool? isRewatching,
    int? score,
    int? numWatchedEpisodes,
    int? priority,
    int? numTimesRewatched,
    int? rewatchValue,
    String? tags,
    String? comments,
    String? startDate,
    String? finishDate,
  }) async {
    String url = '$animeEndPoint/$animeId/my_list_status';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    if (!headers.containsKey('Authorization')) {
      throw 'Access token required for updating list status';
    }

    // MAL requires form-urlencoded format, not JSON
    headers['Content-Type'] = 'application/x-www-form-urlencoded';

    Map<String, String> requestBody = {};

    if (status != null) requestBody['status'] = status;
    if (isRewatching != null) {
      requestBody['is_rewatching'] = isRewatching.toString();
    }
    if (score != null) requestBody['score'] = score.toString();
    if (numWatchedEpisodes != null) {
      requestBody['num_watched_episodes'] = numWatchedEpisodes.toString();
    }
    if (priority != null) requestBody['priority'] = priority.toString();
    if (numTimesRewatched != null) {
      requestBody['num_times_rewatched'] = numTimesRewatched.toString();
    }
    if (rewatchValue != null) {
      requestBody['rewatch_value'] = rewatchValue.toString();
    }
    if (tags != null) requestBody['tags'] = tags;
    if (comments != null) requestBody['comments'] = comments;
    if (startDate != null) requestBody['start_date'] = startDate;
    if (finishDate != null) requestBody['finish_date'] = finishDate;

    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final responseData =
          json.decode(response.body) as Map<String, dynamic>;
      if (kDebugMode) {
        print('List status updated successfully: $responseData');
      }
      return mal_status.MyAnimeListStatus.fromJson(responseData);
    } else {
      throw Exception(
          'Failed to update anime list status: ${response.statusCode}');
    }
  }

  // Update manga list status - PUT /manga/{manga_id}/my_list_status
  Future<manga_status.MyMangaListStatus?> updateMyMangaListStatus({
    required int mangaId,
    String? status,
    bool? isRereading,
    int? score,
    int? numVolumesRead,
    int? numChaptersRead,
    int? priority,
    int? numTimesReread,
    int? rereadValue,
    String? tags,
    String? comments,
    String? startDate,
    String? finishDate,
  }) async {
    String url = '$mangaEndPoint/$mangaId/my_list_status';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    if (!headers.containsKey('Authorization')) {
      throw 'Access token required for updating list status';
    }

    headers['Content-Type'] = 'application/x-www-form-urlencoded';

    Map<String, String> requestBody = {};

    if (status != null) requestBody['status'] = status;
    if (isRereading != null) {
      requestBody['is_rereading'] = isRereading.toString();
    }
    if (score != null) requestBody['score'] = score.toString();
    if (numVolumesRead != null) {
      requestBody['num_volumes_read'] = numVolumesRead.toString();
    }
    if (numChaptersRead != null) {
      requestBody['num_chapters_read'] = numChaptersRead.toString();
    }
    if (priority != null) requestBody['priority'] = priority.toString();
    if (numTimesReread != null) {
      requestBody['num_times_reread'] = numTimesReread.toString();
    }
    if (rereadValue != null) {
      requestBody['reread_value'] = rereadValue.toString();
    }
    if (tags != null) requestBody['tags'] = tags;
    if (comments != null) requestBody['comments'] = comments;
    if (startDate != null) requestBody['start_date'] = startDate;
    if (finishDate != null) requestBody['finish_date'] = finishDate;

    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: requestBody,
    );

    if (response.statusCode == 200) {
      final responseData =
          json.decode(response.body) as Map<String, dynamic>;
      if (kDebugMode) {
        print('Manga list status updated successfully: $responseData');
      }
      return manga_status.MyMangaListStatus.fromJson(responseData);
    } else {
      throw Exception(
          'Failed to update manga list status: ${response.statusCode}');
    }
  }

  // Delete anime from list - DELETE /anime/{anime_id}/my_list_status
  Future<void> deleteAnimeFromList(int animeId) async {
    String url = '$animeEndPoint/$animeId/my_list_status';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    if (!headers.containsKey('Authorization')) {
      throw 'Access token required for deleting from list';
    }

    final response = await http.delete(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 404) {
      throw Exception(
          'Failed to delete anime from list: ${response.statusCode}');
    }
  }

  // Delete manga from list - DELETE /manga/{manga_id}/my_list_status
  Future<void> deleteMangaFromList(int mangaId) async {
    String url = '$mangaEndPoint/$mangaId/my_list_status';

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final Map<String, String> headers = getHeadersForAccountType(selectedAcc);

    if (!headers.containsKey('Authorization')) {
      throw 'Access token required for deleting from list';
    }

    final response = await http.delete(
      Uri.parse(url),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 404) {
      throw Exception(
          'Failed to delete manga from list: ${response.statusCode}');
    }
  }

  // Utility methods
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
    }
  }

  static String getSeasonalSortOptionValue(SeasonalAnimeSortOption option) {
    switch (option) {
      case SeasonalAnimeSortOption.score:
        return "anime_score";
      case SeasonalAnimeSortOption.numListUsers:
        return "anime_num_list_users";
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

  String getMangaListStatusValue(MangaListStatus status) {
    switch (status) {
      case MangaListStatus.reading:
        return 'reading';
      case MangaListStatus.completed:
        return 'completed';
      case MangaListStatus.onHold:
        return 'on_hold';
      case MangaListStatus.dropped:
        return 'dropped';
      case MangaListStatus.planToRead:
        return 'plan_to_read';
    }
  }

  String getMangaListSortValue(MangaListSort sort) {
    switch (sort) {
      case MangaListSort.listScore:
        return 'list_score';
      case MangaListSort.listUpdatedAt:
        return 'list_updated_at';
      case MangaListSort.mangaTitle:
        return 'manga_title';
      case MangaListSort.mangaStartDate:
        return 'manga_start_date';
      case MangaListSort.mangaId:
        return 'manga_id';
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
        final accessToken = UserMalV2.instance.authResponse?.accessToken;
        if (accessToken != null) {
          headers.addAll({
            'Authorization': 'Bearer $accessToken',
          });
        } else {
          throw 'No access token found';
        }
        break;
      default:
        headers.addAll({
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-MAL-CLIENT-ID': clientId,
        });
    }

    return headers;
  }

  static const weekdaysOrderMap = {
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
    'Sunday': 7
  };

  static String? getFormattedAiringDate(
    Broadcast broadcast, [
    DateFormat? dateFormat,
    TimezonePref timezonePref = TimezonePref.local,
  ]) {
    try {
      final weekday = weekdaysOrderMap[broadcast.dayOfTheWeek];
      if (weekday == null || broadcast.startTime.isEmpty) return null;

      final timeSplit = broadcast.startTime.split(":");
      final hours = int.tryParse(timeSplit[0]);
      final mins = int.tryParse(timeSplit[1]);
      if (hours == null || mins == null) return null;

      final now = DateTime.now();

      // Get airing date in UTC (subtracts 9h from JST)
      final airingDate = getAiringDate(broadcast);
      if (airingDate == null) return null;

      // Adjust time based on user's timezone preference
      final adjustedTime = getAdjustedTime(airingDate, now, timezonePref);

      dateFormat ??= DateFormat('EEEE h:mm a');

      final tzName = getTimezoneName(now, timezonePref);

      return '${dateFormat.format(adjustedTime)} ($tzName)';
    } catch (e) {
      debugPrint('Error formatting airing date: $e');
    }
    return null;
  }

  static DateTime? getAiringDate(Broadcast broadcast) {
    final nowDate = DateTime.now();
    try {
      final weekday = weekdaysOrderMap[broadcast.dayOfTheWeek];
      if (weekday != null) {
        final timeSplit = broadcast.startTime.split(":");
        final hours = int.tryParse(timeSplit[0]);
        final mins = int.tryParse(timeSplit[1]);
        if (hours != null && mins != null) {
          return nowDate.nextDate(weekday).add(Duration(
                hours: hours - 9, // Japan Time offset
                minutes: mins,
              ));
        }
      }
    } catch (e) {
      print('Error getting airing date: $e');
    }
    return null;
  }

  /// Adjust airing time based on user's timezone preference.
  /// [airingTime] is in UTC (already converted from JST by subtracting 9h).
  static DateTime getAdjustedTime(
    DateTime airingTime,
    DateTime nowDate, [
    TimezonePref pref = TimezonePref.local,
  ]) {
    switch (pref) {
      case TimezonePref.jst:
        return airingTime.add(const Duration(hours: 9));
      case TimezonePref.utc:
        return airingTime;
      case TimezonePref.local:
        return airingTime.add(Duration(
          minutes: nowDate.timeZoneOffset.inMinutes,
        ));
    }
  }

  /// Get timezone display name based on user preference.
  static String getTimezoneName(DateTime dateTime,
      [TimezonePref pref = TimezonePref.local]) {
    switch (pref) {
      case TimezonePref.jst:
        return 'JST';
      case TimezonePref.utc:
        return 'UTC';
      case TimezonePref.local:
        try {
          return dateTime.timeZoneName;
        } catch (_) {
          final h = dateTime.timeZoneOffset.inHours;
          final m = dateTime.timeZoneOffset.inMinutes.remainder(60);
          return 'UTC${h >= 0 ? '+' : ''}$h${m != 0 ? ':${m.abs().toString().padLeft(2, '0')}' : ''}';
        }
    }
  }

  /// Load the next or previous page of a paginated MAL API response.
  static Future<SearchResult> getContentListPage(Paging page,
      {bool next = true}) async {
    final url = next ? page.next : page.previous;
    if (url == null) return SearchResult();

    final selectedAcc = AccountManagerSingleton().selectedAcc;
    final headers = getHeadersForAccountType(selectedAcc);
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      return SearchResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load page');
    }
  }

  /// Build a weekly airing schedule organized by day of the week.
  /// Returns 8 lists: Monday(0) through Sunday(6) + Other(7).
  static Future<List<List<Anime>>> getSchedule({
    SeasonType? seasonType,
    int? currentYear,
  }) async {
    seasonType ??= MalApi.getSeasonType();
    currentYear ??= MalApi.getCurrentSeasonYear();

    final result = await getAnimeSeasonalResult(
      seasonType, currentYear,
      sortType: SortType.AnimeScore,
      limit: 500,
      fields: [
        'my_list_status',
        'broadcast',
        'status',
        'mean',
        'num_list_users'
      ],
    );

    // 8 buckets: index 0-6 = Monday-Sunday, index 7 = Other
    final schedule = List.generate(8, (_) => <Anime>[]);

    for (final anime in result.data) {
      if (anime.broadcast != null &&
          anime.broadcast!.dayOfTheWeek.isNotEmpty &&
          anime.broadcast!.startTime.isNotEmpty) {
        // Capitalize first letter: MAL API returns lowercase, weekdaysOrderMap uses capitalized keys
        final dayCapitalized = anime.broadcast!.dayOfTheWeek[0].toUpperCase() +
            anime.broadcast!.dayOfTheWeek.substring(1).toLowerCase();
        final weekday = weekdaysOrderMap[dayCapitalized];
        if (weekday != null) {
          // Adjust for timezone: get airing date and find adjusted weekday
          final airingDate = getAiringDate(
            Broadcast(
              dayOfTheWeek: dayCapitalized,
              startTime: anime.broadcast!.startTime,
            ),
          );
          if (airingDate != null) {
            final adjustedDay =
                airingDate.toLocal().weekday; // 1=Monday, 7=Sunday
            schedule[adjustedDay - 1].add(anime);
          } else {
            schedule[weekday - 1].add(anime);
          }
        } else {
          schedule[7].add(anime);
        }
      } else {
        schedule[7].add(anime);
      }
    }

    return schedule;
  }

  /// Wrap a single anime/manga detail lookup into a SearchResult.
  Future<SearchResult> searchById(int id, {String category = "anime"}) async {
    Anime content;
    if (category == "anime") {
      final details = await getAnimeDetails(id);
      content = Anime(
        id: details.id,
        title: details.title,
        imageUrl: details.mainPicture?.medium ?? '',
        score: details.mean ?? 0.0,
        members: details.numListUsers ?? 0,
        mediaType: details.mediaType,
        numEpisodes: details.numEpisodes,
      );
    } else {
      final details = await getMangaDetails(id);
      content = Anime(
        id: details.id,
        title: details.title,
        imageUrl: details.mainPicture?.medium ?? '',
        score: details.mean ?? 0.0,
        members: details.numListUsers ?? 0,
        mediaType: details.mediaType,
        numVolumes: details.numVolumes,
      );
    }
    return SearchResult(data: [content]);
  }

  /// Convenience method to update the episode count for an anime.
  /// Validates bounds and auto-completes when reaching total episodes.
  /// Returns the updated status or null on failure.
  Future<mal_status.MyAnimeListStatus?> updateEpisodeCount(
    dynamic content, {
    int? episodes,
    int? add,
  }) async {
    int totalEpisodes = (episodes ?? 0) + (add ?? 0);
    if (totalEpisodes < 0) return null;

    String? watchStatus;

    // Check bounds if we have episode count info
    int? maxEpisodes;
    int? contentId;

    if (content is MalAnime) {
      maxEpisodes = content.numEpisodes;
      contentId = content.id;
    } else if (content is Anime) {
      maxEpisodes = content.numEpisodes;
      contentId = content.id;
    }

    if (contentId == null) return null;

    if (maxEpisodes != null && maxEpisodes > 0) {
      if (totalEpisodes > maxEpisodes) {
        Fluttertoast.showToast(msg: "Maximum reached!");
        return null;
      }
      if (totalEpisodes == maxEpisodes) {
        watchStatus = "completed";
      }
    }

    return await updateMyAnimeListStatus(
      animeId: contentId,
      numWatchedEpisodes: totalEpisodes,
      status: watchStatus,
    );
  }

  /// Check if the MAL API is under maintenance.
  static Future<bool> isUnderMaintenance() async {
    return MalConnect.isUnderMaintenance();
  }

  /// Check if the device has network connectivity.
  static Future<bool> hasConnection() async {
    return MalConnect.hasConnection();
  }

  /// Search across all MAL categories (anime, manga, character, person, etc.) via HTML scraping.
  static Future<AllSearchResult?> searchAllCategories(String query) async {
    try {
      final url =
          'https://myanimelist.net/search/all?q=${Uri.encodeComponent(query)}&cat=all';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        return HtmlParsers.parseAllSearchResults(document);
      }
    } catch (e) {
      debugPrint('Error searching all categories: $e');
    }
    return null;
  }
}
