import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_other_list_page.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_follow_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_profile_view.dart';
import 'package:mywatchlist/widgets/Anilist/profile/other_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_colors.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_favourites.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_find_user.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';

// Shapes trimmed from anonymous answers of graphql.anilist.co (2026-10-29). Every client here
// is a fake: no test reaches AniList, and no write goes anywhere but a recording list.

http.Response _json(Object data) => http.Response(jsonEncode({'data': data}), 200,
    headers: const {'content-type': 'application/json; charset=utf-8'});

AnilistGraphql _client(
  Map<String, dynamic> Function(String query, Map<String, dynamic> vars) answer, {
  List<Map<String, dynamic>>? reads,
  List<Map<String, dynamic>>? writes,
}) =>
    AnilistGraphql(
      sender: (body, {required auth}) async {
        final d = jsonDecode(body) as Map<String, dynamic>;
        reads?.add(d);
        return _json(answer(d['query'] as String, (d['variables'] as Map?)?.cast() ?? {}));
      },
      mutationSender: (body, {required auth}) async {
        final d = jsonDecode(body) as Map<String, dynamic>;
        writes?.add(d);
        return _json(answer(d['query'] as String, (d['variables'] as Map?)?.cast() ?? {}));
      },
    );

const _user = {
  'id': 7,
  'name': 'befalt',
  'avatar': {'large': 'https://x/a.png'},
  'isFollowing': false,
  'isFollower': true,
};

class _FakeProfile extends AnilistProfileService {
  _FakeProfile() : super(signedIn: true);
  final List<List<int>> saved = [];

  @override
  Future<AnilistProfile> load({
    String? username,
    bool force = false,
    Duration maxAge = const Duration(minutes: 5),
  }) async =>
      AnilistProfile(
        data: UserProfileData(id: 7, username: username ?? 'Me'),
        profileColor: 'purple',
        donatorBadge: 'Donator',
        moderatorRoles: const ['FORUM_MOD'],
        previousNames: const ['old'],
        favorites: const AnilistFavorites(
          anime: [AnilistFavorite(id: 1, title: 'A', url: 'https://anilist.co/anime/1')],
        ),
      );

  @override
  Future<List<AnilistActivityDay>> loadActivityHistory(int userId) async => [
        AnilistActivityDay(DateTime.now().toUtc(), 3, 4),
      ];

  @override
  Future<List<AnilistRankedStat>> loadRanked(
          String username, String category, AnilistStatsPart part) async =>
      const [AnilistRankedStat(name: 'Madhouse', count: 5, mean: 7.5, minutes: 600)];

  @override
  Future<AnilistStatsOverview> loadStatsOverview(String username, String category) async =>
      const AnilistStatsOverview();

  @override
  Future<AnilistFavouritePage> loadFavourites(String username, AnilistFavouriteKind kind,
          {int page = 1, int perPage = 50}) async =>
      const AnilistFavouritePage([
        AnilistFavorite(id: 1, title: 'One', url: 'u1'),
        AnilistFavorite(id: 2, title: 'Two', url: 'u2'),
        AnilistFavorite(id: 3, title: 'Three', url: 'u3'),
      ], hasNext: false);

  @override
  Future<void> saveFavouriteOrder(AnilistFavouriteKind kind, List<int> ids) async =>
      saved.add(ids);
}

class _FakeFollow extends AnilistFollowService {
  _FakeFollow() : super(signedIn: true);
  final List<int> toggled = [];
  final List<String> messages = [];

  @override
  Future<({int? followers, int? following})> counts(int userId) async =>
      (followers: 539, following: 100);

  @override
  Future<AnilistFollowState> toggleFollow(int userId) async {
    toggled.add(userId);
    return const AnilistFollowState(isFollowing: true, isFollower: true);
  }

  @override
  Future<AnilistUserPageResult> users(int userId, AnilistSocialList list,
          {int page = 1, int perPage = 30, bool self = false}) async =>
      const AnilistUserPageResult([
        AnilistUserRow(id: 9, name: 'friend', isFollower: true),
      ], hasNext: false);

  @override
  Future<AnilistUserPageResult> searchUsers(String search, {int page = 1, int perPage = 30}) async =>
      AnilistUserPageResult([AnilistUserRow(id: 3, name: '${search}er')], hasNext: false);

  @override
  Future<int> sendMessage(int recipientId, String message, {bool private = false}) async {
    messages.add('$recipientId:$message');
    return 1;
  }
}

Future<PreferencesBloc> _bloc() async {
  SharedPreferences.setMockInitialValues({});
  return PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
}

Widget _app(PreferencesBloc bloc, Widget home) => BlocProvider.value(
      value: bloc,
      child: MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        locale: const Locale('en'),
        home: home,
      ),
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await initializeDateFormatting('en');
    await S.load(const Locale('en'));
  });

  group('parsing', () {
    test('profile extras: colour, badge, roles, follow flags, score format', () {
      final p = AnilistProfileService.parseProfile({
        'id': 1,
        'name': 'me',
        'options': {'profileColor': 'green'},
        'mediaListOptions': {'scoreFormat': 'POINT_5'},
        'donatorBadge': 'Supporter',
        'donatorTier': 3,
        'moderatorRoles': ['ADMIN', ''],
        'previousNames': ['older'],
        'isFollowing': true,
        'isFollower': true,
        'statistics': {
          'anime': {
            'count': 2,
            'scores': [
              {'score': 80, 'count': 2},
              {'score': 100, 'count': 1},
            ],
          },
        },
      });
      expect(p.profileColor, 'green');
      expect(p.donatorBadge, 'Supporter');
      expect(p.donatorTier, 3);
      expect(p.moderatorRoles, ['ADMIN']);
      expect(p.previousNames, ['older']);
      expect(p.isFollowing && p.isFollower, isTrue);
      expect(p.scoreFormat, 'POINT_5');
      expect(p.anime.rawScores, {80: 2, 100: 1});
    });

    test('scores fold to the account score format', () {
      final raw = {20: 1, 40: 2, 100: 4};
      expect(foldScores(raw, 'POINT_5').map((b) => b.count), [1, 2, 0, 0, 4]);
      expect(foldScores({35: 1, 60: 2, 85: 3}, 'POINT_3').map((b) => b.count), [1, 2, 3]);
      final tens = foldScores({10: 1, 95: 2, 100: 1}, 'POINT_100');
      expect(tens, hasLength(10));
      expect(tens.last.count, 3);
    });

    test('statistics overview, ranked rows and activity history', () {
      final o = AnilistProfileService.parseStatsOverview({
        'standardDeviation': 22.6,
        'episodesWatched': 9000,
        'minutesWatched': 162163,
        'statuses': [
          {'status': 'PLANNING', 'count': 4, 'minutesWatched': 1440},
        ],
        'releaseYears': [
          {'releaseYear': 2025, 'count': 116, 'meanScore': 32.73},
          {'releaseYear': 2019, 'count': 5, 'meanScore': 60},
        ],
        'lengths': [
          {'length': '7-16', 'count': 414, 'meanScore': 38.92},
        ],
      }, manga: false);
      expect(o.standardDeviation, closeTo(2.26, 0.001));
      expect(o.plannedAmount, 1440);
      expect(o.releaseYears.first.label, '2019');
      expect(o.lengths.single.count, 414);

      final tags = AnilistProfileService.parseRanked({
        'tags': [
          {
            'tag': {'id': 5, 'name': 'Male Protagonist'},
            'count': 494,
            'meanScore': 44.28,
            'minutesWatched': 130376,
            'mediaIds': [20607, 151514],
          },
        ],
      }, AnilistStatsPart.tags);
      expect(tags.single.name, 'Male Protagonist');
      expect(tags.single.mean, closeTo(4.428, 0.001));
      expect(tags.single.mediaIds, [20607, 151514]);

      final vas = AnilistProfileService.parseRanked({
        'voiceActors': [
          {
            'voiceActor': {
              'id': 1,
              'name': {'userPreferred': 'Yuuki Kaji'},
              'image': {'large': 'i'},
            },
            'count': 38,
          },
        ],
      }, AnilistStatsPart.voiceActors);
      expect(vas.single.name, 'Yuuki Kaji');
      expect(vas.single.imageUrl, 'i');

      final days = AnilistProfileService.parseActivityHistory([
        {'date': 1700000000, 'amount': 2, 'level': 3},
        {'date': 'x'},
      ]);
      expect(days, hasLength(1));
      expect(days.single.level, 3);
    });

    test('profile colours', () {
      expect(anilistProfileColor('purple'), const Color(0xFFC063FF));
      expect(anilistProfileColor('#112233'), const Color(0xFF112233));
      expect(anilistProfileColor('nope'), isNull);
      expect(titleLangOf(AnilistTitleLanguage.englishStylised), 'en');
      expect(titleLangOf(AnilistTitleLanguage.native), 'ja');
      expect(titleLangOf(AnilistTitleLanguage.romaji), 'ro');
    });
  });

  group('services over a fake client', () {
    test('follow service reads counts, cuts mutuals and sends a message once', () async {
      final writes = <Map<String, dynamic>>[];
      final client = _client((q, v) {
        if (q.contains('SaveMessageActivity')) {
          return {'SaveMessageActivity': {'id': 55}};
        }
        if (q.contains('followers: Page')) {
          return {
            'followers': {'pageInfo': {'total': 539}},
            'following': {'pageInfo': {'total': 100}},
          };
        }
        final root = q.contains('following(userId') ? 'following' : 'followers';
        return {
          'Page': {
            'pageInfo': {'hasNextPage': true, 'total': 3},
            root: [
              _user,
              {..._user, 'id': 8, 'name': 'both', 'isFollowing': true},
            ],
          },
        };
      }, writes: writes);
      final service = AnilistFollowService(client: client, signedIn: true);
      final counts = await service.counts(7);
      expect((counts.followers, counts.following), (539, 100));

      // Own profile: mutuals are who you follow that follows you back.
      final own = await service.users(7, AnilistSocialList.mutual, self: true);
      expect(own.users.map((u) => u.name), ['befalt', 'both']);
      // Another profile: their followers you follow too.
      final other = await service.users(7, AnilistSocialList.mutual);
      expect(other.users.map((u) => u.name), ['both']);
      expect(other.hasNext, isTrue);

      expect(writes, isEmpty);
      expect(await service.sendMessage(7, ' hello '), 55);
      expect(writes.single['variables'], {'to': 7, 'message': 'hello', 'private': false});
      expect(() => service.sendMessage(7, '  '), throwsArgumentError);
    });

    test('profile service pages favourites and saves their order as 1..n', () async {
      final writes = <Map<String, dynamic>>[];
      final client = _client((q, v) {
        if (q.contains('UpdateFavouriteOrder')) {
          return {'UpdateFavouriteOrder': {'__typename': 'Favourites'}};
        }
        return {
          'User': {
            'favourites': {
              'characters': {
                'pageInfo': {'hasNextPage': true},
                'nodes': [
                  {'id': 4, 'name': {'userPreferred': 'Spike'}, 'image': {'large': 'i'}},
                ],
              },
            },
          },
        };
      }, writes: writes);
      final service = AnilistProfileService(client: client, signedIn: false);
      final page = await service.loadFavourites('me', AnilistFavouriteKind.character);
      expect(page.hasNext, isTrue);
      expect(page.items.single.url, 'https://anilist.co/character/4');
      await service.saveFavouriteOrder(AnilistFavouriteKind.character, [3, 1, 2]);
      expect(writes.single['query'], contains('characterIds'));
      expect(writes.single['variables'], {'ids': [3, 1, 2], 'order': [1, 2, 3]});
    });

    test("another user's list is read once, with the viewer's entries only on compare", () async {
      final reads = <Map<String, dynamic>>[];
      final client = _client((q, v) {
        if (q.contains('Viewer')) return {'Viewer': {'name': 'x'}};
        if (q.contains('mediaListEntry')) {
          return {
            'MediaListCollection': {
              'hasNextChunk': false,
              'lists': [
                {
                  'entries': [
                    {'media': {'id': 1, 'mediaListEntry': {'status': 'COMPLETED', 'progress': 12, 'score': 8.5}}},
                    {'media': {'id': 2, 'mediaListEntry': null}},
                  ],
                },
              ],
            },
          };
        }
        return {
          'MediaListCollection': {
            'hasNextChunk': false,
            'lists': [
              {
                'entries': [
                  {
                    'id': 10,
                    'status': 'COMPLETED',
                    'progress': 12,
                    'scoreRaw': 90,
                    'score': 9,
                    'media': {
                      'id': 1,
                      'type': 'ANIME',
                      'title': {'romaji': 'Cowboy Bebop', 'english': 'Cowboy Bebop'},
                      'episodes': 26,
                    },
                  },
                  {
                    'id': 11,
                    'status': 'PLANNING',
                    'progress': 0,
                    'media': {'id': 2, 'type': 'ANIME', 'title': {'romaji': 'Other'}},
                  },
                ],
              },
            ],
          },
        };
      }, reads: reads);
      final source = AnilistOtherListSource(
        username: 'someone',
        client: client,
        profiles: AnilistProfileService(client: client, signedIn: false),
        signedIn: true,
      );
      final adapter = AnilistReadOnlyListAdapter(source: source);
      final all = await adapter.fetch(category: 'anime', status: null, offset: 0, limit: 100);
      expect(all.entries.map((e) => e.id), containsAll([1, 2]));
      expect((await adapter.statusCounts('anime'))![ListEntryStatus.completed], 1);
      await adapter.fetch(category: 'anime', status: null, offset: 0, limit: 100);
      final listReads = reads.where((r) => (r['query'] as String).contains('forceSingleCompleted'));
      expect(listReads, hasLength(1), reason: 'kept for the page');

      adapter.compareFilter = AnilistCompareFilter.onMine;
      final both = await adapter.fetch(category: 'anime', status: null, offset: 0, limit: 100);
      expect(both.entries.map((e) => e.id), [1]);
      adapter.compareFilter = AnilistCompareFilter.notOnMine;
      final theirs = await adapter.fetch(category: 'anime', status: null, offset: 0, limit: 100);
      expect(theirs.entries.map((e) => e.id), [2]);

      // No write is possible from this adapter.
      expect(adapter.canStep(all.entries.first), isFalse);
      final mine = await source.mine('anime');
      final look = AnilistCompareLook(mine);
      expect(look.cardBadges(all.entries.firstWhere((e) => e.id == 1)).single.label, '8.5');
      expect(look.cardBadges(all.entries.firstWhere((e) => e.id == 2)).single.label, '-');
    });
  });

  group('profile screens (fakes only)', () {
    testWidgets("another user's profile offers follow and message; follow runs on tap only",
        (tester) async {
      final bloc = await _bloc();
      addTearDown(bloc.close);
      final follow = _FakeFollow();
      await tester.pumpWidget(_app(
        bloc,
        Scaffold(
          body: AnilistProfileView(
              username: 'Other', service: _FakeProfile(), follow: follow),
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Activity'), findsWidgets);
      expect(find.text('Social'), findsOneWidget);
      expect(find.text('Donator'), findsOneWidget);
      expect(find.text('Moderator'), findsOneWidget);
      expect(find.text('539'), findsOneWidget);
      expect(follow.toggled, isEmpty);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      await tester.pump();
      expect(follow.toggled, [7]);
      expect(find.text('Following'), findsWidgets);
    });

    testWidgets('the own profile has no follow button but edits through the settings page',
        (tester) async {
      final bloc = await _bloc();
      addTearDown(bloc.close);
      await tester.pumpWidget(_app(
        bloc,
        Scaffold(body: AnilistProfileView(service: _FakeProfile(), follow: _FakeFollow())),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Follow'), findsNothing);
      expect(find.text(S.current.Prof_Edit_Profile), findsOneWidget);
    });

    testWidgets('the Social tab lists followers and the Stats tab ranks a statistic',
        (tester) async {
      final bloc = await _bloc();
      addTearDown(bloc.close);
      await tester.pumpWidget(_app(
        bloc,
        Scaffold(
          body: AnilistProfileView(
              username: 'Other', service: _FakeProfile(), follow: _FakeFollow()),
        ),
      ));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Social'));
      await tester.pumpAndSettle();
      expect(find.text('friend'), findsOneWidget);
      expect(find.text('Follows you'), findsWidgets);

      await tester.tap(find.text(S.current.Prof_Tab_Stats));
      await tester.pumpAndSettle();
    });

    testWidgets('reordering favourites writes only when the check is tapped', (tester) async {
      final bloc = await _bloc();
      addTearDown(bloc.close);
      final profile = _FakeProfile();
      await tester.pumpWidget(_app(
        bloc,
        AnilistFavouritesPage(
            username: 'Me', kind: AnilistFavouriteKind.anime, isSelf: true, service: profile),
      ));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byTooltip('Reorder'));
      await tester.pump();
      expect(profile.saved, isEmpty);
      await tester.tap(find.byTooltip('Save order'));
      await tester.pump();
      await tester.pump();
      expect(profile.saved, [
        [1, 2, 3]
      ]);
    });

    testWidgets('finding a user searches after typing and opens nothing by itself',
        (tester) async {
      final bloc = await _bloc();
      addTearDown(bloc.close);
      await tester.pumpWidget(_app(bloc, AnilistFindUserPage(service: _FakeFollow())));
      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.text('bober'), findsOneWidget);
    });

    testWidgets("another user's list page is read only and compares on request", (tester) async {
      final bloc = await _bloc();
      addTearDown(bloc.close);
      final client = _client((q, v) {
        if (q.contains('mediaListEntry')) {
          return {
            'MediaListCollection': {
              'hasNextChunk': false,
              'lists': [
                {
                  'entries': [
                    {'media': {'id': 1, 'mediaListEntry': {'status': 'COMPLETED', 'progress': 1, 'score': 7}}},
                  ],
                },
              ],
            },
          };
        }
        return {
          'MediaListCollection': {
            'hasNextChunk': false,
            'lists': [
              {
                'entries': [
                  {
                    'id': 10,
                    'status': 'COMPLETED',
                    'progress': 1,
                    'media': {
                      'id': 1,
                      'type': 'ANIME',
                      'title': {'romaji': 'Cowboy Bebop'},
                      'episodes': 1,
                    },
                  },
                ],
              },
            ],
          },
        };
      });
      final source = AnilistOtherListSource(
        username: 'someone',
        client: client,
        profiles: AnilistProfileService(client: client, signedIn: false),
        signedIn: true,
      );
      await tester.pumpWidget(_app(bloc, AnilistOtherListPage(username: 'someone', source: source)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('someone’s list'), findsOneWidget);
      expect(find.text('Cowboy Bebop'), findsWidgets);
      await tester.tap(find.byTooltip('Compare with my list'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Not on my list'), findsOneWidget);
    });
  });
}
