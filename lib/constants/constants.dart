import 'package:flutter/material.dart';
import 'dart:ui' as ui;

enum AccountType {
  none,
  myanimelist,
  anilist,
  kitsu,
  simkl,
}

class Constants {
  static const String chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890-._~';

  //myanimelist client id and redirecturi
  static const String malclientId = '2954f0a5d477b5f83c468bad0d3f7052';
  static const String malredirectUri = 'mywatchlist://callback';

  //anilist client id, secret and redirecturi
  static const String anilistClientId = '19606';
  static const String anilistClientSecret =
      '9NzyEe0bYpVb6T7xfZowoW1XsG2fmU3qAoyGQLbd';
  static const String anilistRedirectUri = 'mywatchlist://callback';

  //simkl client id, secret and redirecturi
  static const String simklClientId =
      '651c592199dadfe077ad844067becd03c64bdb72d5e7be704c9b3a0ae179224d';
  static const String simklClientSecret =
      'cea29efcdef0ed917bc5250c37eb1cd29211b3e69710e74f5d58bab6b776e7e0';
  static const String simklRedirectUri = 'mywatchlist://callback';

  //myanimelist api endpoints...
  static const String malapiUrl = 'https://api.myanimelist.net/v2';
  static const String maloauthEndPoint =
      'https://myanimelist.net/v1/oauth2/authorize';
  static const String maltokenEndPoint =
      'https://myanimelist.net/v1/oauth2/token';
  static const String maluserEndPoint =
      'https://api.myanimelist.net/v2/users/@me';
  static const String maluserBaseEndPoint =
      'https://api.myanimelist.net/v2/users';
  static const String malanimeEndPoint = 'https://api.myanimelist.net/v2/anime';
  static const String malanimeRankingEndPoint =
      'https://api.myanimelist.net/v2/anime/ranking';
  static const String malanimeSeasonalEndPoint =
      'https://api.myanimelist.net/v2/anime/season';
  static const String malanimeSuggestedEndPoint =
      'https://api.myanimelist.net/v2/anime/suggestions';

  //anilist api endpoints...
  static const String anilistOAuthEndPoint =
      'https://anilist.co/api/v2/oauth/authorize';
  static const String anilistTokenEndPoint =
      'https://anilist.co/api/v2/oauth/token';

  //simkl api endpoints...
  static const String simklapiUrl = 'https://api.simkl.com/';
  static const String simklOAuthEndPoint = 'https://simkl.com/oauth/authorize';
  static const String simklTokenEndPoint = 'https://api.simkl.com/oauth/token';
  static const String simkUserSettingEndPoint =
      'https://api.simkl.com/users/settings';
}

Future<T?> gotoPage<T>(
    {required BuildContext context, required Widget newPage}) {
  return Navigator.push<T>(
    context,
    MaterialPageRoute(
      builder: (context) =>
          Directionality(textDirection: ui.TextDirection.ltr, child: newPage),
    ),
  );
}
