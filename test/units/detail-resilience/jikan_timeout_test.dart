import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';

void main() {
  final url = Uri.parse('https://api.jikan.moe/v4/anime/1/statistics');

  test('a request without answer fails with JikanUnavailable after the timeout', () async {
    final client = JikanClient(
      client: MockClient((_) => Completer<http.Response>().future),
      minInterval: Duration.zero,
      requestTimeout: const Duration(milliseconds: 50),
    );
    final watch = Stopwatch()..start();
    await expectLater(client.get(url), throwsA(isA<JikanUnavailable>()));
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(client.isUnreachable, isTrue);
  });

  test('after a failure the next requests fail at once, until Retry resets it', () async {
    var calls = 0;
    var fail = true;
    final client = JikanClient(
      client: MockClient((_) async {
        calls++;
        if (fail) throw http.ClientException('Connection refused');
        return http.Response('{}', 200);
      }),
      minInterval: Duration.zero,
    );
    await expectLater(client.get(url), throwsA(isA<JikanUnavailable>()));
    await expectLater(client.get(Uri.parse('$url?x=2')), throwsA(isA<JikanUnavailable>()));
    expect(calls, 1, reason: 'the second request is skipped');

    fail = false;
    client.resetReachability();
    final response = await client.get(Uri.parse('$url?x=3'));
    expect(response.statusCode, 200);
    expect(client.isUnreachable, isFalse);
  });

  test('the pause ends by itself after the cooldown', () async {
    var now = DateTime(2026, 10, 27, 12);
    var calls = 0;
    final client = JikanClient(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) throw http.ClientException('down');
        return http.Response('{}', 200);
      }),
      minInterval: Duration.zero,
      unreachableCooldown: const Duration(seconds: 30),
      now: () => now,
    );
    await expectLater(client.get(url), throwsA(isA<JikanUnavailable>()));
    now = now.add(const Duration(seconds: 31));
    expect((await client.get(url)).statusCode, 200);
  });
}
