import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_forum_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/settings/notification_types_sheet.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

// Fakes only: nothing here reaches AniList.

Map<String, dynamic> _row(int id) => {
      'id': 900 + id,
      'status': 'CURRENT',
      'scoreRaw': 70,
      'score': 7.0,
      'progress': 1,
      'progressVolumes': 0,
      'repeat': 0,
      'priority': 0,
      'private': false,
      'hiddenFromStatusLists': false,
      'notes': '',
      'customLists': null,
      'advancedScores': null,
      'updatedAt': 1700000100,
      'createdAt': 1700000000,
      'startedAt': {'year': null, 'month': null, 'day': null},
      'completedAt': {'year': null, 'month': null, 'day': null},
      'media': {
        'id': id,
        'idMal': id,
        'type': 'ANIME',
        'format': 'TV',
        'status': 'FINISHED',
        'episodes': 12,
        'genres': <String>[],
        'title': {'romaji': 'Shingeki', 'english': 'Attack', 'native': 'Kyojin'},
        'coverImage': {'large': 'https://x/$id.jpg'},
      },
    };

AnilistGraphql _listClient() => AnilistGraphql(
      sender: (body, {required auth}) async => http.Response(
        jsonEncode({
          'data': {
            'MediaListCollection': {
              'hasNextChunk': false,
              'user': {
                'mediaListOptions': {
                  'scoreFormat': 'POINT_10_DECIMAL',
                  'rowOrder': 'score',
                  'animeList': {'sectionOrder': <String>[]},
                  'mangaList': {'sectionOrder': <String>[]},
                },
              },
              'lists': [
                {
                  'entries': [_row(1)],
                },
              ],
            },
          },
        }),
        200,
      ),
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('AnilistListService title language', () {
    test('uses the account title language, not the app preference', () async {
      final service = AnilistListService(
        client: _listClient(),
        owner: () => 'me',
        accountTitleLang: () async => 'en',
      );
      final rows = await service.all('anime');
      expect(rows.single.title, 'Attack');
    });

    test('native account language gives the native title', () async {
      final service = AnilistListService(
        client: _listClient(),
        owner: () => 'me',
        accountTitleLang: () async => 'ja',
      );
      expect((await service.all('anime')).single.title, 'Kyojin');
    });
  });

  group('SaveQueue', () {
    test('runs quick saves one after the other, none dropped', () async {
      final queue = SaveQueue();
      final log = <String>[];
      final first = Completer<void>();
      final a = queue.add(() async {
        log.add('a start');
        await first.future;
        log.add('a end');
      });
      final b = queue.add(() async => log.add('b'));
      await Future<void>.delayed(Duration.zero);
      expect(log, ['a start']);
      first.complete();
      await Future.wait([a, b]);
      expect(log, ['a start', 'a end', 'b']);
    });

    test('a failed save does not block the next one', () async {
      final queue = SaveQueue();
      var ran = false;
      final a = queue.add(() => throw StateError('boom'));
      final b = queue.add(() => ran = true);
      await expectLater(a, throwsStateError);
      await b;
      expect(ran, isTrue);
    });

    testWidgets('two quick toggles in the sheet both reach the saver', (tester) async {
      final saved = <String>[];
      final gate = Completer<void>();
      late BuildContext ctx;
      await pumpInApp(tester, Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }));
      unawaited(showNotificationTypesSheet(
        ctx,
        enabled: const {},
        onChanged: (type, v) async {
          saved.add('$type=$v');
          if (saved.length == 1) await gate.future;
        },
      ));
      await tester.pumpAndSettle();
      final switches = find.byType(SwitchListTile);
      await tester.tap(switches.at(0));
      await tester.tap(switches.at(1));
      await tester.pump();
      expect(saved, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(saved, hasLength(2));
    });
  });

  group('AppImage placeholder', () {
    testWidgets('sizes itself from the width when the height is unbounded', (tester) async {
      await pumpInApp(
        tester,
        const SingleChildScrollView(
          child: SizedBox(width: 100, child: AppImage(url: null)),
        ),
      );
      expect(tester.takeException(), isNull);
      final size = tester.getSize(find.byType(AppImage));
      expect(size.width, 100);
      expect(size.height, 100 * AppImage.placeholderAspect);
    });

    testWidgets('a bounded slot is unchanged', (tester) async {
      await pumpInApp(tester, const AppImage(url: null, width: 50, height: 70));
      expect(tester.getSize(find.byType(AppImage)), const Size(50, 70));
    });
  });

  group('AnilistForumPage standalone', () {
    AnilistSocialService service() => AnilistSocialService(
          client: AnilistGraphql(sender: (body, {required auth}) => Completer<http.Response>().future),
          signedIn: false,
        );

    testWidgets('shows an app bar with a back button when pushed', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => AnilistForumPage(service: service(), standalone: true),
              )),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(AnilistForumPage), findsNothing);
    });
  });
}
