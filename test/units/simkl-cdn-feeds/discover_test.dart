import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';

import 'fakes.dart';

void main() {
  List<Map<String, Object?>> apiItems(String prefix, int count) => [
        for (var i = 1; i <= count; i++)
          {
            'title': '$prefix $i',
            'ids': {'simkl_id': i},
          },
      ];

  group('CDN feeds', () {
    test('trending comes from the CDN without an API call', () async {
      final cdn = FakeCdn((_) => jsonResponse(trendingFile('Hot', count: 5)));
      final api = FakeApi((_) => jsonResponse([]));
      final service = SimklDiscoverService(client: api.client, cdn: cdn.cdn);
      final items = await service.trending(window: SimklTrendingWindow.week, limit: 4);
      expect(items.map((m) => m.title), ['Hot 1', 'Hot 2', 'Hot 3', 'Hot 4']);
      expect(cdn.seen.single.url.path, '/discover/trending/anime/week_100.json');
      expect(api.seen, isEmpty);
    });

    test('trending falls back to the API when the CDN fails', () async {
      final cdn = FakeCdn((_) => jsonResponse('down', 502));
      final api = FakeApi((_) => jsonResponse(apiItems('Api', 2)));
      final service = SimklDiscoverService(client: api.client, cdn: cdn.cdn);
      expect((await service.trending()).map((m) => m.title), ['Api 1', 'Api 2']);
      expect(api.seen.single.url.path, '/anime/trending');
    });

    test('airing today is the CDN calendar of the local day, by time', () async {
      final day = DateTime(2026, 10, 28);
      final cdn = FakeCdn((_) => jsonResponse(calendarFile({
            1: day.add(const Duration(hours: 20)),
            2: day.add(const Duration(hours: 9)),
            3: day.add(const Duration(days: 1, hours: 9)),
            4: day.subtract(const Duration(hours: 2)),
          })));
      final api = FakeApi((_) => jsonResponse([]));
      final service = SimklDiscoverService(client: api.client, cdn: cdn.cdn);
      final items = await service.airingToday(date: day.add(const Duration(hours: 12)));
      expect(items.map((m) => m.title), ['Show 2', 'Show 1']);
      expect(items.first.episode, 3);
      expect(items.first.malId, 3);
      expect(api.seen, isEmpty);
    });

    test('airing falls back to the API with the date', () async {
      final cdn = FakeCdn((_) => jsonResponse('down', 500));
      final api = FakeApi((_) => jsonResponse(apiItems('Air', 1)));
      final service = SimklDiscoverService(client: api.client, cdn: cdn.cdn);
      await service.airingToday(date: DateTime(2026, 11, 2, 12));
      expect(api.seen.single.url.path, '/anime/airing');
      expect(api.seen.single.url.queryParameters['date'], '2026-11-02');
    });
  });

  group('API lists', () {
    late FakeApi api;
    late SimklDiscoverService service;

    setUp(() {
      api = FakeApi((url) {
        if (url.path.startsWith('/anime/genres/')) {
          return jsonResponse(apiItems('Genre p${url.queryParameters['page']}', url.queryParameters['page'] == '1' ? 60 : 7));
        }
        return jsonResponse(apiItems(url.path, 3));
      });
      service = SimklDiscoverService(client: api.client, cdn: FakeCdn((_) => jsonResponse('[]')).cdn);
    });

    test('coming soon asks the upcoming premieres with the format', () async {
      await service.comingSoon(format: SimklFormat.onas);
      final url = api.seen.single.url;
      expect(url.path, '/anime/premieres/soon');
      expect(url.queryParameters['type'], 'onas');
      expect(url.queryParameters['limit'], '60');
      expect(url.queryParameters['client_id'], 'client-id');
    });

    test('best anime asks the bucket and the format; a null answer is an empty list', () async {
      final items = await service.best(filter: SimklBest.year, format: SimklFormat.tv);
      expect(items, hasLength(3));
      expect(api.seen.single.url.path, '/anime/best/year');
      expect(api.seen.single.url.queryParameters['type'], 'tv');
      final empty = SimklDiscoverService(client: FakeApi((_) => jsonResponse(null)).client);
      expect(await empty.best(format: SimklFormat.ovas), isEmpty);
    });

    test('genre browse builds the five-segment path and pages by 60', () async {
      final first = await service.byGenre(genre: 'sci-fi', format: SimklFormat.movies, sort: SimklGenreSort.rank);
      expect(api.seen.single.url.path, '/anime/genres/sci-fi/movies/all/all/rank');
      expect(api.seen.single.url.queryParameters['page'], '1');
      expect(api.seen.single.url.queryParameters['limit'], '60');
      expect(first.items, hasLength(60));
      expect(first.hasMore, isTrue);
      final second = await service.byGenre(genre: 'sci-fi', format: SimklFormat.movies, sort: SimklGenreSort.rank, page: 2);
      expect(second.items, hasLength(7));
      expect(second.hasMore, isFalse);
    });

    test('the last page Simkl serves has no next page', () async {
      final last = await service.byGenre(page: SimklDiscoverService.maxPage);
      expect(last.hasMore, isFalse);
      expect(api.seen.single.url.path, '/anime/genres/all/all/all/all/popular-this-month');
    });
  });

  group('session', () {
    test('signed in, the API lists carry the user token (AUTH V2 refuses them without one)', () async {
      final api = FakeApi((_) => jsonResponse([]), session: true);
      final service = SimklDiscoverService(client: api.client, signedIn: () => true);
      await service.comingSoon();
      await service.search('frieren');
      expect(api.seen.map((s) => s.headers['Authorization']), ['Bearer user-token', 'Bearer user-token']);
    });

    test('a refused session falls back to the anonymous call', () async {
      final api = FakeApi((_) => jsonResponse([]));
      final service = SimklDiscoverService(client: api.client, signedIn: () => true);
      await service.best();
      expect(api.seen.single.headers.containsKey('Authorization'), isFalse);
      expect(api.seen.single.url.queryParameters['client_id'], 'client-id');
    });

    test('signed out, the calls go out with the client id only', () async {
      final api = FakeApi((_) => jsonResponse([]), session: true);
      final service = SimklDiscoverService(client: api.client, signedIn: () => false);
      await service.premieres();
      expect(api.seen.single.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('SimklFeedQuery', () {
    test('a default query shares the home row cache key, options make their own', () {
      for (final feed in SimklFeed.values) {
        expect(SimklFeedQuery(feed).cacheKey, feed.cacheKey);
      }
      final keys = {
        const SimklFeedQuery(SimklFeed.trending).cacheKey,
        const SimklFeedQuery(SimklFeed.trending, window: SimklTrendingWindow.week).cacheKey,
        const SimklFeedQuery(SimklFeed.best, best: SimklBest.voted).cacheKey,
        const SimklFeedQuery(SimklFeed.best, best: SimklBest.voted, format: SimklFormat.tv).cacheKey,
        const SimklFeedQuery(SimklFeed.genres, genre: 'action').cacheKey,
        const SimklFeedQuery(SimklFeed.airing, dayOffset: 2).cacheKey,
      };
      expect(keys, hasLength(6));
    });

    test('only the API lists have a format filter, only genres are paged', () {
      expect([for (final f in SimklFeed.values) if (SimklFeedQuery(f).hasFormat) f],
          [SimklFeed.premieres, SimklFeed.soon, SimklFeed.best, SimklFeed.genres]);
      expect([for (final f in SimklFeed.values) if (SimklFeedQuery(f).paged) f], [SimklFeed.genres]);
    });
  });
}
