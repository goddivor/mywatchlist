import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType, DisplayType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_filter_panel.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';

SearchPanelResult? _applied;

Future<void> _pump(WidgetTester tester, {String category = SearchCategory.all}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await S.load(const Locale('en'));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SearchFilterPanel(
        category: category,
        filters: SearchFilters.empty,
        display: SearchDisplay.defaults,
        onApply: (r) => _applied = r,
        onClose: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<SearchPanelResult> _apply(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, S.current.Srch_Apply));
  await tester.pump();
  return _applied!;
}

void main() {
  setUp(() => _applied = null);

  testWidgets('categories are a radio list in DailyAL order, no chips', (tester) async {
    await _pump(tester);

    expect(find.byType(ChoiceChip), findsNothing);
    final tiles = tester.widgetList<RadioListTile<String>>(find.byType(RadioListTile<String>)).toList();
    expect(tiles.map((t) => t.value), [
      SearchCategory.all,
      SearchCategory.anime,
      SearchCategory.manga,
      SearchCategory.forum,
      SearchCategory.character,
      SearchCategory.person,
      SearchCategory.user,
      SearchCategory.featured,
      SearchCategory.news,
      SearchCategory.club,
      SearchCategory.interestStack,
    ]);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text(S.current.Srch_Tab_Category), findsOneWidget);
  });

  testWidgets('picking a radio selects the category, adds its tabs and keeps the category tab', (tester) async {
    await _pump(tester);

    await tester.tap(find.text(S.current.Srch_Cat_Anime));
    await tester.pumpAndSettle();

    expect(find.text(S.current.Srch_Tab_Filter), findsOneWidget);
    expect(find.text(S.current.Srch_Tab_Display), findsOneWidget);
    // Still on the category tab, the anime radio now checked.
    final group = tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    expect(group.groupValue, SearchCategory.anime);

    final result = await _apply(tester);
    expect(result.category, SearchCategory.anime);
  });

  testWidgets('display tab uses radios and the DailyAL sub types', (tester) async {
    await _pump(tester, category: SearchCategory.anime);

    await tester.tap(find.text(S.current.Srch_Tab_Display));
    await tester.pumpAndSettle();

    final types = tester.widgetList<RadioListTile<DisplayType>>(find.byType(RadioListTile<DisplayType>));
    expect(types.map((t) => t.value), [DisplayType.grid, DisplayType.list_vert]);
    final gridSubs = tester.widgetList<RadioListTile<DisplaySubType>>(find.byType(RadioListTile<DisplaySubType>));
    expect(gridSubs.map((t) => t.value),
        [DisplaySubType.comfortable, DisplaySubType.compact, DisplaySubType.cover_only_grid]);
    expect(find.byType(Slider), findsNWidgets(2));
    expect(find.byType(SegmentedButton<DisplayType>), findsNothing);

    await tester.tap(find.text(S.current.Srch_Display_List));
    await tester.pumpAndSettle();
    final listSubs = tester.widgetList<RadioListTile<DisplaySubType>>(find.byType(RadioListTile<DisplaySubType>));
    expect(listSubs.map((t) => t.value), [DisplaySubType.comfortable, DisplaySubType.compact, DisplaySubType.spacious]);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text(S.current.Srch_Display_Spacious));
    await tester.pumpAndSettle();
    final result = await _apply(tester);
    expect(result.display.type, DisplayType.list_vert);
    expect(result.display.subType, DisplaySubType.spacious);
  });
}
