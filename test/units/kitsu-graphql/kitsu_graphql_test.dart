import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';

/// Saved from anonymous read-only calls to kitsu.io on 2026-10-28 (about one request a second).
/// Nothing here reaches Kitsu and nothing writes to a tracker account.
String _fixture(String name) => File('test/units/kitsu-graphql/fixtures/$name.json').readAsStringSync();

class _Fake {
  _Fake(Map<String, String> byMatch, {this.status = 200}) {
    client = MockClient((request) async {
      requests.add(request);
      for (final entry in byMatch.entries) {
        if (request.url.toString().contains(entry.key) || request.body.contains(entry.key)) {
          return http.Response.bytes(utf8.encode(_fixture(entry.value)), status,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
      }
      return http.Response('{}', 404);
    });
  }

  final int status;
  final List<http.Request> requests = [];
  late final MockClient client;

  KitsuGraphql get gql => KitsuGraphql(
        client: client,
        rest: KitsuHttp(publicClient: client),
        auth: (send, {idempotent}) async => send(client, 'tok'),
      );
}

KitsuGraphql _one(String fixture) => _Fake({'query': fixture}).gql;

void main() {
  group('transport', () {
    test('anonymous POST to kitsu.io/api/graphql without a token, query and variables in the body',
        () async {
      final fake = _Fake({'query': 'profile'});
      await fake.gql.profile('Tamaya');
      final r = fake.requests.single;
      expect(r.method, 'POST');
      expect(r.url.toString(), 'https://kitsu.io/api/graphql');
      expect(r.headers.containsKey('Authorization'), isFalse);
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['query'], contains('findProfileBySlug'));
      expect(body['variables'], {'slug': 'Tamaya'});
    });

    test('auth: true sends the Bearer token given by sendAuthenticated', () async {
      final fake = _Fake({'query': 'profile'});
      await fake.gql.execute('{ __typename }', auth: true);
      expect(fake.requests.single.headers['Authorization'], 'Bearer tok');
    });

    test('no valid session: KitsuSessionExpired, nothing is sent', () async {
      final fake = _Fake({'query': 'profile'});
      final gql = KitsuGraphql(client: fake.client, auth: (send, {idempotent}) async => null);
      await expectLater(gql.execute('{ a }', auth: true), throwsA(isA<KitsuSessionExpired>()));
      expect(fake.requests, isEmpty);
    });

    test('a 401 is KitsuSessionExpired, a 500 is KitsuHttpError', () async {
      await expectLater(
          _Fake({'query': 'profile'}, status: 401).gql.execute('{ a }'), throwsA(isA<KitsuSessionExpired>()));
      await expectLater(
          _Fake({'query': 'profile'}, status: 503).gql.execute('{ a }'),
          throwsA(isA<KitsuHttpError>().having((e) => e.statusCode, 'status', 503)));
    });

    test('errors with no data throw KitsuGraphqlError', () async {
      final gql = KitsuGraphql(
          client: MockClient((_) async => http.Response(
              '{"errors":[{"message":"Connection \'likes\' requires the argument \'first\' or \'last\'"}]}', 200)));
      await expectLater(gql.execute('{ a }'),
          throwsA(isA<KitsuGraphqlError>().having((e) => e.messages.single, 'msg', contains('requires'))));
    });

    test('an unauthenticated error code on a signed-in call is KitsuSessionExpired', () async {
      final client = MockClient((_) async => http.Response(
          '{"data":null,"errors":[{"message":"x","extensions":{"code":"unauthenticated"}}]}', 200));
      final gql = KitsuGraphql(client: client, auth: (send, {idempotent}) => send(client, 't'));
      await expectLater(gql.execute('{ a }', auth: true), throwsA(isA<KitsuSessionExpired>()));
    });

    test('partial errors keep the data', () async {
      final response = await _one('media_anime').execute('query');
      expect(response.errors.single, contains('MediaReaction.author'));
      expect(response.data['findAnimeBySlug'], isNotNull);
    });
  });

  group('pagination', () {
    test('page size is clamped to 1..50 and sent as first/after', () {
      expect(const KitsuPageArgs(first: 0).first, 1);
      expect(const KitsuPageArgs(first: 500).first, 50);
      expect(const KitsuPageArgs(first: 10, after: 'Mw').toVariables(), {'first': 10, 'after': 'Mw'});
    });

    test('nextPage follows endCursor and stops on the last page', () async {
      final units = await _one('media_chapters').mediaUnits(KitsuMediaKind.manga, '56355');
      expect(units.totalCount, 2027);
      expect(units.nodes.map((u) => u.number), [1, 2, 3]);
      final next = units.nextPage(first: 30)!;
      expect((next.after, next.first), ('Mw', 30));
      expect(const KitsuConnection<int>().nextPage(), isNull);
      final last = await _one('profile_library').profileLibrary('Tamaya');
      expect(last.nextPage(), isNull);
    });
  });

  group('media detail', () {
    test('anime: header, rank, streaming, relations, external ids', () async {
      final fake = _Fake({'findAnimeBySlug': 'media_anime'});
      final d = (await fake.gql.mediaDetail(KitsuMediaKind.anime, slug: 'sousou-no-frieren'))!;
      expect(d.kind, KitsuMediaKind.anime);
      expect((d.id, d.slug), ('46474', 'sousou-no-frieren'));
      expect(d.titles.display, 'Sousou no Frieren');
      expect(d.titles.translated, contains('Frieren'));
      expect(d.description, isNotEmpty);
      expect(d.averageRating, closeTo(88.85, 0.5));
      expect(d.averageRatingRank, isNotNull);
      expect(d.userCount, greaterThan(1000));
      expect(d.favoritesCount, greaterThan(100));
      expect(d.youtubeTrailerVideoId, 'qgQunxD0qCk');
      expect(d.status, 'FINISHED');
      expect(d.startDate, DateTime.parse('2023-09-29'));
      expect(d.streamingLinks.map((l) => l.site), containsAll(['Netflix', 'Crunchyroll']));
      expect(d.streamingLinks.first.subs, ['en']);
      expect(d.relations.map((r) => r.kind), contains('SEQUEL'));
      expect(d.relations.firstWhere((r) => r.kind == 'ADAPTATION').media.kind, KitsuMediaKind.manga);
      expect(d.malId, 52991);
      expect(d.anilistId, 154587);
      expect(d.externalId('ANIDB'), anyOf(isNull, isNotEmpty));
      expect(d.categories.map((c) => c.slug), contains('fantasy'));
      expect(d.categories.firstWhere((c) => c.slug == 'fantasy').title, 'Fantasy');
      expect(d.poster!.url, startsWith('https://media.kitsu.app/'));
      final vars = jsonDecode(fake.requests.single.body)['variables'];
      expect(vars, {'key': 'sousou-no-frieren', 'units': 12});
    });

    test('anime: a reaction whose author was deleted is skipped, the rest stay', () async {
      final d = (await _Fake({'findAnimeBySlug': 'media_anime'})
              .gql
              .mediaDetail(KitsuMediaKind.anime, slug: 'x'))!;
      expect(d.reactions.totalCount, greaterThan(100));
      expect(d.reactions.nodes, hasLength(5));
      final first = d.reactions.nodes.first;
      expect(first.author.name, isNotEmpty);
      expect(first.likes, greaterThan(0));
      expect(first.progress, isNonNegative);
    });

    test('anime: posts and episodes (first page, cursor, total)', () async {
      final d = (await _one('media_anime').mediaDetail(KitsuMediaKind.anime, slug: 'x'))!;
      expect(d.posts.totalCount, greaterThan(100));
      expect(d.posts.nodes.first.author.name, isNotEmpty);
      expect(d.units.totalCount, 28);
      expect(d.units.nodes.first.number, 1);
      expect(d.units.nodes.first.title, "The Journey's End");
      expect(d.units.nodes.first.length, 1440);
      expect(d.units.nodes.first.thumbnail, isNotNull);
      expect(d.units.hasNextPage, isTrue);
    });

    test('anime with a cast: characters with the Japanese voice actor, staff, quotes', () async {
      final d = (await _one('media_anime_cast').mediaDetail(KitsuMediaKind.anime, id: '1'))!;
      expect(d.characters.nodes, isNotEmpty);
      final withVoice = d.characters.nodes.firstWhere((c) => c.voice != null);
      expect(withVoice.voice!.name, isNotEmpty);
      expect(withVoice.role, anyOf('MAIN', 'RECURRING', 'BACKGROUND', 'CAMEO'));
      expect(d.staff.nodes.first.role, isNotEmpty);
      expect(d.quotes.first.lines.first.text, isNotEmpty);
      expect(d.streamingLinks, isNotEmpty);
    });

    test('manga: chapters instead of episodes, no streaming', () async {
      final d = (await _one('media_manga').mediaDetail(KitsuMediaKind.manga, slug: 'x'))!;
      expect(d.kind, KitsuMediaKind.manga);
      expect(d.subtype, 'MANGA');
      expect(d.units.nodes.map((c) => c.number), [1, 2, 3, 4, 5]);
      expect(d.streamingLinks, isEmpty);
      expect(d.youtubeTrailerVideoId, isNull);
      expect(d.malId, isNotNull);
    });

    test('unknown title is null', () async {
      final gql = KitsuGraphql(
          client: MockClient((_) async => http.Response('{"data":{"findAnimeBySlug":null}}', 200)));
      expect(await gql.mediaDetail(KitsuMediaKind.anime, slug: 'nope'), isNull);
    });

    test('documents: by slug or by id, anime or manga', () {
      final bySlug = KitsuGraphql.mediaDetailDocument(KitsuMediaKind.anime, bySlug: true);
      expect(bySlug, contains(r'query MediaDetail($key: String!'));
      expect(bySlug, contains(r'findAnimeBySlug(slug: $key)'));
      expect(KitsuGraphql.mediaDetailDocument(KitsuMediaKind.manga, bySlug: false),
          contains(r'findMangaById(id: $key)'));
      expect(KitsuGraphql.mediaDetailDocument(KitsuMediaKind.manga, bySlug: false),
          isNot(contains('streamingLinks')));
    });

    test('paged connections of a title', () async {
      final reactions = await _one('media_reactions').mediaReactions(KitsuMediaKind.anime, '46474');
      expect(reactions.nodes.length, greaterThan(0));
      expect(reactions.hasNextPage, isTrue);
      final posts = await _one('media_posts').mediaPosts(KitsuMediaKind.anime, '46474');
      expect(posts.nodes.first.id, isNotEmpty);
      final chars = await _one('media_characters').mediaCharacters(KitsuMediaKind.anime, '1');
      expect(chars.nodes.first.name, isNotEmpty);
      final staff = await _one('media_staff').mediaStaff(KitsuMediaKind.anime, '1');
      expect(staff.nodes.first.name, isNotEmpty);
      final eps = await _one('media_episodes').mediaUnits(KitsuMediaKind.anime, '46474');
      expect(eps.totalCount, 28);
    });

    test('ratingFrequencies: the 2..20 histogram from JSON:API', () async {
      final fake = _Fake({'/anime/46474': 'rating_frequencies'});
      final h = await fake.gql.ratingFrequencies(KitsuMediaKind.anime, '46474');
      expect(h[20], 5461);
      expect(h[2], 201);
      expect(h[5], 1);
      expect(h[7], 5);
      expect(h.steps, hasLength(19));
      expect(h.total, greaterThan(10000));
      expect(Uri.decodeFull(fake.requests.single.url.toString()), contains('fields[anime]=ratingFrequencies'));
    });

    test('lookupMapping: a MAL id resolves to a Kitsu title', () async {
      final ref = await _one('lookup_mapping').lookupMapping('MYANIMELIST_ANIME', '52991');
      expect((ref!.kind, ref.id, ref.slug), (KitsuMediaKind.anime, '46474', 'sousou-no-frieren'));
    });
  });

  group('post thread', () {
    test('a post with its comments and replies', () async {
      final t = (await _one('post').post('9917665'))!;
      expect(t.post.id, '9917665');
      expect(t.post.contentHtml, startsWith('<p>'));
      expect(t.comments.totalCount, 1);
      expect(t.comments.nodes.single.author.name, isNotEmpty);
      expect(t.comments.nodes.single.repliesCount, 0);
    });

    test('a deleted post is null', () async {
      final gql = KitsuGraphql(
          client: MockClient((_) async => http.Response('{"data":{"findPostById":null}}', 200)));
      expect(await gql.post('1'), isNull);
    });
  });

  group('profile', () {
    test('summary: counters, links, avatar', () async {
      final p = (await _one('profile').profile('Tamaya'))!;
      expect((p.id, p.name), ('286143', 'Tamaya'));
      expect(p.followers, 94);
      expect(p.following, greaterThan(0));
      expect(p.activity, greaterThan(1000));
      expect(p.siteLinks.single.site, 'Discord');
      expect(p.avatar, isNotNull);
      expect(p.waifuOrHusbando, 'Waifu');
      expect(p.birthday, DateTime.parse('2002-12-29'));
    });

    test('activity: kind, old to new values, media', () async {
      final a = await _one('profile_activity').profileActivity('Tamaya', const KitsuPageArgs(first: 3));
      expect(a.totalCount, 1979);
      final e = a.nodes.first;
      expect(e.kind, 'UPDATED');
      expect(e.changes['status'], ['current', 'planned']);
      expect(e.changedTo('status'), 'planned');
      expect(e.changedTo('rating'), isNull);
      expect(e.media.kind, KitsuMediaKind.anime);
    });

    test('reactions, posts, followers, following', () async {
      final r = await _one('profile_reactions').profileReactions('Tamaya');
      expect(r.nodes.first.media!.titles.display, isNotEmpty);
      expect(r.nodes.first.author.name, 'Tamaya');
      final posts = await _one('profile_posts').profilePosts('Tamaya');
      expect(posts.totalCount, greaterThan(100));
      final f = await _one('profile_followers').profileFollowers('Tamaya');
      expect(f.nodes.first.name, isNotEmpty);
      final g = await _one('profile_following').profileFollowing('Tamaya');
      expect(g.nodes, isNotEmpty);
    });

    test('favourites: characters, people and titles, each with a name', () async {
      final fav = await _one('profile_favourites').profileFavourites('Tamaya');
      expect(fav.totalCount, 19);
      expect(fav.nodes.first.type, 'Character');
      expect(fav.nodes.first.name, 'Haruno Yukinoshita');
      expect(fav.nodes.first.image, isNotNull);
    });

    test('public library page with statuses sent as a list', () async {
      final fake = _Fake({'query': 'profile_library'});
      final lib = await fake.gql.profileLibrary('Tamaya',
          kind: KitsuMediaKind.anime, statuses: ['CURRENT']);
      expect(lib.nodes.first.status, 'CURRENT');
      expect(lib.nodes.first.progress, 3);
      expect(lib.nodes.first.rating, isNull);
      final vars = jsonDecode(fake.requests.single.body)['variables'];
      expect(vars['status'], ['CURRENT']);
      expect(vars['type'], 'ANIME');
    });

    test('user search', () async {
      final r = await _one('search_profiles').searchProfiles('tamaya');
      expect(r.nodes, isNotEmpty);
      expect(r.nodes.first.handle, isNotEmpty);
    });
  });

  group('feeds and groups', () {
    test('global feed: posts and comments resolved, reactions listed, next cursor', () async {
      final page = await _Fake({'/feeds/global/global': 'feed_global'}).gql.globalFeed(limit: 6);
      expect(page.items, hasLength(6));
      expect(page.items.map((i) => i.verb),
          containsAll([KitsuFeedVerb.post, KitsuFeedVerb.comment, KitsuFeedVerb.mediaReaction]));
      final post = page.items.firstWhere((i) => i.verb == KitsuFeedVerb.post);
      expect(post.foreignId, startsWith('Post:'));
      expect(post.post!.id, post.subjectId);
      expect(post.post!.user!.name, isNotEmpty);
      final comment = page.items.firstWhere((i) => i.verb == KitsuFeedVerb.comment);
      expect(comment.comment!.content, isNotEmpty);
      expect(page.items.firstWhere((i) => i.verb == KitsuFeedVerb.mediaReaction).post, isNull);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, isNotEmpty);
    });

    test('the request asks for subject and subject.user and passes the cursor', () async {
      final fake = _Fake({'/feeds/group/596': 'feed_group'});
      await fake.gql.groupFeed('596', cursor: 'abc', limit: 3);
      final q = fake.requests.single.url.queryParameters;
      expect(q['include'], 'subject,subject.user');
      expect(q['page[cursor]'], 'abc');
      expect(q['page[limit]'], '3');
    });

    test('media feed filters posts; group feed is the news source', () async {
      final fake = _Fake({'/feeds/media_aggr/Anime-46474': 'feed_media'});
      final page = await fake.gql.mediaFeed(KitsuMediaKind.anime, '46474', limit: 3);
      expect(fake.requests.single.url.queryParameters['filter[kind]'], 'posts');
      expect(page.items, isNotEmpty);
      final news = await _Fake({'/feeds/group/596': 'feed_group'}).gql.groupFeed('596');
      expect(news.items.any((i) => i.post != null || i.comment != null), isTrue);
    });

    test('groups directory', () async {
      final fake = _Fake({'/groups': 'groups'});
      final page = await fake.gql.groups(limit: 3);
      expect(page.groups, hasLength(3));
      expect(page.total, greaterThan(1000));
      expect(page.nextOffset, 3);
      expect(page.groups.first.name, isNotEmpty);
      expect(page.groups.first.membersCount, greaterThan(0));
      expect(fake.requests.single.url.queryParameters['sort'], '-lastActivityAt');
    });

    test('the timeline needs the token', () async {
      final fake = _Fake({'/feeds/timeline/1': 'feed_group'});
      final signedOut = KitsuGraphql(
          rest: KitsuHttp(publicClient: fake.client, auth: (send, {idempotent}) async => null));
      await expectLater(signedOut.timelineFeed('1'), throwsA(isA<KitsuSessionExpired>()));
    });
  });
}
