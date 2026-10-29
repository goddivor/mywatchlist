import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_stats_service.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_profile_view.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

void main() {
  setUpAll(() async => S.load(const Locale('en')));

  test('SimklMedia reads watchers, drop rate and rank of a feed item', () {
    final m = SimklMedia.fromJson({
      'title': 'Show',
      'ids': {'simkl_id': 7},
      'rank': 382,
      'drop_rate': '0.7%',
      'watched': 2522,
    })!;
    expect(m.rank, 382);
    expect(m.dropRate, 0.7);
    expect(m.watchers, 2522);
    expect(SimklMedia.fromJson({'title': 'x', 'ids': {'simkl_id': 1}})!.rank, isNull);
  });

  test('watch stats sum the left to watch of every status', () {
    final s = SimklWatchStats.fromJson({
      'total_mins': 908554,
      'anime': {
        'total_mins': 494025,
        'watching': {'count': 21, 'left_to_watch_episodes': 410, 'left_to_watch_mins': 10250},
        'plantowatch': {'left_to_watch_episodes': 10, 'left_to_watch_mins': 250},
        'completed': {'count': 1291},
      },
      'watched_last_week': {'total_mins': 130, 'anime_mins': 40},
    })!;
    expect(s.totalMins, 494025);
    expect(s.leftMins, 10500);
    expect(s.leftEpisodes, 420);
    expect(s.lastWeekMins, 40);
    expect(SimklWatchStats.fromJson('nope'), isNull);
  });

  test('now watching needs a cover; lists tolerate premium_only', () {
    expect(SimklNowWatching.fromJson({'id': 1, 'title': 'T', 'fanart': null}), isNull);
    final n = SimklNowWatching.fromJson({'id': 1, 'title': 'T', 'fanart': 'https://x/y.jpg'})!;
    expect(n.simklId, 1);
    expect(SimklCustomList.listFrom({'error': 'premium_only'}), isEmpty);
    final l = SimklCustomList.listFrom([
      {'id': 3, 'name': 'Faves', 'items_count': 4},
      {'oops': true},
    ]);
    expect(l.single.name, 'Faves');
    expect(l.single.count, 4);
  });

  test('stats service without a session asks to sign in again', () async {
    final client = SimklClient(
      auth: (send, {idempotent}) async => null,
      clientId: () => 'cid',
      appVersion: () async => '1.0.0',
    );
    await expectLater(SimklStatsService(client: client).watchStats(12), throwsA(isA<SimklSessionExpired>()));
  });

  test('top rated keeps 9 and 10, best first', () {
    ListEntryView e(int id, int score, int day) => ListEntryView(
        id: id, category: 'anime', title: 't$id', score: score, updatedAt: DateTime.utc(2026, 1, day));
    final top = simklTopRated([e(1, 8, 1), e(2, 9, 5), e(3, 10, 1), e(4, 9, 9)]);
    expect([for (final x in top) x.id], [3, 4, 2]);
  });

  test('durations read in days, hours and minutes', () {
    expect(simklDuration(45), '45m');
    expect(simklDuration(320), '5h 20m');
    expect(simklDuration(3 * 1440 + 4 * 60), '3d 4h');
  });
}
