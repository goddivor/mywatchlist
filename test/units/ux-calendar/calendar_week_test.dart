import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/calendar/calendar_cubit.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';
import 'package:mywatchlist/widgets/calendar/calendar_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

CalendarEntry _entry(int id, DateTime at, {int ep = 2, String? status}) => CalendarEntry(
      malId: id,
      title: 'Title $id',
      imageUrl: '',
      episode: ep,
      airingAt: at,
      listStatus: status,
    );

Anime _anime(int id, String status) => Anime(
      id: id,
      title: 'MAL title $id',
      imageUrl: '',
      score: 0,
      members: 0,
      myListStatus: MyListStatus(
        status: status,
        score: 0,
        numEpisodesWatched: 0,
        isRewatching: false,
        updatedAt: '',
      ),
    );

void main() {
  // Wednesday 28 October 2026, 18:40 UTC (the checker's walk).
  final now = DateTime.utc(2026, 10, 28, 18, 40);

  group('withPreviousEpisodes', () {
    test("adds the episode that aired a week before the next one", () {
      final out = withPreviousEpisodes([_entry(1, DateTime.utc(2026, 11, 4, 13), ep: 5)], now: now);
      expect(out, hasLength(2));
      expect(out.last.episode, 4);
      expect(out.last.airingAt, DateTime.utc(2026, 10, 28, 13));
    });

    test('nothing before a first episode, a break or a show still to air', () {
      expect(withPreviousEpisodes([_entry(1, DateTime.utc(2026, 11, 4, 13), ep: 1)], now: now), hasLength(1));
      // next episode in 9 days: the week before is still to come, so unknown
      expect(withPreviousEpisodes([_entry(2, DateTime.utc(2026, 11, 6, 13), ep: 3)], now: now), hasLength(1));
      // airs later today: last week's episode, outside the calendar
      final later = withPreviousEpisodes([_entry(3, DateTime.utc(2026, 10, 28, 20), ep: 3)], now: now);
      expect(buildWeek(later, now: now, pref: TimezonePref.utc, listKnown: true)[0].entries, hasLength(1));
    });

    test('uses the earliest episode of each anime only', () {
      final out = withPreviousEpisodes([
        _entry(1, DateTime.utc(2026, 11, 11, 13), ep: 6),
        _entry(1, DateTime.utc(2026, 11, 4, 13), ep: 5),
      ], now: now);
      expect(out.where((e) => e.episode == 4), hasLength(1));
      expect(out, hasLength(3));
    });
  });

  group('status chips', () {
    test("toggle like DailyAL's All / Plan to Watch / Watching", () {
      expect(toggleFilter(CalendarFilter.watchingOrPlanned, CalendarFilter.watching), CalendarFilter.planToWatch);
      expect(toggleFilter(CalendarFilter.planToWatch, CalendarFilter.planToWatch), CalendarFilter.all);
      expect(toggleFilter(CalendarFilter.all, CalendarFilter.watching), CalendarFilter.watching);
      expect(toggleFilter(CalendarFilter.watching, CalendarFilter.planToWatch), CalendarFilter.watchingOrPlanned);
      expect(toggleFilter(CalendarFilter.watchingOrPlanned, CalendarFilter.all), CalendarFilter.all);
      expect(toggleFilter(null, CalendarFilter.planToWatch), CalendarFilter.planToWatch);
    });

    test('chip states follow the filter value', () {
      expect(isChipOn(CalendarFilter.watchingOrPlanned, CalendarFilter.watching), isTrue);
      expect(isChipOn(CalendarFilter.watchingOrPlanned, CalendarFilter.planToWatch), isTrue);
      expect(isChipOn(CalendarFilter.watchingOrPlanned, CalendarFilter.all), isFalse);
      expect(isChipOn(null, CalendarFilter.all), isTrue);
      expect(isChipOn(CalendarFilter.watching, CalendarFilter.planToWatch), isFalse);
    });

    test('watching or planned keeps both statuses only', () {
      bool keep(String? s) =>
          matchesFilter(_entry(1, now, status: s), CalendarFilter.watchingOrPlanned, listKnown: true);
      expect(keep('watching'), isTrue);
      expect(keep('plan_to_watch'), isTrue);
      expect(keep('completed'), isFalse);
      expect(keep(null), isFalse);
    });
  });

  test("today keeps the list's episodes that already aired, filtered by default", () async {
    SharedPreferences.setMockInitialValues({});
    LiveChartEpisode lc(int id, DateTime at, int ep) =>
        LiveChartEpisode(timestamp: at.millisecondsSinceEpoch ~/ 1000, episode: ep, malId: id);
    final cubit = CalendarCubit(
      timezone: TimezonePref.utc,
      listKnown: true,
      initialFilter: CalendarFilter.watchingOrPlanned,
      clock: () => now,
      cache: ListStatusCache(),
      schedule: AiringSchedule(fetcher: ({required fromCache}) async => [
            lc(1, DateTime.utc(2026, 11, 4, 13), 5), // aired today 13:00 (ep 4)
            lc(2, DateTime.utc(2026, 11, 4, 15, 45), 8), // aired today 15:45 (ep 7)
            lc(3, DateTime.utc(2026, 10, 29, 10), 2), // tomorrow, not on the list
          ]),
      seasonLoader: () async => {1: _anime(1, 'watching'), 2: _anime(2, 'plan_to_watch')},
    );
    await cubit.load();
    final today = cubit.state.days[0].entries;
    expect(today.map((e) => (e.malId, e.episode)), [(1, 4), (2, 7)]);
    expect(cubit.state.days[1].entries, isEmpty);
    cubit.setFilter(CalendarFilter.all);
    expect(cubit.state.days[1].entries.map((e) => e.malId), [3]);
    await cubit.close();
  });

  testWidgets('day header reads the weekday and the count, in French', (tester) async {
    await tester.runAsync(() async {
      await initializeDateFormatting('fr_FR');
      await S.load(const Locale('fr', 'FR'));
    });
    var toggled = false;
    final clock = ValueNotifier<int>(now.millisecondsSinceEpoch ~/ 1000);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        body: Column(children: [
          DayHeader(date: DateTime.utc(2026, 10, 28), count: 2, open: true, onToggle: () => toggled = true),
          EpisodeTile(
            entry: _entry(1, DateTime.utc(2026, 10, 28, 13), ep: 4),
            timezone: TimezonePref.utc,
            clock: clock,
            showStatus: false,
            onOpen: () {},
          ),
        ]),
      ),
    ));
    expect(find.text('Mercredi (2)'), findsOneWidget);
    expect(find.text(S.current.Cal_Aired), findsOneWidget);
    expect(find.byIcon(Icons.add_alert_outlined), findsNothing); // aired: nothing to add
    await tester.tap(find.text('Mercredi (2)'));
    expect(toggled, isTrue);
    clock.dispose();
  });
}
