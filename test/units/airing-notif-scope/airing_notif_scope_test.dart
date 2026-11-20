import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/fakes.dart';

/// Airing alarms must only ever come from the anime of the user's watching and
/// plan-to-watch lists: stale alarms of an anime that left them, or of an account signed
/// out, are cancelled.
class _Notifier extends ChangeNotifier {
  void poke() => notifyListeners();
}

void main() {
  late FakeBackend backend;
  late NotificationPreferences prefs;
  late _Notifier list;
  late _Notifier accounts;
  late Map<int, String> statuses;
  late bool signedIn;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeBackend();
    prefs = NotificationPreferences(subscribedAt: DateTime.utc(2026, 10, 1));
    list = _Notifier();
    accounts = _Notifier();
    statuses = {};
    signedIn = true;
  });

  NotificationService build({CandidateLoader? loadCandidates}) => NotificationService(
        backend: backend,
        texts: const FakeTexts(),
        readPrefs: () => prefs,
        clock: () => DateTime.utc(2026, 10, 27, 12),
        debounce: const Duration(milliseconds: 10),
        loadCandidates: loadCandidates ?? () async => const [],
        loadEpisodes: () async => const [],
        fetchCover: (_, __) async => null,
        trackerChanges: accounts,
        readFeedTracker: () => AccountType.myanimelist,
        isSignedIn: (_) => signedIn,
        listChanges: list,
        readListStatuses: (_) => statuses,
      );

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

  test('no account to read the lists from: every alarm in place is cancelled', () async {
    // The default loader needs a signed-in MyAnimeList account (none in tests).
    final service = NotificationService(
      backend: backend,
      texts: const FakeTexts(),
      readPrefs: () => prefs,
      loadEpisodes: () async => const [],
      fetchCover: (_, __) async => null,
    );
    await service.scheduleAll(force: true);
    expect(backend.cancelAllCalls, 1);
    expect(backend.scheduled, isEmpty);
    expect(service.summary.value.needsMal, isTrue);
  });

  test('an anime leaving the watching list re-plans at once', () async {
    final service = build();
    await service.init();
    statuses = {1: 'watching', 2: 'plan_to_watch'};
    list.poke(); // first load of the cache: not a change
    await settle();
    expect(backend.cancelAllCalls, 0);

    statuses = {1: 'completed', 2: 'plan_to_watch'};
    list.poke();
    await settle();
    expect(backend.cancelAllCalls, 1);

    statuses = {2: 'plan_to_watch'}; // 1 removed: it was not notified any more anyway
    list.poke();
    await settle();
    expect(backend.cancelAllCalls, 1);

    statuses = {};
    list.poke();
    await settle();
    expect(backend.cancelAllCalls, 2, reason: '2 left the plan-to-watch list');
    service.dispose();
  });

  test('changes outside watching / plan to watch do not re-plan', () async {
    final service = build();
    await service.init();
    statuses = {1: 'watching'};
    list.poke();
    await settle();
    statuses = {1: 'watching', 5: 'completed', 6: 'dropped'};
    list.poke();
    await settle();
    expect(backend.cancelAllCalls, 0);
    service.dispose();
  });

  test('signing out of the account the alarms came from re-plans (and so cancels)', () async {
    final service = build();
    await service.init();
    signedIn = false;
    accounts.poke();
    await settle();
    expect(backend.cancelAllCalls, 1);
    accounts.poke();
    await settle();
    expect(backend.cancelAllCalls, 1, reason: 'already signed out');
    service.dispose();
  });

  test('reminders off: a list change schedules nothing', () async {
    prefs = const NotificationPreferences();
    final service = build();
    await service.init();
    statuses = {1: 'watching'};
    list.poke();
    statuses = {1: 'dropped'};
    list.poke();
    await settle();
    expect(backend.scheduled, isEmpty);
    service.dispose();
  });
}
