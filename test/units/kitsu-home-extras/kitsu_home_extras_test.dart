import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuGraphql;
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_row.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_tile.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_rows.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';

/// Fakes only: a [MockClient] answers every request, nothing reaches Kitsu and nothing writes to
/// a tracker account. The news fixture is a saved anonymous read of group 596 (2026-10-28).
class _Fake {
  _Fake(this.handler) {
    client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
    final rest = KitsuHttp(publicClient: client, auth: (send, {idempotent}) async => send(client, 'tok'));
    graphql = KitsuGraphql(
        client: client, rest: rest, auth: (send, {idempotent}) async => send(client, 'tok'));
    catalog = KitsuCatalog(http: rest, graphql: graphql);
  }

  final Future<http.Response> Function(http.Request) handler;
  final List<http.Request> requests = [];
  late final MockClient client;
  late final KitsuGraphql graphql;
  late final KitsuCatalog catalog;
}

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _anime(int id, {int? malId, String title = 'Title'}) => {
      'id': '$id',
      'type': 'anime',
      'attributes': {
        'canonicalTitle': '$title $id',
        'titles': {'en': '$title $id EN', 'en_jp': '$title $id'},
        'averageRating': '80.0',
        'userCount': 10,
      },
      'relationships': {
        'mappings': {
          'data': [if (malId != null) {'type': 'mappings', 'id': 'm$id'}]
        }
      },
    };

Map<String, dynamic> _doc(List<Map<String, dynamic>> animes) => {
      'data': animes,
      'included': [
        for (final a in animes)
          if ((a['relationships']['mappings']['data'] as List).isNotEmpty)
            {
              'id': 'm${a['id']}',
              'type': 'mappings',
              'attributes': {
                'externalSite': 'myanimelist/anime',
                'externalId': '${1000 + int.parse(a['id'] as String)}'
              },
            },
      ],
    };

void main() {
  group('trendingInCategory', () {
    test('asks the site\'s category call and keeps Kitsu\'s order', () async {
      final fake = _Fake((r) async {
        if (r.url.path.endsWith('/trending/anime')) {
          return _json({
            'data': [
              {'id': '3', 'type': 'anime'},
              {'id': '1', 'type': 'anime'},
            ]
          });
        }
        return _json(_doc([_anime(1, malId: 1), _anime(3, malId: 1)]));
      });
      final items = await fake.catalog.trendingInCategory('164', isAnime: true);
      final first = fake.requests.first.url.queryParameters;
      expect(first['in_category'], 'true');
      expect(first['category'], '164');
      expect(items.map((m) => m.id), [3, 1]);
      expect(items.first.malId, 1003);
    });
  });

  group('trendingAmongFollowing', () {
    test('reads localTrending with a token and returns the nodes in order', () async {
      final fake = _Fake((r) async {
        if (r.url.path.endsWith('/graphql')) {
          return _json({
            'data': {
              'localTrending': {
                'nodes': [
                  {'id': '2'},
                  {'id': '1'},
                ]
              }
            }
          });
        }
        return _json(_doc([_anime(1, malId: 1), _anime(2, malId: 1)]));
      });
      final items = await fake.catalog.trendingAmongFollowing(isAnime: true);
      final gql = fake.requests.first;
      expect(gql.headers['Authorization'], 'Bearer tok');
      expect(gql.body, contains('localTrending'));
      expect(items.map((m) => m.id), [2, 1]);
    });

    test('is empty when the user follows no one', () async {
      final fake = _Fake((r) async => _json({
            'data': {
              'localTrending': {'nodes': []}
            }
          }));
      expect(await fake.catalog.trendingAmongFollowing(isAnime: true), isEmpty);
      expect(fake.requests, hasLength(1));
    });
  });

  group('randomMedia', () {
    test('skips a title with no MyAnimeList page and returns the next one', () async {
      var draws = 0;
      final fake = _Fake((r) async {
        if (r.url.path.endsWith('/graphql')) {
          draws++;
          return _json({
            'data': {
              'randomMedia': {'id': '$draws'}
            }
          });
        }
        final id = int.parse(r.url.queryParameters['filter[id]']!);
        return _json(_doc([_anime(id, malId: id == 2 ? 2 : null)]));
      });
      final pick = await fake.catalog.randomMedia(isAnime: true);
      expect(pick?.id, 2);
      expect(draws, 2);
      expect(fake.requests.first.body, contains('ageRatings'));
      expect(fake.requests.first.body, isNot(contains('R18')));
    });

    test('gives up after the tries', () async {
      final fake = _Fake((r) async {
        if (r.url.path.endsWith('/graphql')) {
          return _json({
            'data': {
              'randomMedia': {'id': '5'}
            }
          });
        }
        return _json(_doc([_anime(5)]));
      });
      expect(await fake.catalog.randomMedia(isAnime: true, tries: 2), isNull);
    });
  });

  group('account preferences', () {
    test('title language and rating system come from currentAccount', () async {
      final fake = _Fake((r) async => _json({
            'data': {
              'currentAccount': {
                'titleLanguagePreference': 'LOCALIZED',
                'ratingSystem': 'ADVANCED',
                'sfwFilterPreference': 'SFW',
              }
            }
          }));
      expect(fake.catalog.account, isNull);
      final prefs = await fake.catalog.loadAccountPrefs();
      expect(prefs?.titleLang, 'en');
      expect(prefs?.ratingSystem, KitsuRatingSystem.advanced);
      expect(prefs?.sfwFilter, isTrue);
      expect(fake.catalog.account, prefs);
    });

    test('the account language picks the title of the catalogue', () async {
      final fake = _Fake((r) async {
        if (r.url.path.endsWith('/graphql')) {
          return _json({
            'data': {
              'currentAccount': {'titleLanguagePreference': 'LOCALIZED', 'ratingSystem': 'REGULAR'}
            }
          });
        }
        return _json(_doc([_anime(1, malId: 1)]));
      });
      const query = KitsuMediaQuery(isAnime: true);
      await fake.catalog.loadAccountPrefs();
      expect((await fake.catalog.page(query)).items.single.title, 'Title 1 EN');
      fake.catalog.clearAccountPrefs();
      expect(fake.catalog.account, isNull);
    });

    test('a failure keeps nothing and does not throw', () async {
      final fake = _Fake((r) async => http.Response('{}', 500));
      expect(await fake.catalog.loadAccountPrefs(), isNull);
      expect(fake.catalog.account, isNull);
    });
  });

  group('home sections', () {
    test('news is a Kitsu section, features and suggestions are not', () {
      bool supported(SectionType t) =>
          kitsuSectionSupported(HomeSectionPreference(type: t, enabled: true));
      expect(supported(SectionType.news), isTrue);
      expect(supported(SectionType.userList), isTrue);
      expect(supported(SectionType.topScore), isTrue);
      expect(supported(SectionType.features), isFalse);
      expect(supported(SectionType.suggested), isFalse);
      expect(supported(SectionType.forum), isFalse);
    });
  });

  group('KitsuNewsRow', () {
    Future<void> pump(WidgetTester tester, KitsuFeed feed, void Function(String) open) async {
      HomeSectionCache.clear();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: KitsuNewsRow(title: 'News', feed: feed, onOpenPost: (p) => open(p.id)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('shows the posts of group 596 and opens one', (tester) async {
      final body = File('test/units/kitsu-home-extras/fixtures/feed_group.json')
          .readAsStringSync()
          .replaceAll(RegExp(r'https://media\.kitsu[^"]*'), '');
      final fake = _Fake((r) async => http.Response.bytes(utf8.encode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
      final feed = KitsuFeed(client: fake.graphql);
      String? opened;
      await pump(tester, feed, (id) => opened = id);
      expect(find.text('News'), findsOneWidget);
      expect(find.byType(KitsuNewsCard), findsWidgets);
      expect(fake.requests.first.url.path, contains('/feeds/group/596'));
      await tester.tap(find.byType(KitsuNewsCard).first);
      expect(opened, isNotNull);
    });

    testWidgets('draws nothing when the feed fails', (tester) async {
      final fake = _Fake((r) async => http.Response('{}', 500));
      await pump(tester, KitsuFeed(client: fake.graphql), (_) {});
      expect(find.text('News'), findsNothing);
      expect(find.byType(KitsuNewsCard), findsNothing);
    });
  });

  group('KitsuMediaRow', () {
    testWidgets('keeps a title Kitsu maps to no MyAnimeList page', (tester) async {
      HomeSectionCache.clear();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: KitsuMediaRow(
            cacheKey: 'test:unmapped',
            title: 'Row',
            isAnime: true,
            cardWidth: 100,
            cardHeight: 150,
            load: () async => const [
              KitsuMedia(id: 1, isAnime: true, title: 'Mapped', malId: 5),
              KitsuMedia(id: 2, isAnime: true, title: 'Unmapped'),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(KitsuMediaTile), findsNWidgets(2));
      expect(find.text('Unmapped'), findsOneWidget);
    });
  });
}
