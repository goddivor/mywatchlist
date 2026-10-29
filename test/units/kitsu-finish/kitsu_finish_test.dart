import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart' show KitsuRatingSystem;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuRatingFrequencies;
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_tile.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_follow_button.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_groups_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart' show kitsuTimeAgo;
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_entry_editor.dart';

import '../kitsu-pages/kitsu_fakes.dart';

Widget app(Widget child) => MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: child),
    );

/// Records the entry the editor saves; never reaches Kitsu.
class _FakeClient implements TrackerEntryClient {
  SyncEntry? written;

  @override
  AccountType get tracker => AccountType.kitsu;
  @override
  bool supports({required bool isAnime}) => true;
  @override
  Future<SyncEntry?> read(String mediaId, {required bool isAnime, int? malId}) async => null;
  @override
  Future<SyncEntry> write(String mediaId, SyncEntry entry, {required bool isAnime, int? malId}) async =>
      written = entry;
  @override
  Future<void> delete(String mediaId, {required bool isAnime, int? malId}) async {}
  @override
  Future<String?> findByMalId(int malId, {required bool isAnime}) async => null;
}

KitsuProfiles profilesOver(FakeKitsu fake) => KitsuProfiles(
      http: fake.kitsu,
      library: KitsuLibrary(http: fake.kitsu, owner: () => 'me'),
    );

Future<http.Response> followsHandler(http.Request r, {String? existing}) async {
  if (r.url.path.endsWith('/users')) {
    return jsonResponse({
      'data': [
        {'id': '7', 'type': 'users', 'attributes': {'name': 'me'}}
      ]
    });
  }
  if (r.method == 'GET' && r.url.path.endsWith('/follows')) {
    return jsonResponse({
      'data': [if (existing != null) {'id': existing, 'type': 'follows'}]
    });
  }
  if (r.method == 'POST') {
    return jsonResponse({
      'data': {'id': '900', 'type': 'follows'}
    }, 201);
  }
  return http.Response('', 204);
}

/// What the profile's NestedScrollView gives its tabs.
Widget _absorber(BuildContext context) => SliverOverlapAbsorber(
      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
      sliver: const SliverToBoxAdapter(child: SizedBox(height: 10)),
    );

void main() {
  setUpAll(() async => S.load(const Locale('en')));

  test('JSON:API text is decoded as UTF-8 even without a charset', () async {
    final fake = FakeKitsu((r) async => http.Response.bytes(
        utf8.encode('{"data":{"attributes":{"t":"Jujutsu Kaisen: Shimetsu Kaiyū Zenpen"}}}'), 200,
        headers: {'content-type': 'application/vnd.api+json'}));
    final json = await fake.kitsu.getJson('/anime/1');
    expect(((json['data'] as Map)['attributes'] as Map)['t'], contains('Kaiyū'));
  });

  test('a time percentile of 0.99 is 99 percent, not 1', () {
    expect(KitsuProfiles.percentOfFraction(0.99), closeTo(99, 1e-9));
    expect(KitsuProfiles.percentOfFraction(0.384), closeTo(38.4, 1e-9));
    expect(KitsuProfiles.percentOfFraction(1), 100);
    expect(KitsuProfiles.percentOfFraction(38.4), 38.4);
    final doc = KitsuDocument.from({
      'data': [
        {
          'id': '1',
          'type': 'users',
          'attributes': {'name': 'A'},
          'relationships': {
            'stats': {
              'data': [
                {'type': 'stats', 'id': 's'}
              ]
            }
          },
        }
      ],
      'included': [
        {
          'id': 's',
          'type': 'stats',
          'attributes': {
            'kind': 'anime-amount-consumed',
            'statsData': {
              'media': 1,
              'units': 1,
              'completed': 1,
              'time': 60,
              'percentiles': {'time': 0.99}
            }
          },
        }
      ],
    });
    expect(KitsuProfiles.parse(doc.data.first, doc).anime.timePercentile, closeTo(99, 1e-9));
  });

  test('relative times carry no double space', () {
    final text = kitsuTimeAgo(DateTime.now().subtract(const Duration(minutes: 5)));
    expect(text, isNot(contains('  ')));
    expect(text, startsWith('5 '));
  });

  test('the rating histogram folds into the rating system of the account', () {
    final freq = KitsuRatingFrequencies({2: 1, 3: 2, 4: 4, 5: 8, 6: 16, 11: 32, 12: 64, 16: 128, 17: 256, 20: 512});
    expect(freq.rebucket(4), [1 + 2 + 4 + 8, 16 + 32, 64 + 128, 256 + 512]);
    final stars = freq.rebucket(10);
    expect(stars, hasLength(10));
    expect(stars[0], 3);
    expect(stars[9], 512);
    expect(stars.fold<int>(0, (a, b) => a + b), freq.total);
    expect(freq.rebucket(19), freq.steps);
  });

  group('follow', () {
    test('reads, creates and removes a follow through the signed-in client', () async {
      final fake = FakeKitsu((r) => followsHandler(r));
      final api = profilesOver(fake);
      expect(await api.followId('42'), isNull);
      final get = fake.requests.last;
      expect(get.url.queryParameters['filter[follower]'], '7');
      expect(get.url.queryParameters['filter[followed]'], '42');
      expect(await api.follow('42'), '900');
      final post = fake.requests.last;
      expect(post.method, 'POST');
      final rel = (jsonDecode(post.body)['data']['relationships']) as Map;
      expect(rel['follower']['data']['id'], '7');
      expect(rel['followed']['data']['id'], '42');
      await api.unfollow('900');
      expect(fake.requests.last.method, 'DELETE');
      expect(fake.requests.last.url.path, endsWith('/follows/900'));
    });

    testWidgets('nothing is written until the viewer taps', (tester) async {
      final fake = FakeKitsu((r) => followsHandler(r));
      await tester.pumpWidget(app(KitsuFollowButton(userId: '42', profiles: profilesOver(fake))));
      await tester.pump();
      await tester.pump();
      expect(find.text('Follow'), findsOneWidget);
      expect(fake.requests.where((r) => r.method != 'GET'), isEmpty);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      await tester.pump();
      expect(fake.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(find.text('Following'), findsOneWidget);
      await tester.tap(find.text('Following'));
      await tester.pump();
      await tester.pump();
      expect(fake.requests.where((r) => r.method == 'DELETE'), hasLength(1));
      expect(find.text('Follow'), findsOneWidget);
    });

    testWidgets('an existing follow reads as Following', (tester) async {
      final fake = FakeKitsu((r) => followsHandler(r, existing: '55'));
      await tester.pumpWidget(app(KitsuFollowButton(userId: '42', profiles: profilesOver(fake))));
      await tester.pump();
      await tester.pump();
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('an unreadable state draws no button', (tester) async {
      final fake = FakeKitsu((r) async => http.Response('', 500));
      await tester.pumpWidget(app(KitsuFollowButton(userId: '42', profiles: profilesOver(fake))));
      await tester.pump();
      await tester.pump();
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });

  group('groups', () {
    Map<String, dynamic> members() => {
          'data': [
            {
              'id': 'm1',
              'type': 'groupMembers',
              'relationships': {
                'group': {
                  'data': {'type': 'groups', 'id': '9'}
                }
              }
            }
          ],
          'included': [
            {
              'id': '9',
              'type': 'groups',
              'attributes': {'name': 'Slice of Life', 'membersCount': 120, 'tagline': 'Calm'},
            }
          ],
        };

    test('lists the groups of a user', () async {
      final fake = FakeKitsu((r) async => jsonResponse(members()));
      final groups = await profilesOver(fake).groups('42');
      expect(fake.requests.single.url.queryParameters['filter[query_user]'], '42');
      expect(groups.single.name, 'Slice of Life');
      expect(groups.single.membersCount, 120);
    });

    testWidgets('the tab shows them, or says there are none', (tester) async {
      final fake = FakeKitsu((r) async => jsonResponse(members()));
      await tester.pumpWidget(app(NestedScrollView(
        headerSliverBuilder: (context, _) => [_absorber(context)],
        body: KitsuGroupsTab(userId: '42', profiles: profilesOver(fake)),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text('Slice of Life'), findsOneWidget);

      final none = FakeKitsu((r) async => jsonResponse({'data': []}));
      await tester.pumpWidget(app(NestedScrollView(
        key: UniqueKey(),
        headerSliverBuilder: (context, _) => [_absorber(context)],
        body: KitsuGroupsTab(userId: '43', profiles: profilesOver(none)),
      )));
      await tester.pump();
      await tester.pump();
      expect(find.text('Not in any group yet'), findsOneWidget);
    });
  });

  testWidgets('a Kitsu tile draws the percentage, not a score out of 10', (tester) async {
    final media = KitsuMedia(id: 1, isAnime: true, title: 'Frieren', meanScore: 8.89);
    await tester.pumpWidget(app(SizedBox(width: 130, height: 260, child: KitsuMediaTile(media: media))));
    await tester.pump();
    expect(find.text('89%'), findsOneWidget);
    expect(find.text('8.9'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  group('sync editor in the account rating system', () {
    test('a score snaps to the nearest step of the system', () {
      expect(kitsuScoreIn(0, KitsuRatingSystem.simple), 0);
      expect(kitsuScoreIn(5, KitsuRatingSystem.simple), 4);
      expect(kitsuScoreIn(6, KitsuRatingSystem.simple), 7);
      expect(kitsuScoreIn(9.5, KitsuRatingSystem.simple), 10);
      expect(kitsuScoreIn(7.5, KitsuRatingSystem.regular), 8);
      expect(kitsuScoreIn(7.5, KitsuRatingSystem.advanced), 7.5);
      expect(kitsuScoreIn(0.5, KitsuRatingSystem.advanced), 1);
    });

    Future<_FakeClient> pumpEditor(WidgetTester tester, KitsuRatingSystem system,
        {double score = 0}) async {
      final client = _FakeClient();
      final service = TrackerSyncService(clients: {AccountType.kitsu: client});
      await tester.pumpWidget(app(TrackerEntryEditor(
        service: service,
        tracker: AccountType.kitsu,
        trackerId: '1',
        malId: 1,
        category: 'anime',
        kitsuSystem: system,
        initial: SyncEntry(status: 'watching', score: score, progress: 1),
      )));
      await tester.pump();
      return client;
    }

    testWidgets('Simple offers four faces and saves the chosen one', (tester) async {
      final client = await pumpEditor(tester, KitsuRatingSystem.simple);
      expect(find.text('Rating (4 levels)'), findsOneWidget);
      for (final word in ['Awful', 'Meh', 'Good', 'Great']) {
        expect(find.text(word), findsOneWidget);
      }
      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();
      expect(client.written?.score, 7);
    });

    testWidgets('Regular shows stars', (tester) async {
      await pumpEditor(tester, KitsuRatingSystem.regular, score: 7);
      expect(find.text('Rating (stars)'), findsOneWidget);
      expect(find.text('3.5'), findsOneWidget);
    });

    testWidgets('Advanced shows points', (tester) async {
      await pumpEditor(tester, KitsuRatingSystem.advanced, score: 7.5);
      expect(find.text('Rating (out of 10)'), findsOneWidget);
      expect(find.text('7.5'), findsOneWidget);
    });

    testWidgets('another tracker keeps its own slider', (tester) async {
      final service = TrackerSyncService(clients: {AccountType.anilist: _FakeClient()});
      await tester.pumpWidget(app(TrackerEntryEditor(
        service: service,
        tracker: AccountType.anilist,
        trackerId: '1',
        malId: 1,
        category: 'anime',
        kitsuSystem: KitsuRatingSystem.simple,
      )));
      await tester.pump();
      expect(find.text('Rating (4 levels)'), findsNothing);
      expect(find.byType(Slider), findsOneWidget);
    });
  });
}
