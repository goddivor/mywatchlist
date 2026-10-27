import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/language_settings.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/language/language_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The same locale wiring as `MyWatchListApp` in lib/main.dart.
Widget _app(LanguageBloc bloc) => BlocProvider.value(
      value: bloc,
      child: BlocBuilder<LanguageBloc, LanguageState>(
        builder: (context, state) => MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          locale: state.appLocale,
          home: const LanguageSettings(),
        ),
      ),
    );

/// Built inside the test body: the bloc must live in the test's fake-async zone, or its
/// handlers never run during `pump`.
Future<LanguageBloc> _englishBloc(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'language_code': 'en', 'use_system_language': false});
  final bloc = LanguageBloc(
    prefs: await SharedPreferences.getInstance(),
    deviceLocales: () => const [Locale('en')],
  );
  await bloc.applyCurrent();
  addTearDown(() async {
    await bloc.close();
    await LanguageBloc.apply('en');
  });
  return bloc;
}

void main() {
  testWidgets('tapping French switches the page to French', (tester) async {
    final bloc = await _englishBloc(tester);
    await tester.pumpWidget(_app(bloc));
    expect(find.text('Language Settings'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('language-fr_FR')));
    await tester.pumpAndSettle();

    expect(find.text('Paramètres de langue'), findsOneWidget);
    expect(find.text('Langues disponibles'), findsOneWidget);
    expect(find.text('Langue définie : Français'), findsOneWidget);
    expect(bloc.state.languageCode, 'fr_FR');
  });

  testWidgets('Arabic lays the app out right to left', (tester) async {
    final bloc = await _englishBloc(tester);
    await tester.pumpWidget(_app(bloc));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('language-ar_EG')), 200);
    await tester.tap(find.byKey(const ValueKey('language-ar_EG')));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ListView));
    expect(Directionality.of(context), TextDirection.rtl);
  });
}
