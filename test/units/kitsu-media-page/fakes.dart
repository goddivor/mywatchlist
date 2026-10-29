import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media_detail.dart';

/// Saved from anonymous read-only calls to kitsu.io on 2026-10-28. Nothing here reaches Kitsu.
String fixtureText(String name) => File('test/units/kitsu-media-page/fixtures/$name.json').readAsStringSync();

Map<String, dynamic> fixtureJson(String name) => jsonDecode(fixtureText(name)) as Map<String, dynamic>;

const _pictureKeys = {'posterImage', 'bannerImage', 'avatarImage', 'thumbnail', 'image'};

/// Drops every picture so a widget test never asks the network for one.
Object? withoutPictures(Object? json) {
  if (json is Map) {
    return {
      for (final e in json.entries)
        if (!_pictureKeys.contains(e.key)) e.key: withoutPictures(e.value),
    };
  }
  if (json is List) return [for (final e in json) withoutPictures(e)];
  return json;
}

/// Fake Kitsu: GraphQL documents answered by a substring of the query, JSON:API by path; records
/// every request.
class FakeKitsu {
  FakeKitsu({this.graphql = const {}, this.rest = const {}, this.failAll = false});

  /// Substring of the GraphQL body -> JSON answer.
  final Map<String, Object?> graphql;

  /// Substring of the REST URL -> JSON answer.
  final Map<String, Object?> rest;
  final bool failAll;
  final List<http.Request> requests = [];

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    if (failAll) return http.Response('{}', 503);
    final haystack = request.method == 'POST' ? request.body : request.url.toString();
    final table = request.method == 'POST' ? graphql : rest;
    for (final entry in table.entries) {
      if (haystack.contains(entry.key)) {
        return http.Response.bytes(utf8.encode(jsonEncode(entry.value)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
    }
    return http.Response('{}', 404);
  });

  KitsuGraphql get gql => KitsuGraphql(client: client, rest: KitsuHttp(publicClient: client));

  KitsuMediaDetailService service() => KitsuMediaDetailService(graphql: gql);

  int get graphqlCalls => requests.where((r) => r.method == 'POST').length;
}
