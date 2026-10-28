import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';

/// A saved CDN answer of `fixtures/` (trimmed real files fetched on 2026-10-28).
String fixture(String name) => File('test/units/simkl-cdn-feeds/fixtures/$name').readAsStringSync();

/// One request a fake saw.
class Seen {
  final Uri url;
  final Map<String, String> headers;

  Seen(this.url, this.headers);
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response.bytes(
      utf8.encode(body is String ? body : jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// A [SimklCdn] that answers from memory: [answer] gets the path (`/calendar/v2/anime.json`).
class FakeCdn {
  FakeCdn(this.answer, {DateTime Function()? now}) : _now = now;

  final http.Response Function(String path) answer;
  final DateTime Function()? _now;
  final List<Seen> seen = [];

  late final SimklCdn cdn = SimklCdn(
    get: (uri, headers) async {
      seen.add(Seen(uri, headers));
      return answer(uri.path);
    },
    clientId: () => 'client-id',
    appVersion: () async => '1.2.3',
    now: _now,
  );
}

/// A [SimklClient] without network: [answer] decides every response.
class FakeApi {
  FakeApi(this.answer, {this.session = false});

  final http.Response Function(Uri url) answer;

  /// Whether signed-in calls get a token (false = no session, as `sendAuthenticated` answers).
  final bool session;
  final List<Seen> seen = [];

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) async {
      if (!session) return null;
      return send(
        MockClient((request) async {
          seen.add(Seen(request.url, request.headers));
          return answer(request.url);
        }),
        'user-token',
      );
    },
    publicGet: (uri, headers) async {
      seen.add(Seen(uri, headers));
      return answer(uri);
    },
    clientId: () => 'client-id',
    appVersion: () async => '1.2.3',
  );
}

/// A small trending file (kept under the size that moves parsing to another isolate, which a
/// widget test's fake clock cannot wait for).
String trendingFile(String prefix, {int count = 3}) => jsonEncode([
      for (var i = 1; i <= count; i++)
        {
          'title': '$prefix $i',
          'ids': {'simkl_id': 1000 + i, 'mal': '${2000 + i}'},
          'release_date': '10/19/2026',
          'ratings': {
            'simkl': {'rating': 8.0, 'votes': 10},
          },
          'anime_type': 'tv',
        },
    ]);

/// A small calendar file with one episode per [days] entry (UTC dates).
String calendarFile(Map<int, DateTime> episodes) => jsonEncode({
      'calendar': [
        for (final e in episodes.entries)
          {
            'simkl_id': e.key,
            'date': e.value.toUtc().toIso8601String(),
            'episode': {'episode': 3},
          },
      ],
      'metadata': {
        for (final id in episodes.keys)
          '$id': {
            'title': 'Show $id',
            'ids': {'simkl_id': id, 'mal': '${id + 1}'},
          },
      },
    });
