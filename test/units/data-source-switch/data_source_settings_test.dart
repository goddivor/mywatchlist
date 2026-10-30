import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/screens/settings/data_source_settings.dart';
import 'package:mywatchlist/services/api/jikan_source.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, JikanSource source, {Locale locale = const Locale('en')}) async {
  await S.load(locale);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: S.delegate.supportedLocales,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: DataSourceSettingsPage(source: source),
  ));
  await tester.pumpAndSettle();
}

void main() {
  late bool jikanAnswers;
  late JikanSource source;
  final now = DateTime(2026, 10, 30, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    jikanAnswers = false;
    source = JikanSource(probe: () async => jikanAnswers, now: () => now);
    await source.start(await SharedPreferences.getInstance());
  });

  testWidgets('shows Tenrai and the date until which Jikan is muted', (tester) async {
    await _pump(tester, source);
    expect(find.text(S.current.Dss_Title), findsWidgets);
    expect(find.text('Tenrai'), findsOneWidget);
    expect(find.text(S.current.Dss_Muted_Until('Nov 29, 2026')), findsOneWidget);
    expect(find.text(S.current.Dss_One_Month), findsOneWidget, reason: 'default duration');
  });

  testWidgets('the duration sheet saves the choice', (tester) async {
    await _pump(tester, source);
    await tester.tap(find.text(S.current.Dss_Mute_Duration));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.Dss_One_Week).last);
    await tester.pumpAndSettle();
    expect(source.muteDuration, JikanMuteDuration.oneWeek);
    expect(find.text(S.current.Dss_One_Week), findsOneWidget);
    expect(find.text(S.current.Dss_Muted_Until('Nov 6, 2026')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(JikanSource.muteDurationKey), 'oneWeek');
  });

  testWidgets('Test again: Jikan answers -> Jikan, no date, a message', (tester) async {
    await _pump(tester, source);
    jikanAnswers = true;
    await tester.tap(find.text(S.current.Dss_Test_Again));
    await tester.pumpAndSettle();
    expect(find.text('Jikan'), findsOneWidget);
    expect(find.textContaining('Nov'), findsNothing);
    expect(find.text(S.current.Dss_Jikan_Up), findsOneWidget);
  });

  testWidgets('French: every text of the page is translated', (tester) async {
    await _pump(tester, source, locale: const Locale('fr', 'FR'));
    expect(find.text('Sources de données'), findsWidgets);
    expect(find.text('Mettre Jikan en pause pendant'), findsOneWidget);
    expect(find.text('Tester Jikan à nouveau'), findsOneWidget);
    expect(find.text('Jikan en pause jusqu’au 29 nov. 2026'), findsOneWidget);
    await S.load(const Locale('en'));
  });

  test('the hub entry opens this page and shows the live status', () async {
    await S.load(const Locale('en'));
    expect(AppRoutes.settingsPageFor(SettingsSection.dataSources), isA<DataSourceSettingsPage>());
    expect(SettingsSection.dataSources.title, S.current.Dss_Title);
    expect(dataSourceStatus(source), 'Tenrai · ${S.current.Dss_Muted_Until('Nov 29, 2026')}');
  });
}
