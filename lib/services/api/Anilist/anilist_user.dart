import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Anilist/anilist_user_prof.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';

class AnilistUser {
  static const String userBaseEndPoint = 'https://graphql.anilist.co';
  
  Future<AnilistUserProf> getUserInfo() async {
    final accessToken = UserAnilistV2.instance.accessToken;
    const query = '''
    query {
      Viewer {
        id
        name
        avatar {
          large
        }
        bannerImage
        about
        isFollowing
        isBlocked
        bans
      }
    }
    ''';
    
    final response = await http.post(
      Uri.parse(userBaseEndPoint),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'query': query}),
    );
    
    print('AniList getUserInfo response: ${response.statusCode}');
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      print('AniList user data: ${responseData['data']}');
      return AnilistUserProf.fromJson(responseData['data']['Viewer']);
    } else {
      print('AniList getUserInfo error: ${response.body}');
      throw Exception('Failed to fetch user info');
    }
  }
}
