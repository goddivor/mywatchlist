import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_mal_web_page.dart';

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
MalWebClient _client(MalWebSession session) => MalWebClient(
      session: session,
      minGap: Duration.zero,
      clientFactory: () => throw StateError('no HTTP in this test'),
    );

MalMessageThread _thread() => const MalMessageThread(
      subject: 'Frieren rewatch',
      counterpart: 'Kineta',
      messages: [MalThreadMessage(sender: 'Kineta', html: 'Hi')],
      threadId: 70000001,
      replyId: 90000003,
    );

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    MalMessagesApi.parseInline = true;
    ForumAvatarPictures.clear();
  });

  group('MalWebFormSubmitter', () {
    test('loads MAL\'s page with the session cookies, fills, clicks, reads goodresult', () async {
      final pages = FakeMalWebPages(() => FakeMalWebPage(loadingPolls: 2));
      final session = await _connected();
      final submitter = MalWebFormSubmitter(client: _client(session), pageFactory: pages, pollInterval: Duration.zero);
      final api = MalMessagesApi(client: _client(session), submitter: submitter);

      await api.send(to: ' Kineta ', subject: ' Hi ', body: '[i]Hello[/i]\r\nthere');
      final page = pages.last;
      expect(page.cookies, {'MALSESSIONID': 'abc123', 'is_logged_in': '1'});
      expect(page.loaded.toString(), 'https://myanimelist.net/mymessages.php?go=send&toname=Kineta');
      expect(page.filled, {
        'toname': 'Kineta',
        'subject': 'Hi',
        'message': '[i]Hello[/i]\nthere',
        'action_type': '',
      });
      expect(page.submitted, isTrue);
      expect(page.disposed, isTrue);
    });

    test('reply: MAL\'s reply page, Re: subject once', () async {
      final pages = FakeMalWebPages();
      final session = await _connected();
      final api = MalMessagesApi(
        client: _client(session),
        submitter: MalWebFormSubmitter(client: _client(session), pageFactory: pages, pollInterval: Duration.zero),
      );
      await api.reply(_thread(), 'Sure');
      expect(pages.last.loaded.toString(),
          'https://myanimelist.net/mymessages.php?go=send&replyid=90000003&threadid=70000001&toname=Kineta');
      expect(pages.last.filled, {'subject': 'Re: Frieren rewatch', 'message': 'Sure', 'action_type': ''});
    });

    test('badresult is MAL\'s refusal with its text', () async {
      final pages = FakeMalWebPages(() => FakeMalWebPage(
            answer: '<div class="badresult">You cannot send messages to this user.</div>'
                '<form><textarea name="message"></textarea></form>',
          ));
      final session = await _connected();
      final api = MalMessagesApi(
        client: _client(session),
        submitter: MalWebFormSubmitter(client: _client(session), pageFactory: pages, pollInterval: Duration.zero),
      );
      await expectLater(
        api.reply(_thread(), 'Sure'),
        throwsA(isA<MalWebActionFailed>().having((e) => e.message, 'message', 'You cannot send messages to this user.')),
      );
    });

    test('the form shown again without a reason is a refusal', () {
      expect(
        () => checkSendPage(const MalWebFormResult(url: null, html: '<form><textarea name="message"></textarea></form>')),
        throwsA(isA<MalWebActionFailed>()),
      );
      expect(() => checkSendPage(const MalWebFormResult(url: null, html: '<div id="content">Inbox</div>')),
          returnsNormally);
    });

    test('no form, missing field, alert, login and timeout are clear errors', () async {
      final session = await _connected();
      Future<void> run(FakeMalWebPage page, Matcher matcher, {Duration timeout = const Duration(seconds: 2)}) async {
        final submitter = MalWebFormSubmitter(
          client: _client(session),
          pageFactory: () => page,
          timeout: timeout,
          pollInterval: const Duration(milliseconds: 5),
        );
        await expectLater(
          submitter.submit(MalMessagesApi.messageForm('/mymessages.php?go=send&toname=Kineta', subject: 'a', body: 'b')),
          throwsA(matcher),
        );
        expect(page.disposed, isTrue);
      }

      await run(FakeMalWebPage(formFields: null), isA<MalWebFormMissing>());
      await run(FakeMalWebPage(formFields: const {'subject'}), isA<MalWebFormMissing>());
      await run(FakeMalWebPage(alert: 'Google reCAPTCHA is currently blocked.'),
          isA<MalWebActionFailed>().having((e) => e.message, 'message', 'Google reCAPTCHA is currently blocked.'));
      await run(FakeMalWebPage(neverAnswers: true), isA<MalWebFormTimeout>(),
          timeout: const Duration(milliseconds: 60));
      await run(FakeMalWebPage(loadingPolls: 1 << 30), isA<MalWebFormTimeout>(),
          timeout: const Duration(milliseconds: 60));
      await run(FakeMalWebPage(loginOnLoad: true), isA<MalWebSessionExpired>());
      expect(session.state, MalWebSessionState.expired);
    });

    test('no session: no page is opened', () async {
      final pages = FakeMalWebPages();
      final session = MalWebSession(cookies: _FakeCookies(), platformSupported: true);
      final submitter = MalWebFormSubmitter(client: _client(session), pageFactory: pages);
      await expectLater(
        submitter.submit(MalMessagesApi.messageForm('/mymessages.php?go=send', subject: 'a', body: 'b')),
        throwsA(isA<MalWebNoSession>()),
      );
      expect(pages.pages, isEmpty);
    });

    test('page scripts carry the values as JSON (no injection) and target MAL\'s button', () {
      final form = MalMessagesApi.messageForm('/mymessages.php?go=send',
          subject: 'He said "hi"</script>', body: "it's\nfine");
      final fill = fillScript(form);
      expect(fill, contains(jsonEncode(form.fields)));
      expect(submitScript(form), contains('.btn-recaptcha-submit'));
      expect(formStateScript(form), contains('form.recaptcha-form'));
      expect(formStateScript(form), contains('GRECAPTCHA_SITE_KEY'));
      expect(decodeJsResult('"{\\"state\\":\\"ready\\"}"'), {'state': 'ready'});
      expect(decodeJsResult('{"missing":[]}'), {'missing': []});
      expect(decodeJsResult('plain'), 'plain');
    });

    test('readBadResult reads MAL\'s box text', () {
      expect(readBadResult('<div class="badresult"><b>Nope</b> &amp; no</div>'), 'Nope & no');
      expect(readBadResult('<div class="goodresult">ok</div>'), isNull);
    });
  });

  group('plain writes stay HTTP', () {
    test('delete still posts MAL\'s AJAX form without a page', () async {
      final sent = <http.BaseRequest>[];
      final session = await _connected();
      final client = MalWebClient(
        session: session,
        minGap: Duration.zero,
        clientFactory: () => _RecordingClient(sent),
      );
      final pages = FakeMalWebPages();
      final api = MalMessagesApi(client: client, submitter: MalWebFormSubmitter(client: client, pageFactory: pages));
      await api.delete(const MalMessage(id: 1, counterpart: 'Kineta', subject: 's'));
      expect(sent.last.url.toString(), 'https://myanimelist.net/includes/ajax.inc.php?t=75');
      expect(pages.pages, isEmpty);
    });
  });

  group('user pictures', () {
    test('profile picture read once per user, cached, published to ForumAvatar', () async {
      final fetched = <Uri>[];
      final store = <String, String>{};
      final pictures = MalUserPictures(
        gap: Duration.zero,
        readCache: (name) async => store[name],
        writeCache: (name, url) async => store[name] = url,
        fetch: (url) async {
          fetched.add(url);
          return http.Response(
            '<div class="user-image"><img class="lazyload" data-src="https://cdn.myanimelist.net/images/userimages/7.jpg"></div>',
            200,
          );
        },
      );
      expect(await pictures.of('Kineta'), 'https://cdn.myanimelist.net/images/userimages/7.jpg');
      expect(await pictures.of('kineta'), 'https://cdn.myanimelist.net/images/userimages/7.jpg');
      expect(fetched.single.toString(), 'https://myanimelist.net/profile/Kineta');
      expect(store['kineta'], isNotNull);

      final again = MalUserPictures(
        gap: Duration.zero,
        readCache: (name) async => store[name],
        fetch: (url) async => throw StateError('cached'),
      );
      expect(await again.of('Kineta'), isNotNull);

      final api = MalMessagesApi(pictures: pictures);
      api.prefetchPictures(const [
        MalMessage(id: 1, counterpart: 'Kineta', subject: 's'),
        MalMessage(id: 2, counterpart: 'Xini', subject: 's', avatarUrl: 'https://cdn.myanimelist.net/images/userimages/9.jpg'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ForumAvatarPictures.lookup('kineta'), 'https://cdn.myanimelist.net/images/userimages/7.jpg');
      expect(ForumAvatarPictures.lookup('Xini'), 'https://cdn.myanimelist.net/images/userimages/9.jpg');
      expect(fetched, hasLength(1));
    });

    test('a profile without a picture, or an error, gives null', () async {
      final pictures = MalUserPictures(
        gap: Duration.zero,
        readCache: (_) async => null,
        writeCache: (_, __) async {},
        fetch: (url) async => url.path.contains('Gone')
            ? http.Response('', 404)
            : http.Response('<div class="user-image"><img src="https://cdn.myanimelist.net/images/questionmark_50.gif"></div>', 200),
      );
      expect(await pictures.of('Nobody'), isNull);
      expect(await pictures.of('Gone'), isNull);
    });

    test('rows and the read page give MAL\'s own picture when present', () {
      expect(
        parseProfilePicture('<div class="user-image"><img data-src="//cdn.myanimelist.net/images/userimages/3.webp"></div>'),
        'https://cdn.myanimelist.net/images/userimages/3.webp',
      );
      final page = parseMessagesPage('<div id="content"><div class="message unread" id="message_5">'
          '<div class="mym_user"><img data-src="https://cdn.myanimelist.net/images/userimages/5.jpg">'
          '<a href="/profile/Kineta">Kineta</a></div>'
          '<div class="mym_subject"><a class="subject-link" href="?go=read&id=5">Hello<span> - hi</span></a></div>'
          '</div></div>')!;
      expect(page.messages.single.avatarUrl, 'https://cdn.myanimelist.net/images/userimages/5.jpg');
    });

    testWidgets('ForumAvatar without a known picture shows initials', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ForumAvatar(username: 'Kineta', tappable: false))));
      expect(find.text('KI'), findsOneWidget);
    });
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.sent);
  final List<http.BaseRequest> sent;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request);
    final body = request.url.path == '/'
        ? "<meta name='csrf_token' content='tok'>"
        : '';
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
  }
}
