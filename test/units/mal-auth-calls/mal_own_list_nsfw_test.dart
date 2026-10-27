import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/retry_policy.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';

final _emptyPage = jsonEncode({'data': [], 'paging': {}});

/// nsfw value of the request sent for [url].
String? _nsfwOf(Uri url) => url.queryParameters['nsfw'];

void main() {
  final user = UserMalV2.instance;
  final requests = <Uri>[];

  setUp(() {
    // The NSFW preference is off (default).
    Preferences.reset();
    requests.clear();
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid\nMAL_CLIENT_SECRET=sec');
    FlutterSecureStorage.setMockInitialValues({});
    MalApi.clientId = 'cid';
    AccountManagerSingleton().updateAccountType(AccountType.myanimelist);
    user.setAuthResponse(AuthResponse(
      accessToken: 'T',
      refreshToken: 'R',
      expiresIn: 3600,
      createdTime: DateTime.now(),
    ));
    final client = MockClient((req) async {
      requests.add(req.url);
      return http.Response(_emptyPage, 200);
    });
    user.clientFactory = () => client;
    user.retryPolicy = RetryPolicy(sleep: (_) async {});
    MalApi.httpClient = client;
  });

  tearDown(() {
    user.clientFactory = http.Client.new;
    user.retryPolicy = const RetryPolicy();
    MalApi.httpClient = null;
    AccountManagerSingleton().updateAccountType(AccountType.none);
  });

  Future<T> run<T>(Future<T> Function() body) => http.runWithClient(
      body, () => MockClient((req) async {
            requests.add(req.url);
            return http.Response(_emptyPage, 200);
          }));

  group('withNsfw on the own list', () {
    const base = 'https://api.myanimelist.net/v2/users/@me';

    test('own anime and manga lists get nsfw=1 with the pref off', () {
      expect(MalApi.withNsfw('$base/animelist?limit=5'),
          '$base/animelist?limit=5&nsfw=1');
      expect(MalApi.withNsfw('$base/mangalist'), '$base/mangalist?nsfw=1');
      expect(MalApi.withNsfw('$base/animelist?limit=5', nsfw: false),
          '$base/animelist?limit=5&nsfw=1');
    });

    test('an own list page carrying nsfw=0 is switched to nsfw=1', () {
      expect(MalApi.withNsfw('$base/animelist?offset=100&nsfw=0&limit=5'),
          '$base/animelist?offset=100&limit=5&nsfw=1');
      const truthy = '$base/animelist?nsfw=true';
      expect(MalApi.withNsfw(truthy), truthy);
    });

    test('browse, search, ranking, seasonal and the profile follow the pref',
        () {
      for (final url in [
        'https://api.myanimelist.net/v2/anime?q=a',
        'https://api.myanimelist.net/v2/anime/ranking?ranking_type=all',
        'https://api.myanimelist.net/v2/anime/season/2026/fall',
        'https://api.myanimelist.net/v2/anime/suggestions',
        '$base?fields=anime_statistics',
      ]) {
        expect(Uri.parse(MalApi.withNsfw(url)).queryParameters['nsfw'], '0',
            reason: url);
      }
    });
  });

  group('own list requests on the wire', () {
    test('MalUser own lists send nsfw=1 with the pref off', () async {
      await run(() => MalUser.getMyContentListResult(category: 'anime'));
      await run(() => MalUser.getMyContentListResult(category: 'manga'));
      await run(() => MalUser.getAllUserList('@me', 'anime'));
      final own = requests.where((u) => u.path.contains('/users/@me/'));
      expect(own, hasLength(3));
      expect(own.map(_nsfwOf), everyElement('1'));
    });

    test('MalApi own anime list sends nsfw=1, search keeps nsfw=0', () async {
      await run(() => MalApi().getUserAnimeListResult());
      await run(() => MalApi.authorizedGet(
          'https://api.myanimelist.net/v2/users/@me/mangalist?limit=1'));
      await run(() => MalApi.authorizedGet(
          'https://api.myanimelist.net/v2/anime?q=naruto'));
      expect(requests.map(_nsfwOf), ['1', '1', '0']);
    });
  });
}
