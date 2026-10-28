import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/comments_section.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/profile_comments_api.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _fixture(String name) => File('test/units/mal-session/fixtures/$name').readAsStringSync();

/// A WebView jar in memory.
class _FakeCookies implements WebViewCookies {
  String? jar;
  int clears = 0;
  _FakeCookies([this.jar]);

  @override
  Future<String?> read(String url) async => jar;

  @override
  Future<void> clear(String url) async {
    clears++;
    jar = null;
  }
}

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

const _loggedInJar = 'MALSESSIONID=abc123; is_logged_in=1; anime_update_advanced=0';

Future<MalWebSession> _connectedSession({String user = 'goddivor', _FakeCookies? cookies}) async {
  final session = MalWebSession(
    cookies: cookies ?? _FakeCookies(_loggedInJar),
    platformSupported: true,
  );
  expect(await session.captureFromWebView(username: user), isTrue);
  return session;
}

/// Strips network pictures so widget tests never load an image.
String _noPictures(String html) => html
    .replaceAll(RegExp(r'data-src="[^"]*"'), '')
    .replaceAll(RegExp(r'<img[^>]*class="userimg"[^>]*>'), '');

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ProfileCommentsApi.parseInline = true;
    _signInMal('goddivor');
  });

  tearDown(_signOutMal);

  group('csrf token', () {
    test('reads single and double quoted metas, either attribute order', () {
      expect(parseCsrfToken("<meta name='csrf_token' content='abc'>"), 'abc');
      expect(parseCsrfToken('<meta name="csrf_token" content="def">'), 'def');
      expect(parseCsrfToken('<meta content="ghi" name="csrf_token">'), 'ghi');
      expect(parseCsrfToken('<meta name="other" content="x">'), isNull);
      expect(parseCsrfToken(_fixture('profile_anonymous_2026-10.html')),
          'fixture0token0000000000000000000000000000');
    });
  });

  group('cookies', () {
    test('Cookie header round trip', () {
      final jar = parseCookieHeader(' a=1; b = two ;bad; c=x=y');
      expect(jar, {'a': '1', 'b': 'two', 'c': 'x=y'});
    });

    test('Set-Cookie with Expires commas, renewals and deletions', () {
      final changes = parseSetCookie(
        'MALSESSIONID=new; expires=Thu, 28-Nov-2026 10:00:00 GMT; path=/; HttpOnly,'
        'is_logged_in=1; Max-Age=86400, old=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT',
      );
      expect(changes, {'MALSESSIONID': 'new', 'is_logged_in': '1', 'old': null});
    });

    test('a logged-in jar needs MALSESSIONID or is_logged_in=1', () {
      expect(MalWebSession.looksLoggedIn(parseCookieHeader(_loggedInJar)), isTrue);
      expect(MalWebSession.looksLoggedIn(parseCookieHeader('m_gdpr_mdl=1; MALHLOGSESSID=x')), isFalse);
    });
  });

  group('MalWebSession', () {
    test('captures the WebView jar, stores it, never prints it', () async {
      final session = await _connectedSession();
      expect(session.state, MalWebSessionState.connected);
      expect(session.cookieHeader, contains('MALSESSIONID=abc123'));
      expect(session.toString(), isNot(contains('abc123')));
      final stored = jsonDecode((await const FlutterSecureStorage().read(key: MalWebSession.storageKey))!);
      expect(stored['username'], 'goddivor');
      expect(stored['cookies'], contains('is_logged_in=1'));

      // A new run reads it back.
      final again = MalWebSession(cookies: _FakeCookies(), platformSupported: true);
      await again.ensureLoaded();
      expect(again.isConnected, isTrue);
      expect(again.username, 'goddivor');
    });

    test('a jar without a MAL login is not stored', () async {
      final session = MalWebSession(cookies: _FakeCookies('m_gdpr_mdl=1'), platformSupported: true);
      expect(await session.captureFromWebView(username: 'goddivor'), isFalse);
      expect(session.state, MalWebSessionState.none);
      expect(await const FlutterSecureStorage().read(key: MalWebSession.storageKey), isNull);
    });

    test('signing out of MAL (any path) clears the session and the WebView cookies', () async {
      final cookies = _FakeCookies(_loggedInJar);
      final session = await _connectedSession(cookies: cookies);
      UserMalV2.instance.clear();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(session.state, MalWebSessionState.none);
      expect(cookies.clears, 1);
      expect(await const FlutterSecureStorage().read(key: MalWebSession.storageKey), isNull);
    });

    test('stored cookies of another MAL account are dropped on load', () async {
      await _connectedSession(user: 'someone_else');
      final session = MalWebSession(cookies: _FakeCookies(), platformSupported: true);
      await session.ensureLoaded();
      expect(session.state, MalWebSessionState.none);
    });

    test('unsupported platforms never capture', () async {
      final session = MalWebSession(cookies: _FakeCookies(_loggedInJar), platformSupported: false);
      expect(await session.captureFromWebView(), isFalse);
      expect(session.state, MalWebSessionState.unsupported);
    });

    test('Set-Cookie answers update the stored jar', () async {
      final session = await _connectedSession();
      await session.applySetCookie('MALSESSIONID=rotated; path=/; HttpOnly');
      expect(session.cookieHeader, contains('MALSESSIONID=rotated'));
    });
  });

  group('MalWebClient', () {
    late List<http.Request> sent;

    MalWebClient client(MalWebSession session, Future<http.Response> Function(http.Request) handler) {
      sent = [];
      return MalWebClient(
        session: session,
        minGap: Duration.zero,
        clientFactory: () => MockClient((request) {
          sent.add(request);
          return handler(request);
        }),
      );
    }

    test('POST forms carry the cookies, the page token and the ajax headers', () async {
      final session = await _connectedSession();
      final c = client(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='tok1'>", 200);
        return http.Response('{}', 200);
      });
      await c.postForm('/includes/ajax.inc.php?t=78', {'id': '5'});
      final post = sent.last;
      expect(post.method, 'POST');
      expect(post.bodyFields, {'id': '5', 'csrf_token': 'tok1'});
      expect(post.headers['Cookie'], contains('MALSESSIONID=abc123'));
      expect(post.headers['X-Requested-With'], 'XMLHttpRequest');
      expect(post.headers['User-Agent'], MalWebClient.userAgent);
      expect(post.followRedirects, isFalse);
    });

    test('a refused token is read again and the form sent once more', () async {
      final session = await _connectedSession();
      var tokens = 0;
      var posts = 0;
      final c = client(session, (r) async {
        if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='tok${++tokens}'>", 200);
        posts++;
        return r.bodyFields['csrf_token'] == 'tok2' ? http.Response('{}', 200) : http.Response('', 403);
      });
      final response = await c.postForm('/addcomment.php', {'a': 'b'});
      expect(response.statusCode, 200);
      expect(posts, 2);
    });

    test('a redirect to login.php marks the session expired', () async {
      final session = await _connectedSession();
      final c = client(session, (r) async => http.Response('', 303,
          headers: {'location': 'https://myanimelist.net/login.php?from=%2Feditprofile.php'}));
      expect(await c.checkSession(force: true), isFalse);
      expect(session.state, MalWebSessionState.expired);
      expect(session.cookieHeader, isNull);
    });

    test('the session check passes on 200 and keeps the page token', () async {
      final session = await _connectedSession();
      final c = client(session, (r) async {
        expect(r.url.toString(), 'https://myanimelist.net/editprofile.php?go=myoptions');
        return http.Response("<meta name='csrf_token' content='fromcheck'>", 200);
      });
      expect(await c.checkSession(force: true), isTrue);
      expect(c.cachedCsrf, 'fromcheck');
    });

    test('without a session, GETs are anonymous and writes refuse to start', () async {
      final session = MalWebSession(cookies: _FakeCookies(), platformSupported: true);
      final c = client(session, (r) async => http.Response('ok', 200));
      await c.get('/profile/goddivor');
      expect(sent.single.headers.containsKey('Cookie'), isFalse);
      expect(() => c.postForm('/addcomment.php', {}), throwsA(isA<MalWebNoSession>()));
    });
  });

  group('profile comments parsing (saved pages)', () {
    test('anonymous profile block', () {
      final page = parseProfileComments(_fixture('profile_anonymous_2026-10.html'))!;
      expect(page.comments.map((c) => c.id), [47520185, 47513400]);
      final first = page.comments.first;
      expect(first.author, 'Ver_se_s');
      expect(first.date, 'Oct 30, 2023 8:44 PM');
      expect(first.avatarUrl, startsWith('https://cdn.myanimelist.net/s/common/userimages/'));
      expect(first.html, startsWith('Greetings and thank you'));
      expect(first.canDelete, isFalse);
      expect(first.replyToMemberId, isNull);
      expect(first.conversationUrl, isNull);
      expect(page.memberId, 14110547);
      expect(page.total, 4);
      expect(page.canPost, isFalse);
    });

    test('signed-in profile block: form and actions', () {
      final page = parseProfileComments(_fixture('profile_signed_in_reconstructed.html'))!;
      expect(page.canPost, isTrue);
      expect(page.profileUsername, 'goddivor');
      expect(page.memberId, 14110547);
      final first = page.comments.first;
      expect(first.canDelete, isTrue);
      expect(first.replyToMemberId, 15539544);
      expect(first.conversationUrl, 'https://myanimelist.net/comtocom.php?id1=14110547&id2=15539544');
    });

    test('comments.php page', () {
      final page = parseCommentsListPage(_fixture('comments_list_2026-10.html'))!;
      expect(page.comments, hasLength(2));
      expect(page.comments.first.id, 48975422);
      expect(page.comments.first.date, isNot(startsWith('|')));
      expect(page.total, 9093);
    });

    test('comtocom.php conversation', () {
      const url = 'https://myanimelist.net/comtocom.php?id1=14110547&id2=15539544';
      final conversation = parseConversation(_fixture('comtocom_2026-10.html'), url: url)!;
      expect(conversation.comments.map((c) => c.author), ['Ver_se_s', 'goddivor']);
      expect(conversation.comments.last.date, 'Oct 30, 2023 1:47 PM');
      expect(conversation.usernames, ['goddivor', 'Ver_se_s']);
      expect(conversation.otherMemberId('goddivor'), 15539544);
      expect(conversation.otherMemberId('Ver_se_s'), 14110547);
      expect(conversation.otherMemberId('nobody'), isNull);
    });

    test('a challenge page is not a profile', () {
      expect(parseProfileComments('<html><body>Just a moment...</body></html>'), isNull);
    });
  });

  group('ProfileCommentsApi writes', () {
    late List<http.Request> sent;

    ProfileCommentsApi api(MalWebSession session, String postAnswer) {
      sent = [];
      return ProfileCommentsApi(
        client: MalWebClient(
          session: session,
          minGap: Duration.zero,
          clientFactory: () => MockClient((r) async {
            sent.add(r);
            if (r.method == 'GET') return http.Response("<meta name='csrf_token' content='t'>", 200);
            return http.Response(postAnswer, 200);
          }),
        ),
      );
    }

    test('post sends the fields of MAL\'s own profile form', () async {
      final a = api(await _connectedSession(), '{"commentId":1}');
      await a.post(memberId: 14110547, username: 'goddivor', text: 'hello');
      expect(sent.last.url.path, '/addcomment.php');
      expect(sent.last.bodyFields, {
        'commentSubmit': '1',
        'profileMemId': '14110547',
        'profileUsername': 'goddivor',
        'commentText': 'hello',
        'area': '2',
        'csrf_token': 't',
      });
    });

    test('MAL\'s JSON error becomes MalWebActionFailed with its message', () async {
      final a = api(await _connectedSession(), '{"error":"too_fast","message":"Please wait"}');
      expect(
        () => a.post(memberId: 1, username: 'goddivor', text: 'x'),
        throwsA(isA<MalWebActionFailed>().having((e) => e.message, 'message', 'Please wait')),
      );
    });

    test('reply posts on the author\'s profile, delete uses t=78', () async {
      final a = api(await _connectedSession(), '');
      await a.reply(memberId: 15539544, text: 'hi');
      expect(sent.last.bodyFields['profileMemId'], '15539544');
      expect(sent.last.bodyFields.containsKey('profileUsername'), isFalse);
      await a.delete(47520185);
      expect(sent.last.url.toString(), 'https://myanimelist.net/includes/ajax.inc.php?t=78');
      expect(sent.last.bodyFields, {'id': '47520185', 'csrf_token': 't'});
    });
  });

  group('CommentsSection', () {
    Widget host(Widget tab) => MaterialApp(
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

    ProfileCommentsApi pageApi(MalWebSession session, String html) => ProfileCommentsApi(
          client: MalWebClient(
            session: session,
            minGap: Duration.zero,
            clientFactory: () => MockClient((r) async => http.Response(_noPictures(html), 200)),
          ),
        );

    testWidgets('reads comments without a session and offers to connect', (tester) async {
      final session = MalWebSession(cookies: _FakeCookies(), platformSupported: true);
      await tester.pumpWidget(host(CommentsSection(
        username: 'goddivor',
        session: session,
        api: pageApi(session, _fixture('profile_anonymous_2026-10.html')),
      )));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('Ver_se_s'), findsOneWidget);
      expect(find.text('nilyx'), findsOneWidget);
      expect(find.text(S.current.Ms_Connect_To_Comment), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('with the session: composer and MAL\'s actions', (tester) async {
      late MalWebSession session;
      await tester.runAsync(() async => session = await _connectedSession());
      await tester.pumpWidget(host(CommentsSection(
        username: 'goddivor',
        session: session,
        api: pageApi(session, _fixture('profile_signed_in_reconstructed.html')),
      )));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text(S.current.Ms_Connect_To_Comment), findsNothing);
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      expect(find.text(S.current.Ms_Comment_Delete), findsOneWidget);
      expect(find.text(S.current.Ms_Comment_Reply), findsOneWidget);
      expect(find.text(S.current.Ms_Comment_Conversation), findsOneWidget);
    });
  });
}
