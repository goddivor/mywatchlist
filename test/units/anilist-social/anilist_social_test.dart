import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

// Trimmed from real anonymous answers of graphql.anilist.co (2026-10-29).
const _user = {
  'id': 173268,
  'name': 'Muffaroo',
  'avatar': {'medium': 'https://s4.anilist.co/file/anilistcdn/user/avatar/medium/b173268.png'},
};

final _threadAnswer = {
  'thread': {
    'id': 4446,
    'title': ' Anime Watching Challenge: Challenge Submissions ',
    'body': "<img width='' src='https://i.postimg.cc/X4Vg0J9w/sub1.png'><p>Hello</p>",
    'createdAt': 1533337000,
    'replyCount': 3,
    'viewCount': 120000,
    'likeCount': 50,
    'isLiked': false,
    'isSubscribed': true,
    'isLocked': false,
    'isSticky': true,
    'user': _user,
    'categories': [
      {'id': 7, 'name': 'General'},
    ],
    'mediaCategories': [
      {
        'id': 21,
        'type': 'ANIME',
        'title': {'userPreferred': 'ONE PIECE'},
        'coverImage': {'medium': 'https://x/21.jpg', 'large': 'https://x/21-l.jpg'},
        'bannerImage': null,
      },
    ],
  },
  'comments': {
    'pageInfo': {'hasNextPage': true},
    'threadComments': [
      {
        'id': 674590,
        'comment':
            '<p><a href="https://anilist.co/forum/thread/23941/comment/627142">February 2021 Monthly - Easy</a></p>',
        'likeCount': 0,
        'isLiked': false,
        'isLocked': false,
        'createdAt': 1613788555,
        'user': _user,
        'childComments': [
          {
            'id': 683257,
            'comment': '<p>Congratulations!</p>',
            'likeCount': 2,
            'isLiked': true,
            'isLocked': false,
            'createdAt': 1614065930,
            'user': _user,
            'childComments': [
              {'id': 683300, 'comment': '<p>Thanks</p>', 'user': _user, 'childComments': null},
            ],
          },
        ],
      },
      {'id': 692832, 'comment': '<p>Fixed!</p>', 'user': _user, 'childComments': null},
    ],
  },
};

final _activities = {
  'Page': {
    'pageInfo': {'hasNextPage': true},
    'activities': [
      {
        '__typename': 'ListActivity',
        'id': 1190095206,
        'status': 'watched episode',
        'progress': '46 - 969',
        'likeCount': 462,
        'replyCount': 14,
        'isLiked': false,
        'isSubscribed': false,
        'isPinned': false,
        'createdAt': 1793247420,
        'user': _user,
        'media': {
          'id': 21,
          'type': 'ANIME',
          'title': {'userPreferred': 'ONE PIECE'},
          'coverImage': {'medium': 'https://x/21.jpg'},
        },
      },
      {
        '__typename': 'TextActivity',
        'id': 1190095025,
        'text': "<img width='220' src='https://media1.tenor.com/a.gif'>",
        'likeCount': 3,
        'replyCount': 0,
        'isLiked': true,
        'isPinned': true,
        'createdAt': 1793247396,
        'user': _user,
      },
      {
        '__typename': 'MessageActivity',
        'id': 55,
        'message': '<p>hi</p>',
        'isPrivate': true,
        'messenger': _user,
        'recipient': {'id': 2, 'name': 'Josh'},
      },
      {'__typename': 'SomethingNew', 'id': 1},
    ],
  },
};

http.Response _ok(Object data) => http.Response(jsonEncode({'data': data}), 200);

/// A client answering from [answer]; [reads] and [writes] log the bodies sent.
AnilistGraphql _fake(
  Object Function(Map<String, dynamic> body) answer, {
  List<Map<String, dynamic>>? reads,
  List<Map<String, dynamic>>? writes,
}) =>
    AnilistGraphql(
      sender: (body, {required auth}) async {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        reads?.add(decoded);
        return _ok(answer(decoded));
      },
      mutationSender: (body, {required auth}) async {
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        writes?.add(decoded);
        return _ok(answer(decoded));
      },
    );

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('parseAnilistLink', () {
    test('reads every in-app page', () {
      expect(parseAnilistLink('https://anilist.co/anime/1/Cowboy-Bebop/'),
          const AnilistLink(AnilistLinkKind.anime, id: 1));
      expect(parseAnilistLink('/manga/30013'), const AnilistLink(AnilistLinkKind.manga, id: 30013));
      expect(parseAnilistLink('https://anilist.co/user/Josh'),
          const AnilistLink(AnilistLinkKind.user, name: 'Josh'));
      expect(parseAnilistLink('https://anilist.co/forum/thread/4446'),
          const AnilistLink(AnilistLinkKind.thread, id: 4446));
      expect(parseAnilistLink('https://anilist.co/forum/thread/23941/comment/627142'),
          const AnilistLink(AnilistLinkKind.comment, id: 627142, threadId: 23941));
      expect(parseAnilistLink('https://www.anilist.co/activity/9'),
          const AnilistLink(AnilistLinkKind.activity, id: 9));
      expect(parseAnilistLink('https://anilist.co/review/33465'),
          const AnilistLink(AnilistLinkKind.review, id: 33465));
      expect(parseAnilistLink('https://anilist.co/character/40'),
          const AnilistLink(AnilistLinkKind.character, id: 40));
    });

    test('ignores other sites and pages without a screen', () {
      expect(parseAnilistLink('https://myanimelist.net/anime/1'), isNull);
      expect(parseAnilistLink('https://anilist.co/search/anime'), isNull);
      expect(parseAnilistLink('https://anilist.co/forum/recent'), isNull);
      expect(parseAnilistLink('relative/path'), isNull);
    });
  });

  group('AnilistSocialService reads', () {
    test('thread and its comment tree come in one request', () async {
      final reads = <Map<String, dynamic>>[];
      final service = AnilistSocialService(
        client: _fake((_) => _threadAnswer, reads: reads),
        signedIn: false,
      );
      final (thread, comments) = await service.thread(4446);
      expect(reads, hasLength(1));
      expect(reads.single['query'], contains('thread: Thread(id: \$id)'));
      expect(reads.single['variables'], {'id': 4446, 'perPage': 25});
      expect(thread.title, 'Anime Watching Challenge: Challenge Submissions');
      expect(thread.isSubscribed, isTrue);
      expect(thread.categories.single.id, 7);
      expect(thread.media.single.title, 'ONE PIECE');
      expect(thread.media.single.coverUrl, 'https://x/21-l.jpg');
      expect(comments.hasNext, isTrue);
      expect(comments.items.map((c) => c.id), [674590, 692832]);
      final first = comments.items.first;
      expect(first.children.single.isLiked, isTrue);
      expect(first.flattened.map((c) => c.id), [674590, 683257, 683300]);
    });

    test('updateTree edits and removes at any depth', () async {
      final service = AnilistSocialService(client: _fake((_) => _threadAnswer), signedIn: false);
      final (_, page) = await service.thread(4446);
      var tree = AnilistComment.updateTree(page.items, 683300, (c) => c.copyWith(likeCount: 9));
      expect(tree.first.children.first.children.first.likeCount, 9);
      tree = AnilistComment.updateTree(tree, 683257, (_) => null);
      expect(tree.first.children, isEmpty);
      expect(tree, hasLength(2));
    });

    test('thread filters become Page.threads arguments', () async {
      final reads = <Map<String, dynamic>>[];
      final service = AnilistSocialService(
        client: _fake((_) => {'Page': {'pageInfo': {'hasNextPage': false}, 'threads': []}},
            reads: reads),
        signedIn: false,
      );
      await service.threads(const AnilistThreadFilter(
        sort: 'ID_DESC',
        categoryId: 5,
        subscribed: true,
        search: '  frieren ',
      ));
      final v = reads.single['variables'] as Map<String, dynamic>;
      expect(v['sort'], ['SEARCH_MATCH', 'ID_DESC']);
      expect(v['categoryId'], 5);
      expect(v['subscribed'], isTrue);
      expect(v['search'], 'frieren');
      expect(v.containsKey('mediaCategoryId'), isFalse);
    });

    test('activities: the three kinds, unknown kinds skipped', () async {
      final reads = <Map<String, dynamic>>[];
      final service = AnilistSocialService(
        client: _fake((_) => _activities, reads: reads),
        signedIn: false,
      );
      final page = await service.activities(scope: AnilistFeedScope.global);
      final v = reads.single['variables'] as Map<String, dynamic>;
      expect(v['hasReplies'], isTrue);
      expect(v.containsKey('following'), isFalse);
      expect(page.items.map((a) => a.kind), [
        AnilistActivityKind.list,
        AnilistActivityKind.text,
        AnilistActivityKind.message,
      ]);
      final list = page.items.first;
      expect(list.media?.title, 'ONE PIECE');
      expect(list.progress, '46 - 969');
      expect(page.items[1].isPinned, isTrue);
      final message = page.items[2];
      expect(message.user?.name, 'Muffaroo');
      expect(message.recipient?.name, 'Josh');
      expect(message.isPrivate, isTrue);

      await service.activities(scope: AnilistFeedScope.following, kind: AnilistFeedKind.list);
      final f = reads.last['variables'] as Map<String, dynamic>;
      expect(f['following'], isTrue);
      expect(f['types'], ['ANIME_LIST', 'MANGA_LIST']);
      expect(f.containsKey('hasReplies'), isFalse);
    });

    test('reviews and likes parse', () async {
      final service = AnilistSocialService(
        client: _fake((body) {
          final q = body['query'] as String;
          if (q.contains('likes(')) {
            return {
              'Page': {
                'pageInfo': {'hasNextPage': false},
                'likes': [_user],
              },
            };
          }
          return {
            'Page': {
              'pageInfo': {'hasNextPage': true},
              'reviews': [
                {
                  'id': 33465,
                  'summary': 'Rascal does not dream of being a movie finale',
                  'score': 77,
                  'rating': 2,
                  'ratingAmount': 3,
                  'createdAt': 1793229515,
                  'private': false,
                  'user': _user,
                  'media': {
                    'id': 199340,
                    'type': 'ANIME',
                    'title': {'userPreferred': 'Seishun Buta Yarou'},
                  },
                },
              ],
            },
          };
        }),
        signedIn: false,
      );
      final reviews = await service.reviews(sort: AnilistReviewSort.helpful);
      expect(reviews.items.single.score, 77);
      expect(reviews.items.single.ratingAmount, 3);
      expect(reviews.hasNext, isTrue);
      final likes = await service.likes(AnilistLikeable.thread, 4446);
      expect(likes.items.single.name, 'Muffaroo');
    });
  });

  group('AnilistSocialService writes', () {
    test('a comment goes through mutate with its parent', () async {
      final reads = <Map<String, dynamic>>[];
      final writes = <Map<String, dynamic>>[];
      final service = AnilistSocialService(
        client: _fake(
          (_) => {
            'SaveThreadComment': {'id': 9, 'comment': '<p>yo</p>', 'user': _user},
          },
          reads: reads,
          writes: writes,
        ),
        signedIn: true,
      );
      final saved = await service.saveComment(threadId: 4446, parentId: 674590, markdown: 'yo');
      expect(saved.id, 9);
      expect(reads, isEmpty);
      expect(writes.single['query'], contains('SaveThreadComment'));
      expect(writes.single['variables'],
          {'threadId': 4446, 'parentCommentId': 674590, 'comment': 'yo'});
    });

    test('a delete AniList did not apply throws', () async {
      final service = AnilistSocialService(
        client: _fake((_) => {'DeleteThreadComment': {'deleted': false}}),
        signedIn: true,
      );
      expect(service.deleteComment(1), throwsA(isA<AnilistError>()));
    });

    test('a review vote returns the new counts', () async {
      final writes = <Map<String, dynamic>>[];
      final service = AnilistSocialService(
        client: _fake(
          (_) => {
            'RateReview': {'id': 5, 'rating': 3, 'ratingAmount': 4, 'userRating': 'UP_VOTE'},
          },
          writes: writes,
        ),
        signedIn: true,
      );
      final r = await service.rateReview(5, AnilistReviewVote.up);
      expect(writes.single['variables'], {'id': 5, 'rating': 'UP_VOTE'});
      expect(r.userRating, AnilistReviewVote.up);
      expect(r.rating, 3);
    });

    test('likes use the shared ToggleLikeV2 action', () async {
      final writes = <Map<String, dynamic>>[];
      final gql = _fake(
        (_) => {
          'ToggleLikeV2': {'isLiked': true, 'likeCount': 4},
        },
        writes: writes,
      );
      final service = AnilistSocialService(
          client: gql, actions: AnilistActions(client: gql), signedIn: true);
      final like = await service.toggleLike(AnilistLikeable.activityReply, 7);
      expect(like, const AnilistLikeState(isLiked: true, likeCount: 4));
      expect(writes.single['variables'], {'id': 7, 'type': 'ACTIVITY_REPLY'});
    });
  });

  group('text', () {
    test('list updates read in the app language', () {
      expect(anilistListStatusText('watched episode', '5'), 'Watched episode 5 of');
      expect(anilistListStatusText('read chapter', '1 - 22'), 'Read chapters 1 - 22 of');
      expect(anilistListStatusText('completed', null), 'Completed');
      expect(anilistListStatusText('paused reading', '3'), 'Paused');
      expect(anilistListStatusText('something new', '2'), 'Something new 2');
    });

    test('times are short', () {
      final now = DateTime(2026, 10, 29, 12);
      expect(formatAnilistTime(now.subtract(const Duration(seconds: 10)), now: now), 'now');
      expect(formatAnilistTime(now.subtract(const Duration(minutes: 5)), now: now), '5m');
      expect(formatAnilistTime(now.subtract(const Duration(hours: 3)), now: now), '3h');
      expect(formatAnilistTime(now.subtract(const Duration(days: 2)), now: now), '2d');
      expect(formatAnilistTime(null), '');
    });
  });

  group('AnilistHtml', () {
    testWidgets('a spoiler stays hidden until tapped', (tester) async {
      await pumpInApp(
        tester,
        const SizedBox(
          width: 360,
          child: AnilistHtml(
            "<p>before <span class='markdown_spoiler'><span>the secret</span></span></p>",
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('before', findRichText: true), findsOneWidget);
      expect(find.textContaining('the secret', findRichText: true), findsNothing);
      await tester.tap(find.text('Spoiler'));
      await tester.pumpAndSettle();
      expect(find.textContaining('the secret', findRichText: true), findsOneWidget);
    });

    test('embeds are recognised', () {
      final doc = html_parser.parseFragment(
          "<div class='youtube' id='dQw4w9WgXcQ'></div><video><source src='https://x/a.webm'></video>");
      final elements = doc.children;
      expect(anilistYoutubeId(elements[0]), 'dQw4w9WgXcQ');
      expect(anilistVideoUrl(elements[1]), 'https://x/a.webm');
      expect(anilistYoutubeId(elements[1]), isNull);
    });
  });
}
