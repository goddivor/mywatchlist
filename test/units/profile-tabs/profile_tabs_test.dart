import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/clubs_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/friends_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/history_section.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';

import '../../helpers/no_network.dart';

String _fixture(String name) =>
    File('test/units/profile-tabs/fixtures/$name').readAsStringSync();

/// A source that never answers, as Jikan does on the owner's network.
Future<T> _hang<T>() => Completer<T>().future;

Map<String, dynamic> _friendsEnvelope(List<String> names) => {
      'data': {
        'data': [
          for (final n in names)
            {
              'user': {'username': n},
              'last_online': '2 hours ago',
              'friends_since': 'Oct 5, 2020',
            },
        ],
        'pagination': {'has_next_page': false},
      },
    };

Widget _host(Widget tab) => MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ),
          ],
          body: tab,
        ),
      ),
    );

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid');
    await S.load(const Locale('en'));
  });

  setUp(() {
    ProfileTabsSource.reset();
    ProfileTabsSource.parseInline = true;
    ProfileTabsSource.budget = const Duration(seconds: 1);
    // Everything dead unless a test says otherwise.
    ProfileTabsSource.fetchPage = (url, timeout) => _hang<String>().timeout(timeout);
    ProfileTabsSource.apiFriends = (u, p) => _hang();
    ProfileTabsSource.apiHistory = (u, t) => _hang();
    ProfileTabsSource.apiClubs = (u) => _hang();
  });

  tearDown(ProfileTabsSource.reset);

  group('MAL pages (saved fixtures)', () {
    test('friends: names, real avatar, date without the prefix', () {
      final page = parseFriendsPage(_fixture('friends_page.html'));
      expect(page.friends.length, greaterThanOrEqualTo(2));
      final first = page.friends.first;
      expect(first.username, 'CelesteElaine');
      expect(first.imageUrl, startsWith('https://cdn.myanimelist.net/s/common/userimages/'));
      expect(first.imageUrl, isNot(contains('spacer.gif')));
      expect(first.lastOnline, '3 minutes ago');
      expect(first.friendsSince, 'May 4, 2008 9:29 PM');
      expect(page.hasNextPage, isFalse);
    });

    test('clubs: only club links with an id, no site menu entry', () {
      final clubs = parseClubsPage(_fixture('clubs_page.html'));
      expect(clubs.map((c) => c.id), [263, 328, 241, 636, 10689, 134].take(clubs.length));
      expect(clubs.first.name, "1, 2, 3 Let's Switch! (this club's name)");
      expect(clubs.every((c) => c.id != null && (c.name ?? '').isNotEmpty), isTrue);
    });

    test('history: rows with id, progress and time; the empty page is an empty list', () {
      final rows = parseHistoryPage((_fixture('history_anime_page.html'), 'anime'));
      expect(rows, isNotEmpty);
      expect(rows.first.id, 63801);
      expect(rows.first.title, 'Ranma ½ (2024) 3rd Season');
      expect(rows.first.progress, contains('3'));
      expect(rows.first.dayLabel, 'Oct 23');
      expect(rows.first.category, 'anime');
      expect(parseHistoryPage((_fixture('history_manga_empty.html'), 'manga')), isEmpty);
    });

    test('a page that is not MAL (challenge, maintenance) is an error, not an empty list', () {
      expect(() => parseFriendsPage('<html><body>Just a moment...</body></html>'),
          throwsFormatException);
    });
  });

  group('source', () {
    test('friends come from the MAL page first', () async {
      ProfileTabsSource.fetchPage = (url, timeout) async {
        expect(url.path, '/profile/Xinil/friends');
        return _fixture('friends_page.html');
      };
      final page = await ProfileTabsSource.friends('Xinil');
      expect(page.friends.first.username, 'CelesteElaine');
    });

    test('second friends page asks MAL for offset=100', () async {
      Uri? asked;
      ProfileTabsSource.fetchPage = (url, timeout) async {
        asked = url;
        return _fixture('friends_page.html');
      };
      await ProfileTabsSource.friends('Xinil', page: 2);
      expect(asked!.queryParameters['offset'], '100');
    });

    test('friends fall back to the mwl-api route when the MAL page fails', () async {
      ProfileTabsSource.fetchPage = (url, timeout) async => throw const SocketException('down');
      ProfileTabsSource.apiFriends = (u, p) async => _friendsEnvelope(['anna', 'bob']);
      final page = await ProfileTabsSource.friends('Xinil');
      expect(page.friends.map((f) => f.username), ['anna', 'bob']);
    });

    test('both sources dead: friends fail within the budget', () async {
      final clock = Stopwatch()..start();
      await expectLater(ProfileTabsSource.friends('Xinil'), throwsA(isA<Exception>()));
      expect(clock.elapsed, lessThan(const Duration(milliseconds: 2500)));
    });

    test('clubs and history fail within the budget too', () async {
      final clock = Stopwatch()..start();
      await expectLater(ProfileTabsSource.clubs('Xinil'), throwsA(isA<Exception>()));
      await expectLater(ProfileTabsSource.historyAll('Xinil'), throwsA(isA<Exception>()));
      expect(clock.elapsed, lessThan(const Duration(milliseconds: 5000)));
    });

    test('history keeps the anime rows when the manga page fails', () async {
      ProfileTabsSource.fetchPage = (url, timeout) async {
        if (url.path.endsWith('/anime')) return _fixture('history_anime_page.html');
        throw const SocketException('down');
      };
      final rows = await ProfileTabsSource.historyAll('Luna');
      expect(rows, isNotEmpty);
      expect(rows.every((r) => r.category == 'anime'), isTrue);
    });

    test('clubs fall back to the backend rows, deduplicated, ids required', () async {
      ProfileTabsSource.fetchPage = (url, timeout) async => throw const SocketException('down');
      ProfileTabsSource.apiClubs = (u) async => {
            'data': {
              'clubs': [
                {'id': 1, 'name': 'A'},
                {'id': 1, 'name': 'A again'},
                {'id': null, 'name': 'menu'},
                {'id': 2, 'name': 'B'},
              ],
            },
          };
      final clubs = await ProfileTabsSource.clubs('x');
      expect(clubs.map((c) => c.id), [1, 2]);
    });
  });

  group('tabs with Jikan and MAL both dead', () {
    testWidgets('Friends ends in an error with Retry, then loads on Retry', (tester) async {
      await tester.pumpWidget(_host(const FriendsSection(username: 'Xinil')));
      expect(find.text('Loading friends…'), findsOneWidget);

      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.text('Loading friends…'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);

      ProfileTabsSource.apiFriends = (u, p) async => _friendsEnvelope(['anna', 'bob']);
      ProfileTabsSource.fetchPage = (url, timeout) async => throw const SocketException('down');
      await tester.tap(find.text('Retry'));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('anna'), findsOneWidget);
      expect(find.text('2 friends'), findsOneWidget);
    });

    testWidgets('Friends with no friend shows the empty state', (tester) async {
      ProfileTabsSource.apiFriends = (u, p) async => _friendsEnvelope([]);
      ProfileTabsSource.fetchPage = (url, timeout) async => throw const SocketException('down');
      await tester.pumpWidget(_host(const FriendsSection(username: 'Xinil')));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('No friends yet.'), findsOneWidget);
    });

    testWidgets('Clubs ends in an error with Retry', (tester) async {
      await tester.pumpWidget(_host(const ClubsSection(username: 'Xinil')));
      expect(find.text('Loading clubs…'), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 3));
      expect(find.text('Retry'), findsOneWidget);

      ProfileTabsSource.fetchPage = (url, timeout) async => _fixture('clubs_page.html');
      await tester.tap(find.text('Retry'));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Anime Expo Club'), findsOneWidget);
    });

    testWidgets('History ends in an error with Retry', (tester) async {
      await tester.pumpWidget(_host(const HistorySection(username: 'Luna')));
      expect(find.text('Loading history…'), findsOneWidget);
      await _pumpFor(tester, const Duration(seconds: 4));
      expect(find.text('Retry'), findsOneWidget);

      ProfileTabsSource.fetchPage = (url, timeout) async => url.path.endsWith('/anime')
          ? _fixture('history_anime_page.html')
          : _fixture('history_manga_empty.html');
      await tester.tap(find.text('Retry'));
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(find.textContaining('Ranma'), findsWidgets);
    });
  });

  group('friend model', () {
    test('Jikan wording survives and the MAL prefix is dropped', () {
      final page = parseFriendsEnvelope({
        'data': {
          'friends': [
            {
              'user': {'username': 'a', 'imageUrl': 'https://x/a.jpg'},
              'lastOnline': 'Now',
              'friendSince': 'Friends since Jan 1, 2020',
            },
          ],
        },
      });
      expect(page.friends.single.friendsSince, 'Jan 1, 2020');
      expect(page.friends.single.imageUrl, 'https://x/a.jpg');
    });
  });
}
