import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/bottomnavbar.dart';
import 'package:mywatchlist/widgets/common/nav_indicator.dart';

import '../helpers/pump_app.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  testWidgets('NavItemContainer shows its child and forwards taps', (tester) async {
    var taps = 0;
    await pumpInApp(
      tester,
      NavItemContainer(
        isSelected: true,
        activeColor: Colors.blue,
        onTap: () => taps++,
        child: const Icon(Icons.home),
      ),
    );

    expect(find.byIcon(Icons.home), findsOneWidget);
    await tester.tap(find.byType(NavItemContainer));
    expect(taps, 1);
  });

  testWidgets('the active tab has a pill and no underline bar', (tester) async {
    final changes = <int>[];
    await pumpInApp(tester, BottomNavBar(startIndex: 0, onChanged: changes.add));
    await tester.pumpAndSettle();

    final pill = BottomNavBar.pillColor(
        Theme.of(tester.element(find.byType(BottomNavBar))).colorScheme);
    List<Color?> pills() => tester
        .widgetList<AnimatedContainer>(find.descendant(
          of: find.byType(NavItemContainer),
          matching: find.byType(AnimatedContainer),
        ))
        .map((c) => (c.decoration as BoxDecoration?)?.color)
        .toList();

    expect(find.byType(NavItemContainer), findsNWidgets(5));
    // Only the active tab is filled; nothing else is drawn under the icons.
    expect(pills().where((c) => c == pill).length, 1);
    expect(pills().first, pill);
    final column = find.descendant(of: find.byType(NavItemContainer), matching: find.byType(Column));
    expect(column, findsNothing);

    await tester.tap(find.byType(NavItemContainer).at(2));
    await tester.pumpAndSettle();
    expect(changes, [2]);
    expect(pills()[2], pill);
    expect(pills().where((c) => c == pill).length, 1);
  });
}
