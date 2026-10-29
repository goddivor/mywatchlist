import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_media_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_entry_editor.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_entry.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_format.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import '../../helpers/no_network.dart';

// Trimmed from the anonymous answer of graphql.anilist.co for Frieren (id 154587,
// docs/anilist-report-2026-10-28.md), pictures removed so no test loads an image.
Map<String, dynamic> _media({Map<String, dynamic>? entry, bool favourite = false}) => {
      'id': 154587,
      'idMal': 52991,
      'type': 'ANIME',
      'format': 'TV',
      'status': 'RELEASING',
      'siteUrl': 'https://anilist.co/anime/154587',
      'isAdult': false,
      'isFavourite': favourite,
      'title': {
        'romaji': 'Sousou no Frieren',
        'english': "Frieren: Beyond Journey's End",
        'native': '葬送のフリーレン',
        'userPreferred': 'Sousou no Frieren',
      },
      'synonyms': ['Frieren at the Funeral'],
      'hashtag': '#フリーレン',
      'description': '<p>The adventure is over but life goes on for an elf mage.</p>',
      'season': 'FALL',
      'seasonYear': 2023,
      'startDate': {'year': 2023, 'month': 9, 'day': 29},
      'endDate': {'year': null, 'month': null, 'day': null},
      'episodes': 28,
      'duration': 24,
      'chapters': null,
      'volumes': null,
      'source': 'MANGA',
      'countryOfOrigin': 'JP',
      'isLicensed': true,
      'genres': ['Adventure', 'Drama', 'Fantasy'],
      'weightedScore': 91,
      'meanScore': 90,
      'popularity': 494191,
      'favourites': 56450,
      'trending': 33,
      'bannerImage': null,
      'coverImage': {'extraLarge': null, 'large': null, 'color': '#bbf1a1'},
      'trailer': {'id': 'tR8YH0G67Rk', 'site': 'youtube', 'thumbnail': null},
      'nextAiringEpisode': {'episode': 8, 'airingAt': 4102444800},
      'airingSchedule': {'nodes': []},
      'rankings': [
        {'rank': 50, 'type': 'POPULAR', 'format': 'TV', 'year': null, 'season': null, 'allTime': true},
        {'rank': 1, 'type': 'RATED', 'format': 'TV', 'year': 2023, 'season': null, 'allTime': false},
        {'rank': 1, 'type': 'RATED', 'format': 'TV', 'year': null, 'season': null, 'allTime': true},
      ],
      'stats': {
        'scoreDistribution': [
          {'score': 10, 'amount': 1159},
          {'score': 90, 'amount': 70658},
          {'score': 100, 'amount': 106581},
        ],
        'statusDistribution': [
          {'status': 'CURRENT', 'amount': 74149},
          {'status': 'COMPLETED', 'amount': 305628},
        ],
      },
      'tags': [
        {'id': 1, 'name': 'Travel', 'description': 'Travels', 'category': 'Theme-Other', 'rank': 96,
          'isGeneralSpoiler': false, 'isMediaSpoiler': false, 'isAdult': false},
        {'id': 2, 'name': 'Time Skip', 'description': 'A jump', 'category': 'Theme-Other', 'rank': 80,
          'isGeneralSpoiler': false, 'isMediaSpoiler': true, 'isAdult': false},
      ],
      'externalLinks': [
        {'site': 'Crunchyroll', 'url': 'https://www.crunchyroll.com/series/GG5H5XQX4', 'type': 'STREAMING',
          'language': null, 'color': '#F88B24', 'icon': null, 'notes': null},
        {'site': 'Official Site', 'url': 'https://frieren-anime.jp/', 'type': 'INFO',
          'language': 'Japanese', 'color': null, 'icon': null, 'notes': null},
      ],
      'streamingEpisodes': [
        {'title': 'Episode 7 - Like a Fairy Tale', 'thumbnail': null, 'url': 'https://example.org/7', 'site': 'Crunchyroll'},
        {'title': 'Episode 8 - Frieren the Slayer', 'thumbnail': null, 'url': 'https://example.org/8', 'site': 'Crunchyroll'},
      ],
      'studios': {
        'edges': [
          {'isMain': true, 'node': {'id': 11, 'name': 'MADHOUSE'}},
          {'isMain': false, 'node': {'id': 48, 'name': 'Toho'}},
        ]
      },
      'staff': {
        'edges': [
          {'role': 'Director', 'node': {'id': 5, 'name': {'userPreferred': 'Keiichirou Saitou'}, 'image': {'medium': null}}},
        ]
      },
      'characters': {
        'edges': [
          {
            'role': 'MAIN',
            'node': {'id': 176754, 'name': {'userPreferred': 'Frieren'}, 'image': {'medium': null}},
            'voiceActors': [
              {'id': 119331, 'name': {'userPreferred': 'Atsumi Tanezaki'}, 'image': {'medium': null}, 'languageV2': 'Japanese'},
            ],
          },
        ]
      },
      'relations': {
        'edges': [
          {'relationType': 'SOURCE', 'node': _ref(118586, 'Sousou no Frieren', type: 'MANGA')},
          {'relationType': 'SEQUEL', 'node': _ref(182255, 'Sousou no Frieren 2nd Season')},
        ]
      },
      'recommendations': {
        'nodes': [
          {'id': 7, 'rating': 1208, 'userRating': 'NO_RATING', 'mediaRecommendation': _ref(21827, 'Violet Evergarden')},
        ]
      },
      'reviews': {'nodes': []},
      'trends': {
        'nodes': [
          {'date': 1793199600, 'trending': 303, 'averageScore': 91, 'popularity': 494191, 'inProgress': 74149, 'episode': null},
          {'date': 1793113200, 'trending': 250, 'averageScore': 91, 'popularity': 494000, 'inProgress': 74000, 'episode': null},
        ]
      },
      'mediaListEntry': entry,
    };

Map<String, dynamic> _ref(int id, String title, {String type = 'ANIME'}) => {
      'id': id,
      'type': type,
      'format': type == 'MANGA' ? 'MANGA' : 'TV',
      'status': 'FINISHED',
      'seasonYear': 2020,
      'title': {'userPreferred': title},
      'coverImage': {'large': null},
      'weightedScore': 85,
      'mediaListEntry': null,
    };

const _entry = {
  'id': 900,
  'mediaId': 154587,
  'status': 'CURRENT',
  'progress': 6,
  'progressVolumes': 0,
  'repeat': 0,
  'priority': 0,
  'private': false,
  'notes': '',
  'hiddenFromStatusLists': false,
  'scoreRaw': 85,
  'score': 8.5,
  'customLists': [],
  'advancedScores': {},
  'startedAt': {'year': 2023, 'month': 10, 'day': 1},
  'completedAt': {'year': null, 'month': null, 'day': null},
};

final _viewer = {
  'id': 1,
  'mediaListOptions': {'scoreFormat': 'POINT_10_DECIMAL', 'rowOrder': 'score', 'animeList': {}, 'mangaList': {}},
};

final _following = {
  'mediaList': [
    {
      'status': 'COMPLETED',
      'progress': 28,
      'scoreRaw': 90,
      'user': {'id': 2, 'name': 'Friend', 'avatar': {'medium': null}, 'mediaListOptions': {'scoreFormat': 'POINT_5'}},
    }
  ]
};

final _threads = {
  'pageInfo': {'hasNextPage': true},
  'threads': [
    {'id': 3, 'title': 'Episode 7 Discussion', 'replyCount': 76, 'viewCount': 1, 'likeCount': 1,
      'isSticky': false, 'isLocked': false, 'repliedAt': 1793199600, 'createdAt': 1793199600,
      'user': {'name': 'Mod', 'avatar': {'medium': null}}, 'categories': []},
  ]
};

/// An AniList client answering from the saved page; reads and writes are recorded and no
/// write ever leaves the test.
class _Fake {
  _Fake({this.entry, this.favourite = false, this.expired = false});

  final Map<String, dynamic>? entry;
  final bool favourite;
  final bool expired;
  final reads = <Map<String, dynamic>>[];
  final readAuth = <bool>[];
  final writes = <Map<String, dynamic>>[];

  http.Response _ok(Object data) => http.Response(jsonEncode({'data': data}), 200,
      headers: const {'content-type': 'application/json; charset=utf-8'});

  late final AnilistGraphql client = AnilistGraphql(
    sender: (body, {required auth}) async {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      reads.add(decoded);
      readAuth.add(auth);
      if (auth && expired) return null;
      final q = decoded['query'] as String;
      if (q.contains('media: Media(')) {
        return _ok({
          'media': _media(entry: auth ? entry : null, favourite: auth && favourite),
          if (q.contains('viewer:')) 'viewer': _viewer,
          if (q.contains('following:')) 'following': _following,
          if (q.contains('threads:')) 'threads': _threads,
        });
      }
      if (q.contains('characters(page')) {
        return _ok({
          'Media': {
            'characters': {
              'pageInfo': {'hasNextPage': false},
              'edges': (_media()['characters'] as Map)['edges'],
            }
          }
        });
      }
      if (q.contains('recommendations(page')) {
        return _ok({
          'Media': {
            'recommendations': {
              'pageInfo': {'hasNextPage': false},
              'nodes': (_media()['recommendations'] as Map)['nodes'],
            }
          }
        });
      }
      throw StateError('Unexpected read: $q');
    },
    mutationSender: (body, {required auth}) async {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      writes.add(decoded);
      final q = decoded['query'] as String;
      if (q.contains('SaveMediaListEntry')) {
        final v = decoded['variables'] as Map<String, dynamic>;
        return _ok({
          'SaveMediaListEntry': {..._entry, 'progress': v['progress'], 'status': v['status'] ?? 'CURRENT'}
        });
      }
      if (q.contains('ToggleFavourite')) return _ok({'ToggleFavourite': {'__typename': 'Favourites'}});
      if (q.contains('SaveRecommendation')) {
        return _ok({'SaveRecommendation': {'id': 7, 'rating': 1209, 'userRating': 'RATE_UP'}});
      }
      throw StateError('Unexpected write: $q');
    },
  );

  AnilistMediaDetailService service({bool signedIn = false}) =>
      AnilistMediaDetailService(client: client, signedIn: signedIn);
}

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await initializeDateFormatting('en');
    await S.load(const Locale('en'));
  });

  group('AnilistMediaDetailService', () {
    test('reads the whole page anonymously in one request', () async {
      final fake = _Fake();
      final d = (await fake.service().detail(154587))!;
      expect(fake.reads, hasLength(1));
      expect(fake.readAuth.single, false);
      final query = fake.reads.single['query'] as String;
      expect(query, contains('threads:'));
      expect(query, isNot(contains('viewer:')));
      expect(d.title, 'Sousou no Frieren');
      expect(d.malId, 52991);
      expect(d.weightedScore, 91);
      expect(d.meanScore, 90);
      expect(d.startDate, '2023-09-29');
      expect(d.endDate, isNull);
      expect(d.tags.where((t) => t.spoiler).single.name, 'Time Skip');
      expect(d.links.first.streaming, isTrue);
      expect(d.studios.where((s) => s.main).single.name, 'MADHOUSE');
      expect(d.characters.single.voiceActors.single.language, 'Japanese');
      expect(d.entry, isNull);
      expect(d.threads.single.replyCount, 76);
      expect(d.moreThreads, isTrue);
    });

    test('top rankings are all time first, one rated and one popular', () async {
      final d = (await _Fake().service().detail(154587))!;
      final top = d.topRankings;
      expect(top.map((r) => (r.type, r.rank, r.allTime)), [('RATED', 1, true), ('POPULAR', 50, true)]);
      expect(AnilistMediaFormat.ranking(top.first), '#1 Highest rated all time');
      expect(AnilistMediaFormat.ranking(d.rankings[1]), '#1 Highest rated 2023');
    });

    test('relations put sequels before the source', () async {
      final d = (await _Fake().service().detail(154587))!;
      expect(d.sortedRelations.map((r) => r.type), ['SEQUEL', 'SOURCE']);
      expect(d.sortedRelations.last.media.category, 'manga');
    });

    test('signed in, the same request adds the entry, settings and followed users', () async {
      final fake = _Fake(entry: _entry, favourite: true);
      final d = (await fake.service(signedIn: true).detail(154587))!;
      expect(fake.reads, hasLength(1));
      expect(fake.readAuth.single, true);
      expect(d.entry!.scoreRaw, 85);
      expect(d.entry!.progress, 6);
      expect(d.isFavourite, isTrue);
      expect(d.listOptions!.scoreFormat, AnilistScoreFormat.point10Decimal);
      expect(d.following.single.scoreFormat, AnilistScoreFormat.point5);
      expect(d.following.single.scoreRaw, 90);
      // Episode 8 airs next, the user saw 6: one behind, and episode 7 is the next to watch.
      expect(d.behind, 1);
      expect(d.continueEpisode!.number, 7);
    });

    test('a dead session still shows the public page', () async {
      final fake = _Fake(entry: _entry, expired: true);
      final d = await fake.service(signedIn: true).detail(154587);
      expect(d, isNotNull);
      expect(fake.readAuth, [true, false]);
      expect(d!.entry, isNull);
    });

    test('keeps the page ten minutes', () async {
      final fake = _Fake();
      final service = fake.service();
      await service.detail(154587);
      await service.detail(154587);
      expect(fake.reads, hasLength(1));
      await service.detail(154587, force: true);
      expect(fake.reads, hasLength(2));
    });
  });

  group('rules', () {
    final today = DateTime(2026, 10, 29);
    AnilistListEntry entry(String status, int progress, {String? completed, int repeat = 0}) =>
        AnilistListEntry(
          entryId: 1,
          mediaId: 2,
          category: 'anime',
          status: status,
          progress: progress,
          repeat: repeat,
          scoreRaw: 75,
          completedAt: completed,
        );

    test('+1 sends the progress alone, never the score', () {
      final vars = anilistPlusOne(entry('CURRENT', 3), total: 12, today: today).toVariables();
      expect(vars['progress'], 4);
      expect(vars.containsKey('score'), isFalse);
      expect(vars.containsKey('scoreRaw'), isFalse);
      expect(vars.containsKey('status'), isFalse);
    });

    test('+1 on a planned title starts it; the last episode completes it', () {
      final start = anilistPlusOne(entry('PLANNING', 0), total: 12, today: today).toVariables();
      expect(start['status'], 'CURRENT');
      expect(start['startedAt'], isNotNull);
      final last = anilistPlusOne(entry('REPEATING', 11, repeat: 1), total: 12, today: today).toVariables();
      expect(last['status'], 'COMPLETED');
      expect(last['repeat'], 2);
      expect(last['completedAt'], isNotNull);
    });

    test('a vote moves the rating by the difference', () {
      const r = AnilistRecommendation(
        id: 1,
        rating: 10,
        media: AnilistTitleRef(id: 3, category: 'anime', title: 'x'),
        userRating: AnilistRecommendationVote.down,
      );
      expect(r.voted(AnilistRecommendationVote.up).rating, 12);
      expect(r.voted(AnilistRecommendationVote.none).rating, 11);
    });

    test('scores and countdowns', () {
      expect(AnilistMediaFormat.percent(82), '82%');
      expect(AnilistMediaFormat.countdown(DateTime(2026, 1, 3, 5), now: DateTime(2026, 1, 1, 2)), '2d 3h');
      expect(AnilistMediaFormat.countdown(DateTime(2026), now: DateTime(2026, 1, 2)), isNull);
      expect(AnilistMediaFormat.date('2023-09'), 'Sep 2023');
    });
  });

  group('page', () {
    Future<void> pumpPage(WidgetTester tester, _Fake fake,
        {bool signedIn = false, AnilistListWrite? write}) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(AnilistMediaPage(
        id: 154587,
        service: fake.service(signedIn: signedIn),
        actions: AnilistActions(client: fake.client),
        social: AnilistSocialService(client: fake.client, signedIn: signedIn),
        write: write ?? AnilistListWrite(client: fake.client),
        lists: AnilistListService(client: fake.client),
        clock: () => DateTime(2026, 10, 29),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('shows AniList scores, labels, rankings and tabs', (tester) async {
      await pumpPage(tester, _Fake());
      expect(find.text('Sousou no Frieren'), findsWidgets);
      expect(find.text('91%'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('#1 Highest rated all time'), findsOneWidget);
      expect(find.text('Ep 8 in ' '${AnilistMediaFormat.countdown(DateTime.fromMillisecondsSinceEpoch(4102444800 * 1000, isUtc: true))}'),
          findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Relations'), findsOneWidget);
      expect(find.text('Add to list'), findsOneWidget);
      // Spoiler tags stay hidden until asked.
      expect(find.textContaining('Travel'), findsOneWidget);
      expect(find.textContaining('Time Skip'), findsNothing);
      await tester.tap(find.text('Show spoilers'));
      await tester.pump();
      expect(find.textContaining('Time Skip'), findsOneWidget);
    });

    testWidgets('signed in: entry card, followed users, and +1 writes the progress only', (tester) async {
      final fake = _Fake(entry: _entry);
      await pumpPage(tester, fake, signedIn: true);
      expect(find.text('6 / 28'), findsOneWidget);
      expect(find.text('8.5'), findsOneWidget);
      expect(find.text('Continue watching'), findsOneWidget);
      expect(fake.writes, isEmpty);

      await tester.tap(find.byTooltip('Add one'));
      await tester.pumpAndSettle();
      final save = fake.writes.single;
      expect(save['query'], contains('SaveMediaListEntry'));
      expect((save['variables'] as Map)['progress'], 7);
      expect((save['variables'] as Map).containsKey('scoreRaw'), isFalse);
      expect(find.text('7 / 28'), findsOneWidget);

      await tester.tap(find.text('Social'));
      await tester.pumpAndSettle();
      expect(find.text('Friend'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsWidgets);
      expect(find.text('Episode 7 Discussion'), findsOneWidget);
    });

    testWidgets('favourite and recommendation vote are written only on tap', (tester) async {
      final fake = _Fake(entry: _entry);
      await pumpPage(tester, fake, signedIn: true);
      expect(fake.writes, isEmpty);
      await tester.tap(find.byTooltip('Add to favourites'));
      await tester.pumpAndSettle();
      expect(fake.writes.single['query'], contains('animeId'));
      expect(find.byTooltip('Remove from favourites'), findsOneWidget);

      await tester.tap(find.text('Relations'));
      await tester.pumpAndSettle();
      expect(find.text('Violet Evergarden'), findsWidgets);
      await tester.tap(find.byTooltip('Good recommendation').first);
      await tester.pumpAndSettle();
      final vote = fake.writes.last;
      expect(vote['query'], contains('SaveRecommendation'));
      expect((vote['variables'] as Map)['recId'], 21827);
      expect((vote['variables'] as Map)['rating'], 'RATE_UP');
      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    });

    testWidgets('signed out: a write asks to sign in and sends nothing', (tester) async {
      final fake = _Fake();
      await pumpPage(tester, fake);
      await tester.tap(find.byTooltip('Add to favourites'));
      await tester.pumpAndSettle();
      expect(fake.writes, isEmpty);
    });

    testWidgets('the editor result replaces the entry', (tester) async {
      final fake = _Fake(entry: _entry);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      AnilistEditTarget? opened;
      await tester.pumpWidget(_app(AnilistMediaPage(
        id: 154587,
        service: fake.service(signedIn: true),
        social: AnilistSocialService(client: fake.client, signedIn: true),
        lists: AnilistListService(client: fake.client),
        editor: (context, target) async {
          opened = target;
          return AnilistEditSaved(AnilistListEntry.fromJson(
              {..._entry, 'status': 'COMPLETED', 'progress': 28}, category: 'anime', mediaId: 154587));
        },
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(opened!.total, 28);
      expect(opened!.entry!.scoreRaw, 85);
      expect(find.text('28 / 28'), findsOneWidget);
      expect(fake.writes, isEmpty);
    });
  });

  group('entry points', () {
    testWidgets('openAnilistTitle and the list adapter open the native page, mapped or not',
        (tester) async {
      final fake = _Fake();
      final previous = AnilistMediaDetailService.instance;
      AnilistMediaDetailService.instance = fake.service();
      addTearDown(() => AnilistMediaDetailService.instance = previous);
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Column(
          children: [
            TextButton(
              onPressed: () => openAnilistTitle(context, category: 'anime', id: 154587),
              child: const Text('title'),
            ),
            TextButton(
              onPressed: () => AnilistUserListAdapter().open(
                  context, const ListEntryView(id: 154587, malId: 52991, category: 'anime', title: 'Row')),
              child: const Text('row'),
            ),
          ],
        ),
      )));
      await tester.tap(find.text('title'));
      await tester.pumpAndSettle();
      expect(find.byType(AnilistMediaPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(AnilistMediaPage))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('row'));
      await tester.pumpAndSettle();
      expect(find.byType(AnilistMediaPage), findsOneWidget);
    });

    test('anilist.co title links go to the native page', () {
      expect(parseAnilistLink('https://anilist.co/anime/154587/Sousou-no-Frieren'),
          const AnilistLink(AnilistLinkKind.anime, id: 154587));
    });
  });
}
