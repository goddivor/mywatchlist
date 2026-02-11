import 'dart:convert';

import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:http/http.dart' as http;

class SimklUser {
  final String userInfoEndpoint = 'https://api.simkl.com/users/settings';
  final String clientid = Constants.simklClientId;

  Future<UserProfSimkl> getUserInfo() async {
    final authToken = UserSimklV2.instance.accessToken;
    

    final response = await http.get(
      Uri.parse(userInfoEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        'simkl-api-key': clientid,
      },
    );

    print('Simkl getUserInfo response: ${response.statusCode}');
    print('Simkl access token: ${authToken != null ? "present" : "null"}');
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      print('Simkl user data: $data');
      return UserProfSimkl.fromJson(data);
    } else {
      print('Simkl getUserInfo error: ${response.body}');
      throw Exception('Failed to load user info');
    }
  }
}
