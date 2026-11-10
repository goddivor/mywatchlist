import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/charts/ranked_bar_list.dart';
import 'package:mywatchlist/widgets/charts/score_stack_chart.dart';
import 'package:mywatchlist/widgets/charts/status_bar_chart.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

import '../../helpers/pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => LanguageBloc.apply('en'));

  test('status colours follow the preference, the theme marker keeps the default', () {
    final colors = statusChartColors([0xFF112233, -1, -1, -1, -1]);
    expect(colors.first, const Color(0xFF112233));
    expect(colors[1], defaultStatusChartColors[1]);
    expect(colors, hasLength(5));
    expect(statusChartColors(const []), defaultStatusChartColors);
  });

  testWidgets('status chart draws one bar per status', (tester) async {
    await pumpInApp(
      tester,
      StatusBarChart(
        values: const [2, 30, 1, 3, 9],
        labels: const ['Watching', 'Completed', 'On hold', 'Dropped', 'Plan'],
        colors: defaultStatusChartColors,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(StatusBarChart), findsOneWidget);
  });

  testWidgets('score chart handles an empty list', (tester) async {
    await pumpInApp(
      tester,
      ScoreStackChart(
        scoreByStatus: {for (var i = 1; i <= 10; i++) i: List.filled(5, 0)},
        labels: const ['a', 'b', 'c', 'd', 'e'],
        colors: defaultStatusChartColors,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranked list collapses and expands', (tester) async {
    final items = [
      for (var i = 0; i < 12; i++)
        RankedBarItem(label: 'Item $i', count: 12 - i, mean: 7.5),
    ];
    await pumpInApp(
      tester,
      SingleChildScrollView(child: RankedBarList(items: items, color: Colors.teal)),
    );
    expect(find.text('Item 7'), findsOneWidget);
    expect(find.text('Item 8'), findsNothing);

    await tester.tap(find.text(S.current.Prof_Dist_Show_All(12)));
    await tester.pump();
    expect(find.text('Item 11'), findsOneWidget);
    expect(find.text(S.current.Prof_Dist_Show_Less), findsOneWidget);
  });

  testWidgets('message state shows its action', (tester) async {
    var taps = 0;
    await pumpInApp(
      tester,
      ProfileMessage(
        icon: Icons.person,
        title: 'Title',
        body: 'Body',
        actionLabel: 'Go',
        onAction: () => taps++,
      ),
    );
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  test('every English profile key has a French translation, and the reverse', () {
    Map<String, dynamic> read(String locale) => jsonDecode(
          File('lib/l10n/units/user-profile-mal/intl_$locale.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
    final en = read('en');
    final fr = read('fr_FR');
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      expect(fr.containsKey(key), isTrue, reason: 'missing in fr_FR: $key');
      if (key.startsWith('Prof_')) {
        expect(fr[key], isNot(contains('—')), reason: 'em dash in $key');
      }
    }
  });
}
