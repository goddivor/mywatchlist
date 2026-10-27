import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/widgets/common/adaptive_layout.dart';

void main() {
  test('size classes follow the Material 3 breakpoints', () {
    expect(ScreenSize.fromWidth(390), ScreenSize.compact);
    expect(ScreenSize.fromWidth(600), ScreenSize.medium);
    expect(ScreenSize.fromWidth(839), ScreenSize.medium);
    expect(ScreenSize.fromWidth(840), ScreenSize.expanded);
    expect(ScreenSize.fromWidth(1600), ScreenSize.large);
    expect(ScreenSize.compact.isTablet, isFalse);
    expect(ScreenSize.medium.isTablet, isTrue);
  });

  Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
  }

  final layout = AdaptiveLayout(
    compact: (_) => const Text('phone'),
    expanded: (_) => const Text('two panes'),
  );

  testWidgets('phone width builds the compact layout', (tester) async {
    await pumpAt(tester, 400, layout);
    expect(find.text('phone'), findsOneWidget);
  });

  testWidgets('a missing size falls back to the next smaller one', (tester) async {
    await pumpAt(tester, 700, layout);
    expect(find.text('phone'), findsOneWidget);
    await pumpAt(tester, 1300, layout);
    expect(find.text('two panes'), findsOneWidget);
  });

  testWidgets('adaptiveValue picks per size', (tester) async {
    late int columns;
    await pumpAt(
      tester,
      900,
      Builder(builder: (context) {
        columns = adaptiveValue(context, compact: 3, medium: 4, expanded: 6);
        return const SizedBox();
      }),
    );
    expect(columns, 6);
  });
}
