import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/main.dart' as app show MalMessagesWatcher, MalHubMessagesPoller;
import 'package:mywatchlist/screens/mal_web/message_thread_screen.dart';
import 'package:mywatchlist/screens/mal_web/messages_screen.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/fakes.dart';

class _FakeCookies implements WebViewCookies {
  String? jar;
  _FakeCookies([this.jar]);
  @override
  Future<String?> read(String url) async => jar;
  @override
  Future<void> clear(String url) async => jar = null;
}

const _jar = 'MALSESSIONID=abc123; is_logged_in=1';

Future<MalWebSession> _connected() async {
  final session = MalWebSession(cookies: _FakeCookies(_jar), platformSupported: true);
  expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
  return session;
}

class _FakeNotifier implements MalHubNotifier {
  final List<HubSystemNotification> shown = [];
  @override
  bool get isSupported => true;
  @override
  Future<bool> allowed() async => true;
  @override
  Future<void> show(MalHubChannel channel, List<HubSystemNotification> notifications) async =>
      shown.addAll(notifications);
  @override
  Future<void> cancel(int id) async {}
}

/// Inbox and thread from memory: no request is ever sent to MAL.
class _FakeMessages extends MalMessagesApi {
  _FakeMessages({super.client, this.page = const MalMessagesPage([])});
  MalMessagesPage page;
  final List<MalMessage> opened = [];

  @override
  Future<MalMessagesPage> inbox({int offset = 0}) async {
    MalMessagesApi.unread.value = page.unread;
    return page;
  }

  @override
  Future<MalMessagesPage> sent({int offset = 0}) async => const MalMessagesPage([]);

  @override
  Future<MalMessageThread> thread(MalMessage message) async {
    opened.add(message);
    return const MalMessageThread(
      subject: 'Club night',
      counterpart: 'Ren_99',
      messages: [MalThreadMessage(sender: 'Ren_99', html: 'See you there', isMine: false)],
    );
  }
}

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    MalMessagesApi.unread.value = 0;
  });

  group('message payloads', () {
    test('mymessages.php links are a thread, the inbox or the sent box', () {
      expect(MalMessageLink.parse('https://myanimelist.net/mymessages.php?go=read&id=12'),
          const MalMessageLink(id: 12));
      expect(MalMessageLink.parse('https://myanimelist.net/mymessages.php?go=read&id=12&f=1&threadid=7'),
          const MalMessageLink(id: 12, sent: true, threadId: 7));
      expect(MalMessageLink.parse('/mymessages.php'), const MalMessageLink());
      expect(MalMessageLink.parse('https://myanimelist.net/mymessages.php?go=sent'), const MalMessageLink(sent: true));
      for (final url in [
        null,
        'https://myanimelist.net/mymessages.php?go=send&toname=Ren_99',
        'https://myanimelist.net/mymessages.php?go=read',
        'https://myanimelist.net/anime/1/x',
        'https://example.com/mymessages.php',
      ]) {
        expect(MalMessageLink.parse(url), isNull, reason: '$url');
      }
    });

    test('the watcher payload carries the message and its thread', () {
      const m = MalMessage(id: 5, counterpart: 'Ren_99', subject: 'Hi', isRead: false, threadId: 70);
      final payload = MalHubPayload.message(m);
      expect(MalHubPayload.isHub(payload), isTrue);
      expect(MalHubPayload.messageLink(payload), const MalMessageLink(id: 5, threadId: 70));
      expect(MalHubPayload.messageLink('malhub:42|https://myanimelist.net/anime/1/x'), isNull);
      expect(MalHubPayload.messageLink(MalHubPayload.screen), isNull);
    });

    test('NotificationRoute: a message payload opens the thread, a box payload the messages', () {
      final thread = NotificationRoute.parse('malhub:|https://myanimelist.net/mymessages.php?go=read&id=9&threadid=3')!;
      expect(thread.kind, NotificationRouteKind.malMessage);
      expect(thread.id, 9);
      expect(thread.threadId, 3);
      expect(thread.sent, isFalse);
      final box = NotificationRoute.parse('malhub:|https://myanimelist.net/mymessages.php?go=sent')!;
      expect(box.kind, NotificationRouteKind.malMessages);
      expect(box.sent, isTrue);
      // Other hub payloads stay with the hub opener.
      expect(NotificationRoute.parse('malhub:42|https://myanimelist.net/anime/1/x'), isNull);
      expect(NotificationRoute.parse('malhub:'), isNull);
    });

    test('NotificationService sends message taps to onOpen, other hub taps to the hub opener', () async {
      const message = 'malhub:|https://myanimelist.net/mymessages.php?go=read&id=2';
      final backend = FakeBackend(launch: message);
      final hubTaps = <String>[];
      final service = NotificationService(backend: backend, openHubPayload: hubTaps.add);
      await service.init();
      // Never a home-shell launch route: delivered once the navigator exists.
      expect(service.takeLaunchPayload(), isNull);
      final opened = <String>[];
      service.onOpen = opened.add;
      service.flushPendingTap();
      expect(opened, [message]);
      backend.tapHandler!(message);
      backend.tapHandler!('malhub:7|https://myanimelist.net/anime/1/x');
      expect(opened, [message, message]);
      expect(hubTaps, ['malhub:7|https://myanimelist.net/anime/1/x']);
    });
  });

  group('in-app thread', () {
    late MalMessagesApi saved;
    setUp(() => saved = MalMessagesApi.instance);
    tearDown(() => MalMessagesApi.instance = saved);

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<BuildContext> pumpHost(WidgetTester tester) async {
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        home: Builder(builder: (context) {
          host = context;
          return const Scaffold();
        }),
      ));
      return host;
    }

    testWidgets('a tapped message notification opens its thread in the app', (tester) async {
      final session = (await tester.runAsync(_connected))!;
      final api = _FakeMessages(client: MalWebClient(session: session, minGap: Duration.zero));
      MalMessagesApi.instance = api;
      final host = await pumpHost(tester);
      unawaited(AppRoutes.openFromNotification(
          host, 'malhub:|https://myanimelist.net/mymessages.php?go=read&id=2&threadid=70'));
      await settle(tester);
      expect(find.byType(MalMessageThreadScreen), findsOneWidget);
      expect(api.opened.single.id, 2);
      expect(api.opened.single.threadId, 70);
      expect(api.opened.single.isSent, isFalse);
      expect(find.text('Club night'), findsOneWidget);
      expect(find.text('Ren_99'), findsWidgets);
    });

    testWidgets('an inbox payload opens the messages screen', (tester) async {
      final session = (await tester.runAsync(_connected))!;
      MalMessagesApi.instance = _FakeMessages(client: MalWebClient(session: session, minGap: Duration.zero));
      final host = await pumpHost(tester);
      unawaited(AppRoutes.openFromNotification(host, 'malhub:|https://myanimelist.net/mymessages.php'));
      await settle(tester);
      expect(find.byType(MalMessagesScreen), findsOneWidget);
    });
  });

  group('hub POSTs through MalWebClient.postJson', () {
    late List<http.Request> sent;

    MalNotificationsApi api(MalWebSession session, Future<http.Response> Function(http.Request) handler) {
      sent = [];
      return MalNotificationsApi(
        client: MalWebClient(
          session: session,
          minGap: Duration.zero,
          clientFactory: () => MockClient((r) {
            sent.add(r);
            return handler(r);
          }),
        ),
      );
    }

    MalNotificationItem item(String id) =>
        MalNotificationItem.fromJson({'id': int.parse(id), 'typeIdentifier': 'on_air', 'isRead': false})!;

    test('one JSON body with the ids and the token, the hub page as referer', () async {
      final session = await _connected();
      final a = api(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='tok1'>", 200);
        return http.Response('{"success":true}', 200);
      });
      expect(await a.markRead([item('11'), item('12')]), isTrue);
      final posts = sent.where((r) => r.method == 'POST').toList();
      expect(posts, hasLength(1));
      expect(posts.single.url.path, MalNotificationsApi.markReadPath);
      expect(posts.single.headers['Content-Type'], startsWith('application/json'));
      expect(posts.single.headers['X-Requested-With'], 'XMLHttpRequest');
      expect(posts.single.headers['Referer'], '${MalWebClient.base}${MalNotificationsApi.pagePath}');
      expect(posts.single.headers['Cookie'], contains('MALSESSIONID=abc123'));
      expect(jsonDecode(posts.single.body), {
        'notification_ids': [11, 12],
        'csrf_token': 'tok1',
      });
    });

    test('a login redirect expires the session; another redirect is a refusal', () async {
      final session = await _connected();
      var login = true;
      final a = api(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='t'>", 200);
        return http.Response('', 303, headers: {
          'location': login ? 'https://myanimelist.net/login.php?from=x' : 'https://myanimelist.net/',
        });
      });
      await expectLater(a.denyFriendRequests([item('3')]), throwsA(isA<MalWebSessionExpired>()));
      expect(session.state, MalWebSessionState.expired);

      final other = await _connected();
      login = false;
      final b = api(other, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='t'>", 200);
        return http.Response('', 302, headers: {'location': 'https://myanimelist.net/'});
      });
      expect(await b.acceptFriendRequests([item('3')]), isFalse);
    });

    test('nothing to send: no request at all', () async {
      final session = await _connected();
      final a = api(session, (r) async => http.Response('true', 200));
      expect(await a.markRead(const []), isTrue);
      expect(sent, isEmpty);
    });

    test('a server error is reported', () async {
      final session = await _connected();
      final a = api(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='t'>", 200);
        return http.Response('oops', 500);
      });
      await expectLater(a.markRead([item('1')]), throwsA(isA<MalWebActionFailed>()));
    });
  });

  group('message poller next to the hub poller', () {
    test('main still exposes the poller and the watcher it registers', () {
      expect(identical(app.MalMessagesWatcher.instance, MalMessagesWatcher.instance), isTrue);
      final poller = app.MalHubMessagesPoller(notifier: _FakeNotifier());
      expect(poller, isA<MalHubPoller>());
    });

    test('a new unread message is notified with an in-app payload, the poller reads the inbox', () async {
      final notifier = _FakeNotifier();
      final api = _FakeMessages(page: const MalMessagesPage([MalMessage(id: 1, counterpart: 'a', subject: 's')]));
      final watcher = MalMessagesWatcher(api: api, notifier: notifier, mayNotify: () => true, canRead: () => true);
      final poller = MalHubMessagesPoller(
        hub: MalNotificationsHub(malSignedIn: () => false),
        notifier: notifier,
        readPrefs: () => NotificationPreferences(subscribedAt: DateTime(2026)),
        watcher: watcher,
      );
      await poller.poll(force: true); // first look: remembers only
      expect(notifier.shown, isEmpty);
      api.page = const MalMessagesPage([
        MalMessage(id: 8, counterpart: 'Ren_99', subject: 'Club night', isRead: false, threadId: 70),
        MalMessage(id: 1, counterpart: 'a', subject: 's'),
      ]);
      await poller.poll(force: true);
      final shown = notifier.shown.single;
      expect(shown.body, 'Club night');
      expect(NotificationRoute.parse(shown.payload)?.kind, NotificationRouteKind.malMessage);
      expect(NotificationRoute.parse(shown.payload)?.id, 8);
    });
  });
}
