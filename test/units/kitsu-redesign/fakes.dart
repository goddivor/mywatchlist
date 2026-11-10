import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media_detail.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';

/// The title page record of Frieren saved from an anonymous read of kitsu.io on 2026-10-28
/// (pictures removed so no widget asks the network for one).
Map<String, dynamic> animeFixture() =>
    jsonDecode(File('test/units/kitsu-redesign/fixtures/media_anime.json').readAsStringSync())
        as Map<String, dynamic>;

/// A fake Kitsu, fakes only: GraphQL documents answered by a substring of the request body,
/// JSON:API by a substring of the URL; every request is recorded. Nothing reaches Kitsu and no
/// account is written to: "writes" are answered from these tables.
class FakeKitsu {
  FakeKitsu({Map<String, Object? Function(http.Request)>? graphql, Map<String, Object? Function(http.Request)>? rest})
      : gqlRoutes = graphql ?? {},
        restRoutes = rest ?? {};

  final Map<String, Object? Function(http.Request)> gqlRoutes;
  final Map<String, Object? Function(http.Request)> restRoutes;
  final List<http.Request> requests = [];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    final post = request.method == 'POST';
    final haystack = post ? request.body : request.url.toString();
    for (final entry in (post ? gqlRoutes : restRoutes).entries) {
      if (haystack.contains(entry.key)) {
        final body = entry.value(request);
        if (body == null) return http.Response('{}', 500);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
    }
    return http.Response('{}', 404);
  });

  Future<http.Response?> _send(Future<http.Response> Function(http.Client, String) send, {bool? idempotent}) =>
      send(client, 'tok');

  late final KitsuHttp kitsu = KitsuHttp(publicClient: client, auth: _send);
  late final KitsuGraphql gql = KitsuGraphql(client: client, rest: kitsu, auth: _send);
  late final KitsuLibrary library = KitsuLibrary(http: kitsu, owner: () => 'me');
  late final KitsuMyLibrary my = KitsuMyLibrary(graphql: gql, http: kitsu, library: library);
  late final KitsuCatalog catalog = KitsuCatalog(http: kitsu, graphql: gql);
  KitsuMediaDetailService detail() => KitsuMediaDetailService(graphql: gql);

  /// The GraphQL `input` variables of every request whose body contains [marker].
  List<Map<String, dynamic>> inputs(String marker) => [
        for (final r in requests)
          if (r.method == 'POST' && r.body.contains(marker))
            ((jsonDecode(r.body) as Map)['variables'] as Map)['input'] as Map<String, dynamic>,
      ];
}

/// A GraphQL `LibraryEntry` as Kitsu answers it.
Map<String, dynamic> entryJson({
  String id = '900',
  String status = 'CURRENT',
  int progress = 5,
  int? rating,
  String? reaction,
  Map<String, dynamic>? media,
  int? nextNumber,
}) =>
    {
      'id': id,
      'status': status,
      'progress': progress,
      'rating': rating,
      'reconsumeCount': 0,
      'reconsuming': false,
      'private': false,
      'notes': null,
      'startedAt': null,
      'finishedAt': null,
      'reaction': reaction == null ? null : {'reaction': reaction},
      'nextUnit': nextNumber == null
          ? null
          : {'id': 'u$nextNumber', 'number': nextNumber, 'titles': {'canonical': 'Next one'}},
      if (media != null) 'media': media,
    };

Map<String, dynamic> userDoc() => {
      'data': [
        {'id': '42', 'type': 'users', 'attributes': {'name': 'me'}}
      ]
    };
