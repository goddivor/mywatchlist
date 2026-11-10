import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/forums_section.dart';
import 'package:mywatchlist/screens/settings/mal_session_settings.dart';
import 'package:mywatchlist/screens/user_profile/sections/about_section.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_profile_page.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/user/accounts/widgets/account_tile.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: Center(child: home)),
    );

String _fixture(String name) =>
    File('test/units/user-profile-mal/fixtures/$name').readAsStringSync();

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MalNotificationsHub.instance.unread.value = 0;
  });

  group('bell label', () {
    test('says the count', () {
      expect(bellSemanticsLabel(25), 'Notifications, 25 unread');
      expect(bellSemanticsLabel(0), 'Notifications');
    });

    testWidgets('the bell is one button labelled with the unread count', (tester) async {
      final handle = tester.ensureSemantics();
      MalNotificationsHub.instance.unread.value = 25;
      await tester.pumpWidget(_app(const MalBellWithLabel()));
      expect(find.bySemanticsLabel('Notifications, 25 unread'), findsOneWidget);
      expect(find.bySemanticsLabel('25'), findsNothing);
      MalNotificationsHub.instance.unread.value = 0;
      await tester.pump();
      expect(find.bySemanticsLabel('Notifications, 0 unread'), findsNothing);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      handle.dispose();
    });
  });

  group('title clubs row', () {
    testWidgets('lists the clubs of the title and hides itself when there are none',
        (tester) async {
      await tester.pumpWidget(_app(TitleClubsRow(
        id: 21,
        category: 'manga',
        fetch: (id, category) async {
          expect([id, category], [21, 'manga']);
          return [
            ClubHtml(id: 7, name: 'Pirates', members: '1,204'),
            ClubHtml(id: null, name: 'No id'),
          ];
        },
      )));
      await tester.pump();
      expect(find.text('Clubs'), findsOneWidget);
      expect(find.text('Pirates'), findsOneWidget);
      expect(find.text('1,204 Members'), findsOneWidget);
      expect(find.text('No id'), findsNothing);

      await tester.pumpWidget(_app(TitleClubsRow(key: const ValueKey('none'), id: 1, fetch: (_, __) async => [])));
      await tester.pump();
      expect(find.text('Clubs'), findsNothing);
    });

    testWidgets('a page MAL does not answer adds nothing', (tester) async {
      await tester.pumpWidget(
          _app(TitleClubsRow(id: 1, fetch: (_, __) async => throw Exception('503'))));
      await tester.pump();
      expect(find.text('Clubs'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Supporter badge from the profile page', () {
    test('read from the profile status list only', () {
      final other = parseMalProfilePage(_fixture('profile_xinil_2026-10.html'))!;
      expect(other['is_supporter'], isTrue);
      final owner = parseMalProfilePage(_fixture('profile_goddivor_2026-10.html'))!;
      expect(owner['is_supporter'], isFalse);
    });
  });

  group('About time zone', () {
    testWidgets('is a labelled line in the About block', (tester) async {
      await tester.pumpWidget(_app(
          const AboutTimeZone(username: 'neo', timezone: 'America/Los_Angeles')));
      await tester.pump();
      expect(find.text('Time zone:'), findsOneWidget);
      expect(find.text('Los Angeles'), findsOneWidget);
    });

    testWidgets('reads the cached profile when the page was not given the zone',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'cached_user_profile_v1_neo':
            '{"savedAt":"${DateTime.now().toIso8601String()}","data":{"timezone":"Europe/Paris"}}',
      });
      await tester.pumpWidget(_app(const AboutTimeZone(username: 'neo')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Paris'), findsOneWidget);
    });

    testWidgets('shows nothing without a zone', (tester) async {
      await tester.pumpWidget(_app(const AboutTimeZone(username: 'neo')));
      await tester.pump();
      expect(find.text('Time zone:'), findsNothing);
    });
  });

  group('account tile menu', () {
    testWidgets('the MyAnimeList website session is an entry of the tile menu',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(_app(SizedBox(
        width: 380,
        child: AccountTile(
          info: TrackerInfo.myAnimeList,
          status: TrackerStatus.connected,
          username: 'neo',
          isActive: true,
          onSignOut: () {},
          menuEntries: [
            AccountMenuEntry(
                icon: Icons.language, label: S.current.Ms_Settings_Title, onTap: () => opened++),
          ],
        ),
      )));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('MyAnimeList website'), findsOneWidget);
      expect(find.text(S.current.Acc_Sign_Out), findsOneWidget);
      await tester.tap(find.text('MyAnimeList website'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });

    test('the session page still exists as a screen', () {
      expect(const MalSessionSettingsPage(), isA<StatefulWidget>());
    });
  });
}
