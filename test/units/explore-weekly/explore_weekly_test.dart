import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show PageParsers;
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/weekly/weekly_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart' show TimezonePref;
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';

import '../../helpers/html_fixtures.dart';
import 'dart:io';

Map<String, dynamic> _node(int id, {double? mean, int? scorers, String? status}) => {
      'id': id,
      'title': 'Anime $id',
      'mean': mean,
      'num_scoring_users': scorers,
      'broadcast': {'day_of_the_week': 'saturday', 'start_time': '23:30'},
      if (status != null) 'my_list_status': {'status': status, 'score': 7},
    };

void main() {
  group('scheduleWeekday', () {
    // A Wednesday, 12:00 UTC.
    final now = DateTime.utc(2026, 10, 28, 12);

    test('JST keeps the MAL day', () {
      expect(MalApi.scheduleWeekday('saturday', '23:30', pref: TimezonePref.jst, now: now),
          DateTime.saturday);
    });

    test('a late-night JST slot is the same day in UTC after 9:00 JST', () {
      expect(MalApi.scheduleWeekday('saturday', '23:30', pref: TimezonePref.utc, now: now),
          DateTime.saturday);
    });

    test('an early-morning JST slot is the day before in UTC', () {
      expect(MalApi.scheduleWeekday('monday', '01:00', pref: TimezonePref.utc, now: now),
          DateTime.sunday);
      expect(MalApi.scheduleWeekday('Monday', '08:59', pref: TimezonePref.utc, now: now),
          DateTime.sunday);
    });

    test('a 24:30 slot is the next day in JST', () {
      expect(MalApi.scheduleWeekday('friday', '24:30', pref: TimezonePref.jst, now: now),
          DateTime.saturday);
    });

    test('unknown or "other" slots go to the eighth tab', () {
      expect(MalApi.scheduleWeekday('other', '12:00', pref: TimezonePref.jst, now: now), 8);
      expect(MalApi.scheduleWeekday('monday', null, pref: TimezonePref.jst, now: now), 8);
      expect(MalApi.scheduleWeekday(null, '12:00', pref: TimezonePref.utc, now: now), 8);
      expect(MalApi.scheduleWeekday('monday', 'noon', pref: TimezonePref.utc, now: now), 8);
    });
  });

  group('WeeklyData', () {
    final entries = [
      weeklyEntryFromNode(_node(1, mean: 7.1, scorers: 10)),
      weeklyEntryFromNode(_node(2, mean: 8.5, scorers: 5, status: 'watching')),
      weeklyEntryFromNode(_node(3, mean: 6.0, scorers: 50, status: 'plan_to_watch')),
    ];

    test('reads a MAL node with its list status and scorers', () {
      final e = entries[1];
      expect(e.id, 2);
      expect(e.status, ListEntryStatus.current);
      expect(e.score, 7);
      expect(e.scoringUsers, 5);
      expect(e.broadcast, const BroadcastSlot(DateTime.saturday, 23 * 60 + 30));
      expect(entries[0].status, isNull);
    });

    test('sorts by score and by scorers', () {
      final byMean = WeeklyData.apply(entries, const ListViewSettings(sortKey: ListSortKeys.mean));
      expect(byMean.map((e) => e.id), [2, 1, 3]);
      final byScorers =
          WeeklyData.apply(entries, const ListViewSettings(sortKey: ListSortKeys.scorers));
      expect(byScorers.map((e) => e.id), [3, 1, 2]);
    });

    test('"Not in list" is three-state: only, or excluded', () {
      const only = ListFilter(included: {
        WeeklyData.statusFacet: {WeeklyData.notInList}
      });
      expect(
          WeeklyData.apply(
                  entries, const ListViewSettings(sortKey: ListSortKeys.mean, filter: only))
              .map((e) => e.id),
          [1]);
      const inList = ListFilter(excluded: {
        WeeklyData.statusFacet: {WeeklyData.notInList}
      });
      expect(
          WeeklyData.apply(
                  entries, const ListViewSettings(sortKey: ListSortKeys.mean, filter: inList))
              .map((e) => e.id),
          [2, 3]);
      const watching = ListFilter(included: {
        WeeklyData.statusFacet: {'watching'}
      });
      expect(
          WeeklyData.apply(
                  entries, const ListViewSettings(sortKey: ListSortKeys.mean, filter: watching))
              .map((e) => e.id),
          [2]);
    });

    test('today is the tab of the zone of the preferences', () {
      // Wednesday 20:00 UTC is Thursday 05:00 in Japan.
      final now = DateTime.utc(2026, 10, 28, 20);
      expect(WeeklyData.todayIndex(TimezonePref.utc, now), DateTime.wednesday - 1);
      expect(WeeklyData.todayIndex(TimezonePref.jst, now), DateTime.thursday - 1);
    });
  });

  group('random pick without Jikan', () {
    test('a draw past the end of the ranking draws again below it', () async {
      final asked = <int>[];
      final id = await ExploreData.randomFromRanking('anime', (offset) async {
        asked.add(offset);
        return offset < 1000 ? 42 : null;
      }, random: _Fixed([20000, 5000, 400]));
      expect(id, 42);
      expect(asked, [20000, 5000, 400]);
    });

    test('gives up after four empty draws', () async {
      var calls = 0;
      final id = await ExploreData.randomFromRanking('manga', (_) async {
        calls++;
        return null;
      }, random: Random(1));
      expect(id, isNull);
      expect(calls, lessThanOrEqualTo(4));
    });

    test('reads the id of the first ranking row', () {
      expect(
          ExploreData.firstRankingId({
            'data': [
              {
                'node': {'id': 5114}
              }
            ]
          }),
          5114);
      expect(ExploreData.firstRankingId({'data': []}), isNull);
      expect(ExploreData.firstRankingId(null), isNull);
    });
  });

  group('report a recommendation', () {
    test('the MAL page row carries its id and the report page', () {
      final rows = PageParsers.parseRecentRecommendations(
        htmlFixture(
            File('test/units/profile-tabs/fixtures/recommendations_feed.html').readAsStringSync()),
        'anime',
      );
      final reco = CommunityRecommendation.fromHtml(rows.first)!;
      expect(reco.id, 226469);
      expect(reco.reportUrl('anime'),
          'https://myanimelist.net/dbchanges.php?go=reportanimerecommendation&id=226469');
      expect(reco.reportUrl('manga'),
          'https://myanimelist.net/dbchanges.php?go=reportmangarecommendation&id=226469');
    });

    test('no report link without an id (Jikan rows)', () {
      const reco = CommunityRecommendation(
        first: RecoRef(id: 1, title: 'A'),
        second: RecoRef(id: 2, title: 'B'),
      );
      expect(reco.reportUrl('anime'), isNull);
    });
  });
}

/// Returns the given values from [nextInt] in order.
class _Fixed implements Random {
  final List<int> values;
  var _i = 0;
  _Fixed(this.values);

  @override
  int nextInt(int max) => values[_i++].clamp(0, max - 1);

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}
