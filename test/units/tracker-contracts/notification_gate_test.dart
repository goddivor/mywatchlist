import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/notifications/notification_backend.dart';
import 'package:mywatchlist/services/notifications/notification_gate.dart';
import 'package:mywatchlist/services/notifications/notification_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Permission-only fake: the gate never schedules anything.
class _FakeBackend implements NotificationBackend {
  _FakeBackend({this.granted = false, this.grantOnRequest = true, this.isSupported = true});

  bool granted;
  final bool grantOnRequest;
  int requests = 0;

  @override
  final bool isSupported;

  @override
  Future<NotificationPermissions> permissions() async =>
      NotificationPermissions(notifications: granted);

  @override
  Future<NotificationPermissions> requestPermissions() async {
    requests++;
    if (grantOnRequest) granted = true;
    return permissions();
  }

  @override
  Future<void> init(void Function(String? payload) onTap) => throw UnimplementedError();
  @override
  Future<String?> launchPayload() => throw UnimplementedError();
  @override
  Future<void> cancelAll() => throw UnimplementedError();
  @override
  Future<void> schedule(PlannedNotification notification, NotificationLook look) =>
      throw UnimplementedError();
  @override
  Future<int> pendingCount() => throw UnimplementedError();
}

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('NotificationGate', () {
    test('the kill switch defaults to on; permission still required', () async {
      final backend = _FakeBackend();
      final gate = NotificationGate(await _prefs(), backend: backend);
      expect(gate.switchOn, isTrue);
      expect(NotificationGate.defaultSwitch, isTrue);
      expect(await gate.mayNotify(), isFalse);
      backend.granted = true;
      expect(await gate.mayNotify(), isTrue);
    });

    test('it ignores the airing reminders master', () async {
      // `prefs_notifications_v1` without subscribedAt = airing reminders off.
      final prefs = await _prefs({'prefs_notifications_v1': '{"subscribedAt":null}'});
      final gate = NotificationGate(prefs, backend: _FakeBackend(granted: true));
      expect(await gate.mayNotify(), isTrue);
    });

    test('turning off is saved and read back by a new gate', () async {
      final prefs = await _prefs();
      final backend = _FakeBackend(granted: true);
      final gate = NotificationGate(prefs, backend: backend);
      expect(await gate.setAllowed(false), isFalse);
      expect(gate.switchOn, isFalse);
      expect(prefs.getBool(NotificationGate.switchKey), isFalse);
      expect(await gate.mayNotify(), isFalse);

      final again = NotificationGate(prefs, backend: backend);
      expect(again.switchOn, isFalse);
      expect(await again.mayNotify(), isFalse);
      expect(backend.requests, 0);
    });

    test('turning on asks for the permission once when missing', () async {
      final backend = _FakeBackend();
      final gate = NotificationGate(await _prefs({NotificationGate.switchKey: false}),
          backend: backend);
      final seen = <bool>[];
      gate.switchListenable.addListener(() => seen.add(gate.switchListenable.value));
      expect(await gate.setAllowed(true), isTrue);
      expect(backend.requests, 1);
      expect(seen, [true]);
      expect(await gate.setAllowed(true), isTrue);
      expect(backend.requests, 1);
    });

    test('a refused permission keeps the switch on but blocks', () async {
      final backend = _FakeBackend(grantOnRequest: false);
      final gate = NotificationGate(await _prefs(), backend: backend);
      expect(await gate.setAllowed(true), isFalse);
      expect(gate.switchOn, isTrue);
      expect(await gate.mayNotify(), isFalse);
    });

    test('no prompt when asked not to (background isolate)', () async {
      final backend = _FakeBackend();
      final gate = NotificationGate(await _prefs(), backend: backend);
      expect(await gate.setAllowed(true, requestPermission: false), isFalse);
      expect(backend.requests, 0);
    });

    test('never on an unsupported platform', () async {
      final gate =
          NotificationGate(await _prefs(), backend: _FakeBackend(granted: true, isSupported: false));
      expect(await gate.mayNotify(), isFalse);
      expect(await gate.setAllowed(true), isFalse);
    });

    test('shared() is one gate per isolate', () async {
      await _prefs();
      NotificationGate.debugShared = null;
      final a = await NotificationGate.shared();
      expect(identical(a, await NotificationGate.shared()), isTrue);
      NotificationGate.debugShared = null;
    });
  });

  group('TrackerChannel', () {
    setUpAll(() => S.load(const Locale('en')));

    test('ids are unique and frozen', () {
      final ids = TrackerChannel.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, [
        'airing_watching',
        'airing_plan_to_watch',
        'mal_hub',
        'mal_friends_activity',
        'mal_messages',
        'anilist_airing_watching',
        'anilist_airing_plan_to_watch',
        'anilist_notifications',
        'kitsu_airing_watching',
        'kitsu_airing_plan_to_watch',
        'kitsu_notifications',
        'simkl_airing_watching',
        'simkl_airing_plan_to_watch',
      ]);
    });

    test('the ids already on phones are kept', () {
      expect(TrackerChannel.find(AccountType.myanimelist, NotificationPurpose.airingWatching)!.id,
          NotificationKind.watching.channelId);
      expect(
          TrackerChannel.find(AccountType.myanimelist, NotificationPurpose.airingPlanToWatch)!.id,
          NotificationKind.planToWatch.channelId);
      expect(TrackerChannel.find(AccountType.anilist, NotificationPurpose.inbox)!.id,
          'anilist_notifications');
    });

    test('what each tracker has', () {
      expect(TrackerChannel.find(AccountType.simkl, NotificationPurpose.inbox), isNull);
      expect(TrackerChannel.find(AccountType.anilist, NotificationPurpose.messages), isNull);
      expect(TrackerChannel.of(AccountType.none), isEmpty);
      final pm = TrackerChannel.find(AccountType.myanimelist, NotificationPurpose.messages)!;
      expect(pm.isHighImportance, isTrue);
      expect(TrackerChannel.all.where((c) => c.isHighImportance), [pm]);
    });

    test('names carry the tracker brand', () {
      for (final c in TrackerChannel.all) {
        expect(c.name, isNotEmpty);
        expect(c.description, isNotEmpty);
      }
      expect(TrackerChannel.find(AccountType.kitsu, NotificationPurpose.inbox)!.name,
          'Kitsu · Notifications');
      expect(
          TrackerChannel.find(AccountType.anilist, NotificationPurpose.airingWatching)!.name,
          contains('AniList'));
    });
  });
}
