import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/main.dart';
import 'package:mywatchlist/screens/settings/notifications_settings.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/pages/side_bar.dart' show SidebarMenuItem;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';
import 'package:mywatchlist/widgets/mal_web/notification_tiles.dart';
import 'package:provider/provider.dart';
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

/// Records what the app asks of WorkManager; never talks to the platform.
class _FakeScheduler implements MalHubScheduler {
  final List<String> calls = [];
  @override
  bool get isSupported => true;
  @override
  Future<void> register() async => calls.add('register');
  @override
  Future<void> cancel() async => calls.add('cancel');
}

class _FakeNotifier implements MalHubNotifier {
  bool permitted = true;
  final List<HubSystemNotification> shown = [];
  @override
  bool get isSupported => true;
  @override
  Future<bool> allowed() async => permitted;
  @override
  Future<void> show(MalHubChannel channel, List<HubSystemNotification> notifications) async =>
      shown.addAll(notifications);
  @override
  Future<void> cancel(int id) async {}
}

/// An inbox answering from memory: no request is ever sent to MAL.
class _FakeInbox extends MalMessagesApi {
  _FakeInbox(this.page);
  MalMessagesPage page;
  int reads = 0;

  @override
  Future<MalMessagesPage> inbox({int offset = 0}) async {
    reads++;
    MalMessagesApi.unread.value = page.unread;
    return page;
  }
}

MalMessage _message(int id, {bool read = false, String from = 'Ren_99'}) =>
    MalMessage(id: id, counterpart: from, subject: 'Hello $id', isRead: read);

Widget _app(Widget home) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: Center(child: home)),
    );

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MalNotificationsHub.instance.unread.value = 0;
    MalMessagesApi.unread.value = 0;
  });

  group('bell and sidebar entries', () {
    testWidgets('the bell shows the unread count of the hub', (tester) async {
      await tester.pumpWidget(_app(const MalNotificationsBell()));
      expect(find.text('4'), findsNothing);
      MalNotificationsHub.instance.unread.value = 4;
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
      MalNotificationsHub.instance.unread.value = 120;
      await tester.pump();
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('the sidebar entries carry the notification and message counts', (tester) async {
      late SidebarMenuItem notifications;
      late SidebarMenuItem messages;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        notifications = malNotificationsSidebarItem(context);
        messages = malMessagesSidebarItem(context);
        return Column(children: [notifications.trailing!, messages.trailing!]);
      })));
      MalNotificationsHub.instance.unread.value = 2;
      MalMessagesApi.unread.value = 7;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(notifications.title, S.current.Mn_Title);
      expect(messages.title, S.current.Pm_Title);
    });
  });

  group('background worker registration', () {
    test('registers once while wanted and cancels when it stops being', () async {
      var wanted = true;
      final scheduler = _FakeScheduler();
      final polling = MalBackgroundPolling(scheduler: scheduler, wanted: () => wanted);
      await polling.sync();
      await polling.sync();
      expect(scheduler.calls, ['register']);
      expect(polling.isRegistered, isTrue);
      wanted = false;
      await polling.sync();
      await polling.sync();
      expect(scheduler.calls, ['register', 'cancel']);
      expect(polling.isRegistered, isFalse);
    });

    test('the job runs every 30 minutes under the shared task name', () {
      expect(malHubWorkerFrequency, const Duration(minutes: 30));
      expect(malHubWorkerName, isNotEmpty);
    });
  });

  group('private messages', () {
    late _FakeNotifier notifier;
    late _FakeInbox api;
    late bool mayNotify;
    late MalMessagesWatcher watcher;

    setUp(() {
      notifier = _FakeNotifier();
      api = _FakeInbox(MalMessagesPage([_message(1, read: true)]));
      mayNotify = true;
      watcher = MalMessagesWatcher(
        api: api,
        notifier: notifier,
        mayNotify: () => mayNotify,
        canRead: () => true,
      );
    });

    test('the first look only remembers, a later unread message is notified once', () async {
      expect(await watcher.check(), 0);
      api.page = MalMessagesPage([_message(2), _message(1, read: true)]);
      expect(await watcher.check(), 1);
      expect(notifier.shown.single.title, S.current.Mhw_Message_From('Ren_99'));
      expect(notifier.shown.single.body, 'Hello 2');
      expect(MalHubPayload.parse(notifier.shown.single.payload)?.url, contains('mymessages.php?go=read&id=2'));
      expect(await watcher.check(), 0);
      expect(notifier.shown, hasLength(1));
    });

    test('the unread count is refreshed even when nothing is notified', () async {
      watcher.push.value = false;
      await watcher.check();
      api.page = MalMessagesPage([_message(3), _message(2)]);
      expect(await watcher.check(), 0);
      expect(MalMessagesApi.unread.value, 2);
      expect(notifier.shown, isEmpty);
    });

    test('the switch, the master switch and the system permission are honoured', () async {
      await watcher.check();
      api.page = MalMessagesPage([_message(2)]);
      mayNotify = false;
      expect(await watcher.check(), 0);
      api.page = MalMessagesPage([_message(3)]);
      mayNotify = true;
      notifier.permitted = false;
      expect(await watcher.check(), 0);
      api.page = MalMessagesPage([_message(4)]);
      notifier.permitted = true;
      await watcher.setPush(false);
      expect(await watcher.check(), 0);
      expect((await SharedPreferences.getInstance()).getBool(MalMessagesWatcher.pushKey), isFalse);
      api.page = MalMessagesPage([_message(5)]);
      await watcher.setPush(true);
      expect(await watcher.check(), 1);
    });

    test('no MAL account: the inbox is not read', () async {
      final idle = MalMessagesWatcher(api: api, notifier: notifier, canRead: () => false);
      expect(await idle.check(), 0);
      expect(api.reads, 0);
    });

    test('the poller looks at the inbox each time it polls', () async {
      final hub = MalNotificationsHub(malSignedIn: () => false);
      final inbox = MalMessagesWatcher(api: api, notifier: notifier, mayNotify: () => true, canRead: () => true);
      final poller = MalHubMessagesPoller(
        hub: hub,
        notifier: notifier,
        readPrefs: () => NotificationPreferences(subscribedAt: DateTime(2026)),
        watcher: inbox,
      );
      await poller.poll(force: true);
      expect(api.reads, 1);
      api.page = MalMessagesPage([_message(9)]);
      await poller.poll(force: true);
      expect(notifier.shown.map((n) => n.body), contains('Hello 9'));
    });
  });

  group('web client', () {
    test('postJson sends the JSON with the token and the cookies, and retries a refused token', () async {
      final session = MalWebSession(cookies: _FakeCookies('MALSESSIONID=abc123; is_logged_in=1'), platformSupported: true);
      expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
      var token = 0;
      final posts = <http.Request>[];
      final client = MalWebClient(
        session: session,
        minGap: Duration.zero,
        clientFactory: () => MockClient((request) async {
          if (request.method == 'GET') {
            token++;
            return http.Response("<meta name='csrf_token' content='tok$token'>", 200);
          }
          posts.add(request);
          return http.Response('true', posts.length == 1 ? 403 : 200);
        }),
      );
      final response = await client.postJson('/x.json', {'notification_ids': [1, 'b']});
      expect(response.statusCode, 200);
      expect(posts, hasLength(2));
      expect(posts.first.headers['Content-Type'], 'application/json');
      expect(posts.first.headers['Cookie'], contains('MALSESSIONID=abc123'));
      expect(jsonDecode(posts.first.body), {'notification_ids': [1, 'b'], 'csrf_token': 'tok1'});
      expect(jsonDecode(posts.last.body)['csrf_token'], 'tok2');
    });

    test('postJson without a website session sends nothing', () async {
      final client = MalWebClient(
        session: MalWebSession(cookies: _FakeCookies(), platformSupported: true),
        clientFactory: () => MockClient((_) async => fail('no request expected')),
      );
      await expectLater(client.postJson('/x.json', const {}), throwsA(isA<MalWebNoSession>()));
    });
  });

  group('settings switches', () {
    testWidgets('the MyAnimeList switches show for a MAL account and write their preference', (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      UserMalV2.instance
        ..authResponse = AuthResponse(accessToken: 'token')
        ..username = 'goddivor'
        ..needsReLogin = false;
      addTearDown(() => UserMalV2.instance
        ..authResponse = null
        ..username = null);
      final prefs = await SharedPreferences.getInstance();
      final bloc = PreferencesBloc(store: PreferencesStore(prefs));
      addTearDown(bloc.close);
      bloc.add(NotificationPreferencesChanged((p) => p.copyWith(subscribedAt: DateTime.now())));
      final service = NotificationService(
        backend: FakeBackend(),
        texts: const FakeTexts(),
        readPrefs: () => bloc.state.notifications,
        loadCandidates: () async => const [],
        loadEpisodes: () async => const [],
        fetchCover: (_, __) async => null,
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: UserManager.instance,
          child: BlocProvider.value(
            value: bloc,
            child: MaterialApp(
              localizationsDelegates: const [
                S.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: S.delegate.supportedLocales,
              home: NotificationSettingsPage(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private messages'), findsOneWidget);
      expect(find.text("Friends' activity"), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Private messages'));
      await tester.pumpAndSettle();
      expect(MalMessagesWatcher.instance.push.value, isFalse);
      expect(prefs.getBool(MalMessagesWatcher.pushKey), isFalse);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Notifications'));
      await tester.pumpAndSettle();
      expect(MalHubPoller.instance.pushHub.value, isFalse);
      expect(prefs.getBool(MalHubPoller.pushHubKey), isFalse);
      MalMessagesWatcher.instance.push.value = true;
      MalHubPoller.instance.pushHub.value = true;
    });
  });
}
