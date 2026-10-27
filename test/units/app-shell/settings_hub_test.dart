import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/screens/open_screen.dart';
import 'package:mywatchlist/screens/settings/settings_page.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget home, {Locale? locale}) {
  return tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: S.delegate.supportedLocales,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return LanguageBloc.apply('en');
  });

  testWidgets('the hub lists every settings page and the cross-tracker switch',
      (tester) async {
    await _pump(tester, const SettingsPage());
    await tester.pumpAndSettle();
    for (final section in SettingsSection.values) {
      await tester.scrollUntilVisible(find.text(section.title), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(section.title), findsOneWidget, reason: section.name);
    }
    await tester.scrollUntilVisible(find.text(S.current.Settings_Cross_Sync), -200,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('a stub tile opens its coming-soon page', (tester) async {
    await _pump(tester, const SettingsPage());
    await tester.pumpAndSettle();
    final about = find.text(SettingsSection.about.title);
    await tester.scrollUntilVisible(about, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(about);
    await tester.pumpAndSettle();
    expect(find.byType(ComingSoonPage), findsOneWidget);
  });

  testWidgets('the hub is translated', (tester) async {
    await _pump(tester, const SettingsPage(), locale: const Locale('fr', 'FR'));
    await tester.pumpAndSettle();
    expect(find.text('Apparence'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    addTearDown(() => LanguageBloc.apply('en'));
  });

  testWidgets('the startup loader shows a progress bar', (tester) async {
    await _pump(tester, const AppStartupLoader());
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
