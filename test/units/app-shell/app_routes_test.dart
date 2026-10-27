import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/utils/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => LanguageBloc.apply('en'));

  group('NotificationRoute.parse', () {
    test('content payloads', () {
      final anime = NotificationRoute.parse('anime:21')!;
      expect(anime.kind, NotificationRouteKind.content);
      expect(anime.category, 'anime');
      expect(anime.id, 21);
      expect(NotificationRoute.parse(' manga:2 ')!.category, 'manga');
      expect(NotificationRoute.contentPayload('anime', 5), 'anime:5');
    });

    test('screen payloads', () {
      expect(NotificationRoute.parse('calendar')!.kind,
          NotificationRouteKind.calendar);
      expect(NotificationRoute.parse('bookmarks')!.kind,
          NotificationRouteKind.bookmarks);
    });

    test('invalid payloads are ignored', () {
      for (final payload in [null, '', 'anime', 'anime:x', 'anime:0', 'club:3', 'a:1:2']) {
        expect(NotificationRoute.parse(payload), isNull, reason: '$payload');
      }
    });
  });

  test('every settings section has a page, a title and a description', () {
    for (final section in SettingsSection.values) {
      expect(AppRoutes.settingsPageFor(section), isA<Widget>());
      expect(section.title, isNotEmpty);
      expect(section.description, isNotEmpty);
    }
  });

  test('tracker labels', () {
    expect(AppRoutes.trackerLabel(AccountType.myanimelist), 'MyAnimeList');
    expect(AppRoutes.trackerLabel(AccountType.none), isEmpty);
  });

  Future<void> pumpLauncher(WidgetTester tester, void Function(BuildContext) open) {
    return tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(onPressed: () => open(context), child: const Text('go')),
        ),
      ),
    ));
  }

  testWidgets('calendar and profile helpers open their stubs', (tester) async {
    final openers = <void Function(BuildContext)>[
      AppRoutes.openCalendar,
      (c) => AppRoutes.openUserProfile(c, tracker: AccountType.anilist, username: 'neo'),
      (c) => AppRoutes.openUserStats(c, tracker: AccountType.kitsu),
      (c) => AppRoutes.openSettingsPage(c, SettingsSection.dub),
    ];
    for (final open in openers) {
      await tester.pumpWidget(const SizedBox()); // fresh navigator per helper
      await pumpLauncher(tester, open);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(ComingSoonPage), findsOneWidget);
      expect(find.text(S.current.Shell_Coming_Soon), findsOneWidget);
    }
  });

  testWidgets('openSidebar inside the shell asks the shell', (tester) async {
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: HomeShell(
        openSidebar: () => opened++,
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => AppRoutes.openSidebar(context),
            child: const Text('menu'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('menu'));
    expect(opened, 1);
  });
}
