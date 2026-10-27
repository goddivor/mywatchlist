import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid\nMAL_CLIENT_SECRET=sec');
  });

  tearDown(() {
    MalApi.httpClient = null;
    MalApi.resetMaintenanceCache();
    Preferences.reset();
  });

  group('withNsfw', () {
    test('adds nsfw=0 or nsfw=1 after the existing query', () {
      expect(
          MalApi.withNsfw('https://api.myanimelist.net/v2/anime?q=a&limit=5',
              nsfw: false),
          'https://api.myanimelist.net/v2/anime?q=a&limit=5&nsfw=0');
      expect(
          MalApi.withNsfw('https://api.myanimelist.net/v2/anime?q=a',
              nsfw: true),
          'https://api.myanimelist.net/v2/anime?q=a&nsfw=1');
    });

    test('starts the query when there is none', () {
      expect(
          MalApi.withNsfw('https://api.myanimelist.net/v2/anime/ranking',
              nsfw: true),
          'https://api.myanimelist.net/v2/anime/ranking?nsfw=1');
    });

    test('keeps a URL that already carries nsfw', () {
      const url = 'https://api.myanimelist.net/v2/anime?q=a&nsfw=1&offset=100';
      expect(MalApi.withNsfw(url, nsfw: false), url);
    });

    test('defaults to the saved preference (off)', () {
      expect(MalApi.withNsfw('https://x.test/a?b=1'),
          'https://x.test/a?b=1&nsfw=0');
    });
  });

  group('timezone preference', () {
    // 2026-01-05 is a Monday; 20:00 JST is 11:00 UTC.
    final utc = DateTime.utc(2026, 1, 5, 11);

    test('JST adds nine hours, UTC leaves the time', () {
      final now = DateTime.now();
      expect(MalApi.getAdjustedTime(utc, now, TimezonePref.jst).hour, 20);
      expect(MalApi.getAdjustedTime(utc, now, TimezonePref.utc).hour, 11);
      expect(MalApi.getTimezoneName(now, TimezonePref.jst), 'JST');
      expect(MalApi.getTimezoneName(now, TimezonePref.utc), 'UTC');
    });

    test('the format follows the preference when none is given', () {
      final b = Broadcast(dayOfTheWeek: 'Monday', startTime: '20:00');
      final jst = MalApi.getFormattedAiringDate(b, null, TimezonePref.jst);
      final utcText = MalApi.getFormattedAiringDate(b, null, TimezonePref.utc);
      expect(jst, endsWith('(JST)'));
      expect(utcText, endsWith('(UTC)'));
      // Default preference is the device time zone: neither JST nor UTC label forced.
      final byDefault = MalApi.getFormattedAiringDate(b);
      expect(byDefault, endsWith('(${DateTime.now().timeZoneName})'));
    });
  });

  group('isUnderMaintenance', () {
    test('true on a 503, with the client id header', () async {
      late http.BaseRequest seen;
      MalApi.httpClient = MockClient((request) async {
        seen = request;
        return http.Response('', 503);
      });
      expect(await MalApi.isUnderMaintenance(force: true), isTrue);
      expect(seen.headers.keys.map((k) => k.toLowerCase()),
          contains('x-mal-client-id'));
    });

    test('false on 200, and on a network error', () async {
      MalApi.httpClient = MockClient((_) async => http.Response('{}', 200));
      expect(await MalApi.isUnderMaintenance(force: true), isFalse);
      MalApi.httpClient =
          MockClient((_) async => throw http.ClientException('down'));
      expect(await MalApi.isUnderMaintenance(force: true), isFalse);
    });

    test('the answer is kept for a minute', () async {
      var calls = 0;
      MalApi.httpClient = MockClient((_) async {
        calls++;
        return http.Response('', 503);
      });
      expect(await MalApi.isUnderMaintenance(force: true), isTrue);
      expect(await MalApi.isUnderMaintenance(), isTrue);
      expect(calls, 1);
    });
  });

  group('manga progress', () {
    test('MyListStatus parses chapters and volumes read', () {
      final s = MyListStatus.fromJson({
        'status': 'reading',
        'score': 8,
        'num_chapters_read': 12,
        'num_volumes_read': 2,
      });
      expect(s.numChaptersRead, 12);
      expect(s.numVolumesRead, 2);
      expect(s.toJson()['num_chapters_read'], 12);
    });

    test('anime status keeps null progress and an unchanged JSON', () {
      final s = MyListStatus.fromJson(
          {'status': 'watching', 'num_episodes_watched': 3});
      expect(s.numEpisodesWatched, 3);
      expect(s.numChaptersRead, isNull);
      expect(s.toJson().containsKey('num_chapters_read'), isFalse);
    });

    test('the manga detail request asks for the read counters', () {
      expect(MalApi.mangaDetailFields, contains('num_chapters_read'));
    });
  });

  group('full list status', () {
    test('MyListStatus keeps every field, partial dates as text', () {
      final s = MyListStatus.fromJson({
        'status': 'completed',
        'score': 9,
        'is_rereading': true,
        'start_date': '2019-03',
        'finish_date': '2019',
        'priority': 2,
        'comments': 'good',
        'tags': ['a', 'b'],
        'num_times_rewatched': 1,
        'num_times_reread': 3,
        'rewatch_value': 4,
        'reread_value': 5,
        'updated_at': '2020-01-01T00:00:00+00:00',
      });
      expect(s.startDate, '2019-03');
      expect(s.finishDate, '2019');
      expect(s.tags, ['a', 'b']);
      expect(s.priority, 2);
      expect(s.numTimesReread, 3);
      expect(s.rereadValue, 5);
      expect(s.rewatchValue, 4);
      expect(s.comments, 'good');
      expect(MyListStatus.fromJson(s.toJson()).startDate, '2019-03');
    });

    test('missing fields fall back to neutral values', () {
      final s = MyListStatus.fromJson({'status': 'watching'});
      expect(s.startDate, isNull);
      expect(s.tags, isEmpty);
      expect(s.priority, 0);
    });

    test('detail requests ask for every list field', () {
      for (final f in [MalApi.animeDetailFields, MalApi.mangaDetailFields]) {
        final block =
            RegExp(r'my_list_status\{([^}]*)\}').firstMatch(f)!.group(1)!;
        for (final k in [
          'start_date',
          'finish_date',
          'priority',
          'comments',
          'tags',
          'updated_at'
        ]) {
          expect(block, contains(k));
        }
      }
      expect(MalApi.animeDetailFields, contains('num_episodes_watched'));
      expect(MalApi.mangaDetailFields, contains('num_volumes_read'));
    });

    test('a partial date is sent unchanged', () {
      final body = MalApi.listStatusBody(
          {'start_date': '2019-03', 'finish_date': null, 'score': 8});
      expect(body, {'start_date': '2019-03', 'score': '8'});
    });
  });
}
