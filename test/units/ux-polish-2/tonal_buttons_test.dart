import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final black in [false, true]) {
      if (black && brightness == Brightness.light) continue;
      testWidgets('FilledButton.tonal keeps secondaryContainer ($brightness, black $black)',
          (tester) async {
        final theme = AppThemes.generateThemeData(
          seedColor: AppThemes.defaultSeedColor,
          fontFamily: 'Roboto',
          brightness: brightness,
          isBlack: black,
        );
        final scheme = theme.colorScheme;
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Column(children: [
            FilledButton(onPressed: () {}, child: const Text('plain')),
            FilledButton.tonal(onPressed: () {}, child: const Text('tonal')),
          ]),
        ));
        Material materialOf(String label) => tester.widget<Material>(find.descendant(
            of: find.widgetWithText(FilledButton, label), matching: find.byType(Material)));
        expect(materialOf('tonal').color, scheme.secondaryContainer);
        expect(materialOf('plain').color, scheme.primary);
      });
    }
  }
}
