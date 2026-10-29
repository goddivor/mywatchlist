import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_rating.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import '../../helpers/no_network.dart';
import 'fakes.dart';

void main() {
  setUpAll(forbidNetwork);

  group('KitsuRating', () {
    test('shows ratingTwenty in each Kitsu system', () {
      expect(KitsuRating.text(15, KitsuRatingSystem.advanced), '7.5');
      expect(KitsuRating.text(20, KitsuRatingSystem.advanced), '10');
      expect(KitsuRating.text(14, KitsuRatingSystem.regular), '3.5');
      expect(KitsuRating.text(2, KitsuRatingSystem.regular), '0.5');
      expect(KitsuRating.simpleIndex(2), 0);
      expect(KitsuRating.simpleIndex(8), 1);
      expect(KitsuRating.simpleIndex(14), 2);
      expect(KitsuRating.simpleIndex(20), 3);
    });

    test('pickers offer Kitsu\'s steps and snap a rating to them', () {
      expect(KitsuRating.steps(KitsuRatingSystem.simple), [2, 8, 14, 20]);
      expect(KitsuRating.steps(KitsuRatingSystem.regular), hasLength(10));
      expect(KitsuRating.steps(KitsuRatingSystem.advanced), hasLength(19));
      expect(KitsuRating.snap(7, KitsuRatingSystem.regular), anyOf(6, 8));
      expect(KitsuRating.snap(13, KitsuRatingSystem.simple), 14);
      expect(KitsuRating.snap(13, KitsuRatingSystem.advanced), 13);
    });
  });

  group('KitsuMyLibrary', () {
    test('reads the user\'s entry of a title with the token', () async {
      final fake = FakeKitsu(graphql: {
        'MyEntry': (_) => {
              'data': {
                'findAnimeById': {'id': '46474', 'myLibraryEntry': entryJson(rating: 15, reaction: 'So good', nextNumber: 6)}
              }
            },
      });
      final e = await fake.my.entryOf(KitsuMediaKind.anime, '46474');
      expect(e!.status, ListEntryStatus.current);
      expect(e.progress, 5);
      expect(e.rating, 15);
      expect(e.reaction, 'So good');
      expect(e.nextUnit!.number, 6);
      expect(fake.requests.single.headers['Authorization'], 'Bearer tok');
    });

    test('a title outside the library has no entry', () async {
      final fake = FakeKitsu(graphql: {
        'MyEntry': (_) => {
              'data': {
                'findAnimeById': {'id': '1', 'myLibraryEntry': null}
              }
            },
      });
      expect(await fake.my.entryOf(KitsuMediaKind.anime, '1'), isNull);
    });

    test('writes only the fields given, and a 0 rating clears it', () async {
      final fake = FakeKitsu(graphql: {
        'mutation Update': (_) => {
              'data': {
                'libraryEntry': {
                  'update': {'errors': [], 'libraryEntry': entryJson(progress: 6)}
                }
              }
            },
      });
      final saved = await fake.my.update('900', progress: 6);
      await fake.my.update('900', rating: 0);
      expect(saved.progress, 6);
      final inputs = fake.inputs('mutation Update');
      expect(inputs.first, {'id': '900', 'progress': 6});
      expect(inputs.last.containsKey('rating'), isTrue);
      expect(inputs.last['rating'], isNull);
    });

    test('a refused write throws', () async {
      final fake = FakeKitsu(graphql: {
        'mutation Update': (_) => {
              'data': {
                'libraryEntry': {
                  'update': {
                    'errors': [
                      {'message': 'nope'}
                    ],
                    'libraryEntry': null
                  }
                }
              }
            },
      });
      expect(() => fake.my.update('900', progress: 1), throwsA(isA<KitsuWriteRefused>()));
    });

    test('adds a title with its status, and toggles the favourite', () async {
      final fake = FakeKitsu(graphql: {
        'mutation Add': (_) => {
              'data': {
                'libraryEntry': {
                  'create': {'errors': [], 'libraryEntry': entryJson(status: 'PLANNED', progress: 0)}
                }
              }
            },
        'mutation Fav': (_) => {
              'data': {
                'favorite': {
                  'create': {'errors': [], 'result': {'id': '77'}}
                }
              }
            },
      }, rest: {
        '/users': (_) => userDoc(),
        '/favorites': (_) => {'data': []},
      });
      final added = await fake.my.add(KitsuMediaKind.anime, '46474', ListEntryStatus.planned);
      expect(added.status, ListEntryStatus.planned);
      expect(fake.inputs('mutation Add').single,
          {'mediaId': '46474', 'mediaType': 'ANIME', 'status': 'PLANNED'});
      expect(await fake.my.favouriteOf(KitsuMediaKind.anime, '46474'), isNull);
      final favRequest = fake.requests.lastWhere((r) => r.url.path.endsWith('/favorites'));
      expect(favRequest.url.queryParameters['filter[userId]'], '42');
      expect(favRequest.url.queryParameters['filter[itemType]'], 'Anime');
      expect(await fake.my.addFavourite(KitsuMediaKind.anime, '46474'), '77');
      expect(fake.inputs('mutation Fav').single, {'id': '46474', 'type': 'ANIME'});
    });

    test('the Quick update list keeps the entries with a title', () async {
      final fake = FakeKitsu(graphql: {
        'QuickUpdate': (_) => {
              'data': {
                'currentProfile': {
                  'library': {
                    'current': {
                      'nodes': [
                        entryJson(nextNumber: 6, media: {
                          '__typename': 'Anime',
                          'id': '46474',
                          'slug': 'frieren',
                          'titles': {'canonical': 'Frieren'},
                          'episodeCount': 28,
                        }),
                        entryJson(id: '901'),
                      ]
                    }
                  }
                }
              }
            },
      });
      final list = await fake.my.currentEntries(kind: KitsuMediaKind.anime);
      expect(list, hasLength(1));
      expect(list.single.total, 28);
      expect(list.single.media!.titles.display, 'Frieren');
      expect(fake.requests.single.body, contains('"type":"ANIME"'));
    });

    test('an episode discussion reads the episode feed', () async {
      final fake = FakeKitsu(rest: {'/feeds/episode_aggr/353471': (_) => {'data': [], 'included': []}});
      final feed = fake.my.unitFeed(KitsuMediaKind.anime, '353471');
      await feed.loadMore();
      expect(fake.requests.single.url.path, endsWith('/feeds/episode_aggr/353471'));
      feed.dispose();
    });
  });

  group('library counts', () {
    test('the five counts come from one meta.statusCounts answer', () async {
      final fake = FakeKitsu(rest: {
        '/users': (_) => userDoc(),
        '/library-entries': (_) => {
              'data': [],
              'meta': {
                'count': 30,
                'statusCounts': {'current': 3, 'planned': 10, 'completed': 15, 'onHold': 1, 'dropped': 1}
              }
            },
      });
      final adapter = KitsuUserListAdapter(library: fake.library, owner: () => 'me');
      final counts = await adapter.statusCounts('anime');
      expect(counts![ListEntryStatus.planned], 10);
      expect(counts[ListEntryStatus.onHold], 1);
      expect(fake.requests.where((r) => r.url.path.endsWith('/library-entries')), hasLength(1));
    });

    test('a status Kitsu leaves out counts 0', () {
      final counts = KitsuUserListAdapter.parseStatusCounts({
        'meta': {
          'statusCounts': {'current': 2}
        }
      })!;
      expect(counts[ListEntryStatus.current], 2);
      expect(counts[ListEntryStatus.dropped], 0);
      expect(KitsuUserListAdapter.parseStatusCounts({'meta': {}}), isNull);
    });

    test('a saved Kitsu entry becomes the list\'s sync entry', () {
      const e = KitsuMyEntry(id: '9', status: ListEntryStatus.completed, progress: 12, rating: 15);
      final sync = KitsuUserListAdapter.syncOf(e, isAnime: true);
      expect(sync.status, 'completed');
      expect(sync.score, 7.5);
      expect(sync.entryId, '9');
    });
  });

  group('catalogue', () {
    Map<String, dynamic> anime(int id, {int? malId}) => {
          'id': '$id',
          'type': 'anime',
          'attributes': {'canonicalTitle': 'Title $id', 'titles': {'en_jp': 'Title $id'}},
          'relationships': {
            'mappings': {'data': []}
          },
        };

    test('Surprise me can draw a title with no MyAnimeList page', () async {
      final fake = FakeKitsu(graphql: {
        'randomMedia': (_) => {
              'data': {
                'randomMedia': {'id': '3'}
              }
            },
      }, rest: {
        '/anime': (_) => {
              'data': [anime(3)]
            },
      });
      final pick = await fake.catalog.randomMedia(isAnime: true, needsMalPage: false);
      expect(pick!.id, 3);
      expect(pick.malId, isNull);
    });

    test('a random pick of the Want to watch list counts it, then reads one entry', () async {
      final fake = FakeKitsu(rest: {
        'page%5Boffset%5D=4': (_) => {
              'data': [
                {
                  'id': 'e1',
                  'type': 'libraryEntries',
                  'relationships': {
                    'anime': {
                      'data': {'type': 'anime', 'id': '8'}
                    }
                  }
                }
              ],
              'included': [anime(8)],
            },
        '/library-entries': (_) => {
              'data': [],
              'meta': {'count': 9}
            },
      });
      final pick = await fake.catalog.randomPlanned('42', isAnime: true, random: _FixedRandom(4));
      expect(pick!.id, 8);
      final first = fake.requests.first.url.queryParameters;
      expect(first['filter[status]'], 'planned');
      expect(first['filter[userId]'], '42');
      expect(fake.requests.every((r) => r.headers['Authorization'] == 'Bearer tok'), isTrue);
    });

    test('an empty Want to watch list gives no pick', () async {
      final fake = FakeKitsu(rest: {
        '/library-entries': (_) => {
              'data': [],
              'meta': {'count': 0}
            },
      });
      expect(await fake.catalog.randomPlanned('42', isAnime: false), isNull);
      expect(fake.requests, hasLength(1));
    });

    test('the latest reactions carry their author and title', () async {
      final fake = FakeKitsu(rest: {
        '/media-reactions': (_) => {
              'data': [
                {
                  'id': 'r1',
                  'type': 'mediaReactions',
                  'attributes': {'reaction': 'Peak fiction', 'upVotesCount': 12, 'progress': 3},
                  'relationships': {
                    'user': {
                      'data': {'type': 'users', 'id': 'u1'}
                    },
                    'anime': {
                      'data': {'type': 'anime', 'id': '46474'}
                    },
                  },
                },
                {
                  'id': 'r2',
                  'type': 'mediaReactions',
                  'attributes': {'reaction': 'No media'},
                  'relationships': {},
                },
              ],
              'included': [
                {'id': 'u1', 'type': 'users', 'attributes': {'name': 'Tamaya', 'slug': 'tamaya'}},
                {
                  'id': '46474',
                  'type': 'anime',
                  'attributes': {'canonicalTitle': 'Sousou no Frieren', 'slug': 'sousou-no-frieren'}
                },
              ],
            },
      });
      final list = await fake.catalog.recentReactions();
      expect(list, hasLength(1));
      expect(list.single.text, 'Peak fiction');
      expect(list.single.likes, 12);
      expect(list.single.author.name, 'Tamaya');
      expect(list.single.media!.kind, KitsuMediaKind.anime);
      expect(list.single.media!.titles.display, 'Sousou no Frieren');
      expect(fake.requests.single.url.queryParameters['sort'], '-createdAt');
    });

    test('favourite categories come with their slug', () async {
      final fake = FakeKitsu(rest: {
        '/category-favorites': (_) => {
              'data': [
                {
                  'id': 'f1',
                  'type': 'categoryFavorites',
                  'relationships': {
                    'category': {
                      'data': {'type': 'categories', 'id': '164'}
                    }
                  }
                }
              ],
              'included': [
                {'id': '164', 'type': 'categories', 'attributes': {'title': 'Elf', 'slug': 'elf'}}
              ],
            },
      });
      final list = await fake.catalog.favouriteCategories('42');
      expect(list.single.slug, 'elf');
      expect(list.single.id, '164');
    });
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final int value;

  @override
  int nextInt(int max) => value;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
