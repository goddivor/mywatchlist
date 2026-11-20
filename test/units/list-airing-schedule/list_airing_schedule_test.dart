import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// An airing ONA MAL gives no broadcast slot for (Kanojo no Tomodachi).
ListEntryView _ona({BroadcastSlot? broadcast}) => ListEntryView(
      id: 64131,
      malId: 64131,
      category: 'anime',
      title: 'Kanojo no Tomodachi',
      status: ListEntryStatus.current,
      progress: 7,
      total: 12,
      mediaType: 'ona',
      releaseState: ReleaseState.releasing,
      releaseStart: '2026-10-01',
      broadcast: broadcast,
    );

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);
  final airsAt = now.add(const Duration(days: 2, hours: 7));

  setUpAll(() async {
    await initializeDateFormatting();
    await S.load(const Locale('en'));
  });
  tearDown(() => AiringSchedule.instance.reset());

  void schedule() => AiringSchedule.instance.replace([
        LiveChartEpisode(timestamp: airsAt.millisecondsSinceEpoch ~/ 1000, episode: 8, malId: 64131),
      ], now: now);

  test('no broadcast slot and no schedule: no countdown', () {
    expect(_ona().upcomingAiring(now), isNull);
    expect(airingText(_ona(), now, 'en'), isNull);
  });

  test('the LiveChart schedule gives the countdown of a title without a broadcast slot', () {
    schedule();
    expect(_ona().upcomingAiring(now), airsAt);
    final text = airingText(_ona(), now, 'en')!;
    expect(text, contains('8'));
    expect(text, contains('2'));
  });

  test('the schedule wins over the weekly broadcast slot', () {
    schedule();
    final slot = BroadcastSlot(DateTime.monday, 0);
    expect(_ona(broadcast: slot).upcomingAiring(now), airsAt);
  });

  test('without the schedule the broadcast slot is still used', () {
    final slot = BroadcastSlot(DateTime.monday, 0);
    expect(_ona(broadcast: slot).upcomingAiring(now), slot.nextAiring(now));
  });

  test('a finished title has no countdown', () {
    schedule();
    const done = ListEntryView(id: 1, malId: 64131, category: 'anime', title: 'T', releaseState: ReleaseState.finished);
    expect(done.upcomingAiring(now), isNull);
  });
}
