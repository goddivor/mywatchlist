import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/user_profile/sections/stats_section.dart';
import 'package:mywatchlist/screens/user_profile/user_insights.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/charts/distribution_radar.dart';

InsightRow _row(int id, String status, int score, List<String> genres) => InsightRow(
      id: id,
      title: 'T$id',
      pictureUrl: null,
      status: status,
      score: score,
      mean: 7.0,
      mediaType: 'tv',
      source: 'manga',
      genres: [for (final g in genres) InsightLabel(0, g)],
      studios: const [],
      authors: const [],
    );

final _insights = UserInsights.fromRows([
  _row(1, 'completed', 9, ['Action', 'Drama', 'Comedy']),
  _row(2, 'completed', 7, ['Action', 'Comedy']),
  _row(3, 'watching', 8, ['Action', 'Romance']),
  _row(4, 'dropped', 4, ['Drama']),
], 'anime');

const _colors = [Colors.green, Colors.blue, Colors.yellow, Colors.red, Colors.grey];

BreakdownRadarData? _data({String? status, bool byMean = false}) => breakdownRadarData(
      insights: _insights,
      kind: InsightKind.genre,
      status: status,
      byMean: byMean,
      statusKeys: UserInsights.statusesFor('anime'),
      statusColors: _colors,
      fallbackColor: Colors.purple,
    );

void main() {
  test('the default view stays the list, the chart choice is saved', () {
    expect(const GeneralPreferences().statsBreakdownChart, isFalse);
    final chart = const GeneralPreferences().copyWith(statsBreakdownChart: true);
    expect(GeneralPreferences.fromJson(chart.toJson()).statsBreakdownChart, isTrue);
    expect(GeneralPreferences.fromJson(const {}).statsBreakdownChart, isFalse);
  });

  test('all statuses: one shape per status that has any of the top genres', () {
    final data = _data()!;
    expect(data.axes.take(1), ['Action'], reason: 'the most frequent genre first');
    expect(data.axes.toSet(), {'Action', 'Drama', 'Comedy', 'Romance'});
    final keys = UserInsights.statusesFor('anime');
    expect([for (final i in data.statuses) keys[i]], ['watching', 'completed', 'dropped']);
    for (final s in data.series) {
      expect(s.values, hasLength(data.axes.length));
    }
    // Completed: Action twice.
    final completed = data.series[data.statuses.indexOf(keys.indexOf('completed'))];
    expect(completed.values[data.axes.indexOf('Action')], 2);
    expect(completed.color, _colors[keys.indexOf('completed')]);
  });

  test('one status: a single shape; the mean sort draws mean scores', () {
    final data = _data(status: 'completed', byMean: true)!;
    expect(data.series, hasLength(1));
    expect(data.series.single.values[data.axes.indexOf('Action')], 8.0, reason: '(9 + 7) / 2');
  });

  test('fewer than 3 items: no radar', () {
    expect(_data(status: 'dropped'), isNull, reason: 'dropped has only Drama');
  });

  testWidgets('the radar draws with its axes', (tester) async {
    final data = _data()!;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 360, child: DistributionRadar(axes: data.axes, series: data.series)),
      ),
    ));
    expect(find.byType(DistributionRadar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
