import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/bookmarks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Locale locale) async {
  await S.load(locale);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: const BookmarksScreen(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Bookmarks.store = BookmarkStore();
  });

  testWidgets('empty state is translated', (tester) async {
    await _pump(tester, const Locale('fr', 'FR'));
    expect(find.text('Aucun signet pour l’instant'), findsOneWidget);
  });

  testWidgets('lists bookmarks and filters by kind', (tester) async {
    await Bookmarks.toggle(
        tracker: 'myanimelist', kind: BookmarkKind.anime, id: 1, title: 'Alpha');
    await Bookmarks.toggle(
        tracker: 'myanimelist', kind: BookmarkKind.manga, id: 2, title: 'Beta');
    await _pump(tester, const Locale('en'));
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.textContaining('Manga'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
  });
}
