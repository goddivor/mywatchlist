import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/user_updates_section.dart';
import 'package:mywatchlist/services/api/MAL/web/friends_updates_api.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:shared_preferences/shared_preferences.dart';


String _fixture(String name) => File('test/units/mal-detail-friends/fixtures/$name').readAsStringSync();

class _FakeCookies implements WebViewCookies {
  String? jar;
  _FakeCookies([this.jar]);
  @override
  Future<String?> read(String url) async => jar;
  @override
  Future<void> clear(String url) async => jar = null;
}

Future<MalWebSession> _connected() async {
  final session = MalWebSession(cookies: _FakeCookies('MALSESSIONID=abc; is_logged_in=1'), platformSupported: true);
  expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
  return session;
}

MalWebSession _disconnected() => MalWebSession(cookies: _FakeCookies(), platformSupported: true);

/// A fake stats page: the default and `?m=top` rows for a signed-in viewer.
FriendsUpdatesApi _api(MalWebSession session, List<Uri> sent, {String page = 'anime_friends.html', String? top = 'anime_top.html'}) {
  final client = MalWebClient(
    session: session,
    minGap: Duration.zero,
    clientFactory: () => MockClient((r) async {
      sent.add(r.url);
      final raw = r.url.query.contains('m=top') && top != null ? _fixture(top) : _fixture(page);
      // No network pictures in widget tests (the image cache needs path_provider).
      final body = raw.replaceAll(RegExp(r'background-image:url\([^)]*\)'), '');
      return http.Response(body, 200, headers: {'content-type': 'text/html; charset=utf-8'});
    }),
  );
  return FriendsUpdatesApi(client: client);
}

void main() {
  final now = DateTime.utc(2026, 10, 30, 12);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('parser (trimmed live pages)', () {
    test('anime: default My Friends page', () {
      final page = parseFriendsUpdates(_fixture('anime_friends.html'), now: now);
      expect(page.signedIn, isTrue);
      expect(page.updates, hasLength(18));
      final first = page.updates.first;
      expect(first.username, 'Ma1cus');
      expect(first.score, 10);
      expect(first.status, 'On-Hold');
      expect(first.episodesSeen, 1156);
      expect(first.episodesTotal, isNull);
      expect(first.imageUrl, contains('userimages'));
      expect(page.updates[2].score, isNull);
      expect(page.updates[2].status, 'Watching');
    });

    test('anime: My Top Friends page (current tab is not a link)', () {
      final page = parseFriendsUpdates(_fixture('anime_top.html'), now: now);
      expect(page.signedIn, isTrue);
      expect(page.updates.map((u) => u.username), ['Grest', 'Aktao', 'KitoKunX']);
    });

    test('manga: volumes and chapters', () {
      final page = parseFriendsUpdates(_fixture('manga_friends.html'), now: now);
      expect(page.signedIn, isTrue);
      expect(page.updates, hasLength(11));
      final first = page.updates.first;
      expect(first.username, 'Buddy2604');
      expect(first.status, 'Reading');
      expect(first.volumesRead, 15);
      expect(first.volumesTotal, isNull);
      expect(first.chaptersRead, 386);
      expect(first.episodesSeen, isNull);
    });

    test('a page without the friends tabs is not signed in', () {
      final guest = _fixture('anime_friends.html').replaceAll(RegExp(r'My Top Friends|My Friends'), 'x');
      expect(parseFriendsUpdates(guest, now: now).signedIn, isFalse);
      expect(parseFriendsUpdates('<html></html>').updates, isEmpty);
    });
  });

  group('api', () {
    test('friends and top friends URLs, anime and manga', () async {
      final sent = <Uri>[];
      final api = _api(await _connected(), sent);
      await api.fetch('anime', 21, FriendsSource.friends);
      await api.fetch('manga', 13, FriendsSource.top);
      expect(sent[0].path, '/anime/21/_/stats');
      expect(sent[0].query, '');
      expect(sent[1].path, '/manga/13/_/stats');
      expect(sent[1].query, 'm=top');
    });

    test('no session: nothing is requested', () async {
      final sent = <Uri>[];
      final api = _api(_disconnected(), sent);
      expect(await api.hasSession, isFalse);
      await expectLater(api.fetch('anime', 21, FriendsSource.friends), throwsA(isA<MalWebNoSession>()));
      expect(sent, isEmpty);
    });
  });

  group('section', () {
    Widget section(FriendsUpdatesApi api, {String category = 'anime'}) => FriendsUpdatesSection(
          id: 21,
          category: category,
          horizPadding: 0,
          api: api,
          everyoneBuilder: (_) => const Text('EVERYONE VIEW'),
        );

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(
          localizationsDelegates: const [S.delegate],
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
    }

    testWidgets('signed in: Friends is the default tab and shows the rows', (tester) async {
      await pump(tester, section(_api(await _connected(), [])));
      expect(find.byKey(const ValueKey('friends-tab-friends')), findsOneWidget);
      expect(find.byKey(const ValueKey('friends-tab-top')), findsOneWidget);
      expect(find.byKey(const ValueKey('friends-tab-everyone')), findsOneWidget);
      expect(find.text('Ma1cus'), findsOneWidget);
      expect(find.text('EVERYONE VIEW'), findsNothing);
      expect(find.byType(UserUpdatesGrid), findsOneWidget);
    });

    testWidgets('Top friends tab loads ?m=top', (tester) async {
      final sent = <Uri>[];
      await pump(tester, section(_api(await _connected(), sent)));
      await tester.tap(find.byKey(const ValueKey('friends-tab-top')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      await tester.pump();
      expect(sent.last.query, 'm=top');
      expect(find.text('KitoKunX'), findsOneWidget);
      expect(find.text('Grest'), findsOneWidget);
    });

    testWidgets('Everyone tab shows the existing source', (tester) async {
      await pump(tester, section(_api(await _connected(), [])));
      await tester.tap(find.byKey(const ValueKey('friends-tab-everyone')));
      await tester.pump();
      expect(find.text('EVERYONE VIEW'), findsOneWidget);
      expect(find.text('Ma1cus'), findsNothing);
    });

    testWidgets('empty friends table: Everyone is the default', (tester) async {
      // A signed-in page with no row.
      final empty = FriendsUpdatesApi(
        client: MalWebClient(
          session: await _connected(),
          minGap: Duration.zero,
          clientFactory: () => MockClient((r) async => http.Response(
              '<html><body><span>My Top Friends | My Friends | All Members</span></body></html>', 200)),
        ),
      );
      await pump(tester, section(empty));
      expect(find.text('EVERYONE VIEW'), findsOneWidget);
      expect(find.byKey(const ValueKey('friends-tab-friends')), findsOneWidget);
    });

    testWidgets('no session: no tabs, only Everyone', (tester) async {
      final sent = <Uri>[];
      await pump(tester, section(_api(_disconnected(), sent)));
      expect(find.byKey(const ValueKey('friends-tab-friends')), findsNothing);
      expect(find.text('EVERYONE VIEW'), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('a row opens the friend profile (tappable with a name)', (tester) async {
      await pump(tester, section(_api(await _connected(), [])));
      final inkwell = tester.widget<InkWell>(find.descendant(of: find.byType(UserUpdatesGrid), matching: find.byType(InkWell)).first);
      expect(inkwell.onTap, isNotNull);
    });
  });
}
