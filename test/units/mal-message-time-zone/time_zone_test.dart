import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_time_zone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final pacific = MalTimeZone.locationOf('America/Los_Angeles')!;

  group('MAL dates are read in the account time zone', () {
    // 2026-11-21 08:00 UTC = 2026-11-21 00:00 in Los Angeles (UTC-8).
    final now = DateTime.utc(2026, 11, 21, 8).toLocal();

    test('an absolute date of the Pacific account is the real instant', () {
      // The issue: shown 07:27 for a message sent at 15:27 UTC.
      final at = parseMalMessageDate('Nov 20, 2026 7:27 AM', now: now, zone: pacific)!;
      expect(at.toUtc(), DateTime.utc(2026, 11, 20, 15, 27));
      expect(at.isUtc, isFalse, reason: 'shown in the phone time');
    });

    test('Today and Yesterday are the account days, not the phone ones', () {
      // In Los Angeles it is just past midnight on Nov 21: "Yesterday" is Nov 20 there.
      expect(parseMalMessageDate('Yesterday, 7:27 AM', now: now, zone: pacific)!.toUtc(),
          DateTime.utc(2026, 11, 20, 15, 27));
      expect(parseMalMessageDate('Today, 12:05 AM', now: now, zone: pacific)!.toUtc(),
          DateTime.utc(2026, 11, 21, 8, 5));
    });

    test('a short date takes the year of the account day, summer time included', () {
      expect(parseMalMessageDate('Jul 4, 9:00 PM', now: now, zone: pacific)!.toUtc(),
          DateTime.utc(2026, 7, 5, 4), reason: 'UTC-7 in July');
    });

    test('relative dates do not depend on the zone', () {
      expect(parseMalMessageDate('5 hours ago', now: now, zone: pacific), now.subtract(const Duration(hours: 5)));
    });

    test('without a known zone the phone time is kept', () {
      MalTimeZone.instance.setForTest(null);
      expect(parseMalMessageDate('Nov 20, 2026 7:27 AM', now: now), DateTime(2026, 11, 20, 7, 27));
    });

    test('the account zone is used by default once known', () {
      MalTimeZone.instance.setForTest('America/Los_Angeles');
      addTearDown(() => MalTimeZone.instance.setForTest(null));
      expect(parseMalMessageDate('Nov 20, 2026 7:27 AM', now: now)!.toUtc(), DateTime.utc(2026, 11, 20, 15, 27));
    });
  });

  group('MalTimeZone', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('asks MAL once, keeps the zone, asks again a day later', () async {
      var asked = 0;
      var clock = DateTime(2026, 11, 24, 10);
      MalTimeZone make() => MalTimeZone(fetch: () async {
            asked++;
            return 'America/Los_Angeles';
          }, clock: () => clock);
      final zone = make();
      await zone.ensure();
      expect(zone.name, 'America/Los_Angeles');
      expect(zone.location, isA<tz.Location>());
      await zone.ensure();
      expect(asked, 1);
      // A new start reads the kept zone without asking.
      final again = make();
      await again.ensure();
      expect(again.name, 'America/Los_Angeles');
      expect(asked, 1);
      clock = clock.add(const Duration(days: 1, minutes: 1));
      await again.ensure();
      expect(asked, 2);
    });

    test('an unknown name or a failing request leaves the zone unknown', () async {
      final bad = MalTimeZone(fetch: () async => 'Mars/Olympus');
      await bad.ensure();
      expect(bad.location, isNull);
      final failing = MalTimeZone(fetch: () async => throw Exception('offline'));
      await failing.ensure();
      expect(failing.location, isNull);
    });

    test('clear forgets the zone (sign out)', () async {
      final zone = MalTimeZone(fetch: () async => 'Europe/Paris');
      await zone.ensure();
      await zone.clear();
      expect(zone.name, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mal_time_zone'), isNull);
    });
  });
}
