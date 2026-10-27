import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_api/client/http_connect.dart';
import 'package:mwl_api/handlers/handler_core.dart';
import 'package:mwl_commons/mwl_commons.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

import '../../helpers/html_fixtures.dart';

/// MAL's stats page (`/anime/<id>/x/stats`) gives the score distribution
/// and the status counts, so Score Stats works without Jikan (issue #134).
/// `anime_stats.html` is a trimmed copy of Cowboy Bebop's real page,
/// fetched on 2026-10-27.
void main() {
  ContentStatsHtml? parse(String html) =>
      PageParsers.parseContentStats(htmlFixture(html));

  ContentStatsHtml animeFixture() => parse(
      File('mwl-api/test/fixtures/anime_stats.html').readAsStringSync())!;

  group('stats page parser', () {
    test('anime: votes and percentage for every score, highest first', () {
      final stats = animeFixture();
      expect(stats.scores.map((e) => e.score), [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
      expect(stats.scores.first.votes, 373391);
      expect(stats.scores.first.percentage, 34.6);
      expect(stats.scores.last.score, 1);
      expect(stats.scores.last.votes, 2499);
      expect(stats.scores.last.percentage, 0.2);
      expect(stats.totalVotes, 1079813);
    });

    test('anime: status counts with thousands separators', () {
      final s = animeFixture().statuses;
      expect(s.watching, 192455);
      expect(s.completed, 1216781);
      expect(s.onHold, 118262);
      expect(s.dropped, 50571);
      expect(s.planToWatch, 516017);
      expect(s.total, 2094086);
    });

    test('manga wording fills watching and plan_to_watch', () {
      final stats = parse('''
<div class="spaceit_pad"><span class="dark_text">Status:</span> Finished</div>
<h2 id="summary_stats">Summary Stats</h2>
<div class="spaceit_pad"><span class="dark_text">Reading:</span> 1,200</div>
<div class="spaceit_pad"><span class="dark_text">Completed:</span> 300</div>
<div class="spaceit_pad"><span class="dark_text">On-Hold:</span> 40</div>
<div class="spaceit_pad"><span class="dark_text">Dropped:</span> 5</div>
<div class="spaceit_pad"><span class="dark_text">Plan to Read:</span> 6,000</div>
<div class="spaceit_pad"><span class="dark_text">Total:</span> 7,545</div>
<br><h2 id="score_stats">Score Stats</h2>
<table class="score-stats"><tr><td class="score-label score-9">9</td>
<td><span>&nbsp;100.0% <small>(1,234 votes)</small></span></td></tr></table>
''')!;
      expect(stats.statuses.watching, 1200);
      expect(stats.statuses.planToWatch, 6000);
      expect(stats.statuses.total, 7545);
      expect(stats.scores.single.score, 9);
      expect(stats.scores.single.votes, 1234);
      expect(stats.scores.single.percentage, 100.0);
    });

    test('rows outside the Summary Stats block are ignored', () {
      final stats = parse('''
<div class="spaceit_pad"><span class="dark_text">Completed:</span> 999</div>
<h2 id="summary_stats">Summary Stats</h2>
<div class="spaceit_pad"><span class="dark_text">Completed:</span> 3</div>
<h2>Other</h2>
<div class="spaceit_pad"><span class="dark_text">Total:</span> 999</div>
''')!;
      expect(stats.statuses.completed, 3);
      expect(stats.statuses.total, 3, reason: 'no Total row: sum of counts');
    });

    test('a title nobody scored yet has statuses but no scores', () {
      final stats = parse('''
<h2 id="summary_stats">Summary Stats</h2>
<div class="spaceit_pad"><span class="dark_text">Plan to Watch:</span> 12</div>
<div class="spaceit_pad"><span class="dark_text">Total:</span> 12</div>
''')!;
      expect(stats.scores, isEmpty);
      expect(stats.statuses.planToWatch, 12);
    });

    test('a page that is not a stats page gives null', () {
      expect(parse('<html><body><p>Not found</p></body></html>'), isNull);
    });

    test('wire format and JSON round trip', () {
      final json = HttpConnect.toJsonReady(animeFixture())
          as Map<String, dynamic>;
      expect(json['scores'].first,
          {'score': 10, 'votes': 373391, 'percentage': 34.6});
      expect((json['statuses'] as Map).keys, [
        'watching',
        'completed',
        'on_hold',
        'dropped',
        'plan_to_watch',
        'total',
      ]);
      final back = ContentStatsHtml.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(back.scores, hasLength(10));
      expect(back.statuses.onHold, 118262);
    });
  });

  group('content/stats route', () {
    final core = HandlerCore();

    Future<(int, Map<String, dynamic>)> get(String pathAndQuery) async {
      final response =
          await core.respond(Uri.parse('http://localhost/$pathAndQuery'));
      final body = jsonDecode(await response.readAsString());
      return (response.statusCode, body as Map<String, dynamic>);
    }

    for (final (query, param) in [
      ('', 'id'),
      ('?id=abc', 'id'),
      ('?id=0', 'id'),
      ('?id=1&category=novel', 'category'),
    ]) {
      test('content/stats$query answers 400', () async {
        final (status, body) = await get('content/stats$query');
        expect(status, 400);
        expect(body['error'], true);
        expect(body['message'], contains(param));
      });
    }
  });

  group('MwlApi.getContentStats', () {
    test('parses the data field', () async {
      final json = HttpConnect.toJsonReady(animeFixture());
      final stats = await MwlApi.fetchContentStats(() async => json);
      expect(stats?.scores, hasLength(10));
      expect(stats?.statuses.total, 2094086);
    });

    test('no data (failed page or refused request) gives null', () async {
      expect(await MwlApi.fetchContentStats(() async => null), isNull);
    });

    test('an error gives null instead of throwing', () async {
      expect(
          await MwlApi.fetchContentStats(
              () async => throw const SocketException('unreachable')),
          isNull);
    });

    test('gives up with null after the timeout', () async {
      final never = Completer<dynamic>();
      final stats = await MwlApi.fetchContentStats(() => never.future,
          timeout: const Duration(milliseconds: 50));
      expect(stats, isNull);
    });

    test('the default timeout is at most 15 s', () {
      expect(MwlApi.contentStatsTimeout,
          lessThanOrEqualTo(const Duration(seconds: 15)));
    });
  });
}
