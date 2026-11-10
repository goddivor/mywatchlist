import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_profile_view.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'kitsu_fakes.dart';

Map<String, dynamic> userDoc() => {
      'data': [
        {
          'id': '42',
          'type': 'users',
          'attributes': {
            'name': 'Patrice',
            'slug': 'patrice',
            'about': 'Hello there',
            'location': 'Lomé',
            'createdAt': '2020-01-15T10:00:00.000Z',
            'avatar': {'large': 'https://img/a.jpg'},
            'coverImage': {'large': 'https://img/c.jpg'},
            'followersCount': 12,
            'followingCount': 3,
            'waifuOrHusbando': 'Waifu',
          },
          'relationships': {
            'stats': {
              'data': [
                {'type': 'stats', 'id': 's1'},
                {'type': 'stats', 'id': 's2'},
                {'type': 'stats', 'id': 's3'},
              ]
            },
            'waifu': {
              'data': {'type': 'characters', 'id': 'c1'}
            },
          },
        }
      ],
      'included': [
        {
          'id': 's1',
          'type': 'stats',
          'attributes': {
            'kind': 'anime-amount-consumed',
            'statsData': {'media': 120, 'units': 1500, 'completed': 80, 'time': 90061},
          },
        },
        {
          'id': 's2',
          'type': 'stats',
          'attributes': {
            'kind': 'anime-category-breakdown',
            'statsData': {
              'categories': {'Comedy': 40, 'Action': 70},
              'total': 110,
            },
          },
        },
        {
          'id': 's3',
          'type': 'stats',
          'attributes': {
            'kind': 'manga-amount-consumed',
            'statsData': {'media': 5, 'units': 90, 'completed': 2, 'time': 3600},
          },
        },
        {
          'id': 'c1',
          'type': 'characters',
          'attributes': {'canonicalName': 'Frieren'},
        },
      ],
    };

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await S.load(const Locale('en'));
  });

  test('parses the user, its statistics and its waifu', () {
    final doc = KitsuDocument.from(userDoc());
    final profile = KitsuProfiles.parse(doc.data.first, doc);
    expect(profile.name, 'Patrice');
    expect(profile.avatarUrl, 'https://img/a.jpg');
    expect(profile.coverUrl, 'https://img/c.jpg');
    expect(profile.followers, 12);
    expect(profile.anime.media, 120);
    expect(profile.anime.units, 1500);
    expect(profile.anime.time, const Duration(seconds: 90061));
    expect(profile.anime.categories.first.key, 'Action');
    expect(profile.anime.categories.first.value, 70);
    expect(profile.manga.units, 90);
    expect(profile.waifuName, 'Frieren');
    expect(profile.webUrl, 'https://kitsu.app/users/patrice');
  });

  test('load asks for the signed-in user and adds the list counts', () async {
    final fake = FakeKitsu((r) async {
      if (r.url.path.endsWith('/users')) return jsonResponse(userDoc());
      return jsonResponse({'data': [], 'meta': {'count': 4}});
    });
    final profiles = KitsuProfiles(
        http: fake.kitsu, library: KitsuLibrary(http: fake.kitsu, owner: () => 'me'));
    final profile = await profiles.load();
    expect(fake.requests.first.url.queryParameters['filter[self]'], 'true');
    expect(profile.anime.statusCounts[ListEntryStatus.completed], 4);
    expect(profile.anime.totalEntries, 20);
    expect(profile.manga.totalEntries, 20);
  });

  test('time spent is written in days and hours, or hours and minutes', () async {
    await S.load(const Locale('en'));
    expect(formatKitsuTime(const Duration(days: 12, hours: 5)), '12 d 5 h');
    expect(formatKitsuTime(const Duration(hours: 3, minutes: 20)), '3 h 20 min');
  });

  testWidgets('the profile view shows the name, counts and the three tabs', (tester) async {
    final profile = KitsuProfiles.parse(
        KitsuDocument.from(userDoc()).data.first, KitsuDocument.from(userDoc()));
    SharedPreferences.setMockInitialValues({});
    final bloc = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(bloc.close);
    await tester.pumpWidget(
      BlocProvider<PreferencesBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: KitsuProfileView(loader: (_) async => profile),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Patrice'), findsWidgets);
    expect(find.text('12 followers'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: KitsuProfileView(loader: (_) async {
          calls++;
          throw const KitsuHttpError(500);
        }),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls, 2);
  });
}
