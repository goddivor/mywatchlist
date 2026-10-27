import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/widgets/common/nav_indicator.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('NavIndicator grows to its width when it becomes active',
      (tester) async {
    Future<void> pumpIndicator(bool active) => pumpInApp(
          tester,
          NavIndicator(isActive: active, color: Colors.blue, width: 24),
        );

    await pumpIndicator(false);
    expect(tester.getSize(find.byType(NavIndicator)).width, 0);

    await pumpIndicator(true);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(NavIndicator)).width, 24);
  });

  testWidgets('NavItemContainer shows its child and forwards taps',
      (tester) async {
    var taps = 0;
    await pumpInApp(
      tester,
      NavItemContainer(
        isSelected: true,
        activeColor: Colors.blue,
        backgroundColor: Colors.white,
        onTap: () => taps++,
        child: const Icon(Icons.home),
      ),
    );

    expect(find.byIcon(Icons.home), findsOneWidget);
    await tester.tap(find.byType(NavItemContainer));
    expect(taps, 1);
  });

  testWidgets('BouncingNavIcon renders its icon in both states',
      (tester) async {
    for (final selected in [false, true]) {
      await pumpInApp(
        tester,
        BouncingNavIcon(
          icon: Icons.search,
          isSelected: selected,
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search), findsOneWidget);
    }
  });
}
