import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_progress.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Fake signed-in Simkl: answers by path and keeps every request with its JSON body. Never
/// touches a real account.
class _Account {
  final Map<String, Object? Function(Uri uri)> routes;
  final List<({String path, Object? body})> calls = [];
  _Account(this.routes);

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) async => send(_Http(this), 'token'),
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
  );

  List<({String path, Object? body})> writes() => [
        for (final c in calls)
          if (c.body != null) c,
      ];
}

class _Http extends http.BaseClient {
  _Http(this.account);
  final _Account account;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final text = request is http.Request ? request.body : '';
    account.calls.add((path: request.url.path, body: text.isEmpty ? null : jsonDecode(text)));
    final route = account.routes[request.url.path];
    final bytes = utf8.encode(jsonEncode(route == null ? {} : route(request.url)));
    return http.StreamedResponse(Stream.value(bytes), 200, headers: {'content-type': 'application/json'});
  }
}

Map<String, dynamic> _show(int id, String status, {int watched = 0, int total = 10}) => {
      'status': status,
      'watched_episodes_count': watched,
      'total_episodes_count': total,
      'not_aired_episodes_count': 0,
      'show': {
        'title': 'Show $id',
        'poster': '11/abc',
        'year': 2008,
        'ids': {'simkl': id, 'imdb': 'tt$id'},
      },
    };

Map<String, dynamic> _movie(int id, String status) => {
      'status': status,
      'user_rating': 8,
      'movie': {
        'title': 'Movie $id',
        'year': 2010,
        'ids': {'simkl': id},
      },
    };

/// Two seasons of 2 episodes and a special, out of order.
const _episodes = [
  SimklEpisode(title: 'b', season: 2, number: 1),
  SimklEpisode(title: 'sp', season: 0, number: 1, isSpecial: true),
  SimklEpisode(title: 'a', season: 1, number: 1),
  SimklEpisode(title: 'a2', season: 1, number: 2),
  SimklEpisode(title: 'b2', season: 2, number: 2),
];

void main() {
  setUpAll(() async {
    await S.load(const Locale('en'));
  });

  test('every kind has its own API path, sync key and site folder', () {
    expect([for (final k in SimklKind.values) k.api], ['tv', 'anime', 'movies']);
    expect([for (final k in SimklKind.values) k.syncKey], ['shows', 'anime', 'movies']);
    expect([for (final k in SimklKind.values) k.activitiesKey], ['tv_shows', 'anime', 'movies']);
    expect(SimklKind.movie.pageUrl(472214, 'inception'), 'https://simkl.com/movies/472214/inception');
    expect(SimklKind.ofCategory('tv'), SimklKind.tv);
    expect(SimklKind.ofType('show'), SimklKind.tv);
    expect(SimklKind.ofType('movie'), SimklKind.movie);
    expect(SimklKind.ofType('special'), isNull);
  });

  test('show and movie lists are read from their own keys', () {
    final shows = parseSimklList({
      'shows': [_show(1, 'watching', watched: 3)],
      'anime': [_show(9, 'watching')],
    }, SimklKind.tv);
    expect(shows.single.id, 1);
    expect(shows.single.category, 'tv');
    expect(shows.single.isAnime, isTrue, reason: 'watched in episodes, not read');
    expect((shows.single.progress, shows.single.total), (3, 10));

    final movies = parseSimklList({
      'movies': [_movie(5, 'completed'), _movie(6, 'plantowatch')],
    }, SimklKind.movie);
    expect([for (final m in movies) m.category], ['movie', 'movie']);
    expect([for (final m in movies) (m.progress, m.total)], [(1, 1), (0, 1)]);
    expect(movies.first.score, 8);
    expect(movies.first.mediaType, 'movie');
  });

  test('a movie record keeps its release, director and box office', () {
    final t = SimklTitle.fromJson({
      'title': 'Inception',
      'type': 'movie',
      'released': '2010-07-15',
      'director': 'Christopher Nolan',
      'budget': 160000000,
      'revenue': 839030630,
      'ids': {'simkl': 472214, 'slug': 'inception'},
    })!;
    expect(t.kind, SimklKind.movie);
    expect(t.director, 'Christopher Nolan');
    expect((t.budget, t.revenue), (160000000, 839030630));
    expect(t.pageUrl, 'https://simkl.com/movies/472214/inception');
    final links = simklExternalLinks({'tmdb': '27205'}, kind: SimklKind.movie);
    expect(links.single.url, 'https://www.themoviedb.org/movie/27205');
  });

  group('writes go to the right catalogue', () {
    late _Account account;

    setUp(() {
      account = _Account({
        '/sync/activities': (_) => {
              'tv_shows': {'all': 't1', 'removed_from_list': 'r'},
              'movies': {'all': 'm1', 'removed_from_list': 'r'},
            },
        '/sync/all-items/shows': (_) => {
              'shows': [_show(1, 'watching', watched: 1, total: 4)],
            },
        '/sync/all-items/movies': (_) => {
              'movies': [_movie(5, 'plantowatch')],
            },
      });
    });

    test('a show steps through its seasons, specials left out', () async {
      final service = SimklListService(
        kind: SimklKind.tv,
        client: account.client,
        episodes: (_) async => _episodes,
      );
      final entry = (await service.entries()).single;
      expect(account.calls.map((c) => c.path), contains('/sync/all-items/shows'));

      // Watched 1 (S1E1): two more are S1E2 and S2E1.
      final saved = await service.setProgress(entry, 3);
      final write = account.writes().last;
      expect(write.path, '/sync/history');
      expect(write.body, {
        'shows': [
          {
            'ids': {'simkl': 1},
            'seasons': [
              {
                'number': 1,
                'episodes': [
                  {'number': 2},
                ],
              },
              {
                'number': 2,
                'episodes': [
                  {'number': 1},
                ],
              },
            ],
          },
        ],
      });
      expect(saved.progress, 3);

      await service.save(saved, status: ListEntryStatus.onHold);
      expect(account.writes().last.path, '/sync/add-to-list');
      expect((account.writes().last.body as Map).keys, ['shows']);
    });

    test('a movie is planned, completed or dropped and has no episodes', () async {
      final service = SimklListService(kind: SimklKind.movie, client: account.client);
      final entry = (await service.entries()).single;
      expect(account.calls.map((c) => c.path), contains('/sync/all-items/movies'));

      // Simkl has no "watching" for a movie: it is recorded as seen.
      final saved = await service.save(entry, status: ListEntryStatus.current);
      expect(account.writes().last.body, {
        'movies': [
          {
            'ids': {'simkl': 5},
            'to': 'completed',
          },
        ],
      });
      expect((saved.status, saved.progress), (ListEntryStatus.completed, 1));

      await service.remove(saved);
      expect(account.writes().last.path, '/sync/remove-from-list');
      expect((account.writes().last.body as Map).keys, ['movies']);
    });

    test('the list adapter reads each category from its own list', () async {
      final shows = SimklListService(kind: SimklKind.tv, client: account.client);
      final movies = SimklListService(kind: SimklKind.movie, client: account.client);
      final adapter = SimklUserListAdapter(
        serviceOf: (k) => k == SimklKind.movie ? movies : shows,
        owner: () => 'me',
      );
      final tv = await adapter.fetch(category: 'tv', status: null, offset: 0, limit: 50);
      final film = await adapter.fetch(category: 'movie', status: null, offset: 0, limit: 50);
      expect(tv.entries.single.title, 'Show 1');
      expect(film.entries.single.title, 'Movie 5');
      expect(adapter.canStep(film.entries.single), isFalse, reason: 'a movie has no +1');
      expect(adapter.canStep(tv.entries.single), isTrue);
    });
  });

  test("a show's next episode comes from next_to_watch and its overview loses the HTML", () {
    final next = SimklNextToWatch.parseAll({
      'shows': [
        {
          ..._show(1, 'watching', watched: 16),
          'next_to_watch': 'S02E09',
          'next_to_watch_info': {'title': 'High Treason', 'episode': 17},
        },
      ],
    }, SimklKind.tv)[1]!;
    expect((next.season, next.episode, next.title), (2, 9, 'High Treason'));
    final t = SimklTitle.fromJson({
      'title': 'BMF',
      'overview': 'Late 1980s. <br><br>The journey of two brothers.',
      'ids': {'simkl': 1},
    }, kind: SimklKind.tv)!;
    expect(t.overview, 'Late 1980s.\n\nThe journey of two brothers.');
  });

  test('the next episode of a show is named by season', () {
    final next = simklNextUp(
      title: const SimklTitle(simklId: 1, title: 'Show', kind: SimklKind.tv),
      episodes: _episodes,
      entry: const ListEntryView(id: 1, category: 'tv', title: 'Show', status: ListEntryStatus.current, progress: 2, total: 4),
      now: DateTime.utc(2030),
    )!;
    expect(next.kind, SimklNextKind.watchNext);
    expect(next.episode, 3, reason: 'its place in the watch order');
    expect(next.code, 'S2E1');
  });
}
