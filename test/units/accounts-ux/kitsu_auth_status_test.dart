import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/auth/kitsu_auth.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';

/// #88 item 2: a Kitsu sign in that fails leaves "in progress" at the source, so no caller
/// has to free the status itself. Fake HTTP only, never the real Kitsu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final user = UserKitsuV2.instance;
  var notified = 0;
  void listener() => notified++;

  setUp(() {
    user.status = AuthStatus.UNAUTHENTICATED;
    user.authResponse = null;
    notified = 0;
    user.addListener(listener);
  });

  tearDown(() => user.removeListener(listener));

  KitsuAuth auth(Future<http.Response> Function(http.Request) handler) =>
      KitsuAuth(client: MockClient(handler));

  test('wrong credentials end unauthenticated and notify the UI', () async {
    var completed = false;
    final ok = await auth((req) async {
      expect(user.status, AuthStatus.INPROGRESS);
      return http.Response('{"error":"invalid_grant"}', 400);
    }).signInWithKitsu(null, 'neo', 'pw', onComplete: () => completed = true);

    expect(ok, isFalse);
    expect(user.status, AuthStatus.UNAUTHENTICATED);
    expect(user.authResponse, isNull);
    expect(completed, isFalse);
    expect(notified, greaterThan(0));
  });

  test('a server error ends unauthenticated', () async {
    final ok = await auth((_) async => http.Response('oops', 500))
        .signInWithKitsu(null, 'neo', 'pw');
    expect(ok, isFalse);
    expect(user.status, AuthStatus.UNAUTHENTICATED);
  });

  test('a network failure ends unauthenticated and still reaches the caller', () async {
    await expectLater(
      auth((_) async => throw const SocketException('offline'))
          .signInWithKitsu(null, 'neo', 'pw'),
      throwsA(isA<SocketException>()),
    );
    expect(user.status, AuthStatus.UNAUTHENTICATED);
    expect(notified, greaterThan(0));
  });

  test('an unreadable success answer ends unauthenticated', () async {
    await expectLater(
      auth((_) async => http.Response('<html>', 200)).signInWithKitsu(null, 'neo', 'pw'),
      throwsA(anything),
    );
    expect(user.status, AuthStatus.UNAUTHENTICATED);
    expect(user.authResponse, isNull);
  });
}
