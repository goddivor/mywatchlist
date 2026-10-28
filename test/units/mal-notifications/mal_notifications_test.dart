import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/notifications_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:mywatchlist/services/notifications/mal_hub_texts.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/widgets/mal_web/notification_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/fakes.dart';

String _fixture(String name) => File('test/units/mal-notifications/fixtures/$name').readAsStringSync();

class _FakeCookies implements WebViewCookies {
  String? jar;
  _FakeCookies([this.jar]);
  @override
  Future<String?> read(String url) async => jar;
  @override
  Future<void> clear(String url) async => jar = null;
}

const _jar = 'MALSESSIONID=abc123; is_logged_in=1';

void _signInMal(String name) {
  UserMalV2.instance
    ..authResponse = AuthResponse(accessToken: 'token')
    ..username = name
    ..needsReLogin = false;
}

void _signOutMal() {
  UserMalV2.instance
    ..authResponse = null
    ..username = null
    ..needsReLogin = false;
}

Future<MalWebSession> _connected() async {
  final session = MalWebSession(cookies: _FakeCookies(_jar), platformSupported: true);
  expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
  return session;
}

/// An API answering from memory.
class _FakeApi extends MalNotificationsApi {
  _FakeApi(this.feed);
  MalNotificationFeed feed;
  bool accept = true;
  Object? error;
  final List<List<String>> markedRead = [];
  final List<String> answered = [];

  @override
  Future<MalNotificationFeed> fetch() async {
    final e = error;
    if (e != null) throw e;
    return feed;
  }

  @override
  Future<bool> markRead(Iterable<MalNotificationItem> items) async {
    markedRead.add([for (final i in items) i.id]);
    return accept;
  }

  @override
  Future<bool> acceptFriendRequests(Iterable<MalNotificationItem> items) async {
    answered.addAll(items.map((i) => 'accept:${i.id}'));
    return accept;
  }

  @override
  Future<bool> denyFriendRequests(Iterable<MalNotificationItem> items) async {
    answered.addAll(items.map((i) => 'deny:${i.id}'));
    return accept;
  }
}

class _FakeNotifier implements MalHubNotifier {
  bool permitted = true;
  final Map<MalHubChannel, List<HubSystemNotification>> shown = {};
  final List<int> cancelled = [];

  @override
  bool get isSupported => true;
  @override
  Future<bool> allowed() async => permitted;
  @override
  Future<void> show(MalHubChannel channel, List<HubSystemNotification> notifications) async =>
      (shown[channel] ??= []).addAll(notifications);
  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

MalNotificationItem _item(String id, {bool read = false, DateTime? at, String type = 'profile_comment'}) =>
    MalNotificationItem.fromJson({
      'id': id,
      'typeIdentifier': type,
      'isRead': read,
      'createdAt': (at ?? DateTime.utc(2026, 10, 28, 12)).millisecondsSinceEpoch ~/ 1000,
      'commentUserName': 'Ren_99',
      'url': 'https://myanimelist.net/profile/goddivor',
      'text': 'hello $id',
    })!;

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    MalNotificationsApi.parseInline = true;
    FriendsActivityApi.parseInline = true;
    _signInMal('goddivor');
  });

  tearDown(_signOutMal);

  group('notification page', () {
    late MalNotificationFeed feed;
    setUp(() => feed = parseNotificationPage(_fixture('notification_page_reconstructed.html'))!);

    test('reads every type MAL\'s script knows, plus an unknown one', () {
      expect(feed.items, hasLength(14));
      expect(feed.history, hasLength(1));
      expect(feed.unreadDigest, 11);
      final kinds = feed.items.map((i) => i.kind).toSet();
      for (final kind in MalNotificationKind.values) {
        expect(kinds, contains(kind), reason: '$kind');
      }
      expect(feed.all, hasLength(15));
      expect(feed.unreadCount, 12);
    });

    test('ids keep MAL\'s own type; text with braces and "};" is intact', () {
      final request = feed.items.first;
      expect(request.id, '9000001');
      expect(request.rawId, '9000001');
      expect(feed.items[1].rawId, 9000002);
      final comment = feed.items.firstWhere((i) => i.kind == MalNotificationKind.profileComment);
      expect(comment.text, 'Did you finish Frieren yet? {braces}; and "quotes" };');
      expect(comment.actorName, 'Ren_99');
      expect(comment.createdAt, DateTime.fromMillisecondsSinceEpoch((1793223000 - 4 * 3600) * 1000, isUtc: true));
    });

    test('targets: anime for airing and related, topic for forum items, profile for friends', () {
      MalNotificationItem of(MalNotificationKind k) => feed.items.firstWhere((i) => i.kind == k);
      expect(of(MalNotificationKind.onAir).animeId, 59978);
      expect(of(MalNotificationKind.relatedAnimeAdd).animeId, 62000);
      expect(of(MalNotificationKind.forumQuote).targetUrl, 'https://myanimelist.net/forum/?topicid=2190000');
      expect(of(MalNotificationKind.friendRequest).targetUrl, 'https://myanimelist.net/profile/Hikari_K');
      expect(of(MalNotificationKind.friendRequest).isPendingFriendRequest, isTrue);
      expect(of(MalNotificationKind.userMentionInClubComment).targetUrl, 'https://myanimelist.net/clubs.php?cid=12345');
      expect(of(MalNotificationKind.paymentStripe).planName, 'MAL Supporter');
      expect(of(MalNotificationKind.clubMassMessageInForum).clubName, 'Anime Watch Party');
    });

    test('every item has a sentence in English and French', () async {
      for (final i in feed.all) {
        expect(describeMalNotification(i).headline, isNotEmpty);
      }
      final fr = await S.load(const Locale('fr', 'FR'));
      final quote = feed.items.firstWhere((i) => i.kind == MalNotificationKind.forumQuote);
      expect(describeMalNotification(quote, fr).headline,
          'Akane a cité votre message dans Sousou no Frieren Season 2 Episode 4 Discussion');
      await S.load(const Locale('en'));
      expect(describeMalNotification(quote).headline,
          'Akane quoted your post in Sousou no Frieren Season 2 Episode 4 Discussion');
    });

    test('separate items assignments and request-items.json are read too', () {
      final page = parseNotificationPage(
          '<script>window.MAL.notification.items = [{"id":1,"typeIdentifier":"on_air","animes":[{"title":"A","url":"/anime/5/A"}]}];</script>');
      expect(page!.items.single.animeId, 5);
      expect(page.items.single.animes.single.url, 'https://myanimelist.net/anime/5/A');
      expect(parseNotificationPage('<html>nothing</html>'), isNull);
      expect(parseRequestItems(_fixture('request_items_reconstructed.json'))!.items, hasLength(5));
    });
  });

  group('MalNotificationsApi', () {
    late List<http.Request> sent;

    MalNotificationsApi api(MalWebSession session, Future<http.Response> Function(http.Request) handler) {
      sent = [];
      MockClient mock() => MockClient((r) {
            sent.add(r);
            return handler(r);
          });
      return MalNotificationsApi(
        client: MalWebClient(session: session, minGap: Duration.zero, clientFactory: mock),
        httpClient: mock,
      );
    }

    test('without a website session nothing is sent', () async {
      final session = MalWebSession(cookies: _FakeCookies(), platformSupported: true);
      final a = api(session, (r) async => http.Response('', 200));
      await expectLater(a.fetch(), throwsA(isA<MalWebNoSession>()));
      expect(sent, isEmpty);
    });

    test('reads the page with the session cookies', () async {
      final session = await _connected();
      final a = api(session, (r) async => http.Response(_fixture('notification_page_reconstructed.html'), 200));
      final feed = await a.fetch();
      expect(feed.items, hasLength(14));
      expect(sent.single.url.path, '/notification');
      expect(sent.single.headers['Cookie'], contains('MALSESSIONID=abc123'));
    });

    test('a redirect to the login page expires the session', () async {
      final session = await _connected();
      final a = api(session, (r) async =>
          http.Response('', 303, headers: {'location': 'https://myanimelist.net/login.php?from=%2Fnotification'}));
      await expectLater(a.fetch(), throwsA(isA<MalWebSessionExpired>()));
      expect(session.state, MalWebSessionState.expired);
    });

    test('mark read posts JSON ids as MAL sent them, with the page token', () async {
      final session = await _connected();
      final a = api(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='tok1'>", 200);
        return http.Response('true', 200);
      });
      final feed = parseNotificationPage(_fixture('notification_page_reconstructed.html'))!;
      expect(await a.markRead(feed.items.take(3)), isTrue);
      final post = sent.last;
      expect(post.url.path, '/notification/api/check-items-as-read.json');
      expect(post.headers['Content-Type'], startsWith('application/json'));
      expect(post.headers['Cookie'], contains('MALSESSIONID=abc123'));
      // The third item is already read: only the two unread ones are sent.
      expect(jsonDecode(post.body), {
        'notification_ids': ['9000001', 9000002],
        'csrf_token': 'tok1',
      });
    });

    test('a refused token is read again once; accept and deny use their endpoints', () async {
      final session = await _connected();
      var tokens = 0;
      final a = api(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='tok${++tokens}'>", 200);
        final body = jsonDecode(r.body) as Map;
        return body['csrf_token'] == 'tok2' ? http.Response('{}', 200) : http.Response('', 403);
      });
      final request = parseNotificationPage(_fixture('notification_page_reconstructed.html'))!.items.first;
      expect(await a.acceptFriendRequests([request]), isTrue);
      expect(sent.where((r) => r.method == 'POST').map((r) => r.url.path).toSet(),
          {'/notification/api/accept-friend-request.json'});
      expect(await a.denyFriendRequests([request]), isTrue);
      expect(sent.last.url.path, '/notification/api/deny-friend-request.json');
    });

    test('an error answer is a refusal', () async {
      final session = await _connected();
      final a = api(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='t'>", 200);
        return http.Response('{"errors":[{"message":"bad"}]}', 200);
      });
      expect(await a.markRead([_item('1')]), isFalse);
    });
  });

  group('friends activity', () {
    test('reads MAL\'s RSS feeds: status, progress, type, date', () {
      final rows = parseFriendFeed(_fixture('rss_rw_xinil_2026-10-28.xml'), friend: 'Xinil', category: 'anime');
      expect(rows, hasLength(15));
      final drop = rows.firstWhere((r) => r.title == 'Kill la Kill');
      expect(drop.isDropped, isTrue);
      expect(drop.malId, 18679);
      expect(drop.mediaType, 'TV');
      expect(drop.progress, 2);
      expect(drop.total, 24);
      expect(drop.date, DateTime.utc(2020, 8, 7, 23, 30, 2));
      final manga = parseFriendFeed(_fixture('rss_rm_goddivor_2026-10-28.xml'), friend: 'goddivor', category: 'manga');
      expect(manga, hasLength(15));
      final planned = manga.firstWhere((r) => r.status == 'plan_to_read' && r.total == null);
      expect(planned.progress, 0);
      expect(friendProgressLabel(planned), 'Ch. 0/?');
      expect(manga.where((r) => r.status == 'reading'), isNotEmpty);
      expect(friendStatusLabel(drop), 'Dropped');
    });

    test('merges the friends\' feeds newest first, skips a failing feed', () async {
      final asked = <String>[];
      final api = FriendsActivityApi(
        loadFriends: (user) async => [
          ProfileFriend(username: 'goddivor', imageUrl: 'https://cdn/x.jpg', lastSeenAt: DateTime.utc(2026, 10, 28)),
          ProfileFriend(username: 'Xinil', lastSeenAt: DateTime.utc(2026, 1, 1)),
          ProfileFriend(username: 'broken'),
        ],
        fetchFeed: (url) async {
          asked.add(url.toString());
          final u = url.queryParameters['u'];
          final type = url.queryParameters['type'];
          if (u == 'broken') throw const SocketException('offline');
          if (u == 'Xinil') return type == 'rw' ? _fixture('rss_rw_xinil_2026-10-28.xml') : null;
          return _fixture(type == 'rw' ? 'rss_rw_goddivor_2026-10-28.xml' : 'rss_rm_goddivor_2026-10-28.xml');
        },
      );
      final partials = <int>[];
      final rows = await api.load('me', onProgress: (p) => partials.add(p.length));
      expect(rows, hasLength(45));
      expect(asked, hasLength(6));
      expect(asked.first, contains('u=goddivor'));
      expect(rows.first.friend, 'goddivor');
      expect(rows.first.friendImageUrl, 'https://cdn/x.jpg');
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i - 1].date!.isBefore(rows[i].date!), isFalse);
      }
      expect(partials, isNotEmpty);
    });
  });

  group('hub', () {
    late MalWebSession session;
    late _FakeApi api;
    late MalNotificationsHub hub;

    setUp(() async {
      session = await _connected();
      api = _FakeApi(MalNotificationFeed(items: [_item('1'), _item('2'), _item('3', read: true)]));
      hub = MalNotificationsHub(api: api, session: session, malSignedIn: () => true);
    });

    test('counts the unread items; mark read is shown at once and kept on success', () async {
      await hub.refresh();
      expect(hub.status, MalHubStatus.ready);
      expect(hub.unread.value, 2);
      final read = <String>[];
      hub.onItemsRead = read.addAll;
      expect(await hub.markRead([hub.items.first]), isTrue);
      expect(hub.unread.value, 1);
      expect(read, ['1']);
      expect(await hub.markAllRead(), isTrue);
      expect(api.markedRead.last, ['2']);
      expect(hub.unread.value, 0);
    });

    test('a refused mark read puts the item back to unread', () async {
      await hub.refresh();
      api.accept = false;
      expect(await hub.markRead([hub.items.first]), isFalse);
      expect(hub.unread.value, 2);
      expect(hub.items.first.isRead, isFalse);
    });

    test('no account, no session and a dead session are told apart', () async {
      final none = MalNotificationsHub(api: api, session: session, malSignedIn: () => false);
      await none.refresh();
      expect(none.status, MalHubStatus.noAccount);
      FlutterSecureStorage.setMockInitialValues({});
      final noWeb = MalNotificationsHub(
          api: api, session: MalWebSession(cookies: _FakeCookies(), platformSupported: true), malSignedIn: () => true);
      await noWeb.refresh();
      expect(noWeb.status, MalHubStatus.noSession);
      api.error = const MalWebSessionExpired();
      await hub.refresh();
      expect(hub.status, MalHubStatus.expired);
    });

    test('a declined friend request leaves the list, an accepted one is read', () async {
      final feed = parseNotificationPage(_fixture('notification_page_reconstructed.html'))!;
      api.feed = feed;
      await hub.refresh();
      final request = hub.items.firstWhere((i) => i.kind == MalNotificationKind.friendRequest);
      expect(await hub.answerFriendRequest(request, accept: true), isTrue);
      expect(hub.items.firstWhere((i) => i.id == request.id).isPendingFriendRequest, isFalse);
      expect(await hub.answerFriendRequest(request, accept: false), isTrue);
      expect(hub.items.any((i) => i.id == request.id), isFalse);
      expect(api.answered, ['accept:9000001', 'deny:9000001']);
    });
  });

  group('poller', () {
    final now = DateTime.utc(2026, 10, 28, 12);
    late _FakeApi api;
    late _FakeNotifier notifier;
    late MalNotificationsHub hub;
    late NotificationPreferences prefs;
    late List<FriendActivity> friendRows;

    MalHubPoller poller() => MalHubPoller(
          hub: hub,
          notifier: notifier,
          readPrefs: () => prefs,
          clock: () => now,
        );

    setUp(() async {
      final session = await _connected();
      api = _FakeApi(MalNotificationFeed(items: [
        _item('new', at: now.subtract(const Duration(hours: 2))),
        _item('old', at: now.subtract(const Duration(days: 10))),
        _item('read', read: true, at: now.subtract(const Duration(hours: 1))),
      ]));
      friendRows = [];
      hub = MalNotificationsHub(
        api: api,
        session: session,
        malSignedIn: () => true,
        malUsername: () => 'goddivor',
        clock: () => now,
        friends: FriendsActivityApi(
          loadFriends: (_) async => const [ProfileFriend(username: 'Ren_99')],
          fetchFeed: (_) async => null,
        ),
      );
      notifier = _FakeNotifier();
      prefs = NotificationPreferences(subscribedAt: now);
    });

    test('first run notifies only recent unread items, then never twice', () async {
      final p = poller();
      expect(await p.pollHub(), 1);
      final shown = notifier.shown[MalHubChannel.hub]!;
      expect(shown.single.title, 'Ren_99 commented on your profile');
      expect(shown.single.body, 'hello new');
      expect(shown.single.id, hubNotificationId('new'));
      expect(MalHubPayload.parse(shown.single.payload),
          (id: 'new', url: 'https://myanimelist.net/profile/goddivor'));
      expect(await p.pollHub(), 0);
      api.feed = MalNotificationFeed(items: [_item('newer', at: now.subtract(const Duration(days: 9))), ...api.feed.items]);
      expect(await p.pollHub(), 1, reason: 'after the first run, any unseen unread item counts');
    });

    test('an item read elsewhere loses its system notification', () async {
      final p = poller();
      await p.pollHub();
      api.feed = MalNotificationFeed(items: [for (final i in api.feed.items) i.copyWith(isRead: true)]);
      await p.pollHub();
      expect(notifier.cancelled, contains(hubNotificationId('new')));
    });

    test('notifications off, no permission or the screen switch off: nothing is shown', () async {
      prefs = const NotificationPreferences();
      expect(await poller().pollHub(), 0);
      SharedPreferences.setMockInitialValues({});
      prefs = NotificationPreferences(subscribedAt: now);
      notifier.permitted = false;
      expect(await poller().pollHub(), 0);
      SharedPreferences.setMockInitialValues({});
      notifier.permitted = true;
      final p = poller();
      await p.setPushHub(false);
      expect(await p.pollHub(), 0);
      expect(hub.unread.value, 2, reason: 'the badge still follows the hub');
      expect(notifier.shown, isEmpty);
    });

    test('friends: the first check remembers, the next one notifies new drops and completions', () async {
      final hub2 = MalNotificationsHub(
        api: api,
        session: hub.session,
        malSignedIn: () => true,
        malUsername: () => 'goddivor',
        clock: () => now,
        friends: FriendsActivityApi(
          loadFriends: (_) async => const [ProfileFriend(username: 'Ren_99')],
          fetchFeed: (url) async {
            if (url.queryParameters['type'] != 'rw') return null;
            final items = [
              for (final r in friendRows)
                '<item><title>${r.title} - TV</title><link>https://myanimelist.net/anime/${r.malId}/x</link>'
                    '<description><![CDATA[${r.statusText} - ${r.progress} of ${r.total} episodes]]></description>'
                    '<pubDate>Wed, 28 Oct 2026 03:00:00 -0700</pubDate></item>',
            ];
            return '<rss><channel>${items.join()}</channel></rss>';
          },
        ),
      );
      FriendActivity row(int id, String status, int progress) => FriendActivity(
          friend: 'Ren_99', category: 'anime', malId: id, title: 'Show $id', link: '', statusText: status, progress: progress, total: 12);
      friendRows = [row(1, 'Watching', 3)];
      final p = MalHubPoller(hub: hub2, notifier: notifier, readPrefs: () => prefs, clock: () => now);
      expect(await p.pollFriends(), 0);
      friendRows = [row(2, 'Dropped', 4), row(3, 'Completed', 12), row(1, 'Watching', 4)];
      expect(await p.pollFriends(), 2);
      final titles = notifier.shown[MalHubChannel.friends]!.map((n) => n.title).toList();
      expect(titles, ['Ren_99 dropped Show 2', 'Ren_99 completed Show 3']);
      expect(await p.pollFriends(), 0);
    });
  });

  group('payloads', () {
    test('parse', () {
      expect(MalHubPayload.parse('anime:5'), isNull);
      expect(MalHubPayload.parse(MalHubPayload.screen), (id: null, url: null));
      expect(MalHubPayload.parse('malhub:|https://myanimelist.net/anime/1/x'),
          (id: null, url: 'https://myanimelist.net/anime/1/x'));
    });

    test('NotificationService hands hub taps to the hub opener, the rest to onOpen', () async {
      final backend = FakeBackend(launch: 'malhub:42|https://myanimelist.net/anime/1/x');
      final hubTaps = <String>[];
      final service = NotificationService(backend: backend, openHubPayload: hubTaps.add);
      await service.init();
      expect(service.takeLaunchPayload(), isNull, reason: 'not a home-shell route');
      final opened = <String>[];
      service.onOpen = opened.add;
      service.flushPendingTap();
      expect(hubTaps, ['malhub:42|https://myanimelist.net/anime/1/x']);
      backend.tapHandler!('malhub:7|');
      backend.tapHandler!('anime:5114');
      expect(hubTaps.last, 'malhub:7|');
      expect(opened, ['anime:5114']);
      service.dispose();
    });
  });

  group('screen', () {
    Widget host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: child,
        );

    MalHubPoller poller(MalNotificationsHub hub) =>
        MalHubPoller(hub: hub, notifier: _FakeNotifier(), readPrefs: () => const NotificationPreferences());

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('without a website session: one-tap Connect', (tester) async {
      final hub = MalNotificationsHub(
        api: _FakeApi(const MalNotificationFeed()),
        session: MalWebSession(cookies: _FakeCookies(), platformSupported: true),
        malSignedIn: () => true,
        malUsername: () => null,
      );
      await tester.pumpWidget(host(MalNotificationsScreen(hub: hub, poller: poller(hub))));
      await settle(tester);
      expect(find.text(S.current.Ms_Connect), findsOneWidget);
      expect(find.text(S.current.Mn_Connect_Title), findsOneWidget);
    });

    testWidgets('lists the hub in French, filters, marks read', (tester) async {
      final session = await tester.runAsync(_connected);
      final feed = parseNotificationPage(_fixture('notification_page_reconstructed.html')
          .replaceAll(RegExp(r'https:\\/\\/cdn\.myanimelist\.net[^"]*'), ''))!;
      final api = _FakeApi(feed);
      final hub = MalNotificationsHub(api: api, session: session, malSignedIn: () => true, malUsername: () => 'goddivor');
      await tester.pumpWidget(host(MalNotificationsScreen(hub: hub, poller: poller(hub)), locale: const Locale('fr', 'FR')));
      await settle(tester);
      final s = S.current;
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('Hikari_K vous a envoyé une demande d\'ami'), findsOneWidget);
      expect(find.text(s.Mn_Accept), findsOneWidget);
      expect(find.byType(MalNotificationTile), findsWidgets);
      await tester.tap(find.widgetWithText(ChoiceChip, s.Mn_Group_Forum));
      await settle(tester);
      expect(find.text('Hikari_K vous a envoyé une demande d\'ami'), findsNothing);
      await tester.tap(find.byTooltip(s.Mn_Mark_All_Read));
      await settle(tester);
      expect(hub.unread.value, 0);
      expect(find.byTooltip(s.Mn_Mark_All_Read), findsNothing);
      await S.load(const Locale('en'));
    });
  });
}
