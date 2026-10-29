import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_character_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_staff_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_studio_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_people_service.dart';
import 'package:mywatchlist/widgets/Anilist/people/anilist_people_ui.dart';

import '../../helpers/no_network.dart';

// Trimmed from real anonymous answers of graphql.anilist.co (2026-10-29).
const _media = {
  'id': 1,
  'type': 'ANIME',
  'format': 'TV',
  'status': 'FINISHED',
  'seasonYear': 1998,
  'startDate': {'year': 1998},
  'title': {'userPreferred': 'Cowboy Bebop'},
  'coverImage': {'large': null},
  'mediaListEntry': {'status': 'COMPLETED'},
};

const _undated = {
  'id': 2,
  'type': 'ANIME',
  'format': 'TV',
  'seasonYear': null,
  'startDate': {'year': null},
  'title': {'userPreferred': 'Upcoming'},
  'coverImage': {'large': null},
  'mediaListEntry': null,
};

const _actor = {
  'id': 95011,
  'name': {'userPreferred': 'Koichi Yamadera', 'full': 'Koichi Yamadera', 'native': null},
  'image': {'medium': null},
  'languageV2': 'Japanese',
};

Map<String, dynamic> _answer(Map<String, dynamic> body) {
  final q = body['query'] as String;
  final v = body['variables'] as Map<String, dynamic>? ?? {};
  if (q.contains('Character(id')) {
    if (q.contains('media(')) {
      return {
        'Character': {
          'media': {
            'pageInfo': {'hasNextPage': false},
            'edges': [
              {
                'characterRole': 'MAIN',
                'node': _media,
                'voiceActors': [_actor],
              },
            ],
          },
        },
      };
    }
    return {
      'Character': {
        'id': 1,
        'name': {
          'userPreferred': 'Spike Spiegel',
          'full': 'Spike Spiegel',
          'native': 'スパイク・スピーゲル',
          'alternative': ['Spike'],
          'alternativeSpoiler': ['Fearless'],
        },
        'image': {'large': null},
        'description': '<p>A bounty hunter.</p>',
        'gender': 'Male',
        'age': '27',
        'bloodType': 'O',
        'dateOfBirth': {'year': null, 'month': 6, 'day': 26},
        'favourites': 1234,
        'isFavourite': false,
      },
    };
  }
  if (q.contains('Staff(id')) {
    if (q.contains('characterMedia')) {
      return {
        'Staff': {
          'characterMedia': {
            'pageInfo': {'hasNextPage': true},
            'edges': [
              {
                'characterRole': 'MAIN',
                'node': _media,
                'characters': [
                  {
                    'id': 1,
                    'name': {'userPreferred': 'Spike Spiegel'},
                    'image': {'medium': null},
                  },
                ],
              },
            ],
          },
        },
      };
    }
    if (q.contains('staffMedia')) {
      return {
        'Staff': {
          'staffMedia': {
            'pageInfo': {'hasNextPage': false},
            'edges': [
              {'staffRole': 'Director', 'node': _media},
            ],
          },
        },
      };
    }
    return {
      'Staff': {
        'id': 95011,
        'name': {'userPreferred': 'Koichi Yamadera', 'native': '山寺宏一'},
        'languageV2': 'Japanese',
        'image': {'large': null},
        'description': null,
        'primaryOccupations': ['Voice Actor'],
        'gender': 'Male',
        'age': 63,
        'dateOfBirth': {'year': 1961, 'month': 6, 'day': 17},
        'dateOfDeath': {'year': null, 'month': null, 'day': null},
        'yearsActive': [1984],
        'homeTown': 'Sendai',
        'favourites': 900,
        'isFavourite': true,
      },
    };
  }
  if (q.contains('Studio(id')) {
    if (q.contains('media(')) {
      return {
        'Studio': {
          'media': {
            'pageInfo': {'hasNextPage': false},
            'edges': [
              {'isMainStudio': true, 'node': _undated},
              {'isMainStudio': true, 'node': _media},
            ],
          },
        },
      };
    }
    return {
      'Studio': {'id': v['id'], 'name': 'Sunrise', 'isAnimationStudio': true, 'favourites': 500, 'isFavourite': false},
    };
  }
  if (q.contains('ToggleFavourite')) return {'ToggleFavourite': {'__typename': 'Favourites'}};
  if (q.contains('Page(')) {
    return {
      'Page': {
        'pageInfo': {'hasNextPage': true},
        'characters': [
          {
            'id': 7,
            'name': {'userPreferred': 'Kuririn'},
            'image': {'medium': null},
            'favourites': 5000,
          },
        ],
        'staff': [
          {
            'id': 8,
            'name': {'userPreferred': 'Someone'},
            'image': {'medium': null},
            'favourites': 20,
          },
        ],
      },
    };
  }
  throw StateError('Unexpected query: $q');
}

AnilistPeopleService _service({
  bool signedIn = false,
  List<Map<String, dynamic>>? reads,
  List<Map<String, dynamic>>? writes,
}) {
  final client = AnilistGraphql(
    sender: (body, {required auth}) async {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      reads?.add(decoded);
      return http.Response(jsonEncode({'data': _answer(decoded)}), 200,
          headers: const {'content-type': 'application/json; charset=utf-8'});
    },
    mutationSender: (body, {required auth}) async {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      writes?.add(decoded);
      return http.Response(jsonEncode({'data': _answer(decoded)}), 200,
          headers: const {'content-type': 'application/json; charset=utf-8'});
    },
  );
  return AnilistPeopleService(client: client, actions: AnilistActions(client: client), signedIn: signedIn);
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

  group('AnilistPeopleService', () {
    test('reads a character with partial birthday and spoiler names', () async {
      final c = await _service().character(1);
      expect(c.names.display, 'Spike Spiegel');
      expect(c.names.spoiler, ['Fearless']);
      expect(c.birthday, const AnilistFuzzyDate(month: 6, day: 26));
      expect(c.favourites, 1234);
    });

    test('reads appearances with their role and voice actors', () async {
      final reads = <Map<String, dynamic>>[];
      final page = await _service(reads: reads)
          .characterMedia(1, type: 'ANIME', onList: true, language: 'ENGLISH');
      expect(page.items.single.role, 'MAIN');
      expect(page.items.single.voiceActors.single.name, 'Koichi Yamadera');
      expect(page.items.single.media.listStatus, 'COMPLETED');
      final vars = reads.single['variables'] as Map;
      expect(vars['onList'], true);
      expect(vars['language'], 'ENGLISH');
    });

    test('manga appearances ask for no voice actors', () async {
      final reads = <Map<String, dynamic>>[];
      await _service(reads: reads).characterMedia(1, type: 'MANGA');
      expect(reads.single['query'], isNot(contains('voiceActors')));
    });

    test('reads staff, voice roles and production roles', () async {
      final service = _service();
      final staff = await service.staff(95011);
      expect(staff.yearsActive, [1984]);
      expect(staff.death, isNull);
      expect(staff.occupations, ['Voice Actor']);
      final voice = await service.staffVoiceRoles(95011);
      expect(voice.hasNext, true);
      expect(voice.items.single.characters.single.name, 'Spike Spiegel');
      final roles = await service.staffRoles(95011);
      expect(roles.items.single.role, 'Director');
    });

    test('moves undated studio titles after the dated ones', () async {
      final page = await _service().studioMedia(1);
      expect(page.items.map((w) => w.media.id), [1, 2]);
    });

    test('toggles a favourite with the right argument', () async {
      final writes = <Map<String, dynamic>>[];
      await _service(writes: writes).toggleFavourite(AnilistFavouriteKind.staff, 8);
      expect(writes.single['query'], contains('staffId'));
      expect((writes.single['variables'] as Map)['id'], 8);
    });

    test('birthday and top loaders read the people', () async {
      final reads = <Map<String, dynamic>>[];
      final service = _service(reads: reads);
      final birthdays = await service.birthdayCharacters();
      expect(birthdays.items.single.name, 'Kuririn');
      expect(birthdays.items.single.favourites, 5000);
      expect(reads.last['query'], contains('isBirthday: true'));
      expect((await service.topStaff()).items.single.id, 8);
      expect(reads.last['query'], contains('staff('));
    });
  });

  test('formats partial dates', () {
    expect(formatAnilistFuzzyDate(const AnilistFuzzyDate(year: 1999)), '1999');
    expect(formatAnilistFuzzyDate(const AnilistFuzzyDate(month: 6, day: 26)), 'Jun 26');
    expect(formatAnilistFuzzyDate(const AnilistFuzzyDate(year: 1961, month: 6, day: 17)), 'Jun 17, 1961');
  });

  group('pages', () {
    testWidgets('character page shows info, hides spoiler names until tapped', (tester) async {
      await tester.pumpWidget(_app(AnilistCharacterPage(characterId: 1, service: _service())));
      await tester.pumpAndSettle();
      expect(find.text('Spike Spiegel'), findsWidgets);
      expect(find.text('Jun 26'), findsOneWidget);
      expect(find.text('Spike'), findsOneWidget);
      expect(find.text('Spike, Fearless'), findsNothing);
      await tester.tap(find.text('Show spoiler names'));
      await tester.pump();
      expect(find.text('Spike, Fearless'), findsOneWidget);
    });

    testWidgets('character page lists anime with role and voice actor', (tester) async {
      await tester.pumpWidget(_app(AnilistCharacterPage(characterId: 1, service: _service())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anime').first);
      await tester.pumpAndSettle();
      expect(find.text('Cowboy Bebop'), findsOneWidget);
      expect(find.text('Main'), findsOneWidget);
      expect(find.text('Koichi Yamadera'), findsOneWidget);
      expect(find.text('On my list'), findsNothing);
    });

    testWidgets('favourite heart toggles through ToggleFavourite when signed in', (tester) async {
      final writes = <Map<String, dynamic>>[];
      final service = _service(signedIn: true, writes: writes);
      await tester.pumpWidget(_app(AnilistStaffPage(staffId: 95011, service: service)));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsWidgets);
      await tester.tap(find.byTooltip('Remove from favourites'));
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(find.byTooltip('Add to favourites'), findsOneWidget);
    });

    testWidgets('signed out, the heart writes nothing', (tester) async {
      final writes = <Map<String, dynamic>>[];
      final service = _service(writes: writes);
      await tester.pumpWidget(_app(AnilistStaffPage(staffId: 95011, service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove from favourites'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
    });

    testWidgets('staff page shows voiced characters and production roles', (tester) async {
      await tester.pumpWidget(_app(AnilistStaffPage(staffId: 95011, service: _service())));
      await tester.pumpAndSettle();
      expect(find.text('Sendai'), findsOneWidget);
      await tester.tap(find.text('Voice roles'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Spike Spiegel'), findsOneWidget);
      await tester.tap(find.text('Staff roles'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Director'), findsOneWidget);
    });

    testWidgets('studio page groups by year with undated last', (tester) async {
      await tester.pumpWidget(_app(AnilistStudioPage(studioId: 4, service: _service())));
      await tester.pumpAndSettle();
      expect(find.text('Sunrise'), findsWidgets);
      final year = tester.getTopLeft(find.text('1998')).dy;
      final tba = tester.getTopLeft(find.text('TBA')).dy;
      expect(year, lessThan(tba));
      expect(find.text('Main studio'), findsOneWidget);
    });
  });
}
