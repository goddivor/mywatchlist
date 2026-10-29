import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media_detail.dart';

import '../../helpers/no_network.dart';
import 'fakes.dart';

void main() {
  setUpAll(forbidNetwork);

  FakeKitsu site() => FakeKitsu(
        graphql: {
          'findAnimeBySlug': fixtureJson('media_anime'),
          'findAnimeById': fixtureJson('media_episodes'),
          'findMangaBySlug': fixtureJson('media_manga'),
        },
        rest: {'/anime/46474': fixtureJson('rating_frequencies')},
      );

  test('detail by slug returns the record and is then known under its id as well', () async {
    final fake = site();
    final service = fake.service();
    final d = await service.detail(KitsuMediaKind.anime, slug: 'sousou-no-frieren');
    expect(d, isNotNull);
    expect(d!.id, '46474');
    expect(d.malId, 52991);
    expect(fake.graphqlCalls, 1);
    // Opened again by its id, or by its slug: served from the cache, nothing is asked.
    await service.detail(KitsuMediaKind.anime, id: '46474');
    await service.detail(KitsuMediaKind.anime, slug: 'sousou-no-frieren');
    expect(fake.graphqlCalls, 1);
    expect(service.peek<KitsuMediaDetail>(KitsuMediaDetailService.detailKey(KitsuMediaKind.anime, '46474')), isNotNull);
  });

  test('force asks again, an expired entry too', () async {
    final fake = site();
    final service = KitsuMediaDetailService(graphql: fake.gql, ttl: Duration.zero);
    await service.detail(KitsuMediaKind.anime, slug: 'sousou-no-frieren');
    await service.detail(KitsuMediaKind.anime, slug: 'sousou-no-frieren');
    expect(fake.graphqlCalls, 2);
    final cached = fake.service();
    await cached.detail(KitsuMediaKind.anime, slug: 'sousou-no-frieren');
    await cached.detail(KitsuMediaKind.anime, slug: 'sousou-no-frieren', force: true);
    expect(fake.graphqlCalls, 4);
  });

  test('a title Kitsu does not know is null, a server error throws', () async {
    final missing = FakeKitsu(graphql: {'findAnimeBySlug': {'data': {'findAnimeBySlug': null}}});
    expect(await missing.service().detail(KitsuMediaKind.anime, slug: 'nope'), isNull);
    await expectLater(FakeKitsu(failAll: true).service().detail(KitsuMediaKind.anime, slug: 'x'), throwsA(anything));
  });

  test('the manga record carries chapters, not episodes', () async {
    final d = await site().service().detail(KitsuMediaKind.manga, slug: 'sousou-no-frieren');
    expect(d!.kind, KitsuMediaKind.manga);
    expect(d.units.nodes, isNotEmpty);
  });

  test('ratings: the histogram is requested once', () async {
    final fake = site();
    final service = fake.service();
    final r = await service.ratings(KitsuMediaKind.anime, '46474');
    expect(r[20], 5461);
    await service.ratings(KitsuMediaKind.anime, '46474');
    expect(fake.requests.where((r) => r.method == 'GET'), hasLength(1));
    expect(service.peek<KitsuRatingFrequencies>(KitsuMediaDetailService.ratingsKey(KitsuMediaKind.anime, '46474')), isNotNull);
  });

  test('units: the next page follows the cursor of the first', () async {
    final fake = site();
    final page = await fake.service().units(KitsuMediaKind.anime, '46474', const KitsuPageArgs(after: 'Mw'));
    expect(page.nodes.first.number, 1);
    expect(page.totalCount, 28);
    final body = fake.requests.last.body;
    expect(body, contains('"after":"Mw"'));
  });
}
