import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';

/// A clock the fake delay moves forward.
class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1);
  final List<Duration> waits = [];
  Future<void> delay(Duration d) async {
    waits.add(d);
    now = now.add(d);
  }
}

JikanClient _client(_Clock clock, MockClientHandler handler,
        {int maxRetries = 3}) =>
    JikanClient(
      client: MockClient(handler),
      now: () => clock.now,
      delay: clock.delay,
      maxRetries: maxRetries,
    );

void main() {
  final url = Uri.parse('https://api.jikan.moe/v4/anime/1/full');

  test('a 429 is retried with the Retry-After delay, then succeeds', () async {
    final clock = _Clock();
    var calls = 0;
    final client = _client(clock, (request) async {
      calls++;
      if (calls == 1) {
        return http.Response('', 429, headers: {'retry-after': '2'});
      }
      return http.Response('{"data":1}', 200);
    });

    final response = await client.get(url);

    expect(response.statusCode, 200);
    expect(calls, 2);
    expect(clock.waits, contains(const Duration(seconds: 2)));
  });

  test('without Retry-After the backoff doubles and is capped', () async {
    final clock = _Clock();
    final client = _client(clock, (_) async => http.Response('', 429));
    final r = http.Response('', 429);
    expect(client.retryDelay(r, 0), const Duration(seconds: 1));
    expect(client.retryDelay(r, 1), const Duration(seconds: 2));
    expect(client.retryDelay(r, 2), const Duration(seconds: 4));
    expect(client.retryDelay(r, 5), const Duration(seconds: 8));
  });

  test('keeps answering 429 after the retries and returns it', () async {
    final clock = _Clock();
    var calls = 0;
    final client = _client(clock, (_) async {
      calls++;
      return http.Response('', 429);
    }, maxRetries: 2);

    final response = await client.get(url);

    expect(response.statusCode, 429);
    expect(calls, 3);
    // A refused answer is never cached.
    await client.get(url);
    expect(calls, 6);
  });

  test('a successful answer is served from the cache until it expires',
      () async {
    final clock = _Clock();
    var calls = 0;
    final client = _client(clock, (_) async {
      calls++;
      return http.Response('ok$calls', 200);
    });

    expect((await client.get(url)).body, 'ok1');
    expect((await client.get(url)).body, 'ok1');
    expect(calls, 1);

    clock.now = clock.now.add(const Duration(minutes: 6));
    expect((await client.get(url)).body, 'ok2');
    expect(calls, 2);
  });

  test('identical requests in flight share one network call', () async {
    final clock = _Clock();
    var calls = 0;
    final client = _client(clock, (_) async {
      calls++;
      return http.Response('x', 200);
    });

    final results = await Future.wait([client.get(url), client.get(url)]);

    expect(calls, 1);
    expect(results.map((r) => r.body), ['x', 'x']);
  });

  test('requests are spaced by the minimum interval', () async {
    final clock = _Clock();
    final client = _client(clock, (_) async => http.Response('x', 200));

    await Future.wait([
      for (var i = 0; i < 4; i++) client.get(Uri.parse('$url?page=$i')),
    ]);

    // The first leaves at once; each of the three others takes the next slot
    // (the fake clock moves as soon as a wait starts, so each is 350 ms).
    expect(clock.waits, List.filled(3, const Duration(milliseconds: 350)));
    expect(clock.now.difference(DateTime.utc(2026, 1, 1)),
        const Duration(milliseconds: 1050));
  });

  test('a 429 pauses the queue for the others too', () async {
    final clock = _Clock();
    var calls = 0;
    final client = _client(clock, (_) async {
      calls++;
      return calls == 1
          ? http.Response('', 429, headers: {'retry-after': '3'})
          : http.Response('x', 200);
    });

    await client.get(url);
    final before = clock.now;
    await client.get(Uri.parse('$url?other=1'));

    expect(clock.now.difference(before) >= Duration.zero, isTrue);
    expect(calls, 3);
  });
}
