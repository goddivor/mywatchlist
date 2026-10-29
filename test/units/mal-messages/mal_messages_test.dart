import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/compose_message_screen.dart';
import 'package:mywatchlist/screens/mal_web/message_thread_screen.dart';
import 'package:mywatchlist/screens/mal_web/messages_screen.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mal-web-recaptcha/fake_mal_web_page.dart';

String _fixture(String name) => File('test/units/mal-messages/fixtures/$name').readAsStringSync();

/// A UTF-8 page (fixtures hold non-Latin-1 characters).
http.Response _page(String body, [int code = 200]) =>
    http.Response.bytes(utf8.encode(body), code, headers: {'content-type': 'text/html; charset=utf-8'});

/// No network pictures in widget tests.
String _noPictures(String html) => html.replaceAll(RegExp(r'data-src="[^"]*"'), '');

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

MalWebSession _disconnected() => MalWebSession(cookies: _FakeCookies(), platformSupported: true);

/// A fake myanimelist.net: answers by path, records every request.
class _FakeMal {
  final List<http.Request> sent = [];
  http.Response Function(http.Request r)? onPost;
  String inbox = _fixture('inbox_reconstructed.html');
  bool loginWall = false;

  MalWebClient client(MalWebSession session) => MalWebClient(
        session: session,
        minGap: Duration.zero,
        clientFactory: () => MockClient((r) async {
          sent.add(r);
          if (loginWall) {
            return http.Response('', 303, headers: {
              'location': 'https://myanimelist.net/login.php?from=%2Fmymessages.php&error=login_required',
            });
          }
          final url = r.url.toString();
          if (r.method == 'POST') {
            return onPost?.call(r) ?? _page(_fixture('send_ok_reconstructed.html'));
          }
          if (url.contains('go=read')) return _page(_noPictures(_fixture('read_reconstructed.html')));
          if (url.contains('go=sent')) return _page(_fixture('sent_reconstructed.html'));
          if (url.contains('mymessages.php')) {
            return _page(url.contains('show=0') ? inbox : _fixture('inbox_empty_reconstructed.html'));
          }
          if (url.contains('prefix.json')) return _page(_fixture('prefix_user_2026-10.json'));
          return _page(_fixture('send_ok_reconstructed.html')); // a page with the csrf meta
        }),
      );
}

/// Every MAL form goes through a fake page; no picture is fetched.
late FakeMalWebPages _pages;

void main() {
  setUp(() {
    _pages = FakeMalWebPages();
    MalWebFormSubmitter.instance = MalWebFormSubmitter(pageFactory: _pages, pollInterval: Duration.zero);
    MalUserPictures.instance = MalUserPictures(
      gap: Duration.zero,
      readCache: (_) async => null,
      writeCache: (_, __) async {},
      fetch: (url) async => http.Response('', 404),
    );
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    MalMessagesApi.parseInline = true;
    MalMessagesApi.unread.value = 0;
    UserMalV2.instance
      ..authResponse = AuthResponse(accessToken: 'token')
      ..username = 'goddivor'
      ..needsReLogin = false;
  });

  tearDown(() {
    UserMalV2.instance
      ..authResponse = null
      ..username = null
      ..needsReLogin = false;
  });

  group('parsers', () {
    test('inbox rows: sender, subject, preview, date, unread, reply ids, delete box', () {
      final page = parseMessagesPage(_fixture('inbox_reconstructed.html'))!;
      expect(page.messages, hasLength(3));
      expect(page.unread, 2);
      final first = page.messages.first;
      expect(first.id, 90000003);
      expect(first.counterpart, 'Kineta');
      expect(first.subject, 'Frieren rewatch');
      expect(first.preview, "Are you joining the rewatch this weekend? I'll start Saturday.");
      expect(first.date, 'Today, 9:03 AM');
      expect(first.isRead, isFalse);
      expect(first.replyId, 90000003);
      expect(first.threadId, 70000001);
      expect(first.box, 1);
      expect(page.messages[1].subject, 'Club invite & list');
      expect(page.messages.last.isRead, isTrue);
    });

    test('sent box rows read with f=1 and box 2', () {
      final page = parseMessagesPage(_fixture('sent_reconstructed.html'), sent: true)!;
      expect(page.messages, hasLength(1));
      final m = page.messages.single;
      expect(m.id, 80000002);
      expect(m.counterpart, 'Kineta');
      expect(m.subject, 'Re: Frieren rewatch');
      expect(m.isSent, isTrue);
      expect(m.isRead, isTrue);
      expect(m.box, 2);
      expect(m.url, 'https://myanimelist.net/mymessages.php?go=read&id=80000002&f=1');
    });

    test('an empty box, and a non-MAL page', () {
      final empty = parseMessagesPage(_fixture('inbox_empty_reconstructed.html'))!;
      expect(empty.messages, isEmpty);
      expect(empty.isEmpty, isTrue);
      expect(parseMessagesPage('<html><body>Just a moment...</body></html>'), isNull);
    });

    test('a read page: body after the header, reply ids, history oldest first', () {
      final t = parseMessageThread(
        _fixture('read_reconstructed.html'),
        subject: 'Frieren rewatch',
        counterpart: 'Kineta',
        me: 'goddivor',
      )!;
      expect(t.subject, 'Frieren rewatch');
      expect(t.counterpart, 'Kineta');
      expect(t.replyId, 90000003);
      expect(t.threadId, 70000001);
      expect(t.canReply, isTrue);
      expect(t.avatarUrl, 'https://cdn.myanimelist.net/images/userimages/1.jpg');
      expect(t.messages, hasLength(3));
      expect(t.messages[0].sender, 'goddivor');
      expect(t.messages[0].isMine, isTrue);
      expect(t.messages[1].sender, 'Kineta');
      final last = t.messages.last;
      expect(last.sender, 'Kineta');
      expect(last.date, 'Today, 9:03 AM');
      expect(last.html, contains('<br>'));
      expect(last.html, contains('<b>Saturday</b>'));
      expect(last.html, isNot(contains('Frieren rewatch')));
      expect(last.html, isNot(contains('lightLink')));
    });

    test('MAL dates', () {
      final now = DateTime(2026, 10, 28, 12);
      expect(parseMalMessageDate('Oct 27, 2026 4:12 PM', now: now), DateTime(2026, 10, 27, 16, 12));
      expect(parseMalMessageDate('Today, 9:03 AM', now: now), DateTime(2026, 10, 28, 9, 3));
      expect(parseMalMessageDate('Yesterday, 1:47 PM', now: now), DateTime(2026, 10, 27, 13, 47));
      expect(parseMalMessageDate('5 hours ago', now: now), DateTime(2026, 10, 28, 7));
      expect(parseMalMessageDate('whenever', now: now), isNull);
    });

    test('send answers', () {
      expect(() => checkSendAnswer(http.Response(_fixture('send_ok_reconstructed.html'), 200)), returnsNormally);
      expect(() => checkSendAnswer(http.Response('', 303)), returnsNormally);
      expect(
        () => checkSendAnswer(http.Response(_fixture('send_refused_reconstructed.html'), 200)),
        throwsA(isA<MalWebActionFailed>().having((e) => e.message, 'message', 'This user does not exist.')),
      );
      expect(() => checkSendAnswer(http.Response('', 500)), throwsA(isA<MalWebActionFailed>()));
    });

    test('user search answer (real page, 2026-10-28), subject and body helpers', () {
      final users = parseUserPrefix(_fixture('prefix_user_2026-10.json'));
      expect(users.map((u) => u.name), ['Toxinikke', 'Tiptoxinialex', 'YiXinigami']);
      expect(users.first.imageUrl, isNull); // MAL's placeholder picture is dropped
      expect(replySubject('Hello'), 'Re: Hello');
      expect(replySubject('RE: Hello'), 'RE: Hello');
      expect(messageBody('\r\n[b]Hi[/b]\r\nline <3\r\n'), '[b]Hi[/b]\nline <3');
    });
  });

  group('MalMessagesApi', () {
    test('inbox and sent read with the session; unread count follows', () async {
      final mal = _FakeMal();
      final api = MalMessagesApi(client: mal.client(await _connected()));
      final inbox = await api.inbox();
      expect(inbox.messages, hasLength(3));
      expect(MalMessagesApi.unread.value, 2);
      expect(mal.sent.last.url.toString(), 'https://myanimelist.net/mymessages.php?go=&show=0');
      expect(mal.sent.last.headers['Cookie'], contains('MALSESSIONID=abc123'));
      await api.sent();
      expect(mal.sent.last.url.toString(), 'https://myanimelist.net/mymessages.php?go=sent');
      await api.thread(inbox.messages.first);
      expect(mal.sent.last.url.toString(),
          'https://myanimelist.net/mymessages.php?go=read&id=90000003&threadid=70000001');
      expect(MalMessagesApi.unread.value, 1);
    });

    test('send and reply go through MAL\'s page; delete posts with the csrf token', () async {
      final mal = _FakeMal();
      final session = await _connected();
      final client = mal.client(session);
      final api = MalMessagesApi(
        client: client,
        submitter: MalWebFormSubmitter(client: client, pageFactory: _pages, pollInterval: Duration.zero),
      );
      await api.send(to: ' Kineta ', subject: ' Hi ', body: '[i]Hello[/i]\r\nthere');
      expect(mal.sent.where((r) => r.method == 'POST'), isEmpty);
      expect(_pages.last.loaded.toString(), 'https://myanimelist.net/mymessages.php?go=send&toname=Kineta');
      expect(_pages.last.filled, {
        'toname': 'Kineta',
        'subject': 'Hi',
        'message': '[i]Hello[/i]\nthere',
        'action_type': '',
      });
      expect(_pages.last.submitted, isTrue);

      final thread = parseMessageThread(_fixture('read_reconstructed.html'),
          subject: 'Frieren rewatch', counterpart: 'Kineta', me: 'goddivor')!;
      await api.reply(thread, 'Sure');
      expect(_pages.last.loaded.toString(),
          'https://myanimelist.net/mymessages.php?go=send&replyid=90000003&threadid=70000001&toname=Kineta');
      expect(_pages.last.filled['subject'], 'Re: Frieren rewatch');
      expect(_pages.last.filled['message'], 'Sure');

      mal.onPost = (_) => http.Response('', 200);
      final sentBox = parseMessagesPage(_fixture('sent_reconstructed.html'), sent: true)!;
      await api.delete(sentBox.messages.single);
      expect(mal.sent.last.url.toString(), 'https://myanimelist.net/includes/ajax.inc.php?t=75');
      expect(mal.sent.last.bodyFields, {
        'id': '80000002',
        'box': '2',
        'csrf_token': 'fixture0token0000000000000000000000000000',
      });
    });

    test('MAL\'s refusal is reported with its text', () async {
      final mal = _FakeMal();
      final client = mal.client(await _connected());
      final pages = FakeMalWebPages(() => FakeMalWebPage(answer: _fixture('send_refused_reconstructed.html')));
      final api = MalMessagesApi(
        client: client,
        submitter: MalWebFormSubmitter(client: client, pageFactory: pages, pollInterval: Duration.zero),
      );
      expect(
        () => api.send(to: 'nobody', subject: 'Hi', body: 'Hello'),
        throwsA(isA<MalWebActionFailed>().having((e) => e.message, 'message', 'This user does not exist.')),
      );
    });

    test('no session: nothing is sent; a login redirect expires the session', () async {
      final mal = _FakeMal();
      final none = MalMessagesApi(client: mal.client(_disconnected()));
      await expectLater(none.inbox(), throwsA(isA<MalWebNoSession>()));
      await expectLater(none.send(to: 'a', subject: 'b', body: 'c'), throwsA(isA<MalWebNoSession>()));
      expect(mal.sent, isEmpty);

      final session = await _connected();
      mal.loginWall = true;
      final api = MalMessagesApi(client: mal.client(session));
      await expectLater(api.inbox(), throwsA(isA<MalWebSessionExpired>()));
      expect(session.state, MalWebSessionState.expired);
    });

    test('friends come first in suggestions, then MAL\'s user search', () async {
      final mal = _FakeMal();
      final api = MalMessagesApi(
        client: mal.client(await _connected()),
        friends: (me) async => const [MalUserSuggestion('Kineta', isFriend: true)],
      );
      expect((await api.friends()).single.name, 'Kineta');
      expect(await api.searchUsers('xi'), isEmpty);
      final found = await api.searchUsers('xini');
      expect(found, hasLength(3));
      expect(mal.sent.last.url.toString(), contains('/search/prefix.json?type=user&keyword=xini'));
    });
  });

  group('screens', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Widget app(Widget home) => MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: home,
        );

    testWidgets('without a website session: one-tap Connect, no compose button', (tester) async {
      final session = _disconnected();
      final mal = _FakeMal();
      await tester.pumpWidget(app(MalMessagesScreen(api: MalMessagesApi(client: mal.client(session)), session: session)));
      await settle(tester);
      expect(find.text(S.current.Pm_Connect_Title), findsOneWidget);
      expect(find.text(S.current.Ms_Connect), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(mal.sent, isEmpty);
    });

    testWidgets('inbox rows, unread badge, sent tab', (tester) async {
      late MalWebSession session;
      await tester.runAsync(() async => session = await _connected());
      final mal = _FakeMal();
      await tester.pumpWidget(app(MalMessagesScreen(api: MalMessagesApi(client: mal.client(session)), session: session)));
      await settle(tester);
      expect(find.text('Frieren rewatch'), findsOneWidget);
      expect(find.text('Kineta'), findsOneWidget);
      expect(find.byType(MalMessageTile), findsNWidgets(3));
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.text(S.current.Pm_Sent_Box));
      await settle(tester);
      expect(find.text('Re: Frieren rewatch'), findsOneWidget);
    });

    testWidgets('thread: bubbles, own messages labelled, reply box', (tester) async {
      late MalWebSession session;
      await tester.runAsync(() async => session = await _connected());
      final mal = _FakeMal();
      const message = MalMessage(
        id: 90000003,
        counterpart: 'Kineta',
        subject: 'Frieren rewatch',
        isRead: false,
        threadId: 70000001,
        replyId: 90000003,
      );
      await tester.pumpWidget(app(MalMessageThreadScreen(
        message: message,
        api: MalMessagesApi(client: mal.client(session)),
        session: session,
      )));
      await settle(tester);
      expect(find.byType(MalMessageBubble), findsNWidgets(3));
      expect(find.textContaining(S.current.Pm_You), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Count me in');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expect(_pages.last.submitted, isTrue);
      expect(_pages.last.filled['message'], 'Count me in');
      expect(find.byType(MalMessageBubble), findsNWidgets(4));
    });

    testWidgets('compose: required fields, then MAL\'s form', (tester) async {
      late MalWebSession session;
      await tester.runAsync(() async => session = await _connected());
      final mal = _FakeMal();
      final api = MalMessagesApi(client: mal.client(session), friends: (_) async => const []);
      await tester.pumpWidget(app(ComposeMalMessageScreen(to: 'Kineta', api: api, session: session)));
      await settle(tester);
      expect(find.text('Kineta'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expect(find.text(S.current.Pm_Subject_Required), findsOneWidget);
      expect(find.text(S.current.Pm_Body_Required), findsOneWidget);
      expect(_pages.pages, isEmpty);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'Hello');
      await tester.enterText(fields.at(2), 'See you [b]Saturday[/b]');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expect(_pages.last.loaded.toString(), 'https://myanimelist.net/mymessages.php?go=send&toname=Kineta');
      expect(_pages.last.filled['message'], 'See you [b]Saturday[/b]');
    });
  });
}
