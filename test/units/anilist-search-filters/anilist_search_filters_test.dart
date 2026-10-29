import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_catalog.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_browse_screen.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_result_tiles.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';

const _dir = 'test/units/anilist-search-filters/fixtures';

Map<String, dynamic> fixture(String name) =>
    json.decode(File('$_dir/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// One request seen by the fake AniList.
class Sent {
  final String query;
  final Map<String, dynamic> variables;
  final bool auth;
  Sent(this.query, this.variables, this.auth);
}

http.Response utf8Json(Object? body) => http.Response.bytes(utf8.encode(json.encode(body)), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

/// A fake AniList: [answer] builds the body of each request.
AnilistGraphql fakeGql(List<Sent> log, Object? Function(Sent) answer) =>
    AnilistGraphql(sender: (body, {required auth}) async {
      final decoded = json.decode(body) as Map<String, dynamic>;
      final sent = Sent(decoded['query'] as String,
          (decoded['variables'] as Map?)?.cast<String, dynamic>() ?? const {}, auth);
      log.add(sent);
      final a = answer(sent);
      if (a is http.Response) return a;
      return utf8Json(a);
    });

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('AnilistMediaQuery', () {
    test('turns every filter into Page.media arguments, bounds made strict', () {
      const q = AnilistMediaQuery(
        category: 'anime',
        sort: 'SCORE_DESC',
        search: ' frieren ',
        season: 'FALL',
        seasonYear: 2023,
        status: 'RELEASING',
        statuses: ['FINISHED'],
        formats: ['TV', 'ONA'],
        country: 'JP',
        countries: ['KR'],
        genre: 'Action',
        genres: ['Drama'],
        genresExcluded: ['Romance'],
        tag: 'Time Skip',
        tagsExcluded: ['Isekai'],
        tagCategories: ['Theme-Fantasy'],
        minimumTagRank: 60,
        sources: ['MANGA'],
        isLicensed: true,
        licensedByIds: [5, 10],
        years: AnilistRange(min: 2015, max: 2020),
        episodes: AnilistRange(min: 12, max: 26),
        duration: AnilistRange(max: 30),
        chapters: AnilistRange(min: 10),
        score: AnilistRange(min: 80),
        popularityMin: 50000,
        onList: false,
      );
      final v = q.variables(adultAllowed: false, signedIn: true);
      expect(v, {
        'type': 'ANIME',
        'sort': ['SCORE_DESC'],
        'search': 'frieren',
        'season': 'FALL',
        'seasonYear': 2023,
        'status_in': ['RELEASING', 'FINISHED'],
        'format_in': ['TV', 'ONA'],
        'countryOfOrigin_in': ['JP', 'KR'],
        'genre_in': ['Action', 'Drama'],
        'genre_not_in': ['Romance'],
        'tag_in': ['Time Skip'],
        'tag_not_in': ['Isekai'],
        'tagCategory_in': ['Theme-Fantasy'],
        'minimumTagRank': 60,
        'source_in': ['MANGA'],
        'isLicensed': true,
        'licensedById_in': [5, 10],
        'startDate_greater': 20149999,
        'startDate_lesser': 20210000,
        'popularity_greater': 49999,
        'onList': false,
        'episodes_greater': 11,
        'episodes_lesser': 27,
        'duration_lesser': 31,
        // Chapters do not apply to anime.
        'weightedScore_greater': 79,
        'isAdult': false,
      });
      // Every variable sent is declared and used.
      for (final name in v.keys) {
        expect(AnilistMediaQuery.gqlDeclarations, contains('\$$name:'));
        expect(AnilistMediaQuery.gqlArguments, contains('\$$name'));
      }
      expect(q.filterCount, 19);
    });

    test('adult: hidden unless allowed, then any, only or none', () {
      const q = AnilistMediaQuery(category: 'manga');
      expect(q.variables(adultAllowed: false)['isAdult'], false);
      expect(q.variables(adultAllowed: true).containsKey('isAdult'), isFalse);
      expect(q.copyWith(adult: true).variables(adultAllowed: true)['isAdult'], true);
      expect(q.copyWith(adult: true).variables(adultAllowed: false)['isAdult'], false);
      expect(q.copyWith(adult: false).variables(adultAllowed: true)['isAdult'], false);
      // onList needs a session.
      expect(q.copyWith(onList: true).variables(adultAllowed: true).containsKey('onList'), isFalse);
    });

    test('search match without a text sorts by popularity', () {
      const q = AnilistMediaQuery(category: 'anime', sort: 'SEARCH_MATCH');
      expect(q.variables(adultAllowed: true)['sort'], ['POPULARITY_DESC']);
      expect(q.copyWith(search: 'x').variables(adultAllowed: true)['sort'], ['SEARCH_MATCH']);
    });

    test('copyWith clears with an explicit null and keeps otherwise', () {
      const q = AnilistMediaQuery(category: 'anime', genre: 'Action', season: 'FALL', seasonYear: 2024);
      expect(q.copyWith(sort: 'SCORE_DESC').genre, 'Action');
      expect(q.copyWith(genre: null).genre, isNull);
      expect(q.copyWith(season: null).seasonYear, 2024);
      expect(q.copyWith(search: 'a') == q.copyWith(search: 'a'), isTrue);
      expect(q.copyWith(search: 'a').key == q.key, isFalse);
    });

    test('forCategory drops what only the other type has', () {
      const q = AnilistMediaQuery(
        category: 'anime',
        sort: 'EPISODES_DESC',
        formats: ['TV'],
        season: 'FALL',
        seasonYear: 2024,
        episodes: AnilistRange(min: 1),
        licensedByIds: [5],
        genres: ['Drama'],
      );
      final m = q.forCategory('manga');
      expect(m.category, 'manga');
      expect(m.formats, isEmpty);
      expect(m.season, isNull);
      expect(m.episodes.isOpen, isTrue);
      expect(m.licensedByIds, isEmpty);
      expect(m.genres, ['Drama']);
      expect(m.sort, 'POPULARITY_DESC');
      expect(q.forCategory('anime'), same(q));
    });

    test('36 sorts plus search match, per category', () {
      expect(AnilistSorts.all.length, 37);
      expect(AnilistSorts.all.where((s) => s != 'SEARCH_MATCH').length, 36);
      expect(AnilistSorts.keysFor('anime'), isNot(contains('CHAPTERS')));
      expect(AnilistSorts.keysFor('manga'), containsAll(['CHAPTERS', 'VOLUMES']));
      expect(AnilistSorts.keysFor('manga'), isNot(contains('EPISODES')));
      expect(AnilistSorts.keyOf('START_DATE_DESC'), 'START_DATE');
      expect(AnilistSorts.of('SCORE', descending: false), 'SCORE');
      expect(AnilistSorts.of('SEARCH_MATCH', descending: true), 'SEARCH_MATCH');
    });
  });

  group('AnilistDiscoverService', () {
    test('search parses a saved answer, public when signed out', () async {
      final log = <Sent>[];
      final service = AnilistDiscoverService(
        client: fakeGql(log, (_) => fixture('media')),
        titleLang: () => 'en',
        signedIn: () => false,
        appAdult: () => false,
      );
      final page = await service.search(const AnilistMediaQuery(category: 'anime', sort: 'SCORE_DESC'));
      expect(log.single.auth, isFalse);
      expect(log.single.query, isNot(contains('mediaListEntry')));
      expect(log.single.variables['isAdult'], false);
      expect(page.hasNext, isTrue);
      final frieren = page.items.first;
      expect(frieren.id, 154587);
      expect(frieren.media.title, 'Frieren: Beyond Journey’s End');
      expect(frieren.score, 91);
      expect(frieren.duration, 24);
      expect(frieren.startYear, 2023);
      expect(frieren.media.popularity, 494191);
      expect(frieren.entry, isNull);
      expect(anilistTypeLine(frieren), 'TV · 28 eps · 2023');
    });

    test('signed in: the token, the list entry and the account adult option', () async {
      final log = <Sent>[];
      final service = AnilistDiscoverService(
        client: fakeGql(log, (sent) {
          if (sent.query.contains('Viewer')) {
            return {
              'data': {
                'Viewer': {
                  'options': {'displayAdultContent': true},
                },
              },
            };
          }
          final m = Map<String, dynamic>.from((fixture('media')['data']['Page']['media'] as List).first as Map);
          m['mediaListEntry'] = {
            'id': 77,
            'status': 'CURRENT',
            'progress': 3,
            'score': 8.5,
            'startedAt': {'year': 2024, 'month': 1, 'day': 2},
            'completedAt': {'year': null, 'month': null, 'day': null},
          };
          return {
            'data': {
              'Page': {
                'pageInfo': {'hasNextPage': false},
                'media': [m],
              },
            },
          };
        }),
        signedIn: () => true,
        appAdult: () => false,
      );
      final page = await service.search(const AnilistMediaQuery(category: 'anime', onList: true));
      await service.search(const AnilistMediaQuery(category: 'anime'));
      // One Viewer read for both searches.
      expect(log.where((s) => s.query.contains('Viewer')).length, 1);
      final search = log.where((s) => !s.query.contains('Viewer')).first;
      expect(search.auth, isTrue);
      expect(search.query, contains('mediaListEntry'));
      expect(search.variables['onList'], true);
      // The account shows adult titles: nothing hides them.
      expect(search.variables.containsKey('isAdult'), isFalse);
      final entry = page.items.single.entry!;
      expect(entry.status, 'CURRENT');
      expect(entry.id, 77);
    });

    test('a dead session falls back to a public search', () async {
      final log = <Sent>[];
      final service = AnilistDiscoverService(
        client: AnilistGraphql(sender: (body, {required auth}) async {
          log.add(Sent(body, const {}, auth));
          if (auth) return null;
          return utf8Json(fixture('media'));
        }),
        signedIn: () => true,
        appAdult: () => false,
      );
      final page = await service.search(const AnilistMediaQuery(category: 'anime'));
      expect(page.items, hasLength(3));
      expect(log.last.auth, isFalse);
      // With onList the public search cannot answer: the error stays.
      expect(service.search(const AnilistMediaQuery(category: 'anime', onList: true)),
          throwsA(isA<AnilistSessionExpired>()));
    });

    test('people: characters, staff, studios and users', () async {
      final people = fixture('people')['data'] as Map<String, dynamic>;
      final log = <Sent>[];
      final service = AnilistDiscoverService(
        client: fakeGql(log, (sent) {
          final alias = sent.query.contains('characters(')
              ? 'c'
              : sent.query.contains('staff(')
                  ? 's'
                  : sent.query.contains('studios(')
                      ? 'st'
                      : 'u';
          return {
            'data': {'Page': people[alias]},
          };
        }),
        signedIn: () => false,
      );
      final c = await service.people(AnilistSearchKind.characters, 'frieren');
      expect(c.items.single.name, 'Frieren');
      expect(c.items.single.nativeName, 'フリーレン');
      expect(c.items.single.favourites, 22574);
      expect(c.items.single.url, 'https://anilist.co/character/176754');
      expect(log.last.variables['sort'], ['SEARCH_MATCH']);
      expect(log.last.query, contains('[CharacterSort]'));

      final s = await service.people(AnilistSearchKind.staff, 'tanezaki');
      expect(s.items.single.detail, 'Voice Actor, Vocalist');

      final st = await service.people(AnilistSearchKind.studios, '');
      expect(st.items.single.name, 'MADHOUSE');
      expect(st.items.single.detail, 'DEATH NOTE');
      expect(log.last.variables['sort'], ['FAVOURITES_DESC']);
      expect(log.last.variables.containsKey('search'), isFalse);

      final u = await service.people(AnilistSearchKind.users, '');
      expect(u.items.map((h) => h.name), ['joshjoshjoshjosh', 'joshjoshjosh']);
      expect(u.hasNext, isTrue);
      expect(log.last.variables['sort'], ['WATCHED_TIME_DESC']);
    });

    test('rows keep the old behaviour: app NSFW switch when signed out', () async {
      final log = <Sent>[];
      final service = AnilistDiscoverService(
        client: fakeGql(log, (_) => fixture('media')),
        signedIn: () => false,
        appAdult: () => true,
      );
      final page = await service.media(const AnilistMediaQuery(category: 'anime', genre: 'Drama'));
      expect(page.items, hasLength(3));
      expect(log.single.variables['genre_in'], ['Drama']);
      expect(log.single.variables.containsKey('isAdult'), isFalse);
    });
  });

  group('AnilistCatalog', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('one batched request, kept a day in memory and on the device', () async {
      final log = <Sent>[];
      var now = DateTime(2026, 10, 29, 12);
      AnilistCatalog make() => AnilistCatalog(
            client: fakeGql(log, (_) => fixture('catalog')),
            clock: () => now,
          );
      final catalog = make();
      final data = await catalog.load();
      expect(log, hasLength(1));
      expect(log.single.query, contains('GenreCollection'));
      expect(log.single.query, contains('MediaTagCollection'));
      expect(log.single.query, contains('mediaType: MANGA'));
      expect(data.genres, contains('Hentai'));
      expect(data.genresFor(adult: false), isNot(contains('Hentai')));
      expect(data.genresFor(adult: false), hasLength(18));
      expect(data.tagsFor(adult: false).any((t) => t.isAdult), isFalse);
      expect(data.tags.any((t) => t.isAdult), isTrue);
      expect(data.animeSources.map((s) => s.site), ['Crunchyroll', 'HIDIVE', 'Netflix']);
      expect(data.mangaSources.map((s) => s.label), contains('Bomtoon (Korean)'));
      expect(data.tagNamed('Isekai')?.category, isNotEmpty);

      await catalog.load();
      expect(log, hasLength(1));

      // A new instance (next launch) reads the device copy.
      final again = await make().load();
      expect(log, hasLength(1));
      expect(again.tags.length, data.tags.length);

      // A day later it asks again.
      now = now.add(const Duration(days: 1, minutes: 1));
      await make().load();
      expect(log, hasLength(2));
    });

    test('a failure serves the last copy, else the built-in genres', () async {
      final failing = AnilistCatalog(
        client: AnilistGraphql(sender: (_, {required auth}) async => http.Response('nope', 500)),
      );
      final fallback = await failing.load();
      expect(fallback.isFallback, isTrue);
      expect(fallback.genres, AnilistDiscoverService.genres);
      expect(fallback.tags, isEmpty);

      final old = DateTime(2026, 10, 1);
      final ok = AnilistCatalog(client: fakeGql([], (_) => fixture('catalog')), clock: () => old);
      await ok.load();
      final stale = await AnilistCatalog(
        client: AnilistGraphql(sender: (_, {required auth}) async => http.Response('nope', 500)),
      ).load();
      expect(stale.isFallback, isFalse);
      expect(stale.tags, isNotEmpty);
    });
  });

  group('active filters', () {
    test('one chip per filter, each removing only itself', () {
      const q = AnilistMediaQuery(
        category: 'anime',
        formats: ['TV'],
        genre: 'Action',
        genresExcluded: ['Romance'],
        tags: ['Isekai'],
        years: AnilistRange(min: 2015, max: 2020),
        score: AnilistRange(min: 70),
        onList: false,
        licensedByIds: [5],
      );
      final chips = activeAnilistFilters(q);
      expect(chips.map((c) => c.label), [
        'TV',
        'Action',
        'Not Romance',
        'Isekai',
        '#5',
        'Year 2015-2020',
        'Score 70+',
        'Not on my list',
      ]);
      final noAction = chips[1].remove();
      expect(noAction.allGenres, isEmpty);
      expect(noAction.genresExcluded, ['Romance']);
      expect(chips[5].remove().years.isOpen, isTrue);
      expect(chips.last.remove().onList, isNull);
      expect(chips.last.remove().filterCount, q.filterCount - 1);
    });

    test('saved editor entry becomes the row entry', () {
      final e = anilistEntryOf(
        const SyncEntry(status: 'on_hold', score: 7.5, progress: 4, entryId: '12', startDate: '2024-01-02'),
      )!;
      expect(e.status, 'PAUSED');
      expect(e.id, 12);
      expect(e.json['startedAt'], {'year': 2024, 'month': 1, 'day': 2});
    });
  });

  group('AnilistBrowseScreen', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Map<String, dynamic> page(List<Map<String, dynamic>> media) => {
          'data': {
            'Page': {
              'pageInfo': {'hasNextPage': false},
              'media': media,
            },
          },
        };
    Map<String, dynamic> title(int id, String name) => {
          'id': id,
          'type': 'ANIME',
          'format': 'TV',
          'episodes': 12,
          'weightedScore': 72,
          'popularity': 1500,
          'title': {'romaji': name},
        };

    testWidgets('search: rows, filter bar, kinds', (tester) async {
      final log = <Sent>[];
      final gql = fakeGql(log, (sent) {
        if (sent.query.contains('characters(')) {
          return {
            'data': {
              'Page': {
                'pageInfo': {'hasNextPage': false},
                'characters': [
                  {
                    'id': 1,
                    'name': {'userPreferred': 'Frieren'},
                    'favourites': 10,
                  },
                ],
              },
            },
          };
        }
        if (sent.query.contains('GenreCollection')) return http.Response('no', 500);
        return page([title(1, 'First show'), title(2, 'Second show')]);
      });
      final service = AnilistDiscoverService(client: gql, signedIn: () => false, appAdult: () => false);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: AnilistBrowseScreen(
          title: '',
          query: const AnilistMediaQuery(category: 'anime', sort: 'SEARCH_MATCH', genre: 'Drama'),
          searchable: true,
          service: service,
          catalog: AnilistCatalog(client: gql),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('First show'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('72%'), findsNWidgets(2));
      expect(find.text('TV · 12 eps'), findsNWidgets(2));
      // Signed out: no pencil.
      expect(find.byIcon(Icons.edit_rounded), findsNothing);
      // Filter bar: filters, sort (popularity: no text yet), the genre chip.
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Popularity'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
      final search = log.lastWhere((s) => s.query.contains('media('));
      expect(search.variables['genre_in'], ['Drama']);

      // Removing the genre chip searches again without it.
      await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'Drama'), matching: find.byType(Icon)));
      await tester.pumpAndSettle();
      expect(log.lastWhere((s) => s.query.contains('media(')).variables.containsKey('genre_in'), isFalse);

      await tester.tap(find.text('Characters'));
      await tester.pumpAndSettle();
      expect(find.text('Frieren'), findsOneWidget);
      expect(find.text('Filters'), findsNothing);
    });
  });
}
