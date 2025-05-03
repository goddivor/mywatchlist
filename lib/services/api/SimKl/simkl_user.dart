import 'dart:convert';

import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:http/http.dart' as http;

class SimklUser {
  final String userInfoEndpoint = 'https://api.simkl.com/users/settings';
  final String clientid = Constants.simklClientId;

  Future<UserProfSimkl> getUserInfo() async {
    final authToken = UserSimkl.instance.accessToken;
    

    final response = await http.get(
      Uri.parse(userInfoEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        'simkl-api-key': clientid,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return UserProfSimkl.fromJson(data);
    } else {
      throw Exception('Failed to load user info');
    }
  }
}
