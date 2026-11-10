import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';

/// Offline: a fake HTTP layer, no network, no Simkl account.
void main() {
  late DateTime clock;
  late List<Uri> urls;
  late List<Map<String, String>> sent;
  late http.Response Function() answer;
  late SimklClient client;

  setUp(() {
    clock = DateTime.utc(2026, 10, 28, 12);
    urls = [];
    sent = [];
    answer = () => http.Response('{"ok":true}', 200);
    client = SimklClient(
      auth: (send, {idempotent}) async {
        final mock = _Fake((r) {
          urls.add(r.url);
          sent.add(r.headers);
          return answer();
        });
        return send(mock, 'tok');
      },
      publicGet: (uri, headers) async {
        urls.add(uri);
        sent.add(headers);
        return answer();
      },
      clientId: () => 'cid',
      appVersion: () async => '1.2.3',
      now: () => clock,
    );
  });

  test('every call carries app-name, app-version and the User-Agent', () async {
    await client.getAuth('/sync/all-items/anime', query: {'extended': 'full'});
    await client.postAuth('/sync/add-to-list', {'shows': []});
    await client.getPublic('/anime/best/all');
    expect(urls, hasLength(3));
    for (var i = 0; i < 3; i++) {
      expect(urls[i].queryParameters['app-name'], 'MyWatchList');
      expect(urls[i].queryParameters['app-version'], '1.2.3');
      expect(sent[i]['User-Agent'], 'MyWatchList/1.2.3');
      expect(sent[i]['app-name'], 'MyWatchList');
      expect(sent[i]['app-version'], '1.2.3');
      expect(sent[i]['simkl-api-key'], 'cid');
    }
    expect(urls[0].queryParameters['extended'], 'full');
    expect(urls[2].queryParameters['client_id'], 'cid');
  });

  test('X-RateLimit-Remaining is read', () async {
    answer = () => http.Response('[]', 200, headers: {'x-ratelimit-remaining': '41'});
    await client.getPublic('/anime/best/all');
    expect(client.rateLimitRemaining, 41);
  });

  test('429 throws SimklRateLimited with Retry-After and pauses the client', () async {
    answer = () => http.Response('{"error":"rate_limit"}', 429, headers: {'retry-after': '30'});
    await expectLater(
      client.getPublic('/a'),
      throwsA(isA<SimklRateLimited>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 30))),
    );
    expect(urls, hasLength(1));

    // During the back-off nothing leaves the device.
    answer = () => http.Response('{}', 200);
    clock = clock.add(const Duration(seconds: 10));
    await expectLater(
      client.getAuth('/b'),
      throwsA(isA<SimklRateLimited>().having((e) => e.retryAfter, 'left', const Duration(seconds: 20))),
    );
    expect(urls, hasLength(1));

    // After it, calls go through again.
    clock = clock.add(const Duration(seconds: 21));
    expect(await client.getAuth('/b'), isNotNull);
    expect(urls, hasLength(2));
  });

  test('it is still a SimklHttpError 429', () async {
    answer = () => http.Response('', 429);
    await expectLater(client.getPublic('/a'), throwsA(isA<SimklHttpError>().having((e) => e.statusCode, 'code', 429)));
  });

  test('without Retry-After the back-off doubles, capped at ten minutes', () async {
    answer = () => http.Response('', 429);
    Future<Duration> hit() async {
      try {
        await client.getPublic('/a');
      } on SimklRateLimited catch (e) {
        return e.retryAfter;
      }
      fail('no 429');
    }

    expect(await hit(), SimklClient.baseBackoff);
    clock = clock.add(const Duration(hours: 1));
    expect(await hit(), SimklClient.baseBackoff * 2);
    clock = clock.add(const Duration(hours: 1));
    expect(await hit(), SimklClient.baseBackoff * 4);
    answer = () => http.Response('', 429, headers: {'retry-after': '99999'});
    clock = clock.add(const Duration(hours: 1));
    expect(await hit(), SimklClient.maxBackoff);
  });

  test('a success resets the doubling; other statuses stay SimklHttpError', () async {
    answer = () => http.Response('', 429);
    await expectLater(client.getPublic('/a'), throwsA(isA<SimklRateLimited>()));
    clock = clock.add(const Duration(hours: 1));
    answer = () => http.Response('{}', 200);
    await client.getPublic('/a');
    answer = () => http.Response('', 429);
    await expectLater(
      client.getPublic('/a'),
      throwsA(isA<SimklRateLimited>().having((e) => e.retryAfter, 'base', SimklClient.baseBackoff)),
    );
    clock = clock.add(const Duration(hours: 1));
    answer = () => http.Response('', 500);
    await expectLater(client.getPublic('/a'), throwsA(isA<SimklHttpError>().having((e) => e.statusCode, 'c', 500)));
  });
}

class _Fake extends http.BaseClient {
  _Fake(this._handler);
  final http.Response Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = _handler(request);
    return http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode, headers: r.headers, request: request);
  }
}
