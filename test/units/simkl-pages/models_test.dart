import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import 'fakes.dart';

void main() {
  group('list parsing', () {
    test('an all-items answer becomes list entries', () {
      final entries = parseSimklAnimeList({
        'anime': [
          simklItem(id: 1, mal: 5114, status: 'completed', rating: 9, watched: 12, total: 12, lastWatched: '2026-10-01T10:00:00Z'),
          simklItem(id: 2, status: 'plantowatch', total: 0),
          simklItem(id: 3, mal: 77, status: 'hold', notAired: 4, watched: 3, total: 12),
          {'show': {'title': 'no ids'}},
          'junk',
        ],
      });
      expect(entries.map((e) => e.id), [1, 2, 3]);
      final done = entries[0];
      expect(done.malId, 5114);
      expect(done.status, ListEntryStatus.completed);
      expect(done.score, 9);
      expect(done.progress, 12);
      expect(done.releaseState, ReleaseState.finished);
      expect(done.updatedAt, DateTime.utc(2026, 10, 1, 10));
      expect(done.imageUrl, 'https://simkl.in/posters/ab/1_m.jpg');
      expect(entries[1].status, ListEntryStatus.planned);
      expect(entries[1].releaseState, ReleaseState.unknown, reason: 'no episode count yet');
      expect(entries[2].status, ListEntryStatus.onHold);
      expect(entries[2].releaseState, ReleaseState.releasing, reason: 'episodes not aired yet');
    });

    test('anything that is not a list gives no entries', () {
      expect(parseSimklAnimeList(null), isEmpty);
      expect(parseSimklAnimeList({'anime': 'x'}), isEmpty);
      expect(parseSimklAnimeList([]), isEmpty);
    });

    test('status words map both ways', () {
      for (final s in ListEntryStatus.values) {
        expect(SimklStatus.parse(SimklStatus.api(s)), s);
      }
      expect(SimklStatus.parse('notinteresting'), ListEntryStatus.dropped);
      expect(SimklStatus.parse('weird'), isNull);
    });
  });

  group('discover parsing', () {
    test('reads ids, rating, year and the air time', () {
      final list = SimklMedia.listFrom([
        {
          'title': 'Trend',
          'poster': 'p/q',
          'release_date': '2025-04-06',
          'ids': {'simkl_id': 10, 'slug': 'trend', 'mal': '5'},
          'ratings': {
            'simkl': {'rating': 0},
            'mal': {'rating': 8.2}
          },
        },
        {
          'title': 'Airing',
          'date': '2026-10-27T15:30:00+0000',
          'episode': {'episode': 4},
          'ids': {'simkl_id': 11},
        },
        {'title': 'no id'},
        {'ids': {'simkl_id': 12}},
        {'title': 'Dup', 'ids': {'simkl_id': 10}},
      ]);
      expect(list.map((m) => m.simklId), [10, 11]);
      expect(list[0].malId, 5);
      expect(list[0].rating, 8.2);
      expect(list[0].year, 2025);
      expect(list[0].posterUrl, 'https://simkl.in/posters/p/q_m.jpg');
      expect(list[1].episode, 4);
      expect(list[1].airDate, DateTime.utc(2026, 10, 27, 15, 30));
    });

    test('a wrapped show and a non-list answer', () {
      expect(SimklMedia.listFrom({'anime': [
        {'show': {'title': 'Wrapped', 'ids': {'simkl': 3}}},
      ]}).single.title, 'Wrapped');
      expect(SimklMedia.listFrom('oops'), isEmpty);
      expect(SimklMedia.listFrom(null), isEmpty);
    });
  });

  test('list stats count statuses, episodes, scores and recent activity', () {
    final list = parseSimklAnimeList({
      'anime': [
        simklItem(id: 1, status: 'completed', rating: 10, watched: 12, lastWatched: '2026-10-02T00:00:00Z'),
        simklItem(id: 2, status: 'completed', rating: 8, watched: 24, lastWatched: '2026-10-03T00:00:00Z'),
        simklItem(id: 3, status: 'watching', watched: 2),
        simklItem(id: 4, status: 'plantowatch'),
      ],
    });
    final stats = SimklListStats.from(list);
    expect(stats.entries, 4);
    expect(stats.byStatus[ListEntryStatus.completed], 2);
    expect(stats.byStatus[ListEntryStatus.dropped], 0);
    expect(stats.episodesWatched, 38);
    expect(stats.scored, 2);
    expect(stats.meanScore, 9);
    expect(stats.scoreByStatus[10], [0, 1, 0, 0, 0]);
    expect(stats.recent.map((e) => e.id), [2, 1], reason: 'latest first, entries without a date left out');
  });
}
