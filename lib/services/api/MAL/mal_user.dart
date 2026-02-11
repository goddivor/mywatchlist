import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';

class MalUser {
  static const String userBaseEndPoint = Constants.maluserBaseEndPoint;
  Future<MalUserProf> getUserInfo({List<String>? fields, String username = "@me"}) async {
    final accessToken = UserMalV2.instance.authResponse?.accessToken;

    // Construction de l'URL avec les champs spécifiés
    String url = '$userBaseEndPoint/$username';
    if (fields != null && fields.isNotEmpty) {
      url += '?fields=${fields.join(",")}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    final profileData = json.decode(response.body);
    return MalUserProf.fromJson(profileData);
  }

  static Future<List<Anime>> getMyContentList({
    int limit = 100,
    int offset = 0,
    String category = "anime",
    String? status = "all",
    String? sortType,
    List<String>? fields,
    String username = "@me",
  }) async {
    final accessToken = UserMalV2.instance.authResponse?.accessToken;

    String fieldsString = (fields != null && fields.isNotEmpty)
        ? fields.join(",")
        : 'id,title,main_picture,mean,num_list_users,status,media_type,num_episodes,start_date,end_date,list_status{is_rewatching,is_rereading,num_times_rewatched,num_times_reread,priority,rewatch_value,reread_value,start_date,finish_date,tags,comments}';

    String url = '$userBaseEndPoint/$username/${category}list?fields=$fieldsString&limit=$limit&offset=$offset';

    // ignore: unnecessary_null_comparison
    if (status != null) {
      url += "&status=$status";
    }
    
    if (sortType != null) {
      url += "&sort=$sortType";
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonData = json.decode(response.body)['data'];
      return jsonData.map((data) => Anime.fromMAlJson(data['node'])).toList();
    } else {
      throw Exception('Failed to get user anime list');
    }
  }
}
