import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, {required VoidCallback openSidebar, Locale? locale}) {
  return tester.pumpWidget(BlocProvider(
    create: (_) => AccountBloc(),
    child: MaterialApp(
      locale: locale ?? const Locale('en'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: HomeShell(
        openSidebar: openSidebar,
        child: const Scaffold(body: AppBarHome(showSettings: true)),
      ),
    ),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the avatar opens the sidebar', (tester) async {
    await LanguageBloc.apply('en');
    var opened = 0;
    await _pump(tester, openSidebar: () => opened++);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu. Long press to switch account'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('a long press on the avatar opens the account switcher as a bottom sheet',
      (tester) async {
    await LanguageBloc.apply('en');
    await _pump(tester, openSidebar: () {});
    await tester.pumpAndSettle();

    await tester.longPress(find.byTooltip('Menu. Long press to switch account'));
    await tester.pumpAndSettle();
    expect(find.text('Switch account'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('the four buttons have translated tooltips', (tester) async {
    await LanguageBloc.apply('fr_FR');
    await _pump(tester, openSidebar: () {}, locale: const Locale('fr', 'FR'));
    await tester.pumpAndSettle();
    for (final tooltip in ['Recherche', 'Signets', 'Calendrier', 'Paramètres']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    await LanguageBloc.apply('en');
  });
}
