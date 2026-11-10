import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/user_profile/user_insights.dart';

InsightRow row(
  int id, {
  String status = 'completed',
  int score = 8,
  double? mean = 6.5,
  List<String> genres = const ['Action'],
  List<String> studios = const [],
  String? media = 'tv',
}) =>
    InsightRow(
      id: id,
      title: 'Show $id',
      pictureUrl: null,
      status: status,
      score: score,
      mean: mean,
      mediaType: media,
      source: 'manga',
      genres: [for (final g in genres) InsightLabel(1, g)],
      studios: [for (final s in studios) InsightLabel(2, s)],
      authors: const [],
    );

void main() {
  group('UserInsights.fromRows', () {
    test('counts scored entries per score and status, unrated apart', () {
      final insights = UserInsights.fromRows([
        row(1, score: 8),
        row(2, score: 8, status: 'dropped'),
        row(3, score: 0),
        row(4, score: 10, status: 'watching'),
      ], 'anime');

      expect(insights.unrated, 1);
      expect(insights.scoreByStatus.keys, [for (var i = 1; i <= 10; i++) i]);
      // statuses: watching, completed, on_hold, dropped, plan_to_watch
      expect(insights.scoreByStatus[8], [0, 1, 0, 1, 0]);
      expect(insights.scoreByStatus[10], [1, 0, 0, 0, 0]);
    });

    test('a duplicated entry is counted once and does not stop the loop', () {
      final insights = UserInsights.fromRows([
        row(1, score: 7),
        row(1, score: 7),
        row(2, score: 7),
      ], 'anime');
      expect(insights.scoreByStatus[7]!.fold<int>(0, (a, b) => a + b), 2);
    });

    test('distribution items merge statuses and sort by count then mean', () {
      final insights = UserInsights.fromRows([
        row(1, score: 9, genres: ['Action', 'Drama']),
        row(2, score: 7, genres: ['Action']),
        row(3, score: 10, status: 'dropped', genres: ['Drama']),
        row(4, score: 8, genres: ['Action']),
      ], 'anime');

      final all = insights.items(InsightKind.genre);
      expect(all.map((e) => e.name), ['Action', 'Drama']);
      expect(all.first.count, 3);
      expect(all.first.mean, 8);

      final dropped = insights.items(InsightKind.genre, status: 'dropped');
      expect(dropped.map((e) => e.name), ['Drama']);

      final byMean = insights.items(InsightKind.genre, byMean: true);
      expect(byMean.first.name, 'Drama');
    });

    test('above-the-community list needs a low mean, a high score and a finished status', () {
      final insights = UserInsights.fromRows([
        row(1, score: 10, mean: 6.0),
        row(2, score: 10, mean: 7.5),
        row(3, score: 8, mean: 6.0, status: 'dropped'),
        row(4, score: 9, mean: 6.9, status: 'watching'),
      ], 'anime');
      expect(insights.aboveMean.map((e) => e.id), [1, 4]);
      expect(insights.aboveMean.first.gap, closeTo(4, 1e-9));
    });

    test('manga uses reading / plan_to_read statuses', () {
      expect(UserInsights.statusesFor('manga').first, 'reading');
      final insights = UserInsights.fromRows([row(1, status: 'reading')], 'manga');
      expect(insights.scoreByStatus[8], [1, 0, 0, 0, 0]);
    });
  });

  test('parsePage reads nodes, labels, authors and the next page', () {
    final body = jsonEncode({
      'data': [
        {
          'node': {
            'id': 7,
            'title': 'Berserk',
            'main_picture': {'medium': 'https://img/m.jpg'},
            'mean': 9.3,
            'media_type': 'manga',
            'genres': [
              {'id': 1, 'name': 'Action'}
            ],
            'authors': [
              {
                'node': {'id': 99, 'first_name': 'Kentaro', 'last_name': 'Miura'},
                'role': 'Story & Art'
              }
            ],
          },
          'list_status': {'status': 'reading', 'score': 10},
        },
        {'node': {'id': 8}},
      ],
      'paging': {'next': 'https://api/next'},
    });

    final page = UserInsightsLoader.parsePage(body);
    expect(page.next, 'https://api/next');
    expect(page.rows, hasLength(1));
    final r = page.rows.single;
    expect(r.title, 'Berserk');
    expect(r.pictureUrl, 'https://img/m.jpg');
    expect(r.status, 'reading');
    expect(r.score, 10);
    expect(r.genres.single.name, 'Action');
    expect(r.authors.single.name, 'Kentaro Miura');
    expect(r.authors.single.id, 99);
  });
}
