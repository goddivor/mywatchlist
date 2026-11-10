import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  testWidgets('renders nothing without any entry', (tester) async {
    await pumpInApp(tester, const AppBarMenu());
    expect(find.byType(PopupMenuButton<int>), findsNothing);
  });

  testWidgets('lists only the slots given and calls their callback', (tester) async {
    final taps = <String>[];
    await pumpInApp(
      tester,
      AppBarMenu(
        onShare: () => taps.add('share'),
        onBookmark: () => taps.add('bookmark'),
        bookmarked: true,
        items: [AppBarMenuItem(label: 'Extra', icon: Icons.info, onTap: () => taps.add('extra'))],
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Open in Browser'), findsNothing);
    expect(find.text('Remove bookmark'), findsOneWidget);
    expect(find.text('Extra'), findsOneWidget);

    await tester.tap(find.text('Remove bookmark'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra'));
    await tester.pumpAndSettle();
    expect(taps, ['bookmark', 'extra']);
  });
}
