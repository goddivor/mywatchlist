import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';

/// Sender over a [MockClient]: fakes only, nothing reaches a tracker.
AuthSender senderFor(
  Future<http.Response> Function(http.Request) handler, {
  bool signedIn = true,
}) {
  final client = MockClient(handler);
  return (send, {idempotent}) async =>
      signedIn ? send(client, 'token') : null;
}

http.Response json200(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

void main() {
  group('AniList', () {
    test('reads the entry with decimal scores and fuzzy dates', () async {
      late http.Request seen;
      final client = AnilistEntryClient(
        auth: senderFor((r) async {
          seen = r;
          return json200({
            'data': {
              'Media': {
                'mediaListEntry': {
                  'id': 9,
                  'status': 'CURRENT',
                  'score': 7.5,
                  'progress': 4,
                  'progressVolumes': 1,
                  'repeat': 2,
                  'notes': 'hi',
                  'startedAt': {'year': 2020, 'month': 2, 'day': null},
                  'completedAt': {'year': null, 'month': null, 'day': null},
                }
              }
            }
          });
        }),
      );
      final e = (await client.read('123', isAnime: true))!;
      expect(e.status, 'watching');
      expect(e.score, 7.5);
      expect(e.progress, 4);
      expect(e.repeat, 2);
      expect(e.startDate, '2020-02');
      expect(e.finishDate, isNull);
      expect(e.entryId, '9');
      final sent = jsonDecode(seen.body) as Map;
      expect(sent['query'], contains('POINT_10_DECIMAL'));
      expect(seen.headers['Authorization'], 'Bearer token');
    });

    test('a media that is not on the list reads as null', () async {
      final client = AnilistEntryClient(
          auth: senderFor((_) async => json200({
                'data': {
                  'Media': {'mediaListEntry': null}
                }
              })));
      expect(await client.read('1', isAnime: false), isNull);
    });

    test('writes the score as scoreRaw so decimals survive', () async {
      late Map vars;
      final client = AnilistEntryClient(
        auth: senderFor((r) async {
          vars = (jsonDecode(r.body) as Map)['variables'] as Map;
          return json200({
            'data': {
              'SaveMediaListEntry': {
                'id': 1,
                'status': 'COMPLETED',
                'score': 7.5,
                'progress': 12
              }
            }
          });
        }),
      );
      final saved = await client.write(
        '5',
        const SyncEntry(
            status: 'completed',
            score: 7.5,
            progress: 12,
            startDate: '2020-02-03'),
        isAnime: true,
      );
      expect(vars['mediaId'], 5);
      expect(vars['status'], 'COMPLETED');
      expect(vars['scoreRaw'], 75);
      expect(vars['progress'], 12);
      expect(vars['startedAt'], {'year': 2020, 'month': 2, 'day': 3});
      expect(vars.containsKey('completedAt'), isFalse);
      expect(vars.containsKey('notes'), isFalse);
      expect(saved.score, 7.5);
    });

    test('finds the AniList media by MAL id', () async {
      late Map vars;
      final client = AnilistEntryClient(
        auth: senderFor((r) async {
          vars = (jsonDecode(r.body) as Map)['variables'] as Map;
          return json200({
            'data': {
              'Media': {'id': 777}
            }
          });
        }),
      );
      expect(await client.findByMalId(5114, isAnime: false), '777');
      expect(vars, {'mal': 5114, 'type': 'MANGA'});
    });

    test('no session raises SyncAuthRequired', () async {
      final client = AnilistEntryClient(
          auth: senderFor((_) async => json200({}), signedIn: false));
      expect(() => client.read('1', isAnime: true),
          throwsA(isA<SyncAuthRequired>()));
    });

    test('an HTTP error raises SyncRequestFailed', () async {
      final client = AnilistEntryClient(
          auth: senderFor((_) async => http.Response('nope', 500)));
      expect(() => client.read('1', isAnime: true),
          throwsA(isA<SyncRequestFailed>()));
    });
  });

  group('Kitsu', () {
    http.Response users() => json200({
          'data': [
            {'id': '42'}
          ]
        });

    test('updates the existing library entry in half points', () async {
      final calls = <String>[];
      Map? patched;
      final client = KitsuEntryClient(
        auth: senderFor((r) async {
          calls.add('${r.method} ${r.url.path}');
          if (r.url.path.endsWith('/users')) return users();
          if (r.method == 'GET') {
            return json200({
              'data': [
                {'id': '900', 'attributes': {}}
              ]
            });
          }
          patched = jsonDecode(r.body) as Map;
          return json200({
            'data': {
              'id': '900',
              'attributes': {
                'status': 'current',
                'ratingTwenty': 15,
                'progress': 3,
                'startedAt': '2020-02-03T00:00:00.000Z'
              }
            }
          });
        }),
      );
      final saved = await client.write(
        '5',
        const SyncEntry(
            status: 'watching',
            score: 7.5,
            progress: 3,
            startDate: '2020-02-03'),
        isAnime: true,
      );
      expect(calls.last, 'PATCH /api/edge/library-entries/900');
      final attrs = (patched!['data'] as Map)['attributes'] as Map;
      expect(attrs['ratingTwenty'], 15);
      expect(attrs['status'], 'current');
      expect(attrs['startedAt'], '2020-02-03T00:00:00.000Z');
      expect(saved.score, 7.5);
      expect(saved.startDate, '2020-02-03');
    });

    test('creates the entry when the media is not on the list', () async {
      Map? created;
      final client = KitsuEntryClient(
        auth: senderFor((r) async {
          if (r.url.path.endsWith('/users')) return users();
          if (r.method == 'GET') return json200({'data': []});
          created = jsonDecode(r.body) as Map;
          return http.Response(
              jsonEncode({
                'data': {
                  'id': '1',
                  'attributes': {'status': 'planned'}
                }
              }),
              201);
        }),
      );
      final saved = await client.write(
          '5', const SyncEntry(status: 'plan_to_read'),
          isAnime: false);
      final data = created!['data'] as Map;
      expect((data['relationships'] as Map).containsKey('manga'), isTrue);
      expect(saved.status, 'plan_to_read');
    });

    test('maps MAL ids through Kitsu mappings', () async {
      Uri? asked;
      final client = KitsuEntryClient(
        auth: senderFor((r) async {
          asked = r.url;
          return json200({
            'data': [
              {
                'relationships': {
                  'item': {
                    'data': {'id': '321'}
                  }
                }
              }
            ]
          });
        }),
      );
      expect(await client.findByMalId(5114, isAnime: true), '321');
      expect(asked!.queryParameters['filter[externalSite]'],
          'myanimelist/anime');
      expect(asked!.queryParameters['filter[externalId]'], '5114');
    });
  });

  group('Simkl', () {
    final list = {
      'anime': [
        {
          'status': 'plantowatch',
          'user_rating': 8,
          'watched_episodes_count': 2,
          'show': {
            'ids': {'simkl': 11, 'mal': 5114}
          }
        }
      ]
    };

    test('reads one entry out of the list, by MAL id or Simkl id', () async {
      var fetches = 0;
      final client = SimklEntryClient(
        auth: senderFor((_) async {
          fetches++;
          return json200(list);
        }),
      );
      final byMal = await client.read('mal:5114', isAnime: true);
      expect(byMal!.status, 'plan_to_watch');
      expect(byMal.score, 8);
      expect(byMal.progress, 2);
      final bySimkl = await client.read('11', isAnime: true);
      expect(bySimkl, isNotNull);
      expect(await client.read('mal:1', isAnime: true), isNull);
      expect(fetches, 1, reason: 'the list is kept for a minute');
    });

    test('has no manga', () async {
      final client = SimklEntryClient(auth: senderFor((_) async => json200({})));
      expect(client.supports(isAnime: false), isFalse);
      expect(() => client.read('mal:1', isAnime: false),
          throwsA(isA<SyncUnsupported>()));
    });

    test('links by MAL id without any search', () async {
      final client = SimklEntryClient(auth: senderFor((_) async => json200({})));
      expect(await client.findByMalId(5114, isAnime: true), 'mal:5114');
      expect(await client.findByMalId(5114, isAnime: false), isNull);
    });
  });
}
