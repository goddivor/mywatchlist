import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/pages/Simkl/simkl_explore_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_home_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_media_page.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_stats_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_progress.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_profile_view.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import '../../helpers/no_network.dart';
import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const base = 'https://simkl.com/anime/831411/kimetsu-no-yaiba';

  setUpAll(() async {
    forbidNetwork();
    await initializeDateFormatting();
  });

  setUp(HomeSectionCache.clear);

  FakeSimkl titleSite() => FakeSimkl(
        api: {
          '/anime/831411': (_) => withoutPictures(jsonDecode(fixture('simkl_anime_831411.json'))),
          '/anime/episodes/831411': (_) => withoutPictures(jsonDecode(fixture('simkl_episodes_831411.json'))),
        },
        pages: {base: () => withoutImages(fixture('simkl_title_frieren.html'))},
      );

  double y(WidgetTester tester, String text) => tester.getTopLeft(find.text(text).first).dy;

  group('title page', () {
    testWidgets('ratings strip, next-episode card, synopsis first, community and information last', (tester) async {
      final site = titleSite();
      await pumpPage(tester, SimklMediaPage(simklId: 831411, service: site.details()), height: 6000);

      expect(find.text('Kimetsu no Yaiba'), findsWidgets);
      expect(find.text('Demon Slayer: Kimetsu no Yaiba'), findsWidgets, reason: 'the other form of the title');
      expect(find.text('2019 – 2024 · Fuji TV · 22h 55m · 55 eps · TV · TV-MA'), findsOneWidget);
      expect(find.text('Simkl'), findsOneWidget);
      expect(find.text('8.7'), findsOneWidget);
      expect(find.text('MAL'), findsWidgets);
      expect(find.text('8.6'), findsOneWidget);
      expect(find.text('#14'), findsOneWidget);
      expect(find.text('0.8%'), findsOneWidget);
      expect(find.text('Last aired'), findsOneWidget);
      expect(find.text('Ep. 2 · Trainer Sakonji Urokodaki'), findsOneWidget);
      expect(find.text('Add to list'), findsNothing, reason: 'signed out: no status bar');

      final order = ['8.7', 'Last aired', 'Synopsis', 'Episodes', 'Watchers', 'Related', 'Recommendations', 'Community', 'Information'];
      for (var i = 1; i < order.length; i++) {
        expect(y(tester, order[i - 1]), lessThan(y(tester, order[i])), reason: '${order[i - 1]} before ${order[i]}');
      }
      expect(y(tester, 'Community'), lessThan(y(tester, '245 reactions')));
      expect(site.writes(), isEmpty);
    });

    testWidgets('French', (tester) async {
      await pumpPage(tester, SimklMediaPage(simklId: 831411, service: titleSite().details()), locale: 'fr_FR', height: 6000);
      expect(find.text('Dernière diffusion'), findsOneWidget);
      expect(find.text('Communauté'), findsOneWidget);
      expect(find.text('Taux d’abandon'), findsWidgets);
      expect(find.text('Last aired'), findsNothing);
    });

    testWidgets('next-episode card marks the aired episode; status bar opens the editor', (tester) async {
      int? marked;
      var edits = 0;
      await pumpPage(
        tester,
        Scaffold(
          body: Column(children: [
            SimklMyStatusBar(
              entry: const ListEntryView(id: 1, category: 'anime', title: 'T', status: ListEntryStatus.current, progress: 3, total: 12, score: 8),
              total: 12,
              onEdit: () => edits++,
            ),
            SimklNextEpisodeCard(
              next: const SimklNextUp(SimklNextKind.watchNext, episode: 4, episodeTitle: 'The fourth'),
              now: DateTime(2026),
              onMark: () => marked = 4,
            ),
            SimklNextEpisodeCard(
              next: SimklNextUp(SimklNextKind.upcoming, episode: 5, date: DateTime.utc(2026, 1, 3, 12)),
              now: DateTime.utc(2026, 1, 1, 8),
            ),
          ]),
        ),
      );
      expect(find.text('Watching'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('3 / 12'), findsOneWidget);
      expect(find.text('Ep. 4 · The fourth'), findsOneWidget);
      expect(find.textContaining('in 2 d 4 h'), findsOneWidget);
      await tester.tap(find.byTooltip('Mark Ep. 4 watched'));
      expect(marked, 4);
      expect(find.byTooltip('Mark Ep. 5 watched'), findsNothing, reason: 'not aired yet');
      await tester.tap(find.text('Watching'));
      expect(edits, 1);
    });
  });

  group('home and explore', () {
    late FakeSimkl fake;

    setUp(() {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 23, 59);
      fake = FakeSimkl(
        api: {'/anime/1001': (_) => {'title': 'Trend 1', 'ids': {'simkl': 1001}}},
        cdnFiles: {
          '/discover/trending/anime/today_100.json': () => [
                for (var i = 1; i <= 3; i++)
                  {
                    'title': 'Trend $i',
                    'ids': {'simkl_id': 1000 + i},
                    'ratings': {'simkl': {'rating': 8.0, 'votes': 10}},
                  },
              ],
          '/calendar/v2/anime.json': () => {
                'calendar': [
                  {'simkl_id': 7, 'date': today.toUtc().toIso8601String(), 'episode': {'episode': 1}},
                ],
                'metadata': {
                  '7': {'title': 'Show 7', 'ids': {'simkl_id': 7}},
                },
              },
        },
      );
      SimklDiscoverService.instance = SimklDiscoverService(client: fake.client, cdn: fake.cdn, signedIn: () => false);
      SimklDetailService.instance = fake.details();
    });

    testWidgets('trending is a ranked carousel titled for Simkl', (tester) async {
      await pumpPage(tester, const SimklHomePage());
      expect(find.text('Trending'), findsOneWidget);
      expect(find.text('on Simkl'), findsWidgets);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Trend 1'), findsOneWidget);
      await tester.tap(find.text('Trending'));
      await tester.pumpAndSettle();
      expect(find.byType(SimklFeedPage), findsOneWidget);
    });

    testWidgets('the explore schedule lists calendar rows with a Premiere badge and opens the calendar', (tester) async {
      await pumpPage(tester, const SimklExplorePage());
      await tester.tap(find.text('Schedule'));
      await tester.pumpAndSettle();
      expect(find.text('Show 7'), findsOneWidget);
      expect(find.text('23:59'), findsOneWidget);
      expect(find.text('Premiere'), findsOneWidget);
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();
      expect(find.byType(SimklCalendarPage), findsOneWidget);
      expect(find.text('Show 7'), findsOneWidget);
    });
  });

  testWidgets('calendar: My shows first, All anime on demand, finale of a listed title', (tester) async {
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 23, 30).toUtc().toIso8601String();
    final fake = FakeSimkl(
      api: {
        '/sync/activities': (_) => {},
        '/sync/all-items/anime': (_) => {
              'anime': [listItem(id: 1, title: 'Mine', watched: 11, total: 12)],
            },
        '/ratings/anime': (_) => [],
      },
      cdnFiles: {
        '/calendar/v2/anime.json': () => {
              'calendar': [
                {'simkl_id': 1, 'date': at, 'episode': {'episode': 12}},
                {'simkl_id': 2, 'date': at, 'episode': {'episode': 3}},
              ],
              'metadata': {
                '1': {'title': 'Mine 1', 'ids': {'simkl_id': 1}},
                '2': {'title': 'Other 2', 'ids': {'simkl_id': 2}},
              },
            },
      },
    );
    await pumpPage(
      tester,
      SimklCalendarPage(
        service: SimklDiscoverService(client: fake.client, cdn: fake.cdn, signedIn: () => false),
        listService: SimklListService(client: fake.client, owner: () => 'me'),
      ),
    );
    expect(find.text('Mine 1'), findsOneWidget);
    expect(find.text('Other 2'), findsNothing);
    expect(find.text('Finale'), findsOneWidget);
    await tester.tap(find.text('All anime'));
    await tester.pumpAndSettle();
    expect(find.text('Other 2'), findsOneWidget);
    expect(fake.writes(), isEmpty);
  });

  testWidgets('profile: now watching and watch time come first, then the status breakdown', (tester) async {
    final list = [
      const ListEntryView(id: 1, category: 'anime', title: 'Done', status: ListEntryStatus.completed, score: 9, progress: 12, total: 12),
      const ListEntryView(id: 2, category: 'anime', title: 'Going', status: ListEntryStatus.current, progress: 3, total: 12),
    ];
    await pumpPage(
      tester,
      SimklProfileView(
        loader: ({bool force = false}) async => SimklProfileData(
          UserProfSimkl(name: 'Hailey', accountType: 'vip'),
          SimklListStats.from(list),
          watch: const SimklWatchStats(totalMins: 3 * 1440 + 240, leftMins: 600, leftEpisodes: 24, lastWeekMins: 130),
          nowWatching: const SimklNowWatching(simklId: 5, title: 'Frieren', coverUrl: ''),
          episodesByStatus: simklEpisodesByStatus(list),
        ),
      ),
    );
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Now watching'), findsOneWidget);
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Watch time'), findsOneWidget);
    expect(find.text('3d 4h'), findsOneWidget);
    expect(find.text('24 episodes left'), findsOneWidget);
    expect(find.text('2h 10m'), findsOneWidget);
    expect(find.text('12 eps'), findsOneWidget);
    expect(y(tester, 'Now watching'), lessThan(y(tester, 'Watch time')));
    expect(y(tester, 'Watch time'), lessThan(y(tester, 'Anime list')));
  });

  testWidgets('profile speaks French', (tester) async {
    await pumpPage(
      tester,
      SimklProfileView(
        loader: ({bool force = false}) async => SimklProfileData(
          null,
          SimklListStats.from(const [ListEntryView(id: 1, category: 'anime', title: 'x', status: ListEntryStatus.current, progress: 1)]),
          watch: const SimklWatchStats(totalMins: 90, leftEpisodes: 2, leftMins: 50),
          nowWatching: const SimklNowWatching(simklId: 5, title: 'Frieren', coverUrl: ''),
        ),
      ),
      locale: 'fr_FR',
    );
    expect(find.text('En cours'), findsWidgets);
    expect(find.text('Temps de visionnage'), findsOneWidget);
    expect(find.text('2 épisodes restants'), findsOneWidget);
  });
}
