import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_api.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/auth/retry_policy.dart';
import 'package:mywatchlist/services/auth/simkl_auth.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/services/auth/simkl_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';

/// Offline: fake HTTP only (MockClient), fake client ids, never a Simkl account.
const _v1Token = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _v2Token = 'simkl_at_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _v2Refresh = 'simkl_rt_RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR';

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

http.Response _tokenOk(String access, {String scope = 'media:read media:write'}) => http.Response(
    jsonEncode({
      'access_token': access,
      'token_type': 'Bearer',
      'expires_in': 604800,
      'refresh_token': _v2Refresh,
      'scope': scope,
    }),
    200,
    headers: {'content-type': 'application/json'});

SimklAuthResponse _v2Auth({Duration age = Duration.zero}) => SimklAuthResponse(
      accessToken: _v2Token,
      tokenType: 'Bearer',
      scope: 'media:read media:write',
      refreshToken: _v2Refresh,
      expiresIn: 604800,
      createdTime: DateTime.now().subtract(age),
    );

SimklAuthResponse _v1Auth() =>
    SimklAuthResponse(accessToken: _v1Token, tokenType: 'bearer', createdTime: DateTime.now());

void main() {
  final user = UserSimklV2.instance;

  setUpAll(() {
    forbidNetwork();
    dotenv.testLoad(fileInput: 'SIMKL_CLIENT_ID=v1cid\nSIMKL_CLIENT_SECRET=v1sec');
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    SimklOAuth2.clientIdOverride = 'v2cid';
    user.retryPolicy = RetryPolicy(sleep: (_) async {});
    user.clear();
  });

  tearDown(() {
    user.clear();
    SimklOAuth2.clientIdOverride = null;
  });

  group('PKCE', () {
    test('SHA-256 matches the FIPS vectors', () {
      expect(_hex(sha256Of(const [])),
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
      expect(_hex(sha256Of(ascii.encode('abc'))),
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      // Two blocks (56 bytes: the padding spills into a second block).
      expect(_hex(sha256Of(ascii.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'))),
          '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
    });

    test('S256 challenge of RFC 7636 appendix B', () {
      expect(SimklOAuth2.challengeOf('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
          'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    });

    test('verifiers use the unreserved set and the asked length', () {
      final v = SimklOAuth2.randomToken(64);
      expect(v.length, 64);
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v), isTrue);
    });

    test('tokens tell their version by prefix', () {
      expect(SimklOAuth2.isV2Token(_v2Token), isTrue);
      expect(SimklOAuth2.isV2Token(_v1Token), isFalse);
      expect(_v1Auth().canWrite, isTrue, reason: 'V1 tokens are full access');
      expect(SimklAuthResponse(accessToken: _v2Token, scope: 'media:read').canWrite, isFalse);
    });
  });

  group('sign in', () {
    test('V2: consent URL with PKCE S256 and both scopes, code exchanged once', () async {
      final requests = <http.Request>[];
      final auth = SimklAuthV2(
        httpClient: () => MockClient((r) async {
          requests.add(r);
          return _tokenOk(_v2Token);
        }),
        fetchProfile: () async => (name: 'tester', avatar: 'a.png'),
      );
      final url = await auth.startFlow();
      expect(url.toString(), startsWith('https://simkl.com/oauth2/authorize?'));
      final q = url.queryParameters;
      expect(q['client_id'], 'v2cid');
      expect(q['response_type'], 'code');
      expect(q['scope'], 'media:read media:write');
      expect(q['code_challenge_method'], 'S256');
      expect(q['redirect_uri'], 'com.teen.mywatchlist://simkl-callback');

      final ok = await auth.checkIfSignIn(Uri.parse(
          'com.teen.mywatchlist://simkl-callback?code=C1&state=${q['state']}&iss=https%3A%2F%2Fsimkl.com'));
      expect(ok, isTrue);
      expect(requests, hasLength(1));
      final r = requests.single;
      expect(r.url.toString(), 'https://api.simkl.com/oauth2/token');
      expect(r.bodyFields['grant_type'], 'authorization_code');
      expect(r.bodyFields['code'], 'C1');
      expect(r.bodyFields['client_id'], 'v2cid');
      expect(r.bodyFields.containsKey('client_secret'), isFalse);
      expect(SimklOAuth2.challengeOf(r.bodyFields['code_verifier']!), q['code_challenge']);

      expect(user.status, AuthStatus.AUTHENTICATED);
      expect(user.isV2Session, isTrue);
      expect(user.apiClientId, 'v2cid');
      expect(user.supportsRefresh, isTrue);
      expect(user.tokenExpiryTime, isNotNull);
      expect(user.username, 'tester');

      // The same redirect again (replayed link) is refused without a request.
      expect(await auth.checkIfSignIn(Uri.parse(
          'com.teen.mywatchlist://simkl-callback?code=C1&state=${q['state']}')), isFalse);
      expect(requests, hasLength(1));
    });

    test('a wrong state, a foreign issuer or a refusal never exchanges a code', () async {
      var calls = 0;
      final auth = SimklAuthV2(
        httpClient: () => MockClient((_) async {
          calls++;
          return _tokenOk(_v2Token);
        }),
        fetchProfile: () async => null,
      );
      await auth.startFlow();
      expect(await auth.checkIfSignIn(Uri.parse('x://simkl-callback?code=C&state=forged')), isFalse);

      var state = (await auth.startFlow()).queryParameters['state'];
      expect(
          await auth.checkIfSignIn(
              Uri.parse('x://simkl-callback?code=C&state=$state&iss=https%3A%2F%2Fevil.test')),
          isFalse);

      state = (await auth.startFlow()).queryParameters['state'];
      expect(
          await auth.checkIfSignIn(Uri.parse('x://simkl-callback?error=access_denied&state=$state')),
          isFalse);
      expect(calls, 0);
      expect(user.status, AuthStatus.UNAUTHENTICATED);
    });

    test('a V1 session upgrading to V2 stays signed in when the consent is refused', () async {
      user.setAuthResponse(_v1Auth());
      expect(user.canUpgradeToV2, isTrue);
      final auth = SimklAuthV2(
          httpClient: () => MockClient((_) async => _tokenOk(_v2Token)), fetchProfile: () async => null);
      final state = (await auth.startFlow()).queryParameters['state'];
      expect(
          await auth.checkIfSignIn(Uri.parse('x://simkl-callback?error=access_denied&state=$state')),
          isFalse);
      expect(user.accessToken, _v1Token);
      expect(user.status, AuthStatus.AUTHENTICATED);
    });

    test('a refused code exchange ends unauthenticated', () async {
      final auth = SimklAuthV2(
        httpClient: () =>
            MockClient((_) async => http.Response('{"error":"invalid_grant"}', 400)),
        fetchProfile: () async => null,
      );
      final state = (await auth.startFlow()).queryParameters['state'];
      expect(await auth.checkIfSignIn(Uri.parse('x://simkl-callback?code=C&state=$state')), isFalse);
      expect(user.accessToken, isNull);
      expect(user.status, AuthStatus.UNAUTHENTICATED);
    });

    test('without a V2 client id the sign in stays on V1', () async {
      SimklOAuth2.clientIdOverride = '';
      final requests = <http.Request>[];
      final auth = SimklAuthV2(
        httpClient: () => MockClient((r) async {
          requests.add(r);
          return http.Response(jsonEncode({'access_token': _v1Token, 'token_type': 'bearer'}), 200);
        }),
        fetchProfile: () async => null,
      );
      final url = await auth.startFlow();
      expect(url.toString(), startsWith('https://simkl.com/oauth/authorize?'));
      expect(url.queryParameters['client_id'], 'v1cid');
      final ok = await auth.checkIfSignIn(
          Uri.parse('x://simkl-callback?code=C&state=${url.queryParameters['state']}'));
      expect(ok, isTrue);
      expect(requests.single.url.toString(), 'https://api.simkl.com/oauth/token');
      expect(user.isV2Session, isFalse);
      expect(user.apiClientId, 'v1cid');
    });
  });

  group('session lifecycle', () {
    test('an existing V1 session keeps working: no refresh, 401 asks to sign in again', () async {
      user.setAuthResponse(_v1Auth());
      expect(user.supportsRefresh, isFalse);
      expect(user.tokenExpiryTime, isNull);
      expect(user.apiClientId, 'v1cid');
      final seen = <String?>[];
      user.clientFactory = () => MockClient((r) async {
            seen.add(r.headers['Authorization']);
            return http.Response('{}', seen.length == 1 ? 200 : 401);
          });
      final ok = await user.sendAuthenticated(
          (c, t) => c.get(Uri.parse('https://api.simkl.com/sync/activities'),
              headers: {'Authorization': 'Bearer $t'}));
      expect(ok!.statusCode, 200);
      expect(seen.single, 'Bearer $_v1Token');
      await user.sendAuthenticated((c, t) => c.get(Uri.parse('https://api.simkl.com/x')));
      expect(user.needsReLogin, isTrue);
    });

    test('a stored V1 session from an older build is read unchanged', () async {
      FlutterSecureStorage.setMockInitialValues({
        'simkl_auth_response': jsonEncode({
          'access_token': _v1Token,
          'token_type': 'bearer',
          'scope': null,
          'refresh_token': null,
          'expires_in': null,
          'created_time': '2025-01-02 03:04:05.000',
        }),
        'simkl_username': 'old',
      });
      await user.loadFromPreferences();
      expect(user.status, AuthStatus.AUTHENTICATED);
      expect(user.accessToken, _v1Token);
      expect(user.isV2Session, isFalse);
      expect(user.isTokenExpired, isFalse);
      expect(user.canUpgradeToV2, isTrue);
    });

    test('an expiring V2 token is refreshed on /oauth2/token before the call', () async {
      user.setAuthResponse(_v2Auth(age: const Duration(days: 7)));
      final calls = <http.Request>[];
      user.clientFactory = () => MockClient((r) async {
            calls.add(r);
            if (r.url.path == '/oauth2/token') return _tokenOk('simkl_at_NEWNEWNEWNEWNEWNEWNEWNEWNEWNEWNEWN');
            return http.Response('{}', 200);
          });
      final res = await user.sendAuthenticated((c, t) =>
          c.get(Uri.parse('https://api.simkl.com/sync/activities'), headers: {'Authorization': 'Bearer $t'}));
      expect(res!.statusCode, 200);
      expect(calls.first.url.toString(), 'https://api.simkl.com/oauth2/token');
      expect(calls.first.bodyFields, {
        'grant_type': 'refresh_token',
        'client_id': 'v2cid',
        'refresh_token': _v2Refresh,
      });
      expect(calls.last.headers['Authorization'], 'Bearer simkl_at_NEWNEWNEWNEWNEWNEWNEWNEWNEWNEWNEWN');
      expect(user.refreshToken, _v2Refresh);
      expect(user.isTokenExpired, isFalse);
    });

    test('a 401 on a V2 token refreshes once and replays', () async {
      user.setAuthResponse(_v2Auth());
      var apiCalls = 0;
      user.clientFactory = () => MockClient((r) async {
            if (r.url.path == '/oauth2/token') return _tokenOk('simkl_at_SECONDSECONDSECONDSECONDSECONDSE');
            apiCalls++;
            return http.Response('{}', apiCalls == 1 ? 401 : 200);
          });
      final res = await user.sendAuthenticated((c, t) => c.get(Uri.parse('https://api.simkl.com/x')));
      expect(res!.statusCode, 200);
      expect(apiCalls, 2);
      expect(user.needsReLogin, isFalse);
    });

    test('a refused refresh token asks to sign in again', () async {
      user.setAuthResponse(_v2Auth(age: const Duration(days: 8)));
      user.clientFactory =
          () => MockClient((_) async => http.Response('{"error":"invalid_grant"}', 400));
      final res = await user.sendAuthenticated((c, t) => c.get(Uri.parse('https://api.simkl.com/x')));
      expect(res, isNull);
      expect(user.needsReLogin, isTrue);
    });

    test('sign out revokes the V2 grant, then clears the session', () async {
      user.setAuthResponse(_v2Auth());
      final calls = <http.Request>[];
      await SimklAuthV2(httpClient: () => MockClient((r) async {
        calls.add(r);
        return http.Response('', 200);
      })).signOut();
      expect(calls.single.url.toString(), 'https://api.simkl.com/oauth2/revoke');
      expect(calls.single.bodyFields, {'token': _v2Refresh, 'client_id': 'v2cid'});
      expect(user.accessToken, isNull);
    });

    test('sign out of a V1 session sends nothing (V1 has no revocation)', () async {
      user.setAuthResponse(_v1Auth());
      var calls = 0;
      await SimklAuthV2(httpClient: () => MockClient((_) async {
        calls++;
        return http.Response('', 200);
      })).signOut();
      expect(calls, 0);
      expect(user.accessToken, isNull);
    });
  });

  group('catalogue and sync through SimklClient', () {
    late List<http.Request> authed;
    late List<Uri> public;
    late int status;
    late bool signedIn;

    SimklClient fakeClient() => SimklClient(
          auth: (send, {idempotent}) async {
            if (!signedIn) return null;
            return send(
                MockClient((r) async {
                  authed.add(r);
                  return http.Response(status == 200 ? '[{"title":"X"}]' : '{}', status);
                }),
                _v2Token);
          },
          publicGet: (uri, headers) async {
            public.add(uri);
            return http.Response('[{"title":"Y"}]', 200);
          },
          clientId: () => user.apiClientId,
          appVersion: () async => '1.0.0',
        );

    setUp(() {
      authed = [];
      public = [];
      status = 200;
      signedIn = true;
    });

    test('search uses the session token when signed in, anonymous otherwise', () async {
      user.setAuthResponse(_v2Auth());
      final api = SimklApi(client: fakeClient(), signedIn: () => signedIn);
      expect((await api.searchAnime('frieren')).single['title'], 'X');
      final r = authed.single;
      expect(r.url.path, '/search/anime');
      expect(r.headers['Authorization'], 'Bearer $_v2Token');
      expect(r.headers['simkl-api-key'], 'v2cid', reason: 'a token only works with its client id');
      expect(r.url.queryParameters['app-name'], 'MyWatchList');

      signedIn = false;
      expect((await api.searchAnime('frieren')).single['title'], 'Y');
      expect(public.single.queryParameters['q'], 'frieren');
    });

    test('a dead session falls back to the anonymous search', () async {
      user.setAuthResponse(_v1Auth());
      status = 401;
      final api = SimklApi(client: fakeClient(), signedIn: () => true);
      expect((await api.searchAnime('x')).single['title'], 'Y');
    });

    test('a title by id is always anonymous (cached catalogue)', () async {
      user.setAuthResponse(_v2Auth());
      final api = SimklApi(
          client: SimklClient(
            auth: (send, {idempotent}) async => fail('no token for /anime/{id}'),
            publicGet: (uri, headers) async {
              expect(headers.containsKey('Authorization'), isFalse);
              public.add(uri);
              return http.Response('{"ids":{"mal":5114}}', 200);
            },
            appVersion: () async => '1.0.0',
          ),
          signedIn: () => true);
      expect((await api.getAnimeDetails(11))['ids'], {'mal': 5114});
      expect(public.single.path, '/anime/11');
    });

    test('sync client maps SimklClient errors to sync errors', () async {
      final sync = SimklEntryClient(client: fakeClient());
      status = 500;
      await expectLater(sync.read('mal:1', isAnime: true), throwsA(isA<SyncRequestFailed>()));
      signedIn = false;
      await expectLater(sync.read('mal:1', isAnime: true), throwsA(isA<SyncAuthRequired>()));
    });

    test('sync writes go to add-to-list with the app identification', () async {
      user.setAuthResponse(_v2Auth());
      final sync = SimklEntryClient(client: fakeClient());
      status = 201;
      await sync.delete('mal:5114', isAnime: true);
      final r = authed.single;
      expect(r.method, 'POST');
      expect(r.url.path, '/sync/remove-from-list');
      expect(r.url.queryParameters['app-version'], '1.0.0');
      expect(jsonDecode(r.body), {
        'anime': [
          {
            'ids': {'mal': 5114}
          }
        ]
      });
    });
  });
}
