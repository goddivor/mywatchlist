import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_badges.dart';
import 'package:mywatchlist/widgets/user/profile/profile_badges.dart';

String _fixture() => File('test/units/mal-badges/fixtures/badges_page.html').readAsStringSync();

Future<void> _pump(WidgetTester tester, Future<List<MalBadge>> Function(String) load,
    {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: ProfileBadgesCard(username: 'someone', load: load)),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await S.load(const Locale('en'));
  });

  group('parser', () {
    test('every badge of the page: picture, name, link and month', () {
      final badges = parseMalBadgesPage(_fixture());
      expect(badges, hasLength(18));
      final first = badges.first;
      expect(first.name, '20th Anniversary');
      expect(first.imageUrl, 'https://cdn.myanimelist.net/images/badge/2024_20th.png');
      expect(first.url, 'https://myanimelist.net/20th_anniversary');
      expect(first.earnedAt, DateTime(2024, 11));
      expect(badges.every((b) => b.imageUrl.startsWith('https://cdn.myanimelist.net/')), isTrue);
    });

    test('a profile without badges gives an empty list', () {
      expect(parseMalBadgesPage('<html><body><div id="content"></div></body></html>'), isEmpty);
    });
  });

  group('card', () {
    final badges = [
      MalBadge(
        name: '20th Anniversary',
        imageUrl: 'https://cdn.myanimelist.net/images/badge/2024_20th.png',
        url: 'https://myanimelist.net/20th_anniversary',
        earnedAt: DateTime(2024, 11),
      ),
      const MalBadge(name: 'Oshi no Ko', imageUrl: 'https://cdn.myanimelist.net/images/badge/x.png'),
    ];

    testWidgets('no badge: nothing is drawn', (tester) async {
      await _pump(tester, (_) async => const []);
      expect(find.byType(Card), findsNothing);
      expect(find.text('Badges · 0'), findsNothing);
    });

    testWidgets('a failed page: nothing is drawn', (tester) async {
      await _pump(tester, (_) async => throw const SocketException('down'));
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('badges: the count, every name, and a sheet with the month', (tester) async {
      await _pump(tester, (_) async => badges);
      expect(find.text('Badges · 2'), findsOneWidget);
      expect(find.text('20th Anniversary'), findsOneWidget);
      expect(find.text('Oshi no Ko'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('20th Anniversary'));
      await tester.pumpAndSettle();
      expect(find.text('Earned in November 2024'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('a badge without a link has no Open button', (tester) async {
      await _pump(tester, (_) async => badges);
      await tester.tap(find.bySemanticsLabel('Oshi no Ko'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);
    });
  });
}
