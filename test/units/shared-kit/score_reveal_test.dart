import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  testWidgets('shows the score when it is not hidden', (tester) async {
    await pumpInApp(tester, const ScoreReveal(hidden: false, child: Text('8.75')));
    expect(find.text('8.75'), findsOneWidget);
  });

  testWidgets('tap reveals for a while, then hides again', (tester) async {
    await pumpInApp(tester, const ScoreReveal(hidden: true, child: Text('8.75')));
    expect(find.text('8.75'), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

    await tester.tap(find.byType(ScoreReveal));
    await tester.pumpAndSettle();
    expect(find.text('8.75'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('8.75'), findsNothing);
  });

  testWidgets('tapping a revealed score hides it at once', (tester) async {
    await pumpInApp(tester, const ScoreReveal(hidden: true, revealFor: Duration.zero, child: Text('8.75')));
    await tester.tap(find.byType(ScoreReveal));
    await tester.pumpAndSettle();
    expect(find.text('8.75'), findsOneWidget);
    await tester.tap(find.byType(ScoreReveal));
    await tester.pumpAndSettle();
    expect(find.text('8.75'), findsNothing);
  });

  testWidgets('follows the hide-score preference', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final bloc = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(bloc.close);
    await pumpInApp(
      tester,
      BlocProvider.value(value: bloc, child: const ScoreReveal(child: Text('8.75'))),
    );
    expect(find.text('8.75'), findsOneWidget);

    bloc.add(ContentPreferencesChanged((p) => p.copyWith(hideScore: true)));
    await tester.pumpAndSettle();
    expect(find.text('8.75'), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('without a PreferencesBloc it reads the defaults', (tester) async {
    await pumpInApp(tester, const ScoreReveal(child: Text('8.75')));
    expect(find.text('8.75'), findsOneWidget);
  });
}
