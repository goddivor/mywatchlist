import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_screen.dart' show DetailToolbarBackdrop;

Widget _bar(double current, {double max = 400}) => MaterialApp(
      theme: ThemeData(colorScheme: const ColorScheme.dark(surface: Colors.black)),
      home: Scaffold(
        body: FlexibleSpaceBar.createSettings(
          currentExtent: current,
          minExtent: 104,
          maxExtent: max,
          child: const Align(alignment: Alignment.topCenter, child: DetailToolbarBackdrop()),
        ),
      ),
    );

void main() {
  test('opacity ramps over the first pixels of scroll (#120)', () {
    expect(DetailToolbarBackdrop.opacityFor(current: 400, max: 400), 0);
    expect(DetailToolbarBackdrop.opacityFor(current: 376, max: 400), 0.5);
    expect(DetailToolbarBackdrop.opacityFor(current: 300, max: 400), 1);
  });

  testWidgets('nothing while expanded, an opaque bar once the header slid under it', (tester) async {
    await tester.pumpWidget(_bar(400));
    expect(find.byType(ColoredBox), findsNothing);

    await tester.pumpWidget(_bar(200));
    final box = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(DetailToolbarBackdrop), matching: find.byType(ColoredBox)));
    expect(box.color, Colors.black);
  });
}
