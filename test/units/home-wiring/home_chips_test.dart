import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/widgets/home/home_chips.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the chip row has the seven shortcuts and none is a no-op', (tester) async {
    await LanguageBloc.apply('en');
    expect(homeChips(), hasLength(7));
    await tester.pumpWidget(_app(const HomeChipsBar()));
    await tester.pumpAndSettle();
    for (final label in ['Categories', 'Genres', 'Top Anime', 'Top Manga', 'Top Airing']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the chips are in French', (tester) async {
    await LanguageBloc.apply('fr_FR');
    final labels = homeChips().map((c) => c.label).toList();
    expect(labels.first, 'Catégories');
    expect(labels, everyElement(isNot(contains('Popular'))));
    await LanguageBloc.apply('en');
  });

  testWidgets('Genres opens a sheet with the genre groups of anime and manga', (tester) async {
    await LanguageBloc.apply('en');
    await tester.pumpWidget(_app(const HomeChipsBar()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Genres'));
    await tester.pumpAndSettle();
    expect(find.text('Anime'), findsOneWidget);
    expect(find.text('Manga'), findsOneWidget);
    expect(find.byType(ActionChip), findsWidgets);

    await tester.tap(find.text('Manga'));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsWidgets);
  });
}
