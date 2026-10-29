import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/mal_web_form_errors.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_data.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_screen.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_episode.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/episodes_page.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_notifications_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/notifications/mal_hub.dart';
import 'package:mywatchlist/services/notifications/mal_hub_poller.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart' show ListFacetKeys;
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _fixture(String name) => File('test/units/fix-mal-b4/fixtures/$name').readAsStringSync();

// Seasonal ---------------------------------------------------------------------------------

/// Never touches a real list.
class _FakeAdapter extends UserListAdapter {
  @override
  AccountType get tracker => AccountType.myanimelist;
  @override
  String? get owner => 'tester';
  @override
  int get maxPageSize => 500;
  @override
  List<ListSortOption> sortOptions(String category) => const [];
  @override
  String? apiSort(String category, String sortKey, SortDirection direction) => null;
  @override
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  }) async =>
      const ListPage([], hasMore: false);
  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async => null;
  @override
  void open(BuildContext context, ListEntryView entry) {}
  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async => const ListEditUnchanged();
  @override
  bool canStep(ListEntryView entry) => false;
  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) async => entry;
  @override
  Future<void> signInAgain(BuildContext context) async {}
}

const _fresh =
    ListEntryView(id: 1, malId: 1, category: 'anime', title: 'Fresh Show', meanScore: 8.1, genres: ['Action']);
const _old = ListEntryView(id: 2, malId: 2, category: 'anime', title: 'Old Show', meanScore: 7.2);

Future<void> _pumpSeason(WidgetTester tester, Set<int> continuing) async {
  await tester.pumpWidget(MaterialApp(
    home: SeasonalScreen(
      initial: const SeasonKey(SeasonType.SPRING, 2027),
      loader: (season, {bool force = false}) async => [_fresh, _old],
      adapter: _FakeAdapter(),
      malSignedIn: () => false,
      cache: ListStatusCache(saveDelay: Duration.zero),
      continuingIds: (_) => continuing,
    ),
  ));
  await tester.pumpAndSettle();
}

// Hub poller -------------------------------------------------------------------------------

class _FakeCookies implements WebViewCookies {
  @override
  Future<String?> read(String url) async => 'MALSESSIONID=abc123; is_logged_in=1';
  @override
  Future<void> clear(String url) async {}
}

Future<MalWebSession> _connected() async {
  final session = MalWebSession(cookies: _FakeCookies(), platformSupported: true);
  expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
  return session;
}

class _FakeHubApi extends MalNotificationsApi {
  _FakeHubApi(this.feed);
  MalNotificationFeed feed;
  int fetches = 0;
  @override
  Future<MalNotificationFeed> fetch() async {
    fetches++;
    return feed;
  }
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

MalNotificationItem _item(String id, DateTime at) => MalNotificationItem.fromJson({
      'id': id,
      'typeIdentifier': 'profile_comment',
      'isRead': false,
      'createdAt': at.millisecondsSinceEpoch ~/ 1000,
      'commentUserName': 'Ren_99',
      'url': 'https://myanimelist.net/profile/goddivor',
      'text': 'hello $id',
    })!;

// Messages ---------------------------------------------------------------------------------

/// The thread page of one message; records the paths asked (nothing reaches MAL).
MalWebClient _threadClient(MalWebSession session, List<String> asked) => MalWebClient(
      session: session,
      minGap: Duration.zero,
      clientFactory: () => MockClient((r) async {
        asked.add(r.url.toString());
        return http.Response.bytes(
            utf8.encode(File('test/units/mal-messages/fixtures/read_reconstructed.html').readAsStringSync()), 200,
            headers: {'content-type': 'text/html; charset=utf-8'});
      }),
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('seasonal groups', () {
    testWidgets('a saved "Continuing" shows the whole season where nothing continues', (tester) async {
      SharedPreferences.setMockInitialValues({'seasonal_group_v1': 'continuing'});
      await _pumpSeason(tester, const {});
      expect(find.text(S.current.Seasonal_No_Match), findsNothing);
      expect(find.text('Fresh Show'), findsOneWidget);
      expect(find.text('Old Show'), findsOneWidget);
    });

    testWidgets('"Clear filters" also goes back to the whole season', (tester) async {
      // Only "Old Show" continues; "Fresh Show" is new. Saved: Continuing, with a genre filter
      // that only "Fresh Show" passes, so nothing is shown.
      SharedPreferences.setMockInitialValues({
        'seasonal_group_v1': 'continuing',
        SeasonalData.settingsKey(const SeasonKey(SeasonType.SPRING, 2027), global: false): jsonEncode(
            SeasonalData.defaults()
                .copyWith(filter: const ListFilter(included: {ListFacetKeys.genre: {'Action'}}))
                .toJson()),
      });
      await _pumpSeason(tester, const {2});
      expect(find.text(S.current.Seasonal_No_Match), findsOneWidget);
      await tester.tap(find.text(S.current.Seasonal_Clear_Filters));
      await tester.pumpAndSettle();
      expect(find.text('Fresh Show'), findsOneWidget);
      expect(find.text('Old Show'), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getString('seasonal_group_v1'), 'all');
    });

    test('list rows take MAL\'s medium cover, the grid keeps the large one', () {
      expect(mediumCover('https://cdn.myanimelist.net/images/anime/1015/138006l.jpg'),
          'https://cdn.myanimelist.net/images/anime/1015/138006.jpg');
      expect(mediumCover('https://cdn.myanimelist.net/images/anime/1015/138006l.webp'),
          'https://cdn.myanimelist.net/images/anime/1015/138006.webp');
      expect(mediumCover('https://cdn.myanimelist.net/images/anime/1015/138006.jpg'),
          'https://cdn.myanimelist.net/images/anime/1015/138006.jpg');
      expect(mediumCover('https://example.org/cover-l.jpg'), 'https://example.org/cover-l.jpg');
    });
  });

  group('profile', () {
    test('the blog categories sidebar is not a post', () {
      final posts = parseProfileBlogPage(_fixture('blog_categories.html'));
      expect(posts.map((p) => p.title), ['Spring 2018 Anime Rankings', 'Winter 2018 Anime Rankings']);
      expect(posts.first.comments, 2);
      expect(posts.any((p) => p.text.contains('Anime Cards')), isFalse);
    });

    test('the time zone reads as a place', () {
      expect(timeZoneLabel('America/Los_Angeles'), 'Los Angeles');
      expect(timeZoneLabel('America/Argentina/Buenos_Aires'), 'Buenos Aires');
      expect(timeZoneLabel('UTC'), 'UTC');
      expect(timeZoneLabel(' '), isNull);
      expect(timeZoneLabel(null), isNull);
      expect(S.current.FixMalB4_Time_Zone('Los Angeles'), 'Time zone: Los Angeles');
    });
  });

  group('episode pages', () {
    test('MAL\'s sliding pager still offers every page, with the total', () {
      final page = parseEpisodeList(_fixture('one_piece_episodes.html'));
      expect(page.total, 1180);
      expect(page.offsets, [for (var o = 0; o <= 1100; o += 100) o]);
    });

    test('a page in the middle offers the first and the last ones too', () {
      final page = parseEpisodeList(_fixture('one_piece_episodes.html'), offset: 500);
      expect(page.offsets.first, 0);
      expect(page.offsets.last, 1100);
      expect(page.offsets, contains(500));
    });

    test('the Jikan fallback offers the pages Jikan has', () async {
      MalEpisodesPage.reset();
      MalEpisodesPage.parseInline = true;
      MalEpisodesPage.fetch = (_) async => throw const SocketException('offline');
      MalEpisodesPage.jikanPage = (id, page) async => [
            for (var i = 1; i <= 100; i++) AnimeEpisode(malId: i, title: 'Episode $i'),
          ];
      final page = await MalEpisodesPage.load(21);
      expect(page.offsets, [0, 100]);
      MalEpisodesPage.reset();
    });

    test('a reply count is spoken as replies', () {
      expect(S.current.FixMalB4_Episode_Replies(414), '414 replies');
      expect(S.current.FixMalB4_Episode_Replies(1), '1 reply');
    });
  });

  group('hub poller', () {
    final now = DateTime(2026, 10, 29, 12);

    Future<(MalHubPoller, _FakeHubApi, _FakeNotifier, MalNotificationsHub)> make(
        Future<SharedPreferences> Function() storage) async {
      final api = _FakeHubApi(MalNotificationFeed(items: [_item('a', now.subtract(const Duration(hours: 1)))]));
      final hub = MalNotificationsHub(api: api, session: await _connected(), malSignedIn: () => true, clock: () => now);
      final notifier = _FakeNotifier();
      final poller = MalHubPoller(
        hub: hub,
        notifier: notifier,
        readPrefs: () => NotificationPreferences(subscribedAt: now),
        storage: storage,
        clock: () => now,
        malSignedIn: () => true,
      );
      return (poller, api, notifier, hub);
    }

    test('items the background job notified are not notified again', () async {
      final prefs = await SharedPreferences.getInstance();
      final (poller, _, notifier, _) = await make(() async => prefs);
      // The job, in its own isolate, saw and notified "a"; this process' copy is stale.
      SharedPreferences.setMockInitialValues({
        MalHubPoller.seenKey: ['a'],
        MalHubPoller.shownKey: ['a'],
      });
      expect(await poller.pollHub(), 0);
      expect(notifier.shown, isEmpty);
    });

    test('a poll right after the job still reads the hub (the bell gets its count)', () async {
      SharedPreferences.setMockInitialValues({
        MalHubPoller.lastPollKey: now.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
        MalHubPoller.friendsLastPollKey: now.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
      });
      final (poller, api, _, hub) = await make(SharedPreferences.getInstance);
      await poller.poll();
      expect(api.fetches, 0, reason: 'a regular round waits for the interval');
      await poller.poll(forceHub: true);
      expect(api.fetches, 1);
      expect(hub.unread.value, 1);
      expect((await SharedPreferences.getInstance()).getInt(MalHubPoller.unreadKey), 1);
    });

    test('the background round keeps the friends\' interval', () async {
      SharedPreferences.setMockInitialValues({
        MalHubPoller.friendsLastPollKey: now.subtract(const Duration(minutes: 40)).millisecondsSinceEpoch,
      });
      final (poller, _, _, _) = await make(SharedPreferences.getInstance);
      await poller.poll(forceHub: true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(MalHubPoller.friendsLastPollKey),
          now.subtract(const Duration(minutes: 40)).millisecondsSinceEpoch);
    });

    test('a cold start shows the last known count on the bell', () async {
      SharedPreferences.setMockInitialValues({MalHubPoller.unreadKey: 25});
      final (poller, _, _, hub) = await make(SharedPreferences.getInstance);
      poller.restoreUnread(await SharedPreferences.getInstance());
      expect(hub.unread.value, 25);
    });

    test('no MAL account: no count restored', () async {
      SharedPreferences.setMockInitialValues({MalHubPoller.unreadKey: 25});
      final hub = MalNotificationsHub(malSignedIn: () => false);
      final poller = MalHubPoller(hub: hub, notifier: _FakeNotifier(), malSignedIn: () => false);
      poller.restoreUnread(await SharedPreferences.getInstance());
      expect(hub.unread.value, 0);
    });
  });

  group('messages', () {
    setUp(() {
      MalMessagesApi.parseInline = true;
      MalMessagesApi.unread.value = 0;
    });

    test('refreshing an unread thread lowers the badge once', () async {
      final asked = <String>[];
      final api = MalMessagesApi(client: _threadClient(await _connected(), asked));
      MalMessagesApi.unread.value = 2;
      const m = MalMessage(id: 90000003, counterpart: 'Kineta', subject: 'Hello', isRead: false);
      await api.thread(m);
      await api.thread(m);
      await api.thread(m);
      expect(asked, hasLength(3));
      expect(MalMessagesApi.unread.value, 1);
    });

    test('unreadable rows are an error, not an empty inbox', () {
      expect(parseMessagesPage(_fixture('inbox_changed_markup.html')), isNull);
      final empty = parseMessagesPage(File('test/units/mal-messages/fixtures/inbox_empty_reconstructed.html').readAsStringSync());
      expect(empty?.isEmpty, isTrue);
    });

    test('the send answer needs proof: redirect, goodresult, or a refusal', () {
      final compose = Uri.parse('https://myanimelist.net/mymessages.php?go=send&toname=Kineta');
      // A page at the compose address with neither the form nor a result box.
      expect(() => checkSendPage(MalWebFormResult(url: compose, html: '<div id="content">Loading</div>')),
          throwsA(isA<MalWebSendUnconfirmed>()));
      // MAL's redirect to the sent box, or its success box.
      expect(
          () => checkSendPage(MalWebFormResult(
              url: Uri.parse('https://myanimelist.net/mymessages.php?go=sent'), html: '<div id="content"></div>')),
          returnsNormally);
      expect(() => checkSendPage(MalWebFormResult(url: compose, html: '<div class="goodresult">Sent</div>')),
          returnsNormally);
      expect(
          () => checkSendPage(MalWebFormResult(url: compose, html: '<form><textarea name="message"></textarea></form>')),
          throwsA(isA<MalWebActionFailed>()));
      expect(malFormErrorText(const MalWebSendUnconfirmed()), S.current.FixMalB4_Send_Unconfirmed);
    });

    test('the click marks the form page, so a late load of it is not the answer', () {
      final form = MalMessagesApi.messageForm('/mymessages.php?go=send&toname=Kineta', subject: 'a', body: 'b');
      expect(submitScript(form), contains('window.$submittedMarker=true'));
      expect(stillSubmittedScript, contains(submittedMarker));
    });

    testWidgets('a message without a subject leaves no blank line', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: MalMessageTile(
            message: MalMessage(id: 1, counterpart: 'NaTsu879', subject: '', preview: 'hey there', isRead: true),
          ),
        ),
      ));
      expect(find.text('hey there'), findsOneWidget);
      expect(find.text(''), findsNothing);
    });
  });

  group('Top ONA', () {
    test('Jikan is asked without adult entries when NSFW is off, pages included', () {
      final url = JikanApi.topAnimeUrl(type: 'ona', limit: 25, page: 2, sfw: true);
      expect(url.queryParameters['sfw'], 'true');
      expect(JikanApi.topAnimeUrl(type: 'ona', limit: 25, page: 1).queryParameters.containsKey('sfw'), isFalse);
    });
  });
}
