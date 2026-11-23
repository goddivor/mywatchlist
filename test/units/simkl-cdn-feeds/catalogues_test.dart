import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';

import 'fakes.dart';

/// TV shows and movies next to anime: each catalogue reads its own files and paths.
void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  test('an item names its catalogue by its url, else the catalogue asked', () {
    expect(SimklMedia.fromJson({'title': 'A', 'url': '/tv/1/a', 'ids': {'simkl_id': 1}})!.kind, SimklKind.tv);
    expect(SimklMedia.fromJson({'title': 'B', 'url': '/movies/2/b', 'ids': {'simkl_id': 2}})!.kind, SimklKind.movie);
    expect(SimklMedia.fromJson({'title': 'C', 'endpoint_type': 'tv', 'ids': {'simkl_id': 3}})!.kind, SimklKind.tv);
    expect(SimklMedia.fromJson({'title': 'D', 'ids': {'simkl_id': 4}}, SimklKind.movie)!.kind, SimklKind.movie);
  });

  test('trending and calendars come from the files of the catalogue', () async {
    final cdn = FakeCdn((path) => path.contains('calendar')
        ? jsonResponse(jsonEncode({
            'calendar': [
              {
                'simkl_id': 7,
                'date': '2026-11-21T20:00:00Z',
                'episode': {'season': 2, 'episode': 5},
              },
            ],
            'metadata': {
              '7': {'title': 'Show', 'url': '/tv/7/show', 'ids': {'simkl_id': 7}},
            },
          }))
        : jsonResponse(trendingFile('Hot', count: 2)));
    final service = SimklDiscoverService(client: FakeApi((_) => jsonResponse([])).client, cdn: cdn.cdn);

    final shows = await service.trending(kind: SimklKind.tv);
    final movies = await service.trending(kind: SimklKind.movie);
    expect(shows.every((m) => m.kind == SimklKind.tv), isTrue);
    expect(movies.every((m) => m.kind == SimklKind.movie), isTrue);
    final airing = await service.calendar(kind: SimklKind.tv);
    await service.calendar(kind: SimklKind.movie);
    expect([for (final s in cdn.seen) s.url.path], [
      '/discover/trending/tv/today_100.json',
      '/discover/trending/movies/today_100.json',
      '/calendar/v2/tv.json',
      '/calendar/v2/movie_release.json',
    ]);
    expect((airing.single.season, airing.single.episode), (2, 5));
  });

  test('genres, premieres and search use the paths of the catalogue', () async {
    final api = FakeApi((_) => jsonResponse([]));
    final service = SimklDiscoverService(client: api.client, cdn: FakeCdn((_) => jsonResponse([])).cdn);
    await service.byGenre(genre: 'crime', kind: SimklKind.tv);
    await service.byGenre(genre: 'crime', kind: SimklKind.movie, sort: SimklGenreSort.releaseDate);
    await service.premieres(kind: SimklKind.tv, format: SimklFormat.ovas);
    await service.search('dune', kind: SimklKind.movie);
    expect([for (final s in api.seen) s.url.path], [
      '/tv/genres/crime/all-types/all-countries/all-networks/all-years/popular-this-month',
      '/movies/genres/crime/all-types/all-countries/all-years/release-date',
      '/tv/premieres/new',
      '/search/movie',
    ]);
    expect(api.seen[2].url.queryParameters['type'], 'all', reason: 'the anime formats are for anime only');
  });

  test('movies have no premieres and no best list', () {
    expect(SimklFeed.of(SimklKind.movie), [SimklFeed.trending, SimklFeed.airing, SimklFeed.genres]);
    expect(SimklFeed.of(SimklKind.tv), SimklFeed.values);
    expect(const SimklFeedQuery(SimklFeed.best, kind: SimklKind.tv).hasFormat, isFalse);
    expect(simklGenresOf(SimklKind.movie), contains('tv-movie'));
    expect(SimklFeedLabels.genre('tv-movie'), isNot('tv-movie'), reason: 'every genre is translated');
  });
}
