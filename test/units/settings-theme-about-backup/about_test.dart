import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/screens/settings/about_settings.dart';

void main() {
  test('isNewerVersion compares yyyy.m.n numerically', () {
    expect(isNewerVersion('2026.10.1', '2026.10.2'), isTrue);
    expect(isNewerVersion('2026.9.9', '2026.10.1'), isTrue);
    expect(isNewerVersion('2026.10.1', '2026.10.1'), isFalse);
    expect(isNewerVersion('2026.10.2', 'v2026.10.1'), isFalse);
    expect(isNewerVersion('2026.10.1+1', '2026.10.1+9'), isFalse);
    expect(isNewerVersion('2026.10.1', 'nightly'), isFalse);
  });

  test('ReleaseService reads a release, a 404 and an error', () async {
    final service = ReleaseService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/tags/2026.10.1')) {
          return http.Response('{"tag_name":"2026.10.1","body":"- fix","html_url":"https://x/y"}', 200);
        }
        if (request.url.path.endsWith('/tags/0.0.0')) return http.Response('', 404);
        return http.Response('', 500);
      }),
    );
    final release = await service.forVersion('2026.10.1');
    expect(release?.tag, '2026.10.1');
    expect(release?.body, '- fix');
    expect(await service.forVersion('0.0.0'), isNull);
    expect(service.latest(), throwsA(anything));
  });
}
