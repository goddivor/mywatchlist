import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/widgets/common/bottomnavbar.dart';

/// Index of the tab drawn selected (the one whose icon is scaled up).
int _selectedTab(WidgetTester tester) {
  final scales = tester.widgetList<AnimatedScale>(find.byType(AnimatedScale)).toList();
  return scales.indexWhere((scale) => scale.scale > 1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('follows startIndex when the shell changes tab from code', (tester) async {
    await LanguageBloc.apply('en');
    final index = ValueNotifier<int>(0);
    final taps = <int>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: index,
          builder: (_, value, __) => BottomNavBar(startIndex: value, onChanged: taps.add),
        ),
      ),
    ));
    expect(_selectedTab(tester), 0);

    index.value = 3;
    await tester.pump();
    expect(_selectedTab(tester), 3);

    index.value = 0;
    await tester.pump();
    expect(_selectedTab(tester), 0);
    expect(taps, isEmpty, reason: 'a change from code is not a tap');
  });

  testWidgets('a tap selects the tab and reports it once', (tester) async {
    await LanguageBloc.apply('en');
    final taps = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(bottomNavigationBar: BottomNavBar(onChanged: taps.add)),
    ));

    await tester.tap(find.byTooltip('Explore'));
    await tester.pump();
    expect(taps, [4]);
    expect(_selectedTab(tester), 4);
  });

  testWidgets('tab names are translated', (tester) async {
    await LanguageBloc.apply('fr_FR');
    expect(BottomNavBar.labels(), ['Accueil', 'Forum', 'Ma liste', 'Profil', 'Explorer']);
    await LanguageBloc.apply('en');
  });
}
