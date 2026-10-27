import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
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

final _oneAnime = jsonEncode({
  'data': [
    {
      'node': {'id': 1, 'title': 'Cowboy Bebop', 'main_picture': {}}
    }
  ],
  'paging': {},
});

/// Records every request; the token endpoint refuses the refresh, the API
/// answers 401 to a Bearer call and 200 to a client id call.
class _DeadSession {
  final calls = <String>[];

  http.Response handle(http.Request req) {
    if (req.url.path.contains('token')) {
      calls.add('refresh');
      return http.Response('{"error":"invalid_grant"}', 400);
    }
    final bearer = req.headers['Authorization'];
    if (bearer != null) {
      calls.add('bearer');
      return http.Response('{"error":"invalid_token"}', 401);
    }
    calls.add('client-id ${req.headers['X-MAL-CLIENT-ID']}');
    return http.Response(_oneAnime, 200);
  }

  MockClient get client => MockClient((req) async => handle(req));
}

void main() {
  final user = UserMalV2.instance;

  /// Runs [body] with every HTTP client (token, Bearer and public calls)
  /// answered by [client].
  Future<T> withClient<T>(MockClient client, Future<T> Function() body) {
    user.clientFactory = () => client;
    user.retryPolicy = RetryPolicy(sleep: (_) async {});
    return http.runWithClient(body, () => client);
  }

  setUp(() {
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid\nMAL_CLIENT_SECRET=sec');
    FlutterSecureStorage.setMockInitialValues({});
    MalApi.clientId = 'cid';
    AccountManagerSingleton().updateAccountType(AccountType.myanimelist);
    user.setAuthResponse(_auth('OLD', age: const Duration(hours: 2)));
    expect(MalApi.sessionExpired.value, isFalse);
  });

  tearDown(() {
    user.clientFactory = http.Client.new;
    user.retryPolicy = const RetryPolicy();
    AccountManagerSingleton().updateAccountType(AccountType.none);
  });

  test('refresh refused: seasonal falls back to the client id call', () async {
    final server = _DeadSession();
    final result = await withClient(
        server.client, () => MalApi.getCurrentSeasonResult());

    expect(result.data, hasLength(1));
    expect(server.calls, ['refresh', 'client-id cid']);
    expect(MalApi.sessionExpired.value, isTrue);
  });

  test('refresh refused: ranking and details keep working', () async {
    final server = _DeadSession();
    final ranking = await withClient(server.client,
        () => MalApi.getContentRankingResult(RankingType.ALL));
    expect(ranking.data, hasLength(1));

    final details = await withClient(
        MockClient((req) async {
          expect(req.headers['Authorization'], isNull);
          return http.Response(jsonEncode({'id': 5, 'title': 'X'}), 200);
        }),
        () => MalApi().getAnimeDetails(5));
    expect(details.id, 5);
    expect(MalApi.sessionExpired.value, isTrue);
  });

  test('401 after a refused refresh also falls back for a public call',
      () async {
    // Token still fresh locally, but MAL revoked it: 401, refresh refused.
    user.setAuthResponse(_auth('REVOKED'));
    final server = _DeadSession();
    final result =
        await withClient(server.client, () => MalApi().searchAnimeResult('x'));

    expect(result.data, hasLength(1));
    expect(server.calls, ['bearer', 'refresh', 'client-id cid']);
    expect(MalApi.sessionExpired.value, isTrue);
  });

  test('authenticated-only calls keep throwing MalSessionExpired', () async {
    final server = _DeadSession();
    await withClient(server.client, () async {
      await expectLater(MalApi.getContentSuggestionsResult(),
          throwsA(isA<MalSessionExpired>()));
      await expectLater(MalApi().getUserAnimeListResult(),
          throwsA(isA<MalSessionExpired>()));
      await expectLater(MalUser.getMyContentListResult(),
          throwsA(isA<MalSessionExpired>()));
      await expectLater(MalApi().updateMyAnimeListStatus(animeId: 1, score: 7),
          throwsA(isA<MalSessionExpired>()));
    });
    expect(server.calls.where((c) => c.startsWith('client-id')), isEmpty);
    expect(MalApi.sessionExpired.value, isTrue);
  });

  test('the notifier fires once, then clears on a new sign in', () async {
    var notified = 0;
    void listener() => notified++;
    MalApi.sessionExpired.addListener(listener);
    addTearDown(() => MalApi.sessionExpired.removeListener(listener));

    final server = _DeadSession();
    await withClient(server.client, () async {
      await MalApi.getCurrentSeasonResult();
      await MalApi.getCurrentSeasonResult();
    });
    expect(MalApi.sessionExpired.value, isTrue);
    expect(notified, 1);

    user.setAuthResponse(_auth('NEW'));
    expect(MalApi.sessionExpired.value, isFalse);
    expect(notified, 2);
  });

  test('a non MAL account is not affected', () async {
    AccountManagerSingleton().updateAccountType(AccountType.anilist);
    final server = _DeadSession();
    await withClient(server.client, () => MalApi.getCurrentSeasonResult());
    expect(server.calls, ['client-id cid']);
    expect(MalApi.sessionExpired.value, isFalse);
  });
}
