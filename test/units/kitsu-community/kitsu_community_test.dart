import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_forum_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_group_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_post_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_media_discussion_page.dart';

/// Saved from anonymous read-only calls to kitsu.io (2026-10-28). Nothing here reaches Kitsu,
/// nothing writes to a tracker account. Pictures are dropped so no widget fetches one.
String _fixture(String name) => File('test/units/kitsu-community/fixtures/$name.json')
    .readAsStringSync()
    .replaceAll(RegExp(r'https://media\.kitsu[^"]*'), '');

class _Fake {
  _Fake(Map<String, String> byMatch, {this.fail = false}) {
    client = MockClient((request) async {
      requests.add(request);
      if (fail) return http.Response('{}', 500);
      for (final entry in byMatch.entries) {
        if (request.url.toString().contains(entry.key) || request.body.contains(entry.key)) {
          return http.Response.bytes(utf8.encode(_fixture(entry.value)), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
      }
      return http.Response('{}', 404);
    });
  }

  final bool fail;
  final List<http.Request> requests = [];
  late final MockClient client;

  KitsuFeed get feed => KitsuFeed(
        client: KitsuGraphql(
          client: client,
          rest: KitsuHttp(publicClient: client),
          auth: (send, {idempotent}) async => send(client, 'tok'),
        ),
      );
}

const _routes = {
  '/feeds/global/global': 'feed_global',
  '/feeds/group/596': 'feed_group',
  '/feeds/group/': 'feed_group',
  '/feeds/media_aggr/': 'feed_media',
  '/groups': 'groups',
  'findPostById': 'post',
};

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: home,
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('KitsuFeedController', () {
    test('lists posts only, in order, with the cursor of the next page', () async {
      final fake = _Fake(_routes);
      final c = fake.feed.latest();
      await c.loadMore();
      expect(c.isLoaded, isTrue);
      expect(c.length, greaterThan(0));
      expect(c.posts.every((p) => p.id.isNotEmpty), isTrue);
      expect(c.hasMore, isTrue);
      expect(fake.requests.single.url.path, endsWith('/feeds/global/global'));
      c.dispose();
    });

    test('next page passes the cursor and never repeats a post', () async {
      final fake = _Fake(_routes);
      final c = fake.feed.latest();
      await c.loadMore();
      final first = c.length;
      await c.loadMore();
      expect(fake.requests.last.url.queryParameters['page[cursor]'], isNotEmpty);
      // The fixture answers the same page: deduplication keeps the list unchanged.
      expect(c.length, first);
      expect(c.posts.map((p) => p.id).toSet(), hasLength(c.length));
      c.dispose();
    });

    test('a failed first load sets the error and reload clears it', () async {
      var failing = true;
      final good = _Fake(_routes);
      final client = MockClient((request) async {
        if (failing) return http.Response('{}', 500);
        return good.client.send(http.Request(request.method, request.url)).then(http.Response.fromStream);
      });
      final feed = KitsuFeed(
        client: KitsuGraphql(client: client, rest: KitsuHttp(publicClient: client)),
      );
      final c = feed.latest();
      await c.loadMore();
      expect(c.error, isNotNull);
      expect(c.length, 0);
      failing = false;
      await c.reload();
      expect(c.error, isNull);
      expect(c.length, greaterThan(0));
      c.dispose();
    });

    test('news reads group 596 and group feeds read their own id', () async {
      final fake = _Fake(_routes);
      final posts = await fake.feed.newsPosts(limit: 5);
      expect(fake.requests.single.url.path, endsWith('/feeds/group/596'));
      expect(fake.requests.single.url.queryParameters['page[limit]'], '5');
      expect(posts, isNotEmpty);
      final c = fake.feed.group('42');
      await c.loadMore();
      expect(fake.requests.last.url.path, endsWith('/feeds/group/42'));
      c.dispose();
    });

    test('media feed asks for posts of that title', () async {
      final fake = _Fake(_routes);
      final c = fake.feed.media(KitsuMediaKind.anime, '46474');
      await c.loadMore();
      expect(fake.requests.single.url.path, endsWith('Anime-46474'));
      expect(fake.requests.single.url.queryParameters['filter[kind]'], 'posts');
      c.dispose();
    });
  });

  group('screens', () {
    testWidgets('forum tab shows the latest posts, then News and Groups tabs', (tester) async {
      final fake = _Fake(_routes);
      await _pump(tester, KitsuForumPage(feed: fake.feed, showAppBar: false));
      expect(find.text('Latest'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
      await tester.tap(find.text('Groups'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ListTile), findsWidgets);
      expect(fake.requests.any((r) => r.url.path.endsWith('/groups')), isTrue);
    });

    testWidgets('forum shows an error with Retry when Kitsu is unreachable', (tester) async {
      final fake = _Fake(_routes, fail: true);
      await _pump(tester, KitsuForumPage(feed: fake.feed, showAppBar: false));
      expect(find.text('Could not load Kitsu'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a post card opens the post with its comments', (tester) async {
      final fake = _Fake(_routes);
      await _pump(tester, KitsuForumPage(feed: fake.feed, showAppBar: false));
      await tester.tap(find.byType(Card).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(KitsuPostPage), findsOneWidget);
      expect(fake.requests.any((r) => r.body.contains('findPostById')), isTrue);
      expect(find.text('Post'), findsOneWidget);
    });

    testWidgets('post page shows the thread of the saved post', (tester) async {
      final fake = _Fake(_routes);
      await _pump(tester, KitsuPostPage(postId: '9917665', feed: fake.feed));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Supesharisuto'), findsWidgets);
      expect(find.textContaining('Sousou no Frieren'), findsWidgets);
    });

    testWidgets('a deleted post says so', (tester) async {
      final client = MockClient((request) async =>
          http.Response('{"data":{"findPostById":null}}', 200, headers: {'content-type': 'application/json'}));
      final feed = KitsuFeed(
          client: KitsuGraphql(client: client, rest: KitsuHttp(publicClient: client)));
      await _pump(tester, KitsuPostPage(postId: '1', feed: feed));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('This post is no longer available'), findsOneWidget);
    });

    testWidgets('group page shows the group and its feed', (tester) async {
      final fake = _Fake(_routes);
      final groups = await fake.feed.groups();
      final group = groups.groups.first;
      await _pump(tester, KitsuGroupScreen(group: group, feed: fake.feed));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(group.name), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('title discussion page lists the posts about the title', (tester) async {
      final fake = _Fake(_routes);
      await _pump(
        tester,
        KitsuMediaDiscussionPage(
            kind: KitsuMediaKind.anime, mediaId: '46474', title: 'Frieren', feed: fake.feed),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Frieren'), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
    });
  });
}
