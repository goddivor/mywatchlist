import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Kitsu/kitsu_user_prof.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';

class KitsuUser {
  static const String _userBaseEndPoint = "https://kitsu.io/api/edge";
  
  static const String _userEndpoint = "/users?filter[self]=true";

  Future<KitsuUserProf> getUserInfo() async {
    final accessToken = UserKitsuV2.instance.accessToken;

    // Constructing the URL
    // String url = '$userBaseEndPoint/users?filter[self]=true';

    final url = Uri.parse(_userBaseEndPoint + _userEndpoint);
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/vnd.api+json',
        'Accept': 'application/vnd.api+json',
      },
    );

    print('Kitsu getUserInfo response: ${response.statusCode}');
    print('Kitsu access token: ${accessToken != null ? "present" : "null"}');
    if (response.statusCode == 200) {
      final profileData = json.decode(response.body)['data'][0]['attributes'];
      print('Kitsu user data: $profileData');
      return KitsuUserProf.fromJson(profileData);
    } else {
      print('Kitsu getUserInfo error: ${response.body}');
      throw Exception('Failed to fetch user profile');
    }
  }
}
