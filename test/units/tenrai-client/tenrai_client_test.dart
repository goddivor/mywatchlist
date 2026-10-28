import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';

void main() {
  /// A fake clock: `delay` advances `now` instead of sleeping, and records sends.
  late DateTime now;
  late List<DateTime> sentAt;

  TenraiClient client(Future<http.Response> Function(http.Request) answer,
          {int maxPerMinute = 120}) =>
      TenraiClient(
        client: MockClient((request) {
          sentAt.add(now);
          return answer(request);
        }),
        maxPerMinute: maxPerMinute,
        now: () => now,
        delay: (wait) async => now = now.add(wait),
      );

  setUp(() {
    now = DateTime(2026, 10, 28, 12);
    sentAt = [];
  });

  Uri url(int i) => TenraiClient.uri('/anime/$i');

  test('requests are spaced by 250 ms: never more than 4 per second', () async {
    final tenrai = client((_) async => http.Response('{}', 200));
    for (var i = 0; i < 9; i++) {
      await tenrai.get(url(i));
    }
    for (var i = 1; i < sentAt.length; i++) {
      expect(sentAt[i].difference(sentAt[i - 1]) >= const Duration(milliseconds: 250), isTrue);
    }
  });

  test('never more than maxPerMinute requests in any minute', () async {
    final tenrai = client((_) async => http.Response('{}', 200), maxPerMinute: 5);
    for (var i = 0; i < 12; i++) {
      await tenrai.get(url(i));
    }
    for (var i = 5; i < sentAt.length; i++) {
      expect(sentAt[i].difference(sentAt[i - 5]) >= const Duration(minutes: 1), isTrue,
          reason: 'request $i');
    }
  });

  test('a 429 waits for Retry-After, then retries', () async {
    var calls = 0;
    final tenrai = client((_) async {
      calls++;
      if (calls == 1) return http.Response('{}', 429, headers: {'retry-after': '3'});
      return http.Response('{"data":{}}', 200);
    });
    final response = await tenrai.get(url(1));
    expect(response.statusCode, 200);
    expect(sentAt[1].difference(sentAt[0]) >= const Duration(seconds: 3), isTrue);
  });

  test('a 429 that lasts is returned after the retries', () async {
    final tenrai = client((_) async => http.Response('{}', 429, headers: {'retry-after': '1'}));
    expect((await tenrai.get(url(1))).statusCode, 429);
    expect(sentAt.length, 1 + tenrai.maxRetries);
  });

  test('answers are cached and identical requests share one call', () async {
    final tenrai = client((_) async => http.Response('{"data":[]}', 200));
    await Future.wait([tenrai.get(url(1)), tenrai.get(url(1))]);
    await tenrai.get(url(1));
    expect(sentAt.length, 1);
  });

  test('a network failure throws TenraiUnavailable and pauses until Retry', () async {
    var fail = true;
    final tenrai = client((request) async {
      if (fail) throw http.ClientException('down', request.url);
      return http.Response('{"data":{}}', 200);
    });
    await expectLater(tenrai.get(url(1)), throwsA(isA<TenraiUnavailable>()));
    expect(tenrai.isUnreachable, isTrue);
    await expectLater(tenrai.get(url(2)), throwsA(isA<TenraiUnavailable>()));
    expect(sentAt.length, 1);
    fail = false;
    tenrai.resetReachability();
    expect((await tenrai.getJson('/anime/3'))['data'], isA<Map>());
  });

  test('no key is ever sent', () async {
    http.Request? seen;
    final tenrai = client((request) async {
      seen = request;
      return http.Response('{"data":{}}', 200);
    });
    await tenrai.get(url(1));
    expect(seen!.headers.keys.map((k) => k.toLowerCase()),
        isNot(anyOf(contains('authorization'), contains('x-api-key'))));
    expect(seen!.url.queryParameters.keys, isNot(contains('key')));
  });
}
