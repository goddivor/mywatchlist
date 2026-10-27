import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/notifications/notification_models.dart';
import 'package:mywatchlist/services/notifications/notification_planner.dart';
import 'package:mywatchlist/user/preferences/notification_preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart' show NotificationRoute, NotificationRouteKind;
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart' show AiringEpisode;

import 'fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 12); // a Tuesday
  const texts = FakeTexts();
  const prefs = NotificationPreferences();

  AiringEpisode ep(int malId, int episode, DateTime at) =>
      AiringEpisode(malId: malId, episode: episode, airingAt: at);

  AiringCandidate anime(
    int id, {
    String status = 'watching',
    String? airing = 'currently_airing',
    int? total,
    String? day,
    String? time,
  }) =>
      AiringCandidate(
        malId: id,
        title: 'Anime $id',
        status: status,
        airingStatus: airing,
        numEpisodes: total,
        broadcastDay: day,
        broadcastTime: time,
        imageUrl: 'https://img/$id.jpg',
      );

  List<PlannedNotification> plan(
    List<AiringCandidate> candidates,
    List<AiringEpisode> schedule, {
    NotificationPreferences p = prefs,
  }) =>
      NotificationPlanner.plan(
        candidates: candidates,
        schedule: schedule,
        prefs: p,
        texts: texts,
        now: now,
      );

  group('real schedule', () {
    test('schedules the next episode at its air time with the episode number', () {
      final at = DateTime.utc(2026, 10, 28, 15);
      final result = plan([anime(7)], [ep(7, 5, at)]);
      expect(result.first.at, at);
      expect(result.first.episode, 5);
      expect(result.first.title, 'Ep 5 of Anime 7');
      expect(result.first.body, 'watching-body');
      expect(result.first.repeatsWeekly, isFalse);
      expect(result.first.kind, NotificationKind.watching);
    });

    test('projects the following weeks, one episode each', () {
      final at = DateTime.utc(2026, 10, 28, 15);
      final result = plan([anime(7)], [ep(7, 5, at)]);
      expect(result.map((n) => n.episode), [5, 6, 7, 8]);
      expect(result[1].at, at.add(const Duration(days: 7)));
    });

    test('never projects past the known total', () {
      final result = plan([anime(7, total: 6)], [ep(7, 5, DateTime.utc(2026, 10, 28, 15))]);
      expect(result.map((n) => n.episode), [5, 6]);
    });

    test('ignores episodes already aired', () {
      final result = plan([anime(7)], [ep(7, 4, DateTime.utc(2026, 10, 27, 11))]);
      // Nothing upcoming in the schedule: falls back to the broadcast (none here).
      expect(result, isEmpty);
    });

    test('ids are stable and unique per anime and slot', () {
      final result = plan(
        [anime(7), anime(8)],
        [ep(7, 1, DateTime.utc(2026, 10, 28)), ep(8, 1, DateTime.utc(2026, 10, 29))],
      );
      expect(result.map((n) => n.id).toSet().length, result.length);
      expect(result.where((n) => n.malId == 7).first.id, 7 * NotificationPlanner.slotsPerAnime);
      expect(result.any((n) => n.id == 1), isFalse, reason: 'id 1 belongs to the test notification');
    });

    test('payload opens the anime through the app shell hook', () {
      final result = plan([anime(7)], [ep(7, 1, DateTime.utc(2026, 10, 28))]);
      final route = NotificationRoute.parse(result.first.payload);
      expect(route?.kind, NotificationRouteKind.content);
      expect(route?.id, 7);
      expect(route?.category, 'anime');
      expect(animePayload(7), NotificationRoute.contentPayload('anime', 7));
    });
  });

  group('lists and preferences', () {
    final schedule = [
      ep(1, 3, DateTime.utc(2026, 10, 28)),
      ep(2, 3, DateTime.utc(2026, 10, 28, 1)),
      ep(3, 3, DateTime.utc(2026, 10, 28, 2)),
    ];
    final candidates = [
      anime(1),
      anime(2, status: 'plan_to_watch'),
      anime(3, status: 'completed'),
    ];

    test('watching and plan to watch only, with their own body and channel', () {
      final result = plan(candidates, schedule);
      expect(result.map((n) => n.malId).toSet(), {1, 2});
      expect(result.firstWhere((n) => n.malId == 2).body, 'plan-body');
      expect(result.firstWhere((n) => n.malId == 2).kind, NotificationKind.planToWatch);
    });

    test('a list switched off is skipped', () {
      expect(plan(candidates, schedule, p: const NotificationPreferences(watchingList: false))
          .map((n) => n.malId)
          .toSet(), {2});
      expect(plan(candidates, schedule, p: const NotificationPreferences(planToWatchList: false))
          .map((n) => n.malId)
          .toSet(), {1});
    });

    test('a finished series is never notified', () {
      final result = plan([anime(1, airing: 'finished_airing')], schedule);
      expect(result, isEmpty);
    });
  });

  group('weekly broadcast fallback', () {
    test('used when the anime is not in the schedule, repeating weekly', () {
      // Wednesday 23:00 JST = Wednesday 14:00 UTC; now is Tuesday 12:00 UTC.
      final result = plan([anime(9, day: 'wednesday', time: '23:00')], const []);
      expect(result, hasLength(1));
      expect(result.single.at, DateTime.utc(2026, 10, 28, 14));
      expect(result.single.repeatsWeekly, isTrue);
      expect(result.single.episode, isNull);
      expect(result.single.title, 'New: Anime 9');
    });

    test('not used for a series that has not started', () {
      expect(plan([anime(9, airing: 'not_yet_aired', day: 'wednesday', time: '23:00')], const []),
          isEmpty);
    });

    test('nextBroadcast converts JST to UTC and rolls over midnight', () {
      // Tuesday 01:00 JST = Monday 16:00 UTC: already past this week, so next Monday.
      expect(NotificationPlanner.nextBroadcast('tuesday', '01:00', now), DateTime.utc(2026, 11, 2, 16));
      // Sunday 23:30 JST = Sunday 14:30 UTC.
      expect(NotificationPlanner.nextBroadcast('Sunday', '23:30', now), DateTime.utc(2026, 11, 1, 14, 30));
    });

    test('nextBroadcast is strictly in the future and rejects bad slots', () {
      // Tuesday 21:00 JST = 12:00 UTC = now: not strictly after, so a week later.
      expect(NotificationPlanner.nextBroadcast('tuesday', '21:00', now), DateTime.utc(2026, 11, 3, 12));
      expect(NotificationPlanner.nextBroadcast(null, '21:00', now), isNull);
      expect(NotificationPlanner.nextBroadcast('tuesday', '', now), isNull);
      expect(NotificationPlanner.nextBroadcast('someday', '21:00', now), isNull);
      expect(NotificationPlanner.nextBroadcast('tuesday', '25:00', now), isNull);
    });
  });

  test('the list is sorted by time and capped', () {
    final candidates = [for (var i = 1; i <= 80; i++) anime(i)];
    final schedule = [
      for (var i = 1; i <= 80; i++) ep(i, 1, DateTime.utc(2026, 10, 28).add(Duration(minutes: 81 - i))),
    ];
    final result = plan(candidates, schedule);
    expect(result.length, NotificationPlanner.maxNotifications);
    for (var i = 1; i < result.length; i++) {
      expect(result[i].at.isBefore(result[i - 1].at), isFalse);
    }
  });
}
