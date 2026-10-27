import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/calendar/calendar_ics.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';

CalendarEntry _entry(int id, DateTime at, {String? status, int ep = 1, int? total}) => CalendarEntry(
      malId: id,
      title: 'Title $id',
      imageUrl: '',
      episode: ep,
      airingAt: at,
      numEpisodes: total,
      listStatus: status,
    );

LiveChartEpisode _lc(int malId, DateTime at, int ep) =>
    LiveChartEpisode(timestamp: at.millisecondsSinceEpoch ~/ 1000, episode: ep, malId: malId);

void main() {
  group('timezones', () {
    test('JST is nine hours ahead of UTC', () {
      final utc = DateTime.utc(2026, 10, 27, 20, 30);
      final jst = inTimezone(utc, TimezonePref.jst);
      expect(jst.hour, 5);
      expect(jst.day, 28);
      expect(inTimezone(utc, TimezonePref.utc), utc);
    });

    test('the zone decides the day an episode falls on', () {
      final now = DateTime.utc(2026, 10, 27, 12);
      final late = _entry(1, DateTime.utc(2026, 10, 27, 20)); // 05:00 next day in JST
      final utcWeek = buildWeek([late], now: now, pref: TimezonePref.utc, listKnown: true);
      final jstWeek = buildWeek([late], now: now, pref: TimezonePref.jst, listKnown: true);
      expect(utcWeek[0].entries, hasLength(1));
      expect(jstWeek[0].entries, isEmpty);
      expect(jstWeek[1].entries, hasLength(1));
    });
  });

  group('buildWeek', () {
    final now = DateTime.utc(2026, 10, 27, 12);

    test('keeps seven days, sorted, and drops episodes outside the week', () {
      final week = buildWeek([
        _entry(1, DateTime.utc(2026, 10, 27, 18)),
        _entry(2, DateTime.utc(2026, 10, 27, 9)),
        _entry(3, DateTime.utc(2026, 11, 3, 9)), // day 8
        _entry(4, DateTime.utc(2026, 10, 26, 9)), // yesterday
      ], now: now, pref: TimezonePref.utc, listKnown: true);
      expect(week, hasLength(7));
      expect(week[0].entries.map((e) => e.malId), [2, 1]);
      expect(week.expand((d) => d.entries), hasLength(2));
    });

    test('filters by list status; unknown list shows everything', () {
      final list = [
        _entry(1, DateTime.utc(2026, 10, 27, 13), status: 'watching'),
        _entry(2, DateTime.utc(2026, 10, 27, 14), status: 'plan_to_watch'),
        _entry(3, DateTime.utc(2026, 10, 27, 15), status: 'completed'),
        _entry(4, DateTime.utc(2026, 10, 27, 16)),
      ];
      List<int> ids(String? f, {bool known = true}) => buildWeek(list,
              now: now, pref: TimezonePref.utc, filter: f, listKnown: known)[0]
          .entries
          .map((e) => e.malId)
          .toList();
      expect(ids(null), [1, 2, 3, 4]);
      expect(ids(CalendarFilter.all), [1, 2, 3, 4]);
      expect(ids(CalendarFilter.watching), [1]);
      expect(ids(CalendarFilter.planToWatch), [2]);
      expect(ids(CalendarFilter.inList), [1, 2, 3]);
      expect(ids(CalendarFilter.notInList), [4]);
      expect(ids(CalendarFilter.watching, known: false), [1, 2, 3, 4]);
    });
  });

  test('recurrence count runs to the last episode, at least once', () {
    expect(recurrenceCount(total: 12, nextEpisode: 5), 8);
    expect(recurrenceCount(total: 12, nextEpisode: 12), 1);
    expect(recurrenceCount(total: 12, nextEpisode: 14), 1);
    expect(recurrenceCount(total: null, nextEpisode: 3), isNull);
    expect(recurrenceCount(total: 0, nextEpisode: 3), isNull);
  });

  group('ics', () {
    final entry = _entry(5114, DateTime.utc(2026, 10, 27, 15, 30), ep: 7, total: 12);
    final texts = CalendarEventTexts(
      episodeTitle: (ep) => 'Ep $ep - Title; one, two',
      seriesTitle: 'Series reminder',
      description: (ep, at) => 'Line one\nLine two',
    );

    test('writes one CRLF-terminated event with escaped text', () {
      final ics = buildIcs(entry, texts: texts, now: DateTime.utc(2026, 10, 27));
      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(ics, contains('DTSTART:20261027T153000Z'));
      expect(ics, contains('DTEND:20261027T155500Z'));
      expect(ics, contains('SUMMARY:Ep 7 - Title\; one\\, two'));
      expect(ics, contains('DESCRIPTION:Line one\\nLine two'));
      expect(ics, contains('UID:mal-5114-ep7@mywatchlist'));
      expect(ics, isNot(contains('RRULE')));
    });

    test('recurring events carry a weekly RRULE with the count', () {
      final ics = buildIcs(entry, texts: texts, recurringCount: 6);
      expect(ics, contains('RRULE:FREQ=WEEKLY;COUNT=6'));
      expect(ics, contains('SUMMARY:Series reminder'));
    });

    test('lines are folded at 75 bytes without splitting characters', () {
      final long = 'DESCRIPTION:${'é' * 80}';
      final folded = foldIcsLine(long);
      for (final line in folded.split('\r\n')) {
        expect(line.codeUnits.length, lessThanOrEqualTo(75));
      }
      expect(folded.replaceAll('\r\n ', ''), long);
    });

    test('file names keep letters and digits only', () {
      expect(icsFileName('Re:Zero / S2!'), 'ReZero_S2_calendar.ics');
      expect(icsFileName('???'), 'anime_calendar.ics');
    });
  });

  group('AiringSchedule', () {
    test('nextEpisode returns the first episode that has not aired yet', () {
      final schedule = AiringSchedule(fetcher: ({required fromCache}) async => const []);
      final now = DateTime.utc(2026, 10, 27, 12);
      schedule.replace([
        _lc(1, DateTime.utc(2026, 10, 27, 10), 3),
        _lc(1, DateTime.utc(2026, 10, 27, 14), 4),
        _lc(2, DateTime.utc(2026, 10, 28, 14), 9),
        LiveChartEpisode(timestamp: 1, episode: 1, malId: null),
      ], now: now);
      expect(schedule.nextEpisode(1, now: now)?.episode, 4);
      expect(schedule.nextEpisode(2, now: now)?.airingAt, DateTime.utc(2026, 10, 28, 14));
      expect(schedule.nextEpisode(3, now: now), isNull);
      expect(schedule.nextEpisode(null, now: now), isNull);
      expect(schedule.episodes, hasLength(3));
    });

    test('shares one request and keeps the old schedule on failure', () async {
      var calls = 0;
      var fail = false;
      final schedule = AiringSchedule(fetcher: ({required fromCache}) async {
        calls++;
        if (fail) throw Exception('offline');
        return [_lc(1, DateTime.now().add(const Duration(days: 1)), 2)];
      });
      await Future.wait([schedule.ensureLoaded(), schedule.ensureLoaded()]);
      expect(calls, 1);
      expect(schedule.isLoaded, isTrue);
      fail = true;
      await schedule.ensureLoaded(refresh: true);
      expect(calls, 2);
      expect(schedule.error, isNotNull);
      expect(schedule.nextEpisode(1)?.episode, 2);
    });
  });
}
