import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_header.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_progress.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_profile_view.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import 'fakes.dart';

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
    await initializeDateFormatting();
  });

  final kimetsu = SimklTitle.fromJson(jsonDecode(fixture('simkl_anime_831411.json')))!;
  final episodes = SimklEpisode.listFrom(jsonDecode(fixture('simkl_episodes_831411.json')));
  final now = DateTime.utc(2026, 10, 28, 12);

  SimklEpisode ep(int n, DateTime date, {bool aired = true}) =>
      SimklEpisode(title: 'Ep title $n', number: n, date: date, aired: aired);

  group('next-episode card', () {
    test('an ended title not on the list shows its last aired episode', () {
      final next = simklNextUp(title: kimetsu, episodes: episodes, entry: null, now: now)!;
      expect(next.kind, SimklNextKind.ended);
      expect(next.episode, 2);
      expect(next.episodeTitle, 'Trainer Sakonji Urokodaki');
    });

    test('the user\'s next aired episode can be marked, a future one counts down', () {
      const airing = SimklTitle(simklId: 1, title: 'Airing', status: 'airing', totalEpisodes: 12);
      final eps = [
        ep(1, now.subtract(const Duration(days: 14))),
        ep(2, now.subtract(const Duration(days: 7))),
        ep(3, now.add(const Duration(days: 2)), aired: false),
      ];
      const watching = ListEntryView(id: 1, category: 'anime', title: 'Airing', status: ListEntryStatus.current, progress: 1, total: 12);
      final first = simklNextUp(title: airing, episodes: eps, entry: watching, now: now)!;
      expect(first.kind, SimklNextKind.watchNext);
      expect(first.episode, 2);
      final caught = simklNextUp(title: airing, episodes: eps, entry: watching.copyWith(progress: 2), now: now)!;
      expect(caught.kind, SimklNextKind.upcoming);
      expect(caught.episode, 3);
      expect(caught.date, eps[2].date);
      final out = simklNextUp(title: airing, episodes: eps, entry: null, now: now)!;
      expect(out.kind, SimklNextKind.upcoming, reason: 'not on the list: the next air date');
    });

    test('a completed entry points to the direct sequel, or shows nothing', () {
      const done = ListEntryView(id: 831411, category: 'anime', title: 'K', status: ListEntryStatus.completed, progress: 55, total: 55);
      final next = simklNextUp(title: kimetsu, episodes: episodes, entry: done, now: now)!;
      expect(next.kind, SimklNextKind.sequel);
      expect(next.sequel!.title, 'Kimetsu no Yaiba: Mugen Ressha Hen');
      const plain = SimklTitle(simklId: 2, title: 'Plain', status: 'ended');
      expect(simklNextUp(title: plain, episodes: const [], entry: done, now: now), isNull);
    });
  });

  test('the meta line mirrors the site header', () {
    expect(SimklTitleBlock.metaLine(kimetsu), '2019 – 2024 · Fuji TV · 22h 55m · 55 eps · TV · TV-MA');
  });

  group('calendar', () {
    final calendar = [
      SimklMedia(simklId: 1, title: 'Mine', episode: 12, airDate: DateTime.utc(2026, 10, 28, 15)),
      SimklMedia(simklId: 2, title: 'Other', episode: 1, airDate: DateTime.utc(2026, 10, 28, 10)),
      SimklMedia(simklId: 3, title: 'Tomorrow', episode: 4, airDate: DateTime.utc(2026, 10, 29, 10)),
    ];
    const list = {1: ListEntryView(id: 1, category: 'anime', title: 'Mine', status: ListEntryStatus.current, total: 12)};

    test('a day in the time zone setting, by air time, joined with the list', () {
      final day = simklAiringOn(calendar, DateTime(2026, 10, 28), list: list, zone: TimezonePref.utc);
      expect(day.map((a) => a.media.title), ['Other', 'Mine']);
      expect(day.first.premiere, isTrue);
      expect(day.last.finale, isTrue, reason: 'last episode of a listed title');
      expect(day.first.finale, isFalse);
      expect(simklAiringOn(calendar, DateTime(2026, 10, 28), list: list, mine: true, zone: TimezonePref.utc).map((a) => a.media.title),
          ['Mine']);
      expect(simklAiringOn(calendar, DateTime(2026, 10, 28), list: list, mineFirst: true, zone: TimezonePref.utc).map((a) => a.media.title),
          ['Mine', 'Other']);
      // 15:00 UTC is already the next day in Japan.
      expect(simklAiringOn(calendar, DateTime(2026, 10, 29), zone: TimezonePref.jst).map((a) => a.media.title),
          ['Mine', 'Tomorrow']);
    });
  });

  test('list rows take the next airing of the calendar as a Japan-time weekly slot', () {
    const entries = [
      ListEntryView(id: 1, category: 'anime', title: 'Airing', status: ListEntryStatus.current, progress: 3, total: 12, score: 8),
      ListEntryView(id: 2, category: 'anime', title: 'Not in the calendar', releaseState: ReleaseState.finished),
    ];
    final calendar = [
      SimklMedia(simklId: 1, title: 'Airing', episode: 3, airDate: DateTime.utc(2026, 10, 27, 15)), // past
      SimklMedia(simklId: 1, title: 'Airing', episode: 5, airDate: DateTime.utc(2026, 11, 4, 15)),
      SimklMedia(simklId: 1, title: 'Airing', episode: 4, airDate: DateTime.utc(2026, 10, 28, 15)), // Thu 00:00 JST
    ];
    final out = simklWithAiring(entries, calendar, now);
    expect(out[0].releaseState, ReleaseState.releasing);
    expect(out[0].broadcast, const BroadcastSlot(DateTime.thursday, 0));
    expect(out[0].broadcast!.nextAiring(now), DateTime.utc(2026, 10, 28, 15));
    expect(out[0].score, 8, reason: 'the rest of the entry is kept');
    expect(out[0].progress, 3);
    expect(identical(out[1], entries[1]), isTrue);
  });

  test('countdowns and durations read in the app language', () {
    expect(SimklFormat.countdown(now.add(const Duration(days: 2, hours: 4)), now), 'in 2 d 4 h');
    expect(SimklFormat.countdown(now.add(const Duration(minutes: 70)), now), 'in 1 h 10 min');
    expect(SimklFormat.countdown(now.subtract(const Duration(minutes: 1)), now), isNull);
    expect(SimklFormat.clock(DateTime.utc(2026, 1, 1, 14, 5), zone: TimezonePref.jst), '23:05');
  });

  test('episodes watched are summed per status for the profile', () {
    final by = simklEpisodesByStatus(const [
      ListEntryView(id: 1, category: 'anime', title: 'a', status: ListEntryStatus.current, progress: 3),
      ListEntryView(id: 2, category: 'anime', title: 'b', status: ListEntryStatus.current, progress: 4),
      ListEntryView(id: 3, category: 'anime', title: 'c', status: ListEntryStatus.completed, progress: 12),
      ListEntryView(id: 4, category: 'anime', title: 'd', progress: 9),
    ]);
    expect(by, {ListEntryStatus.current: 7, ListEntryStatus.completed: 12});
  });
}
