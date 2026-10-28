import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';

/// One request the fake Simkl server saw.
class SeenRequest {
  final String method;
  final Uri url;
  final Map<String, String> headers;
  final Object? body;

  SeenRequest(this.method, this.url, this.headers, this.body);
}

/// A [SimklClient] with no network and no real account: [answer] decides the response of every
/// request, [seen] records them. Nothing here can write to a real Simkl account.
class FakeSimkl {
  FakeSimkl(this.answer, {this.signedIn = true});

  final http.Response Function(SeenRequest request) answer;
  final bool signedIn;
  final List<SeenRequest> seen = [];

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) async {
      if (!signedIn) return null;
      final mock = MockClient((request) async {
        final recorded = SeenRequest(
          request.method,
          request.url,
          request.headers,
          request.body.isEmpty ? null : jsonDecode(request.body),
        );
        seen.add(recorded);
        return answer(recorded);
      });
      return send(mock, 'test-token');
    },
    publicGet: (uri, headers) async {
      final recorded = SeenRequest('GET', uri, headers, null);
      seen.add(recorded);
      return answer(recorded);
    },
    clientId: () => 'client-id',
  );

  static http.Response json(Object? body, [int status = 200]) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

/// A `sync/all-items/anime` item.
Map<String, dynamic> simklItem({
  required int id,
  int? mal,
  String title = 'Title',
  String status = 'watching',
  int rating = 0,
  int watched = 0,
  int total = 12,
  int notAired = 0,
  String? lastWatched,
  bool poster = true,
}) =>
    {
      'status': status,
      'user_rating': rating == 0 ? null : rating,
      'watched_episodes_count': watched,
      'total_episodes_count': total,
      'not_aired_episodes_count': notAired,
      'last_watched_at': lastWatched,
      'show': {
        'title': '$title $id',
        'poster': poster ? 'ab/$id' : null,
        'year': 2024,
        'ids': {'simkl': id, 'slug': 'slug-$id', if (mal != null) 'mal': mal},
      },
    };
