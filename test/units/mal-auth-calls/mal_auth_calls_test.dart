import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/retry_policy.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';

AuthResponse _auth(String access, {Duration age = Duration.zero}) =>
    AuthResponse(
      accessToken: access,
      refreshToken: 'R1',
      expiresIn: 3600,
      createdTime: DateTime.now().subtract(age),
    );

http.Response _tokenOk(String access) => http.Response(
    jsonEncode({
      'access_token': access,
      'refresh_token': 'R2',
      'expires_in': 3600,
      'token_type': 'Bearer',
    }),
    200);

final _emptyList = jsonEncode({'data': [], 'paging': {}});

void main() {
  final user = UserMalV2.instance;

  void useClient(MockClient client) {
    user.clientFactory = () => client;
    user.retryPolicy = RetryPolicy(sleep: (_) async {});
  }

  setUp(() {
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid\nMAL_CLIENT_SECRET=sec');
    FlutterSecureStorage.setMockInitialValues({});
    AccountManagerSingleton().updateAccountType(AccountType.myanimelist);
  });

  tearDown(() {
    user.clientFactory = http.Client.new;
    user.retryPolicy = const RetryPolicy();
    AccountManagerSingleton().updateAccountType(AccountType.none);
  });

  test('expired token is refreshed, then the MAL call succeeds', () async {
    user.setAuthResponse(_auth('OLD', age: const Duration(hours: 2)));
    final calls = <String>[];
    useClient(MockClient((req) async {
      if (req.url.host == 'myanimelist.net' &&
          req.url.path.contains('token')) {
        calls.add('refresh');
        return _tokenOk('NEW');
      }
      calls.add('api ${req.headers['Authorization']}');
      return http.Response(_emptyList, 200);
    }));

    final result = await MalUser.getMyContentListResult();
    expect(result.data, isEmpty);
    expect(calls, ['refresh', 'api Bearer NEW']);
  });

  test('401 triggers one refresh and one replay (search)', () async {
    user.setAuthResponse(_auth('STALE'));
    final calls = <String>[];
    useClient(MockClient((req) async {
      if (req.url.path.contains('token')) {
        calls.add('refresh');
        return _tokenOk('NEW');
      }
      final h = req.headers['Authorization'];
      calls.add('api $h');
      return h == 'Bearer NEW'
          ? http.Response(_emptyList, 200)
          : http.Response('{}', 401);
    }));

    final result = await MalApi().searchAnimeResult('naruto');
    expect(result.data, isEmpty);
    expect(calls, ['api Bearer STALE', 'refresh', 'api Bearer NEW']);
  });

  test('list write goes through the refresh path too', () async {
    user.setAuthResponse(_auth('OLD', age: const Duration(hours: 2)));
    String? sentAuth;
    String? sentBody;
    useClient(MockClient((req) async {
      if (req.url.path.contains('token')) return _tokenOk('NEW');
      sentAuth = req.headers['Authorization'];
      sentBody = req.body;
      return http.Response(
          jsonEncode({'status': 'watching', 'score': 8, 'num_episodes_watched': 1}),
          200);
    }));

    await MalApi().updateMyAnimeListStatus(animeId: 1, score: 8);
    expect(sentAuth, 'Bearer NEW');
    expect(sentBody, contains('score=8'));
  });

  test('refresh rejected: MalSessionExpired surfaces and account needs re-login',
      () async {
    user.setAuthResponse(_auth('OLD', age: const Duration(hours: 2)));
    useClient(MockClient((req) async {
      if (req.url.path.contains('token')) {
        return http.Response('{"error":"invalid_grant"}', 400);
      }
      fail('the API must not be called without a valid token');
    }));

    await expectLater(
        MalUser.getAllUserList('@me', 'anime'), throwsA(isA<MalSessionExpired>()));
    expect(user.needsReLogin, isTrue);
    expect(user.authResponse, isNull);
  });

  test('list writes refuse a non MAL account without touching the network',
      () async {
    AccountManagerSingleton().updateAccountType(AccountType.none);
    useClient(MockClient((req) async => fail('no request expected')));
    await expectLater(MalApi().deleteAnimeFromList(1), throwsA(isA<String>()));
  });
}
