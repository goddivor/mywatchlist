import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import 'kitsu_fakes.dart';

void main() {
  group('KitsuMedia', () {
    test('reads titles, score, ranks and the MyAnimeList mapping', () {
      final doc = KitsuDocument.from({
        'data': [animeResource(1, 'Frieren', malId: 52991)],
        'included': mappingsOf(1, malId: 52991),
      });
      final media = KitsuMedia.fromResource(doc.data.first, doc, titleLang: 'ro');
      expect(media.title, 'Frieren');
      expect(media.malId, 52991);
      expect(media.meanScore, closeTo(8.25, 0.001));
      expect(media.total, 12);
      expect(media.releaseState, ReleaseState.releasing);
      expect(media.malMediaType, 'tv');
      expect(media.malStatus, 'currently_airing');
      expect(media.otherTitles, containsAll(['Frieren EN', 'Frieren JA']));
    });

    test('the title follows the preferred language', () {
      final doc = KitsuDocument.from({
        'data': [animeResource(1, 'Frieren')],
        'included': mappingsOf(1),
      });
      String title(String lang) =>
          KitsuMedia.fromResource(doc.data.first, doc, titleLang: lang).title;
      expect(title('en'), 'Frieren EN');
      expect(title('ja'), 'Frieren JA');
      expect(title('ro'), 'Frieren');
    });

    test('a title without a MyAnimeList mapping has no card model', () {
      final doc = KitsuDocument.from({
        'data': [animeResource(2, 'Local only')],
        'included': mappingsOf(2),
      });
      final media = KitsuMedia.fromResource(doc.data.first, doc, titleLang: 'ro');
      expect(media.malId, isNull);
      expect(media.toAnime(), isNull);
    });

    test('the card model is keyed by the MyAnimeList id', () {
      final doc = KitsuDocument.from({
        'data': [animeResource(3, 'Mapped', malId: 77)],
        'included': mappingsOf(3, malId: 77),
      });
      final anime = KitsuMedia.fromResource(doc.data.first, doc, titleLang: 'ro').toAnime()!;
      expect(anime.id, 77);
      expect(anime.imageUrl, 'https://img/l3.jpg');
      expect(anime.score, closeTo(8.25, 0.001));
      expect(anime.mediaType, 'tv');
    });

    test('manga subtypes map to MyAnimeList media types', () {
      KitsuMedia manga(String subtype) => KitsuMedia.fromResource({
            'id': '1',
            'type': 'manga',
            'attributes': {'canonicalTitle': 'M', 'subtype': subtype, 'chapterCount': 10},
          }, const KitsuDocument([], {}, {}, false), titleLang: 'ro');
      expect(manga('novel').malMediaType, 'light_novel');
      expect(manga('oneshot').malMediaType, 'one_shot');
      expect(manga('doujin').malMediaType, 'doujinshi');
      expect(manga('manga').total, 10);
      expect(manga('manga').isAnime, isFalse);
    });
  });

  group('KitsuMediaQuery', () {
    test('asks for the mappings and a page', () {
      const query = KitsuMediaQuery(
          isAnime: true, filters: {'status': 'current'}, sort: '-userCount');
      final params = query.params(limit: 15, offset: 30);
      expect(params['filter[status]'], 'current');
      expect(params['sort'], '-userCount');
      expect(params['include'], 'mappings');
      expect(params['page[limit]'], '15');
      expect(params['page[offset]'], '30');
    });

    test('a text search drops the sort', () {
      final query = const KitsuMediaQuery(isAnime: false, sort: 'popularityRank').withText(' naruto ');
      final params = query.params(limit: 20, offset: 0);
      expect(params['filter[text]'], 'naruto');
      expect(params.containsKey('sort'), isFalse);
      expect(query.path, '/manga');
    });

    test('equal queries are equal and have the same key', () {
      const a = KitsuMediaQuery(isAnime: true, filters: {'a': '1', 'b': '2'}, sort: 's');
      const b = KitsuMediaQuery(isAnime: true, filters: {'b': '2', 'a': '1'}, sort: 's');
      expect(a, b);
      expect(a.key, b.key);
    });
  });

  group('KitsuCatalog', () {

    test('trending reads the ids then the mappings, in Kitsu order', () async {
      final fake = FakeKitsu((r) async {
        if (r.url.path.endsWith('/trending/anime')) {
          return jsonResponse({
            'data': [
              {'id': '2', 'type': 'anime'},
              {'id': '1', 'type': 'anime'},
            ],
          });
        }
        return jsonResponse({
          'data': [animeResource(1, 'One', malId: 11), animeResource(2, 'Two', malId: 22)],
          'included': [...mappingsOf(1, malId: 11), ...mappingsOf(2, malId: 22)],
        });
      });
      final items = await KitsuCatalog(http: fake.kitsu).trending(isAnime: true);
      expect(items.map((m) => m.malId), [22, 11]);
      expect(fake.requests.last.url.queryParameters['filter[id]'], '2,1');
    });

    test('a page reports whether Kitsu has a next one', () async {
      final fake = FakeKitsu((r) async => jsonResponse({
            'data': [animeResource(1, 'One', malId: 11)],
            'included': mappingsOf(1, malId: 11),
            'links': {'next': 'https://kitsu.io/api/edge/anime?page[offset]=20'},
          }));
      final page = await KitsuCatalog(http: fake.kitsu)
          .page(const KitsuMediaQuery(isAnime: true), limit: 50);
      expect(page.hasMore, isTrue);
      expect(page.items, hasLength(1));
      // Media endpoints never get more than 20 per page.
      expect(fake.requests.single.url.queryParameters['page[limit]'], '20');
    });
  });
}
