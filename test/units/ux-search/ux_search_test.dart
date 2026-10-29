import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_sections.dart' show RankingsRow, SeasonalPicker;
import 'package:mywatchlist/screens/search/search_filter_panel.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_history.dart';
import 'package:mywatchlist/screens/search/search_home_view.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

Future<void> _pumpPanel(WidgetTester tester, SearchFilters filters) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SearchFilterPanel(
        category: SearchCategory.anime,
        filters: filters,
        display: SearchDisplay.defaults,
        onApply: (_) {},
        onClose: () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text(S.current.Srch_Tab_Filter));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  testWidgets('search home has Explore\'s season picker and picture rows, no tip text', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpInApp(
      tester,
      SearchHomeView(
        history: SearchHistory.instance,
        suggestions: ValueNotifier(SuggestionState.idle),
        onQuery: (_) {},
      ),
    );
    await tester.pump();
    expect(find.byType(SeasonalPicker), findsOneWidget);
    expect(find.byType(RankingsRow), findsNWidgets(2));
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.text(S.current.Srch_Start_Title), findsNothing);
    expect(find.text(S.current.Srch_Special_Tip), findsNothing);
  });

  testWidgets('Direction appears only once an order is picked', (tester) async {
    await _pumpPanel(tester, SearchFilters.empty);
    expect(find.text(S.current.Srch_F_OrderBy), findsOneWidget);
    expect(find.text(S.current.Srch_F_Sort), findsNothing);
    expect(find.text(S.current.Srch_Needs_Order), findsNothing);
  });

  testWidgets('Direction is there with an order', (tester) async {
    await _pumpPanel(tester, SearchFilters.empty.set(FilterKey.orderBy, 'score'));
    expect(find.text(S.current.Srch_F_Sort), findsOneWidget);
  });

  testWidgets('a searchable picker lists the current value first and prints no count',
      (tester) async {
    final many = [for (var i = 0; i < 40; i++) SelectOption(i, 'Genre $i')];
    await pumpInApp(
      tester,
      SizedBox(height: 600, child: SearchableSelect<int>(options: many, selected: 30, onSelected: (_) {})),
    );
    expect(find.textContaining(RegExp(r'^\d+ options?$')), findsNothing);
    final first = tester.widgetList<SelectOptionTile<int>>(find.byType(SelectOptionTile<int>)).first;
    expect(first.option.value, 30);
    expect(first.checked, isTrue);

    // Typing a search still finds it, without reordering by selection.
    await tester.enterText(find.byType(TextField), 'genre 3');
    await tester.pump();
    final values = tester
        .widgetList<SelectOptionTile<int>>(find.byType(SelectOptionTile<int>))
        .map((t) => t.option.value)
        .toList();
    expect(values.first, 3);
    expect(values, contains(30));
  });

  testWidgets('a result row shows #rank, score with members, type and length, and a pencil',
      (tester) async {
    final item = Anime(
      id: 52991,
      title: 'Sousou no Frieren',
      imageUrl: '',
      score: 9.3,
      members: 1540000,
      numVolumes: 12,
      mediaType: 'manga',
    );
    await pumpInApp(
      tester,
      SizedBox(width: 400, child: MediaTile(item: item, category: SearchCategory.manga, index: 2)),
    );
    expect(find.text('#3'), findsOneWidget);
    expect(find.textContaining('9.3'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    final title = tester.widget<Text>(find.text('Sousou no Frieren'));
    expect(title.style?.fontWeight, isNot(FontWeight.w600));
  });
}
