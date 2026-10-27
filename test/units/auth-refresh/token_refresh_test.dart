import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/retry_policy.dart';
import 'package:mywatchlist/user/base_user.dart';

/// Minimal user, same refresh behaviour as UserMalV2 without its singleton.
class FakeUser extends BaseUser<AuthResponse> {
  FakeUser({this.refreshable = true});

  final bool refreshable;

  @override
  bool get supportsRefresh =>
      refreshable && (refreshToken?.isNotEmpty ?? false);
  @override
  String get authResponseKey => 'fake_auth';
  @override
  String get usernameKey => 'fake_user';
  @override
  String get profileImageKey => 'fake_img';
  @override
  String get clientId => 'cid';
  @override
  String get clientSecret => 'sec';
  @override
  String get redirectUri => 'app://cb';
  @override
  String get tokenEndPoint => 'https://auth.test/token';
  @override
  AuthResponse? authResponseFromJson(Map<String, dynamic> json) =>
      AuthResponse.fromJson(json);
  @override
  Map<String, dynamic>? authResponseToJson(AuthResponse? r) => r?.toJson();
  @override
  String? get accessToken => authResponse?.accessToken;
  @override
  String? get refreshToken => authResponse?.refreshToken;
  @override
  DateTime? get tokenExpiryTime {
    final a = authResponse;
    if (a?.createdTime == null || a?.expiresIn == null) return null;
    return a!.createdTime!.add(Duration(seconds: a.expiresIn!));
  }
}

AuthResponse _auth(String access,
        {Duration age = Duration.zero, String refresh = 'R1'}) =>
    AuthResponse(
      accessToken: access,
      refreshToken: refresh,
      expiresIn: 3600,
      createdTime: DateTime.now().subtract(age),
    );

FakeUser _user({
  required MockClient client,
  AuthResponse? auth,
  bool refreshable = true,
}) {
  final u = FakeUser(refreshable: refreshable)
    ..clientFactory = (() => client)
    ..retryPolicy = RetryPolicy(sleep: (_) async {});
  u.setAuthResponse(auth ?? _auth('A1'));
  return u;
}

http.Response _tokenOk(String access, {String? refresh = 'R2'}) =>
    http.Response(
        jsonEncode({
          'access_token': access,
          'refresh_token': refresh,
          'expires_in': 3600,
          'token_type': 'Bearer',
        }),
        200);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('expired token is refreshed before the call', () async {
    final seen = <String>[];
    var refreshCalls = 0;
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') {
        refreshCalls++;
        expect(req.bodyFields['grant_type'], 'refresh_token');
        expect(req.bodyFields['refresh_token'], 'R1');
        return _tokenOk('A2');
      }
      seen.add(req.headers['Authorization']!);
      return http.Response('{}', 200);
    });
    final user = _user(
        client: client, auth: _auth('A1', age: const Duration(hours: 2)));

    final res = await user.sendAuthenticated(
        (c, t) => c.get(Uri.parse('https://api.test/x'),
            headers: {'Authorization': 'Bearer $t'}));

    expect(res!.statusCode, 200);
    expect(refreshCalls, 1);
    expect(seen, ['Bearer A2']);
    expect(user.refreshToken, 'R2');
    expect(user.status, AuthStatus.AUTHENTICATED);
  });

  test('token inside the skew window is refreshed too', () async {
    var refreshCalls = 0;
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') {
        refreshCalls++;
        return _tokenOk('A2');
      }
      return http.Response('{}', 200);
    });
    // 3600 s lifetime, 3570 s old: 30 s left, below the 60 s skew.
    final user = _user(
        client: client,
        auth: _auth('A1', age: const Duration(seconds: 3570)));
    await user.sendAuthenticated((c, t) => c.get(Uri.parse('https://api.test/x')));
    expect(refreshCalls, 1);
  });

  test('401 refreshes once and replays the request once', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') return _tokenOk('A2');
      calls.add(req.headers['Authorization']!);
      return http.Response('', calls.length == 1 ? 401 : 200);
    });
    final user = _user(client: client);

    final res = await user.sendAuthenticated((c, t) => c.get(
        Uri.parse('https://api.test/x'),
        headers: {'Authorization': 'Bearer $t'}));

    expect(res!.statusCode, 200);
    expect(calls, ['Bearer A1', 'Bearer A2']);
    expect(user.status, AuthStatus.AUTHENTICATED);
    expect(user.needsReLogin, isFalse);
  });

  test('401 after a successful refresh does not loop and ends logged out',
      () async {
    var apiCalls = 0;
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') return _tokenOk('A2');
      apiCalls++;
      return http.Response('', 401);
    });
    final user = _user(client: client);

    final res = await user.sendAuthenticated(
        (c, t) => c.get(Uri.parse('https://api.test/x')));

    expect(res!.statusCode, 401);
    expect(apiCalls, 2);
    expect(user.status, AuthStatus.UNAUTHENTICATED);
    expect(user.needsReLogin, isTrue);
  });

  test('refresh rejected by the server leads to the logged-out state',
      () async {
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') {
        return http.Response('{"error":"invalid_grant"}', 400);
      }
      return http.Response('', 401);
    });
    final user = _user(client: client);
    user.setUserInfo('neo', 'img');

    final res = await user.sendAuthenticated(
        (c, t) => c.get(Uri.parse('https://api.test/x')));

    expect(res!.statusCode, 401);
    expect(user.status, AuthStatus.UNAUTHENTICATED);
    expect(user.authResponse, isNull);
    expect(user.needsReLogin, isTrue);
    expect(user.username, 'neo', reason: 'identity kept for the re-login UI');
  });

  test('expired token whose refresh is rejected returns null, no API call',
      () async {
    var apiCalls = 0;
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') return http.Response('', 401);
      apiCalls++;
      return http.Response('{}', 200);
    });
    final user = _user(
        client: client, auth: _auth('A1', age: const Duration(days: 40)));

    final res = await user.sendAuthenticated(
        (c, t) => c.get(Uri.parse('https://api.test/x')));

    expect(res, isNull);
    expect(apiCalls, 0);
    expect(user.status, AuthStatus.UNAUTHENTICATED);
  });

  test('network failure while refreshing keeps the session', () async {
    final client = MockClient((req) async {
      throw const SocketException('offline');
    });
    final user = _user(
        client: client, auth: _auth('A1', age: const Duration(days: 40)));
    user.retryPolicy = RetryPolicy(maxAttempts: 2, sleep: (_) async {});

    expect(await user.refreshAccessToken(), isFalse);
    expect(user.status, AuthStatus.AUTHENTICATED);
    expect(user.needsReLogin, isFalse);
  });

  test('a tracker without refresh token marks re-login on 401 (Simkl)',
      () async {
    var refreshCalls = 0;
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') refreshCalls++;
      return http.Response('', 401);
    });
    final user = _user(
        client: client,
        refreshable: false,
        auth: AuthResponse(accessToken: 'S1'));

    final res = await user.sendAuthenticated(
        (c, t) => c.get(Uri.parse('https://api.test/x')));

    expect(res!.statusCode, 401);
    expect(refreshCalls, 0);
    expect(user.status, AuthStatus.UNAUTHENTICATED);
    expect(user.needsReLogin, isTrue);
  });

  test('concurrent 401s share a single refresh request', () async {
    var refreshCalls = 0;
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _tokenOk('A2');
      }
      return http.Response(
          '', req.headers['Authorization'] == 'Bearer A1' ? 401 : 200);
    });
    final user = _user(client: client);

    final results = await Future.wait(List.generate(
        4,
        (_) => user.sendAuthenticated((c, t) => c.get(
            Uri.parse('https://api.test/x'),
            headers: {'Authorization': 'Bearer $t'}))));

    expect(results.map((r) => r!.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test('refresh keeps the old refresh token when the server omits it',
      () async {
    final client = MockClient((req) async => _tokenOk('A2', refresh: null));
    final user = _user(client: client);
    expect(await user.refreshAccessToken(), isTrue);
    expect(user.refreshToken, 'R1');
    expect(user.accessToken, 'A2');
  });

  group('retry', () {
    test('transient errors are retried then succeed', () async {
      var n = 0;
      final client = MockClient((req) async {
        if (++n < 3) throw const SocketException('reset');
        return http.Response('ok', 200);
      });
      final user = _user(client: client);
      final res = await user.sendAuthenticated(
          (c, t) => c.get(Uri.parse('https://api.test/x')));
      expect(res!.body, 'ok');
      expect(n, 3);
    });

    test('gives up after 8 attempts and rethrows', () async {
      var n = 0;
      final client = MockClient((req) async {
        n++;
        throw const SocketException('down');
      });
      final user = _user(client: client);
      await expectLater(
          user.sendAuthenticated(
              (c, t) => c.get(Uri.parse('https://api.test/x'))),
          throwsA(isA<SocketException>()));
      expect(n, 8);
    });

    test('4xx other than 401 is never retried', () async {
      for (final code in [400, 403, 404, 429]) {
        var n = 0;
        final client = MockClient((req) async {
          n++;
          return http.Response('', code);
        });
        final user = _user(client: client);
        final res = await user.sendAuthenticated(
            (c, t) => c.get(Uri.parse('https://api.test/x')));
        expect(res!.statusCode, code);
        expect(n, 1, reason: 'status $code');
        expect(user.status, AuthStatus.AUTHENTICATED);
      }
    });

    test('backoff doubles and is capped', () {
      const p = RetryPolicy();
      expect(p.delayAfter(1), const Duration(milliseconds: 250));
      expect(p.delayAfter(2), const Duration(milliseconds: 500));
      expect(p.delayAfter(7), const Duration(seconds: 4));
    });
  });

  test('MalConnect.authGet goes through the refreshing path', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      if (req.url.host == 'auth.test') return _tokenOk('A2');
      seen.add(req.headers['Authorization']!);
      return http.Response('{}', seen.length == 1 ? 401 : 200);
    });
    final user = _user(client: client);

    final res = await MalConnect.authGet('https://api.test/x', user: user);

    expect(res.statusCode, 200);
    expect(seen, ['Bearer A1', 'Bearer A2']);
  });

  test('MalConnect.authGet throws MalSessionExpired when signed out', () async {
    final client = MockClient((req) async => http.Response('{}', 200));
    final user = _user(client: client)..clear();
    await expectLater(MalConnect.authGet('https://api.test/x', user: user),
        throwsA(isA<MalSessionExpired>()));
  });

  test('makeAuthenticatedRequest sends JSON bodies with the bearer token',
      () async {
    late http.Request got;
    final client = MockClient((req) async {
      got = req;
      return http.Response('{}', 200);
    });
    final user = _user(client: client);
    final res = await user.makeAuthenticatedRequest('https://api.test/x',
        method: 'PUT', body: {'a': 1});
    expect(res!.statusCode, 200);
    expect(got.method, 'PUT');
    expect(got.headers['Authorization'], 'Bearer A1');
    expect(got.body, '{"a":1}');
  });
}
