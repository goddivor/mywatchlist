import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/notifications_screen.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mal-web-recaptcha/fake_mal_web_page.dart';

class _FakeCookies implements WebViewCookies {
  String? jar;
  _FakeCookies([this.jar]);
  @override
  Future<String?> read(String url) async => jar;
  @override
  Future<void> clear(String url) async => jar = null;
}

Future<MalWebSession> _connected() async {
  final session = MalWebSession(cookies: _FakeCookies('MALSESSIONID=abc123; is_logged_in=1'), platformSupported: true);
  expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
  return session;
}

/// A client that must never reach the network.
MalWebClient _noHttp(MalWebSession session) => MalWebClient(
      session: session,
      minGap: Duration.zero,
      clientFactory: () => throw StateError('no HTTP in this test'),
    );

MalNotificationItem _item(Object id, {bool read = false}) =>
    MalNotificationItem.fromJson({'id': id, 'typeIdentifier': 'on_air', 'isRead': read})!;

const _loginPage = '<html><body><form action="/login.php?from=%2Fnotification">'
    '<input name="user_name"></form></body></html>';

class _NoNotifier implements MalHubNotifier {
  @override
  bool get isSupported => true;
  @override
  Future<bool> allowed() async => false;
  @override
  Future<void> show(MalHubChannel channel, List<HubSystemNotification> notifications) async {}
  @override
  Future<void> cancel(int id) async {}
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    MalNotificationsApi.parseInline = true;
  });

  group('MAL\'s answer', () {
    test('only a JSON success:true is an acceptance', () {
      expect(MalNotificationsApi.accepted('{"success":true}'), isTrue);
      expect(MalNotificationsApi.accepted(' {"success": true} \n'), isTrue);
      expect(MalNotificationsApi.accepted('{"success":false}'), isFalse);
      expect(MalNotificationsApi.accepted('{}'), isFalse);
      expect(MalNotificationsApi.accepted('{"errors":[{"message":"bad"}]}'), isFalse);
      expect(MalNotificationsApi.accepted('true'), isFalse);
      expect(MalNotificationsApi.accepted(''), isFalse);
      // The defect: an HTML page that happens to contain "true" counted as accepted.
      expect(MalNotificationsApi.accepted('<html><script>var a = true;</script></html>'), isFalse);
    });

    test('plain HTTP: an HTML page answered with 200 is a refusal', () async {
      final session = await _connected();
      final api = MalNotificationsApi(
        webView: false,
        client: MalWebClient(
          session: session,
          minGap: Duration.zero,
          clientFactory: () => MockClient((r) async => r.method == 'GET'
              ? http.Response("<meta name='csrf_token' content='t'>", 200)
              : http.Response('<html><script>window.x = true;</script></html>', 200)),
        ),
      );
      expect(await api.markRead([_item('480720423')]), isFalse);
    });
  });

  group('sent from MAL\'s page in the WebView', () {
    late FakeMalWebPages pages;
    late MalWebSession session;

    MalNotificationsApi api({FakeMalWebPage Function()? page, Duration timeout = const Duration(seconds: 5)}) {
      pages = FakeMalWebPages(page);
      final client = _noHttp(session);
      return MalNotificationsApi(
        client: client,
        submitter: MalWebFormSubmitter(
          client: client,
          pageFactory: pages,
          pollInterval: Duration.zero,
          timeout: timeout,
        ),
      );
    }

    setUp(() async => session = await _connected());

    test('mark read: MAL\'s /notification page, MAL\'s endpoint, the ids as MAL sent them', () async {
      final a = api(page: () => FakeMalWebPage(ajaxNotReadyPolls: 2, ajaxPendingPolls: 2));
      expect(await a.markRead([_item('480720423'), _item(480720424), _item('1', read: true)]), isTrue);
      final page = pages.pages.single;
      expect(page.cookies, {'MALSESSIONID': 'abc123', 'is_logged_in': '1'});
      expect(page.loaded.toString(), 'https://myanimelist.net/notification');
      // Sent once, after jQuery was ready.
      final call = page.ajaxSent.single;
      expect(call.path, MalNotificationsApi.markReadPath);
      expect(call.body, {
        'notification_ids': ['480720423', 480720424],
      });
      expect(page.disposed, isTrue);
    });

    test('accept and deny use their endpoints', () async {
      final a = api();
      expect(await a.acceptFriendRequests([_item('7')]), isTrue);
      expect(pages.last.ajaxSent.single.path, MalNotificationsApi.acceptPath);
      expect(await a.denyFriendRequests([_item('8')]), isTrue);
      expect(pages.last.ajaxSent.single.path, MalNotificationsApi.denyPath);
      expect(pages.last.ajaxSent.single.body, {
        'notification_ids': ['8'],
      });
    });

    test('an HTML or empty answer is a refusal', () async {
      for (final body in ['<html>true</html>', '', '{"success":false}']) {
        final a = api(page: () => FakeMalWebPage(ajaxReply: MalWebAjaxAnswer(status: 200, body: body)));
        expect(await a.markRead([_item('1')]), isFalse, reason: body);
      }
    });

    test('the login page instead of JSON expires the session', () async {
      final a = api(page: () => FakeMalWebPage(ajaxReply: const MalWebAjaxAnswer(status: 200, body: _loginPage)));
      await expectLater(a.markRead([_item('1')]), throwsA(isA<MalWebSessionExpired>()));
      expect(session.state, MalWebSessionState.expired);
    });

    test('an error status or no answer at all is reported', () async {
      final a = api(page: () => FakeMalWebPage(ajaxReply: const MalWebAjaxAnswer(status: 403, body: 'no')));
      await expectLater(
          a.markRead([_item('1')]), throwsA(isA<MalWebActionFailed>().having((e) => e.statusCode, 'status', 403)));
      final b = api(page: () => FakeMalWebPage(ajaxReply: const MalWebAjaxAnswer(status: 0, body: '')));
      await expectLater(b.markRead([_item('1')]), throwsA(isA<MalWebActionFailed>()));
      final c = api(
        page: () => FakeMalWebPage(ajaxReply: null),
        timeout: const Duration(milliseconds: 200),
      );
      await expectLater(c.markRead([_item('1')]), throwsA(isA<MalWebFormTimeout>()));
    });

    test('a page sent to the login never sends the call', () async {
      final a = api(page: () => FakeMalWebPage(loginOnLoad: true));
      await expectLater(a.markRead([_item('1')]), throwsA(isA<MalWebSessionExpired>()));
      expect(pages.pages.single.ajaxSent, isEmpty);
    });

    test('nothing to send: no page at all', () async {
      final a = api();
      expect(await a.markRead([_item('1', read: true)]), isTrue);
      expect(pages.pages, isEmpty);
    });

    test('the hub puts the items back when MAL refuses', () async {
      final a = api(page: () => FakeMalWebPage(ajaxReply: const MalWebAjaxAnswer(status: 200, body: '<html></html>')));
      final hub = MalNotificationsHub(api: _Feed(a), session: session, malSignedIn: () => true);
      await hub.refresh();
      expect(hub.unread.value, 2);
      expect(await hub.markAllRead(), isFalse);
      expect(hub.unread.value, 2);
      expect(hub.items.every((i) => !i.isRead), isTrue);
    });
  });

  group('scripts', () {
    test('MAL\'s own jQuery call: JSON body, same origin, raw answer kept', () {
      final script = sendAjaxScript(MalWebAjax(
        page: _page,
        path: '/notification/api/check-items-as-read.json',
        body: const {
          'notification_ids': ['480720423', 5],
        },
      ));
      expect(script, contains(r'window.$||window.jQuery'));
      expect(script, contains('url:"/notification/api/check-items-as-read.json"'));
      expect(script, contains('data:JSON.stringify({"notification_ids":["480720423",5]})'));
      expect(script, contains('contentType:"application/json"'));
      expect(script, contains('type:"POST"'));
      expect(script, contains('meta[name="csrf_token"]'));
      expect(ajaxAnswerScript, contains(ajaxAnswerMarker));
    });

    test('the WebView\'s JSON-quoted answer is read back', () {
      final quoted = jsonEncode(jsonEncode({'status': 200, 'body': '{"success":true}'}));
      expect(decodeJsResult(quoted), {'status': 200, 'body': '{"success":true}'});
      expect(decodeJsResult('""'), '');
    });
  });

  testWidgets('the notifications screen hosts the invisible WebView', (tester) async {
    await S.load(const Locale('en'));
    final hub = MalNotificationsHub(
      api: MalNotificationsApi(webView: false),
      session: MalWebSession(cookies: _FakeCookies(), platformSupported: true),
      malSignedIn: () => true,
      malUsername: () => null,
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: MalNotificationsScreen(
        hub: hub,
        poller: MalHubPoller(hub: hub, notifier: _NoNotifier(), readPrefs: () => const NotificationPreferences()),
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(MalWebFormHost), findsOneWidget);
    expect(MalWebFormHost.mounted, isTrue);
  });
}

final Uri _page = Uri.parse('https://myanimelist.net/notification');

/// Reads a fixed feed, writes through the real [MalNotificationsApi] given.
class _Feed extends MalNotificationsApi {
  _Feed(this.real) : super(webView: false);
  final MalNotificationsApi real;

  @override
  Future<MalNotificationFeed> fetch() async => MalNotificationFeed(items: [_item('1'), _item('2')]);

  @override
  Future<bool> markRead(Iterable<MalNotificationItem> items) => real.markRead(items);
}
