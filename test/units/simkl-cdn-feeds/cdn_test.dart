import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';

import 'fakes.dart';

void main() {
  group('parsing the saved CDN files', () {
    test('trending: ids, MAL id, rating, year from MM/DD/YYYY, overview without tags', () {
      final items = parseSimklTrending(fixture('trending_week_100.json'));
      expect(items, hasLength(40));
      final first = items.first;
      expect(first.title, 'Cyberpunk: Edgerunners 2');
      expect(first.simklId, 2830474);
      expect(first.malId, 61990);
      expect(first.slug, 'cyberpunk-edgerunners-ii');
      expect(first.rating, 7.9);
      expect(first.year, 2026);
      expect(first.animeType, 'ona');
      expect(first.posterUrl, 'https://simkl.in/posters/20/202577490fc9c8e931_m.jpg');
      expect(first.overview, isNot(contains('<br>')));
      expect(first.episode, isNull);
      expect(items[1].title, 'Black Clover Second Season');
    });

    test('calendar: one item per episode with the title metadata, by air time', () {
      final items = parseSimklCalendar(fixture('calendar_v2_anime.json'));
      expect(items, hasLength(80));
      final first = items.first;
      expect(first.title, 'GuAn');
      expect(first.simklId, 3198578);
      expect(first.malId, 62789);
      expect(first.episode, 15);
      expect(first.airDate, DateTime.utc(2026, 10, 26, 15));
      for (var i = 1; i < items.length; i++) {
        expect(items[i].airDate!.isBefore(items[i - 1].airDate!), isFalse);
      }
    });

    test('broken or unexpected bodies give empty lists', () {
      expect(parseSimklTrending('{}'), isEmpty);
      expect(parseSimklCalendar('[]'), isEmpty);
      expect(parseSimklCalendar('{"calendar":[{"simkl_id":1,"date":"x"}],"metadata":{"1":{"title":"A"}}}'), isEmpty);
    });

    test('episodesOn keeps the local day only', () {
      final items = parseSimklCalendar(fixture('calendar_v2_anime.json'));
      final day = DateTime(2026, 10, 28, 12);
      final today = episodesOn(items, day);
      expect(today, isNotEmpty);
      for (final item in today) {
        final local = item.airDate!.toLocal();
        expect([local.year, local.month, local.day], [2026, 10, 28]);
      }
    });
  });

  group('SimklCdn', () {
    test('asks the documented file with the app identification', () async {
      final fake = FakeCdn((_) => jsonResponse(fixture('trending_week_100.json')));
      final items = await fake.cdn.trending(SimklTrendingWindow.week);
      expect(items, hasLength(40), reason: 'a large file is parsed off the UI isolate');
      final seen = fake.seen.single;
      expect(seen.url.host, 'data.simkl.in');
      expect(seen.url.path, '/discover/trending/anime/week_100.json');
      expect(seen.url.queryParameters, {'client_id': 'client-id', 'app-name': 'MyWatchList', 'app-version': '1.2.3'});
      expect(seen.headers['User-Agent'], 'MyWatchList/1.2.3');
    });

    test('the calendar is downloaded once for every caller while fresh', () async {
      var now = DateTime(2026, 10, 28, 12);
      final fake = FakeCdn((_) => jsonResponse(fixture('calendar_v2_anime.json')), now: () => now);
      final both = await Future.wait([fake.cdn.calendar(), fake.cdn.airingOn(DateTime(2026, 10, 28, 12))]);
      expect(fake.seen, hasLength(1), reason: 'the running request is shared');
      expect(fake.seen.single.url.path, '/calendar/v2/anime.json');
      expect(both.first, hasLength(80));
      await fake.cdn.calendar();
      expect(fake.seen, hasLength(1));
      now = now.add(SimklCdn.calendarTtl + const Duration(minutes: 1));
      await fake.cdn.calendar();
      expect(fake.seen, hasLength(2), reason: 'older than the ttl');
      fake.cdn.invalidate();
      await fake.cdn.calendar();
      expect(fake.seen, hasLength(3), reason: 'pull to refresh');
    });

    test('each trending period is its own file', () async {
      final fake = FakeCdn((path) => jsonResponse(trendingFile(path)));
      final today = await fake.cdn.trending(SimklTrendingWindow.today);
      final month = await fake.cdn.trending(SimklTrendingWindow.month);
      expect(fake.seen.map((s) => s.url.path), [
        '/discover/trending/anime/today_100.json',
        '/discover/trending/anime/month_100.json',
      ]);
      expect(today.first.title, contains('today'));
      expect(month.first.title, contains('month'));
    });

    test('an error status throws and is not kept', () async {
      var status = 503;
      final fake = FakeCdn((_) => jsonResponse(trendingFile('x'), status));
      await expectLater(
        fake.cdn.trending(SimklTrendingWindow.today),
        throwsA(isA<SimklHttpError>().having((e) => e.statusCode, 'status', 503)),
      );
      status = 200;
      expect(await fake.cdn.trending(SimklTrendingWindow.today), hasLength(3));
      expect(fake.seen, hasLength(2));
    });
  });
}
