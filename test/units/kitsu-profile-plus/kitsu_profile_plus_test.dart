import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart' show KitsuDocument;
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_profile_view.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_activity_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_category_donut.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_people.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart';

/// Saved anonymous read-only answers of kitsu.io (see the kitsu-graphql unit). Nothing here
/// reaches Kitsu and nothing writes to a tracker account.
String _fixture(String name) =>
    File('test/units/kitsu-graphql/fixtures/$name.json').readAsStringSync();

class _Fake {
  _Fake(this.byMatch) {
    client = MockClient((request) async {
      requests.add(request);
      for (final entry in byMatch.entries) {
        if (request.body.contains(entry.key)) {
          return http.Response.bytes(utf8.encode(_fixture(entry.value)), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
      }
      return http.Response('{}', 404);
    });
  }

  final Map<String, String> byMatch;
  final List<http.Request> requests = [];
  late final MockClient client;

  KitsuSocial get social => KitsuSocial(
      graphql: KitsuGraphql(
        client: client,
        rest: KitsuHttp(publicClient: client),
        auth: (send, {idempotent}) async => send(client, 'tok'),
      ));
}

KitsuLibraryEvent _event(String kind, Map<String, List<Object?>> changes,
        {KitsuMediaKind media = KitsuMediaKind.anime}) =>
    KitsuLibraryEvent(
      id: '1',
      kind: kind,
      media: KitsuMediaRef(kind: media, id: '9'),
      changes: changes,
    );

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: child,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await S.load(const Locale('en'));
  });

  group('activity sentences', () {
    test('a status change names both statuses', () {
      expect(
        kitsuEventText(_event('UPDATED', {
          'status': ['current', 'planned']
        })),
        'Moved from Currently watching to Want to watch',
      );
    });

    test('manga words are used for manga', () {
      expect(
        kitsuEventText(_event('PROGRESSED', {
          'progress': [3, 4]
        }, media: KitsuMediaKind.manga)),
        'Read chapter 4',
      );
      expect(
        kitsuEventText(_event('PROGRESSED', {
          'progress': [3, 4]
        })),
        'Watched episode 4',
      );
    });

    test('ratings are shown out of ten', () {
      expect(
        kitsuEventText(_event('RATED', {
          'rating': [null, 17]
        })),
        'Rated 8.5/10',
      );
      expect(
        kitsuEventText(_event('RATED', {
          'rating': [10, 16]
        })),
        'Changed the rating from 5 to 8/10',
      );
    });

    test('kinds without a change still read as a sentence', () {
      expect(kitsuEventText(_event('REACTED', {})), 'Wrote a reaction');
      expect(kitsuEventText(_event('ANNOTATED', {})), 'Edited the notes');
      expect(kitsuEventText(_event('UPDATED', {})), 'Updated this entry');
    });
  });

  test('the REST user carries the counters and a handle for GraphQL', () {
    final user = {
      'id': '7',
      'type': 'users',
      'attributes': {
        'name': 'No Slug',
        'commentsCount': 316,
        'postsCount': 147,
        'mediaReactionsCount': 20,
        'likesReceivedCount': 55,
      },
    };
    final profile = KitsuProfiles.parse(user, KitsuDocument.from({'data': [user]}));
    expect(profile.commentsCount, 316);
    expect(profile.postsCount, 147);
    expect(profile.reactionsCount, 20);
    expect(profile.likesReceivedCount, 55);
    expect(profile.handle, '7');
  });

  group('KitsuSocial', () {
    test('favourites keeps one type and follows the pages', () async {
      final fake = _Fake({'ProfileConnection': 'profile_favourites'});
      final characters = await fake.social.favourites('Tamaya', 'Character');
      expect(characters, isNotEmpty);
      expect(characters.every((f) => f.type == 'Character'), isTrue);
      // The fixture says there is a next page, so the pages are read up to the cap.
      expect(fake.requests.length, KitsuSocial.maxFavouritePages);
    });

    test('a pager loads page after page and stops at the end', () async {
      final fake = _Fake({'ProfileConnection': 'profile_followers'});
      final pager = KitsuPager((page) => fake.social.followers('Tamaya', page));
      await pager.loadMore();
      expect(pager.items, isNotEmpty);
      expect(pager.total, 94);
      expect(pager.hasMore, isTrue);
      final first = pager.items.length;
      await pager.loadMore();
      expect(pager.items.length, greaterThan(first));
      final cursor = jsonDecode(fake.requests.last.body)['variables']['after'];
      expect(cursor, 'Mw');
      pager.dispose();
    });

    test('a failed page keeps what was loaded and can be retried', () async {
      var fail = false;
      final fake = _Fake({'ProfileConnection': 'profile_followers'});
      final pager = KitsuPager<KitsuAuthor>((page) {
        if (fail) throw const KitsuHttpError(500);
        return fake.social.followers('Tamaya', page);
      });
      await pager.loadMore();
      final loaded = pager.items.length;
      fail = true;
      await pager.loadMore();
      expect(pager.error, isNotNull);
      expect(pager.items.length, loaded);
      fail = false;
      await pager.loadMore();
      expect(pager.error, isNull);
      expect(pager.items.length, greaterThan(loaded));
      pager.dispose();
    });

    test('the library asks for the status and the kind', () async {
      final fake = _Fake({'ProfileLibrary': 'profile_library'});
      final page = await fake.social.library('Tamaya',
          kind: KitsuMediaKind.anime, status: 'CURRENT', page: const KitsuPageArgs());
      expect(page.nodes, isNotEmpty);
      final vars = jsonDecode(fake.requests.single.body)['variables'] as Map;
      expect(vars['type'], 'ANIME');
      expect(vars['status'], ['CURRENT']);
    });
  });

  testWidgets('the activity tab lists the events with their sentence', (tester) async {
    final fake = _Fake({'ProfileConnection': 'profile_activity'});
    KitsuSocial.instance = fake.social;
    await tester.pumpWidget(_app(Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
        ],
        body: const KitsuActivityTab(slug: 'Tamaya'),
      ),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.text('Moved from Currently watching to Want to watch'), findsWidgets);
    expect(find.textContaining('MERCHANT MEETS THE WISE WOLF'), findsWidgets);
  });

  testWidgets('the followers page lists the people and opens none without a tap', (tester) async {
    final fake = _Fake({'ProfileConnection': 'profile_followers'});
    await tester.pumpWidget(_app(KitsuPeoplePage(
        slug: 'Tamaya', followers: true, social: fake.social)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Followers'), findsOneWidget);
    expect(find.byType(KitsuPersonTile), findsWidgets);
  });

  testWidgets('user search waits for two letters then lists the matches', (tester) async {
    final fake = _Fake({'SearchProfiles': 'search_profiles'});
    await tester.pumpWidget(_app(KitsuUserSearchPage(social: fake.social)));
    await tester.enterText(find.byType(TextField), 'T');
    await tester.pump(const Duration(milliseconds: 600));
    expect(fake.requests, isEmpty);
    await tester.enterText(find.byType(TextField), 'tam');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump();
    expect(fake.requests, isNotEmpty);
    expect(jsonDecode(fake.requests.first.body)['variables']['username'], 'tam');
    expect(find.text('Tamaya'), findsWidgets);
  });

  testWidgets('another user gets a List tab, the signed-in user does not', (tester) async {
    const profile = KitsuProfile(id: '1', name: 'Pat', slug: 'pat');
    SharedPreferences.setMockInitialValues({});
    final bloc = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(bloc.close);
    for (final self in [true, false]) {
      await tester.pumpWidget(BlocProvider<PreferencesBloc>.value(
        value: bloc,
        child: _app(KitsuProfileView(userId: self ? null : '1', loader: (_) async => profile)),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Reactions'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('List'), self ? findsNothing : findsOneWidget);
    }
  });

  testWidgets('a title row opens the Kitsu title, never a MyAnimeList page', (tester) async {
    final opened = <String>[];
    final previous = KitsuTitleLinks.opener;
    KitsuTitleLinks.opener = (context, kind, id, slug) => opened.add('${kind.name}:$id:$slug');
    addTearDown(() => KitsuTitleLinks.opener = previous);
    await tester.pumpWidget(_app(const Scaffold(
      body: KitsuMediaLine(
        media: KitsuMediaRef(
            kind: KitsuMediaKind.manga, id: '5', slug: 'berserk', titles: KitsuTitles(canonical: 'Berserk')),
      ),
    )));
    await tester.tap(find.text('Berserk'));
    expect(opened, ['manga:5:berserk']);
  });

  test('the donut keeps the biggest categories and groups the rest', () {
    final parts = KitsuCategoryDonut.slices(
        [for (var i = 1; i <= 9; i++) MapEntry('c$i', i)], 6, 'Other');
    expect(parts.length, 7);
    expect(parts.first.key, 'c9');
    expect(parts.last, const MapEntry('Other', 6));
  });

  test('the time percentile is read from the stats', () {
    final user = {
      'id': '1',
      'type': 'users',
      'attributes': {'name': 'P'},
      'relationships': {
        'stats': {
          'data': [
            {'type': 'stats', 'id': 's'}
          ]
        }
      },
    };
    final doc = KitsuDocument.from({
      'data': [user],
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
              'percentiles': {'time': 38.4}
            },
          },
        }
      ],
    });
    expect(KitsuProfiles.parse(user, doc).anime.timePercentile, 38.4);
  });
}
