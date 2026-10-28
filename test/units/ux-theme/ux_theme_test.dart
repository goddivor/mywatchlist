import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/theme_settings.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ThemeBloc> _loaded() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final bloc = ThemeBloc(prefs: prefs, readDynamicAccent: () async => null, syncSystemBars: false);
  bloc.add(ThemeLoadStarted());
  await pumpEventQueue();
  return bloc;
}

void main() {
  testWidgets('no accent caption, no preview card, background title on one line', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final bloc = await tester.runAsync(_loaded) as ThemeBloc;
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: MaterialApp(theme: bloc.state.lightThemeData, home: const ThemeSettings()),
    ));
    await tester.pump();

    expect(find.text(S.current.Theme_Accent_Now_Fixed), findsNothing);
    expect(find.text(S.current.Theme_Accent_Now_Fall), findsNothing);
    expect(find.text(S.current.Preview), findsNothing);
    expect(find.text(S.current.Theme_Preview_Button), findsNothing);

    await tester.scrollUntilVisible(find.text(S.current.Select_bg), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.getSize(find.text(S.current.Select_bg)).height, lessThan(30));
    await tester.runAsync(bloc.close);
  });
}
