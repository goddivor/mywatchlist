import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_notifications_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_notifications_service.dart';
import 'package:mywatchlist/widgets/Anilist/notifications/anilist_notification_bell.dart';
import 'package:mywatchlist/widgets/Anilist/notifications/anilist_notification_tile.dart';

import '../../helpers/no_network.dart';

// Shapes follow the live schema (introspected anonymously on 2026-10-29); no sample comes
// from an account, so the tests never touch one.
const _user = {
  'id': 7,
  'name': 'Josh',
  'avatar': {'medium': 'https://x/a.png'},
};
const _media = {
  'id': 21,
  'type': 'ANIME',
  'title': {'userPreferred': 'ONE PIECE'},
  'coverImage': {'medium': 'https://x/21.jpg'},
};

final _items = [
  {'__typename': 'AiringNotification', 'id': 1, 'type': 'AIRING', 'episode': 6, 'createdAt': 1793247420, 'media': _media},
  {'__typename': 'FollowingNotification', 'id': 2, 'type': 'FOLLOWING', 'context': ' started following you.', 'createdAt': 1793247000, 'user': _user},
  {'__typename': 'ActivityReplyNotification', 'id': 3, 'type': 'ACTIVITY_REPLY', 'activityId': 99, 'createdAt': 1793240000, 'user': _user},
  {'__typename': 'ThreadCommentReplyNotification', 'id': 4, 'type': 'THREAD_COMMENT_REPLY', 'commentId': 55, 'thread': {'id': 8, 'title': 'Best of 2026'}, 'createdAt': 1793200000, 'user': _user},
  {'__typename': 'MediaDataChangeNotification', 'id': 5, 'type': 'MEDIA_DATA_CHANGE', 'reason': 'Fixed the cover', 'createdAt': 1793100000, 'media': _media},
  {'__typename': 'MediaDeletionNotification', 'id': 6, 'type': 'MEDIA_DELETION', 'deletedMediaTitle': 'Old', 'createdAt': 1793000000},
  {'__typename': 'AiringNotification', 'id': 7, 'type': 'SOMETHING_NEW', 'createdAt': 1792000000},
];

AnilistGraphql _fake(List<Map<String, dynamic>> log, {int unread = 2}) => AnilistGraphql(
      sender: (body, {required auth}) async {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        log.add(decoded);
        final query = decoded['query'] as String;
        final Object data;
        if (query.contains('resetNotificationCount: true')) {
          data = {'Page': {'notifications': []}};
        } else if (query.contains('notifications(')) {
          data = {
            'Viewer': {'unreadNotificationCount': unread},
            'Page': {'pageInfo': {'hasNextPage': true}, 'notifications': _items},
          };
        } else {
          data = {'Viewer': {'unreadNotificationCount': unread}};
        }
        return http.Response(jsonEncode({'data': data}), 200);
      },
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('service', () {
    test('parses the types and ignores unknown ones as plain rows', () async {
      final log = <Map<String, dynamic>>[];
      final service = AnilistNotificationsService(client: _fake(log), signedIn: true);
      final page = await service.page();
      expect(page.items.length, 7);
      expect(page.hasNext, isTrue);
      expect(page.items[0].kind, AnilistNotificationKind.airing);
      expect(page.items[0].episode, 6);
      expect(page.items[0].subject!.title, 'ONE PIECE');
      expect(page.items[2].activityId, 99);
      expect(page.items[3].threadId, 8);
      expect(page.items[3].commentId, 55);
      expect(page.items[5].otherTitle, 'Old');
      expect(page.items[6].kind, isNull);
      expect(AnilistNotificationKind.fromWire('SOMETHING_NEW'), isNull);
      // Reading never marks the inbox read.
      expect(log.single['query'], contains('resetNotificationCount: false'));
      expect(log.single['variables']['types'], isNull);
      // AniList answers 500 to `type_in: null`: "All" sends no filter at all.
      expect(log.single['query'], isNot(contains('type_in')));
      expect((log.single['variables'] as Map).containsKey('types'), isFalse);
    });

    test('group filters send their types; unreadSince is the oldest unread', () async {
      final log = <Map<String, dynamic>>[];
      final service = AnilistNotificationsService(client: _fake(log), signedIn: true);
      final page = await service.page(group: AnilistNotificationGroup.follows);
      expect(log.single['variables']['types'], ['FOLLOWING']);
      expect(log.single['query'], contains(r'type_in: $types'));
      expect(page.unread, 2);
      expect(page.unreadSince, page.items[1].createdAt);
      expect(AnilistNotificationGroup.values.length, 6);
      final all = AnilistNotificationGroup.values.expand((g) => g.kinds ?? const []).toSet();
      expect(all.length, AnilistNotificationKind.values.length);
    });

    test('markRead sends the reset read; signed out sends nothing', () async {
      final log = <Map<String, dynamic>>[];
      await AnilistNotificationsService(client: _fake(log), signedIn: true).markRead();
      expect(log.single['query'], contains('resetNotificationCount: true'));
      final none = <Map<String, dynamic>>[];
      await AnilistNotificationsService(client: _fake(none), signedIn: false).markRead();
      expect(none, isEmpty);
    });
  });

  group('unread count', () {
    test('refreshes at most once a minute unless forced, and clears when read', () async {
      final log = <Map<String, dynamic>>[];
      var now = DateTime(2026, 10, 29, 12);
      final count = AnilistUnreadCount(
        service: AnilistNotificationsService(client: _fake(log, unread: 4), signedIn: true),
        clock: () => now,
      );
      await count.refresh();
      expect(count.count, 4);
      await count.refresh();
      expect(log.length, 1);
      now = now.add(const Duration(seconds: 61));
      await count.refresh();
      expect(log.length, 2);
      await count.refresh(force: true);
      expect(log.length, 3);
      count.markedRead();
      expect(count.count, 0);
    });

    test('signed out keeps zero and asks nothing', () async {
      final log = <Map<String, dynamic>>[];
      final count = AnilistUnreadCount(
        service: AnilistNotificationsService(client: _fake(log), signedIn: false),
      );
      await count.refresh();
      expect(count.count, 0);
      expect(log, isEmpty);
    });
  });

  group('text', () {
    test('sentences per type', () async {
      final service = AnilistNotificationsService(client: _fake([]), signedIn: true);
      final items = (await service.page()).items;
      final s = S.current;
      expect(describeAnilistNotification(items[0], s).text, 'Episode 6 of ONE PIECE aired');
      expect(describeAnilistNotification(items[1], s), (lead: 'Josh', text: 'started following you'));
      expect(describeAnilistNotification(items[2], s).text, 'replied to your activity');
      expect(describeAnilistNotification(items[3], s).text, 'replied to your comment in Best of 2026');
      expect(describeAnilistNotification(items[5], s).text, 'Old was deleted');
    });
  });

  group('widgets', () {
    testWidgets('page lists, filters and marks read once', (tester) async {
      final log = <Map<String, dynamic>>[];
      final service = AnilistNotificationsService(client: _fake(log), signedIn: true);
      final unread = AnilistUnreadCount(service: service)..markedRead();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        home: AnilistNotificationsPage(service: service, unread: unread),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.textContaining('Episode 6 of ONE PIECE aired'), findsOneWidget);
      expect(log.where((b) => (b['query'] as String).contains('resetNotificationCount: true')).length, 1);
      await tester.tap(find.text('Follows'));
      await tester.pump();
      await tester.pump();
      expect(log.last['variables']['types'], ['FOLLOWING']);
      // Marking read happens once, not per filter.
      expect(log.where((b) => (b['query'] as String).contains('resetNotificationCount: true')).length, 1);
    });

    testWidgets('page signed out offers to sign in', (tester) async {
      final service = AnilistNotificationsService(client: _fake([]), signedIn: false);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        home: AnilistNotificationsPage(service: service),
      ));
      expect(find.text('Sign in to see your notifications'), findsOneWidget);
    });

    testWidgets('bell shows the count', (tester) async {
      final service = AnilistNotificationsService(client: _fake([], unread: 3), signedIn: true);
      final unread = AnilistUnreadCount(service: service);
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        home: Scaffold(body: AnilistNotificationBell(unread: unread, onOpen: () => opened++)),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      expect(opened, 1);
    });
  });
}
