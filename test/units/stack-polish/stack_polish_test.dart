import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('formatStackDate', () {
    test('follows the locale', () {
      expect(formatStackDate('Oct 27 2026, 1:37 AM', 'en'), 'Oct 27, 2026 1:37 AM');
      final fr = formatStackDate('Oct 27 2026, 1:37 AM', 'fr_FR');
      expect(fr, contains('27'));
      expect(fr, contains('oct'));
      expect(fr, contains('01:37'));
      expect(fr, isNot(contains('AM')));
    });

    test('reads PM, a bare date and a leading label', () {
      expect(formatStackDate('Created Dec 3 2025, 12:05 PM', 'fr_FR'), contains('12:05'));
      expect(formatStackDate('Dec 3 2025, 11:05 PM', 'fr_FR'), contains('23:05'));
      expect(formatStackDate('Dec 3 2025', 'fr_FR'), allOf(contains('3'), contains('déc'), contains('2025')));
    });

    test('keeps text it cannot read', () {
      expect(formatStackDate(' 3 days ago ', 'fr_FR'), '3 days ago');
    });
  });

  testWidgets('an entry cover is 100 x 150 and the date is French under fr_FR', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr', 'FR'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: const Scaffold(
        body: StackEntryTile(item: {'title': 'Frieren', 'malId': 52991}, category: 'anime'),
      ),
    ));
    await tester.pump();
    expect(tester.getSize(find.byType(AvatarWidget)), const Size(100, 150));
    expect(S.current.StackPolish_Created('27 oct. 2026'), 'Créée le 27 oct. 2026');
  });
}
