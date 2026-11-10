import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart' show AiringEpisode;
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 12);
  late FakeBackend backend;
  late NotificationPreferences prefs;
  late List<String> coverCalls;
  var candidates = <AiringCandidate>[];
  var failLists = false;

  NotificationService build({Duration debounce = const Duration(milliseconds: 20)}) {
    return NotificationService(
      backend: backend,
      texts: const FakeTexts(),
      readPrefs: () => prefs,
      clock: () => now,
      debounce: debounce,
      loadCandidates: () async {
        if (failLists) throw Exception('offline');
        return candidates;
      },
      loadEpisodes: () async => [
        AiringEpisode(malId: 1, episode: 3, airingAt: DateTime.utc(2026, 10, 28, 15)),
      ],
      fetchCover: (url, id) async {
        coverCalls.add(url);
        return '/covers/$id.jpg';
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    prefs = NotificationPreferences(subscribedAt: DateTime.utc(2026, 10, 1));
    coverCalls = [];
    failLists = false;
    candidates = const [
      AiringCandidate(
        malId: 1,
        title: 'One',
        status: 'watching',
        airingStatus: 'currently_airing',
        imageUrl: 'https://img/1.jpg',
      ),
    ];
  });

  test('scheduleAll cancels then schedules the planned notifications with covers', () async {
    final service = build();
    await service.scheduleAll();
    expect(backend.cancelAllCalls, 1);
    expect(backend.scheduled.map((n) => n.episode), [3, 4, 5, 6]);
    expect(backend.looks.first.imagePath, '/covers/1.jpg');
    expect(backend.looks.first.bigPicture, isTrue);
    expect(backend.looks.first.channelName, 'Watching');
    expect(coverCalls, ['https://img/1.jpg'], reason: 'one download per anime');
    expect(service.summary.value.scheduled, 4);
    expect(service.summary.value.next, DateTime.utc(2026, 10, 28, 15));
    expect(service.summary.value.running, isFalse);
  });

  test('the large image preference switches the big picture off', () async {
    prefs = prefs.copyWith(largeImage: false);
    final service = build();
    await service.scheduleAll();
    expect(backend.looks.first.bigPicture, isFalse);
    expect(backend.looks.first.imagePath, isNotNull);
  });

  test('an automatic run happens at most once a day, a forced one always', () async {
    final service = build();
    await service.scheduleAll();
    await service.scheduleAll();
    expect(backend.cancelAllCalls, 1);
    await service.scheduleAll(force: true);
    expect(backend.cancelAllCalls, 2);
  });

  test('turned off: everything is cancelled and nothing scheduled', () async {
    prefs = const NotificationPreferences();
    final service = build();
    await service.scheduleAll();
    expect(backend.cancelAllCalls, 1);
    expect(backend.scheduled, isEmpty);
    expect(service.summary.value.scheduled, 0);
  });

  test('without the system permission nothing is cancelled or scheduled', () async {
    backend.permission = const NotificationPermissions();
    final service = build();
    await service.scheduleAll();
    expect(backend.cancelAllCalls, 0);
    expect(backend.scheduled, isEmpty);
  });

  test('when the lists cannot be read the existing reminders are kept', () async {
    final service = build();
    await service.scheduleAll();
    failLists = true;
    await service.scheduleAll(force: true);
    expect(backend.cancelAllCalls, 1);
    expect(backend.scheduled, hasLength(4));
    expect(service.summary.value.failed, isTrue);
    expect(service.summary.value.scheduled, 4);
  });

  test('unsupported platforms do nothing and never throw', () async {
    backend.supported = false;
    final service = build();
    await service.init();
    await service.scheduleAll(force: true);
    expect(backend.cancelAllCalls, 0);
    expect(await service.sendTest(), isFalse);
  });

  test('a burst of calls ends with one more run that sees the latest preferences', () async {
    final service = build();
    final first = service.scheduleAll(force: true);
    prefs = prefs.copyWith(watchingList: false);
    final second = service.scheduleAll(force: true);
    await Future.wait([first, second]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(backend.scheduled, isEmpty, reason: 'the last run had the watching list off');
  });

  group('open from a notification', () {
    test('the launch payload is read at init and taken once', () async {
      backend.launch = 'anime:21';
      final service = build();
      await service.init();
      expect(service.takeLaunchPayload(), 'anime:21');
      expect(service.takeLaunchPayload(), isNull);
    });

    test('a tap while the app runs reaches onOpen', () async {
      final service = build();
      final opened = <String>[];
      service.onOpen = opened.add;
      await service.init();
      backend.tapHandler!('anime:5114');
      backend.tapHandler!(null);
      expect(opened, ['anime:5114']);
    });

    test('a tap before onOpen is set is delivered by flushPendingTap', () async {
      final service = build();
      await service.init();
      backend.tapHandler!('calendar');
      final opened = <String>[];
      service.onOpen = opened.add;
      service.flushPendingTap();
      service.flushPendingTap();
      expect(opened, ['calendar']);
    });
  });

  test('sendTest schedules one notification in two seconds that opens the anime', () async {
    final service = build();
    expect(await service.sendTest(), isTrue);
    final n = backend.scheduled.single;
    expect(n.id, NotificationService.testId);
    expect(n.at, now.add(const Duration(seconds: 2)));
    expect(n.payload, 'anime:21');
    expect(n.body, 'test-body');
  });

  test('sendTest reports a refusal when notifications are blocked', () async {
    backend.permission = const NotificationPermissions();
    expect(await build().sendTest(), isFalse);
    expect(backend.scheduled, isEmpty);
  });

  test('changing the notification preferences reschedules once, others do not', () async {
    final service = build(debounce: const Duration(milliseconds: 10));
    final states = Stream<AppPreferences>.fromIterable([
      AppPreferences(notifications: prefs),
      AppPreferences(notifications: prefs),
      AppPreferences(notifications: prefs.copyWith(planToWatchList: false)),
      AppPreferences(notifications: prefs.copyWith(planToWatchList: false, largeImage: false)),
    ]);
    service.bindPreferences(states);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(backend.cancelAllCalls, 1, reason: 'the two changes were merged into one run');
    service.dispose();
  });
}
