import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Simkl/simkl_search_all_page.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart' hide SimklFormat;
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/notifications/notification_payload.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/services/notifications/simkl_release_planner.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart' show AiringEpisode;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notifications/fakes.dart';

final _now = DateTime.utc(2026, 11, 24, 12);

final _texts = SimklReleaseTexts(
  episodeTitle: (title, code) => '$title · $code',
  movieTitle: (title) => '$title is out',
  watchingBody: 'watching',
  planShowBody: 'plan show',
  planMovieBody: 'plan movie',
);

const _shows = [
  ListEntryView(id: 10, category: 'tv', title: 'Reacher', status: ListEntryStatus.current),
  ListEntryView(id: 11, category: 'tv', title: 'Planned', status: ListEntryStatus.planned),
  ListEntryView(id: 12, category: 'tv', title: 'Dropped', status: ListEntryStatus.dropped),
];

const _movies = [
  ListEntryView(id: 20, category: 'movie', title: 'Dune', status: ListEntryStatus.planned),
  ListEntryView(id: 21, category: 'movie', title: 'Seen', status: ListEntryStatus.completed),
];

final _showCalendar = [
  SimklMedia(simklId: 10, title: 'Reacher', season: 2, episode: 6, airDate: DateTime.utc(2026, 12, 1, 8)),
  SimklMedia(simklId: 10, title: 'Reacher', season: 2, episode: 5, airDate: DateTime.utc(2026, 11, 24, 8)), // aired
  SimklMedia(simklId: 10, title: 'Reacher', season: 2, episode: 7, airDate: DateTime.utc(2026, 12, 8, 8)),
  SimklMedia(simklId: 11, title: 'Planned', season: 1, episode: 1, airDate: DateTime.utc(2026, 11, 30, 20)),
  SimklMedia(simklId: 12, title: 'Dropped', season: 3, episode: 2, airDate: DateTime.utc(2026, 11, 26, 20)),
  SimklMedia(simklId: 99, title: 'Not mine', season: 1, episode: 2, airDate: DateTime.utc(2026, 11, 26, 20)),
];

final _movieCalendar = [
  SimklMedia(simklId: 20, title: 'Dune', airDate: DateTime.utc(2026, 12, 18)),
  SimklMedia(simklId: 21, title: 'Seen', airDate: DateTime.utc(2026, 12, 20)),
];

List<PlannedNotification> _plan({NotificationPreferences prefs = const NotificationPreferences()}) =>
    SimklReleasePlanner.plan(
      shows: _shows,
      showCalendar: _showCalendar,
      movies: _movies,
      movieCalendar: _movieCalendar,
      prefs: prefs,
      texts: _texts,
      now: _now,
    );

void main() {
  group('planner', () {
    test('coming episodes of watching and planned shows, and planned movies, in time order', () {
      final plan = _plan();
      expect(plan.map((n) => n.title), [
        'Planned · S1E1',
        'Reacher · S2E6',
        'Reacher · S2E7',
        'Dune is out',
      ]);
      expect(plan.map((n) => n.body), ['plan show', 'watching', 'watching', 'plan movie']);
      expect(plan[1].payload, 'simkl:tv:10');
      expect(plan.last.payload, 'simkl:movie:20');
      expect(plan.last.kind, NotificationKind.planToWatch);
    });

    test('ids and cover keys stay apart from the anime (malId * 8 + slot) and the MAL hub', () {
      final plan = _plan();
      final reacher = plan.where((n) => n.title.startsWith('Reacher')).toList();
      expect(reacher.map((n) => n.id), [
        SimklReleasePlanner.idBase + 10 * 8,
        SimklReleasePlanner.idBase + 10 * 8 + 1,
      ]);
      expect(reacher.first.coverId, SimklReleasePlanner.idBase + 10);
      expect(reacher.first.malId, isNull);
      for (final n in plan) {
        expect(n.id, lessThan(0x40000000));
        expect(n.id, greaterThanOrEqualTo(SimklReleasePlanner.idBase));
      }
    });

    test('the list switches of the notification settings apply', () {
      final noWatching = _plan(prefs: const NotificationPreferences(watchingList: false));
      expect(noWatching.map((n) => n.title), ['Planned · S1E1', 'Dune is out']);
      final noPlan = _plan(prefs: const NotificationPreferences(planToWatchList: false));
      expect(noPlan.map((n) => n.title), ['Reacher · S2E6', 'Reacher · S2E7']);
    });

    test('the payloads read back; any other payload is not a Simkl title', () {
      expect(parseSimklTitlePayload('simkl:tv:10'), (simklId: 10, movie: false));
      expect(parseSimklTitlePayload('simkl:movie:20'), (simklId: 20, movie: true));
      expect(parseSimklTitlePayload('simkl:anime:20'), isNull);
      expect(parseSimklTitlePayload('simkl:tv:0'), isNull);
      expect(parseSimklTitlePayload('anime:20'), isNull);
      expect(parseSimklTitlePayload(null), isNull);
      // The tracker-tagged format does not take them for one of its own kinds.
      expect(NotificationPayload.parse('simkl:tv:10'), isNull);
    });
  });

  group('service', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Simkl shows and movies are scheduled next to the anime, with their own covers', () async {
      final backend = FakeBackend();
      final feeds = <AccountType>[];
      final covers = <int>[];
      final service = NotificationService(
        backend: backend,
        texts: const FakeTexts(),
        readPrefs: () => NotificationPreferences(subscribedAt: DateTime.utc(2026, 10, 1)),
        clock: () => _now,
        readFeedTracker: () => AccountType.simkl,
        loadCandidates: () async => const [
          AiringCandidate(malId: 1, title: 'One', status: 'watching', airingStatus: 'currently_airing'),
        ],
        loadEpisodes: () async => [
          AiringEpisode(malId: 1, episode: 3, airingAt: DateTime.utc(2026, 11, 25, 15)),
        ],
        loadSimklReleases: (feed, prefs, now) async {
          feeds.add(feed);
          return [
            PlannedNotification(
              id: SimklReleasePlanner.idOf(10, 0),
              kind: NotificationKind.watching,
              at: DateTime.utc(2026, 11, 25, 8),
              title: 'Reacher · S2E6',
              body: 'watching',
              payload: 'simkl:tv:10',
              imageUrl: 'https://img/reacher.jpg',
              coverId: SimklReleasePlanner.coverIdOf(10),
            ),
          ];
        },
        fetchCover: (url, id) async {
          covers.add(id);
          return '/covers/$id.jpg';
        },
        pruneCovers: (_) async {},
      );
      await service.scheduleAll(force: true);
      expect(feeds, [AccountType.simkl]);
      expect(backend.scheduled.first.title, 'Reacher · S2E6', reason: 'in time order with the anime');
      expect(backend.scheduled.map((n) => n.payload), contains('simkl:tv:10'));
      expect(backend.looks.first.imagePath, '/covers/${SimklReleasePlanner.coverIdOf(10)}.jpg');
      expect(covers, contains(SimklReleasePlanner.coverIdOf(10)));
    });

    test('a failing Simkl calendar leaves the anime notifications in place', () async {
      final backend = FakeBackend();
      final service = NotificationService(
        backend: backend,
        texts: const FakeTexts(),
        readPrefs: () => NotificationPreferences(subscribedAt: DateTime.utc(2026, 10, 1)),
        clock: () => _now,
        readFeedTracker: () => AccountType.simkl,
        loadCandidates: () async => const [
          AiringCandidate(malId: 1, title: 'One', status: 'watching', airingStatus: 'currently_airing'),
        ],
        loadEpisodes: () async => [
          AiringEpisode(malId: 1, episode: 3, airingAt: DateTime.utc(2026, 11, 25, 15)),
        ],
        loadSimklReleases: (_, __, ___) async => throw Exception('offline'),
        fetchCover: (_, __) async => null,
        pruneCovers: (_) async {},
      );
      await service.scheduleAll(force: true);
      expect(backend.scheduled, isNotEmpty);
      expect(backend.scheduled.every((n) => n.malId == 1), isTrue);
    });
  });

  testWidgets('the search over every catalogue shows one row per catalogue', (tester) async {
    await S.load(const Locale('en'));
    final asked = <String>[];
    final client = SimklClient(
      publicGet: (uri, headers) async {
        final response = await _Http(asked).send(http.Request('GET', uri));
        return http.Response.fromStream(response);
      },
      clientId: () => 'cid',
      appVersion: () async => '1.0.0',
    );
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: SimklSearchAllPage(
        service: SimklDiscoverService(client: client, signedIn: () => false),
        initialQuery: 'dune',
      ),
    ));
    await tester.pumpAndSettle();
    expect(asked.toSet(), {'/search/tv', '/search/anime', '/search/movie'});
    expect(find.text('Dune show'), findsOneWidget);
    expect(find.text('Dune movie'), findsOneWidget);
    expect(find.text('No results found'), findsOneWidget, reason: 'no anime matches');
  });
}

/// Answers Simkl's search: one show, no anime, one movie.
class _Http extends http.BaseClient {
  _Http(this.asked);
  final List<String> asked;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    asked.add(path);
    final body = switch (path) {
      '/search/tv' => [
          {'title': 'Dune show', 'ids': {'simkl_id': 1}},
        ],
      '/search/movie' => [
          {'title': 'Dune movie', 'ids': {'simkl_id': 2}},
        ],
      _ => [],
    };
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), 200,
        headers: {'content-type': 'application/json'});
  }
}
