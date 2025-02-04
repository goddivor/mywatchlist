import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Kitsu/kitsu_user_prof.dart';
import 'package:mywatchlist/user/user.dart';

class KitsuUser {
  static const String _userBaseEndPoint = "https://kitsu.io/api/edge";
  
  static const String _userEndpoint = "/users?filter[self]=true";

  Future<KitsuUserProf> getUserInfo() async {
    final accessToken = UserKitsu.instance.authResponse?.accessToken;

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

    if (response.statusCode == 200) {
      final profileData = json.decode(response.body)['data'][0]['attributes'];
      return KitsuUserProf.fromJson(profileData);
    } else {
      throw Exception('Failed to fetch user profile');
    }
  }
}
