import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/retry_policy.dart';
import 'package:mywatchlist/user/base_user.dart';

import 'fake_user.dart';

// Short limits so the suite stays fast; ratios match the real defaults.
const _response = Duration(milliseconds: 80);
const _idle = Duration(milliseconds: 80);
const _step = Duration(milliseconds: 30);

/// Records every client the user builds and whether it was closed.
class _TrackedClient extends http.BaseClient {
  _TrackedClient(this._inner);
  final http.Client _inner;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);
  @override
  void close() => closed = true;
}

final _clients = <_TrackedClient>[];

FakeUser _user(http.Client mock, {int maxAttempts = 8}) {
  final u = FakeUser()
    ..clientFactory = (() {
      final c = _TrackedClient(mock);
      _clients.add(c);
      return c;
    })
    ..retryPolicy = RetryPolicy(
      maxAttempts: maxAttempts,
      responseTimeout: _response,
      idleTimeout: _idle,
      sleep: (_) async {},
    );
  u.setAuthResponse(AuthResponse(
    accessToken: 'A1',
    refreshToken: 'R1',
    expiresIn: 3600,
    createdTime: DateTime.now(),
  ));
  return u;
}

/// Headers at once, then [chunks] bytes, one every [_step].
http.StreamedResponse _slowBody(int chunks) {
  final ctl = StreamController<List<int>>();
  () async {
    for (var i = 0; i < chunks; i++) {
      await Future<void>.delayed(_step);
      ctl.add(utf8.encode('x'));
    }
    await ctl.close();
  }();
  return http.StreamedResponse(ctl.stream, 200);
}

Future<http.Response> _get(http.Client c, String t) =>
    c.get(Uri.parse('https://api.test/list'),
        headers: {'Authorization': 'Bearer $t'});

Future<http.Response> _put(http.Client c, String t) =>
    c.put(Uri.parse('https://api.test/status'),
        headers: {'Authorization': 'Bearer $t'}, body: 'status=watching');

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    _clients.clear();
  });

  test('a slow but healthy large response is not cut nor resent', () async {
    var n = 0;
    final mock = MockClient.streaming((req, _) async {
      n++;
      return _slowBody(12); // ~360 ms in total, 4.5x the response timeout
    });
    final res = await _user(mock).sendAuthenticated(_get);
    expect(res!.statusCode, 200);
    expect(res.body, 'x' * 12);
    expect(n, 1);
  });

  test('a stalled body times out and the GET is retried', () async {
    var n = 0;
    final mock = MockClient.streaming((req, _) async {
      n++;
      if (n == 1) {
        // Two bytes, then silence.
        final ctl = StreamController<List<int>>()..add([65, 66]);
        return http.StreamedResponse(ctl.stream, 200);
      }
      return http.StreamedResponse(Stream.value(utf8.encode('ok')), 200);
    });
    final res = await _user(mock).sendAuthenticated(_get);
    expect(res!.body, 'ok');
    expect(n, 2);
  });

  test('a GET whose headers never come is aborted before the retry',
      () async {
    var n = 0;
    final mock = MockClient((req) async {
      n++;
      if (n == 1) return Completer<http.Response>().future; // hangs
      expect(_clients.first.closed, isTrue,
          reason: 'the timed out attempt is cancelled first');
      return http.Response('ok', 200);
    });
    final res = await _user(mock).sendAuthenticated(_get);
    expect(res!.body, 'ok');
    expect(n, 2);
    expect(_clients.every((c) => c.closed), isTrue);
  });

  test('a PUT that timed out is never replayed', () async {
    var n = 0;
    final mock = MockClient((req) async {
      n++;
      return Completer<http.Response>().future;
    });
    await expectLater(_user(mock).sendAuthenticated(_put),
        throwsA(isA<TimeoutException>()));
    expect(n, 1);
    expect(_clients.single.closed, isTrue);
  });

  test('a DELETE cut by a connection reset is never replayed', () async {
    var n = 0;
    final mock = MockClient((req) async {
      n++;
      throw const SocketException('Connection reset by peer',
          osError: OSError('Connection reset by peer', 104));
    });
    await expectLater(
        _user(mock).sendAuthenticated(
            (c, t) => c.delete(Uri.parse('https://api.test/status'))),
        throwsA(isA<SocketException>()));
    expect(n, 1);
  });

  test('a PUT that never left the device is retried', () async {
    var n = 0;
    final mock = MockClient((req) async {
      if (++n < 3) {
        throw const SocketException('Connection refused',
            osError: OSError('Connection refused', 111));
      }
      return http.Response('', 200);
    });
    final res = await _user(mock).sendAuthenticated(_put);
    expect(res!.statusCode, 200);
    expect(n, 3);
  });

  test('a PUT marked idempotent is retried after a timeout', () async {
    var n = 0;
    final mock = MockClient((req) async {
      if (++n == 1) return Completer<http.Response>().future;
      return http.Response('', 200);
    });
    final res =
        await _user(mock).sendAuthenticated(_put, idempotent: true);
    expect(res!.statusCode, 200);
    expect(n, 2);
  });

  test('a per call deadline bounds the whole call and cancels it', () async {
    var n = 0;
    final mock = MockClient.streaming((req, _) async {
      n++;
      return _slowBody(20); // ~600 ms, healthy but too long for this caller
    });
    final sw = Stopwatch()..start();
    await expectLater(
        _user(mock).sendAuthenticated(_get,
            timeout: const Duration(milliseconds: 150)),
        throwsA(isA<TimeoutException>()));
    expect(sw.elapsed, lessThan(const Duration(milliseconds: 400)));
    expect(n, 1, reason: 'no attempt is started once the deadline passed');
    expect(_clients.single.closed, isTrue);
  });

  test('a refresh POST that timed out is not replayed, session kept',
      () async {
    var refreshCalls = 0;
    final mock = MockClient((req) async {
      refreshCalls++;
      return Completer<http.Response>().future;
    });
    final user = _user(mock);
    expect(await user.refreshAccessToken(), isFalse);
    expect(refreshCalls, 1);
    expect(user.status, AuthStatus.AUTHENTICATED);
    expect(user.needsReLogin, isFalse);
  });

  test('isNotDelivered only accepts errors raised before sending', () {
    expect(
        RetryPolicy.isNotDelivered(
            const SocketException('Failed host lookup: api.test')),
        isTrue);
    expect(
        RetryPolicy.isNotDelivered(const SocketException(
            'HTTP connection timed out after 0:00:15.000000')),
        isTrue);
    expect(RetryPolicy.isNotDelivered(const HandshakeException('tls')),
        isTrue);
    expect(RetryPolicy.isNotDelivered(TimeoutException('t')), isFalse);
    expect(
        RetryPolicy.isNotDelivered(const SocketException('Broken pipe',
            osError: OSError('Broken pipe', 32))),
        isFalse);
    expect(RetryPolicy.isNotDelivered(http.ClientException('x')), isFalse);
  });
}
