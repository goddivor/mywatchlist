import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/screens/user_profile/sections/weekly_section.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_view.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';

ListEntryView _entry(int id, {BroadcastSlot? slot, ReleaseState state = ReleaseState.releasing}) =>
    ListEntryView(
      id: id,
      malId: id,
      category: 'anime',
      title: 'T$id',
      releaseState: state,
      broadcast: slot,
    );

void main() {
  group('profile tabs', () {
    test('another user gets List first and no Weekly; you get Weekly and no List', () {
      final other = profileTabsFor(isSelf: false);
      final self = profileTabsFor(isSelf: true);
      expect(other.first, UserProfileTab.list);
      expect(other, isNot(contains(UserProfileTab.weekly)));
      expect(self, isNot(contains(UserProfileTab.list)));
      expect(self, contains(UserProfileTab.weekly));
      expect(other, contains(UserProfileTab.comments));
      expect(self, contains(UserProfileTab.comments));
    });

    test('another user opens on the list by default, an explicit tab is kept', () {
      expect(openingProfileTab(UserProfileTab.stats, isSelf: false), UserProfileTab.list);
      expect(openingProfileTab(UserProfileTab.history, isSelf: false), UserProfileTab.history);
      expect(openingProfileTab(UserProfileTab.stats, isSelf: true), UserProfileTab.stats);
      expect(openingProfileTab(UserProfileTab.list, isSelf: true), UserProfileTab.stats);
    });
  });

  group('weekly grouping', () {
    test('a JST slot moves to the day of the chosen zone', () {
      // Monday 01:00 JST = Sunday 16:00 UTC.
      const slot = BroadcastSlot(DateTime.monday, 60);
      expect(weeklyDayOf(slot, TimezonePref.jst), 0);
      expect(weeklyDayOf(slot, TimezonePref.utc), 6);
      expect(weeklyDayOf(slot, TimezonePref.local, localOffset: const Duration(hours: 2)), 6);
      expect(weeklyDayOf(null, TimezonePref.utc), 7);
    });

    test('only airing titles, once each, sorted by time', () {
      final days = groupWeekly([
        _entry(1, slot: const BroadcastSlot(DateTime.friday, 23 * 60)),
        _entry(2, slot: const BroadcastSlot(DateTime.friday, 20 * 60)),
        _entry(2, slot: const BroadcastSlot(DateTime.friday, 20 * 60)),
        _entry(3, slot: const BroadcastSlot(DateTime.friday, 21 * 60), state: ReleaseState.finished),
        _entry(4),
      ], TimezonePref.jst);
      expect(days[4].map((e) => e.id), [2, 1]);
      expect(days[7].map((e) => e.id), [4]);
      expect(days.expand((d) => d).length, 3);
    });
  });

  group('MAL list adapter', () {
    test("another user's list URL names them and keeps adult entries", () {
      final url = Uri.parse(MalUserListAdapter.pageUrl(
        category: 'manga',
        status: null,
        offset: 0,
        limit: 10,
        username: 'Some User',
      ));
      expect(url.path, endsWith('/users/Some%20User/mangalist'));
      expect(url.queryParameters['nsfw'], '1');
      final own = Uri.parse(MalUserListAdapter.pageUrl(
          category: 'anime', status: null, offset: 0, limit: 10));
      expect(own.path, endsWith('/users/@me/animelist'));
    });

    test('manga counts come from the profile numbers without Jikan', () async {
      var jikanCalls = 0;
      final a = MalUserListAdapter(
        owner: () => 'Tester',
        get: (_) async => http.Response('{}', 200),
        jikanGet: (_) async {
          jikanCalls++;
          return http.Response('{}', 500);
        },
        mangaStats: (name) async {
          expect(name, 'Tester');
          return const ListStats(totalEntries: 9, current: 4, completed: 5);
        },
      );
      final counts = await a.statusCounts('manga');
      expect(counts![ListEntryStatus.current], 4);
      expect(counts[ListEntryStatus.completed], 5);
      expect(jikanCalls, 0);
    });

    test('manga counts fall back to Jikan when the profile has none', () async {
      final a = MalUserListAdapter(
        owner: () => 'Tester',
        get: (_) async => http.Response('{}', 200),
        mangaStats: (_) async => null,
        jikanGet: (uri) async => http.Response(
            jsonEncode({
              'data': {
                'manga': {'reading': 1, 'completed': 2, 'on_hold': 0, 'dropped': 0, 'plan_to_read': 3}
              }
            }),
            200),
      );
      final counts = await a.statusCounts('manga');
      expect(counts![ListEntryStatus.planned], 3);
    });

    test("another user's list cannot be stepped", () {
      final a = MalUserListAdapter(username: 'X', get: (_) async => http.Response('{}', 200));
      expect(a.canStep(_entry(1).copyWith(status: ListEntryStatus.current)), isFalse);
    });
  });
}
