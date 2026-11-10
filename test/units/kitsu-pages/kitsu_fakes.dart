import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';

/// A [KitsuHttp] over a [MockClient]: fakes only, nothing reaches Kitsu (the owner's account is
/// on the emulator, tests never write to it).
class FakeKitsu {
  FakeKitsu(this.handler, {this.signedIn = true}) {
    final client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
    kitsu = KitsuHttp(
      publicClient: client,
      auth: (send, {idempotent}) async => signedIn ? send(client, 'token') : null,
    );
  }

  final Future<http.Response> Function(http.Request) handler;
  final bool signedIn;
  final List<http.Request> requests = [];
  late final KitsuHttp kitsu;
}

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/vnd.api+json'});

/// An anime resource with a MyAnimeList mapping.
Map<String, dynamic> animeResource(int id, String title,
        {int? malId, String status = 'current', int episodes = 12, num rating = 82.5}) =>
    {
      'id': '$id',
      'type': 'anime',
      'attributes': {
        'canonicalTitle': title,
        'titles': {'en': '$title EN', 'en_jp': title, 'ja_jp': '$title JA'},
        'posterImage': {'small': 'https://img/s$id.jpg', 'large': 'https://img/l$id.jpg'},
        'averageRating': '$rating',
        'userCount': 1000,
        'popularityRank': 5,
        'ratingRank': 7,
        'subtype': 'TV',
        'status': status,
        'episodeCount': episodes,
        'startDate': '2024-04-06',
      },
      'relationships': {
        'mappings': {
          'data': [
            {'type': 'mappings', 'id': 'x$id'},
            if (malId != null) {'type': 'mappings', 'id': 'm$id'},
          ],
        },
      },
    };

List<Map<String, dynamic>> mappingsOf(int id, {int? malId}) => [
      {
        'id': 'x$id',
        'type': 'mappings',
        'attributes': {'externalSite': 'anilist/anime', 'externalId': '999$id'},
      },
      if (malId != null)
        {
          'id': 'm$id',
          'type': 'mappings',
          'attributes': {'externalSite': 'myanimelist/anime', 'externalId': '$malId'},
        },
    ];
