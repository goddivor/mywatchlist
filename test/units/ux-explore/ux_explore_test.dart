import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart' show SeasonType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_sections.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/explore/random_picker.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart' show ShadowButton;

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  testWidgets('a section header opens its list with an arrow, not a "View All" text',
      (tester) async {
    var opened = 0;
    await pumpInApp(
      tester,
      SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExploreSectionHeader(title: 'Reviews', onViewAll: () => opened++),
            const ExploreSectionHeader(title: 'Genres'),
          ],
        ),
      ),
    );
    expect(find.text(S.current.View_All), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_forward_outlined));
    expect(opened, 1);

    // Regular weight, like DailyAL's titles.
    final title = tester.widget<Text>(find.text('Reviews'));
    expect(title.style?.fontWeight, isNot(FontWeight.w700));
    // Both headers are as tall, with or without the arrow.
    expect(tester.getSize(find.byType(ExploreSectionHeader).first).height,
        tester.getSize(find.byType(ExploreSectionHeader).last).height);
  });

  testWidgets('random buttons are raised surface buttons with coloured icons', (tester) async {
    await pumpInApp(tester, const SizedBox(width: 600, child: RandomPickerRow(isAnime: true)));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ShadowButton), findsNWidgets(3));
    for (final label in [S.current.Random, S.current.Watching, S.current.Plan_To_Watch]) {
      expect(find.text(label), findsOneWidget);
    }
    final colours = tester
        .widgetList<Icon>(find.descendant(
            of: find.byType(RandomPickerRow), matching: find.byType(Icon)))
        .map((i) => i.color)
        .toSet();
    // Three different hues, none left to the button's own foreground.
    expect(colours.length, 3);
    expect(colours, isNot(contains(null)));
  });

  testWidgets('genre group cards show their name only', (tester) async {
    await pumpInApp(tester, const SizedBox(width: 400, child: GenresRow(category: 'anime')));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^\d+ genres?$')), findsNothing);
    expect(find.text(S.current.Genres), findsOneWidget);
  });

  testWidgets('the seasons row centres the season without scrolling the page', (tester) async {
    final page = ScrollController(initialScrollOffset: 260);
    addTearDown(page.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // A narrow phone, so the four seasons do not all fit.
        body: Center(
          child: SizedBox(
            width: 300,
            child: CustomScrollView(
              controller: page,
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 400)),
                SliverToBoxAdapter(child: SeasonalPicker()),
                SliverToBoxAdapter(child: SizedBox(height: 3000)),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(page.offset, 260);

    // The row itself is scrolled so the current season sits as near its middle as it can.
    final row = tester.state<ScrollableState>(find.descendant(
        of: find.byKey(const ValueKey('seasonal-seasons')), matching: find.byType(Scrollable)));
    final season = SeasonKey.current().season;
    final label = find.text(seasonLabel(season));
    final rowBox = tester.getRect(find.byKey(const ValueKey('seasonal-seasons')));
    final labelBox = tester.getRect(label);
    final position = row.position;
    final centred = (labelBox.center.dx - rowBox.center.dx).abs() < 1;
    final atEdge = position.pixels == position.minScrollExtent ||
        position.pixels == position.maxScrollExtent;
    expect(centred || atEdge, isTrue);

    // Picking another season moves the row only.
    final other = SeasonType.values.firstWhere((t) {
      if (t == season) return false;
      final r = tester.getRect(find.text(seasonLabel(t)));
      return r.left >= rowBox.left && r.right <= rowBox.right;
    });
    await tester.tap(find.text(seasonLabel(other)));
    await tester.pumpAndSettle();
    expect(page.offset, 260);
    // The tap selected it: it is now the raised item of the row.
    expect(
        find.ancestor(of: find.text(seasonLabel(other)), matching: find.byType(ShadowButton)),
        findsOneWidget);
  });
}
