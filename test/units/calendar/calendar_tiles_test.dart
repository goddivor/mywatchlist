import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';
import 'package:mywatchlist/widgets/calendar/calendar_tiles.dart';

Future<void> _pump(WidgetTester tester, Locale locale, Widget child) async {
  await tester.runAsync(() async {
    await initializeDateFormatting(locale.toString());
    await S.load(locale);
  });
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: child),
  ));
  await tester.pump();
}

void main() {
  final at = DateTime.utc(2026, 10, 27, 15, 30);
  CalendarEntry entry({String? status}) => CalendarEntry(
        malId: 1,
        title: 'Frieren',
        imageUrl: '',
        episode: 7,
        numEpisodes: 12,
        airingAt: at,
        listStatus: status,
      );

  test('countdown wording follows the remaining time', () async {
    await S.load(const Locale('en'));
    expect(countdownText(at, at.add(const Duration(minutes: 1))), 'Aired');
    expect(countdownText(at, at.subtract(const Duration(days: 2, hours: 3))), 'in 2 d 3 h');
    expect(countdownText(at, at.subtract(const Duration(hours: 5, minutes: 9))), 'in 5 h 9 min');
    expect(countdownText(at, at.subtract(const Duration(minutes: 4, seconds: 5))), 'in 4 min 5 s');
  });

  testWidgets('a watched anime shows its status and the time in the chosen zone (French)', (tester) async {
    final clock = ValueNotifier<int>(at.millisecondsSinceEpoch ~/ 1000 - 3600);
    await _pump(
      tester,
      const Locale('fr', 'FR'),
      EpisodeTile(
        entry: entry(status: 'watching'),
        timezone: TimezonePref.jst,
        clock: clock,
        showStatus: true,
        onOpen: () {},
        onAddToCalendar: () {},
      ),
    );
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.textContaining('Ép. 7 sur 12'), findsOneWidget);
    expect(find.textContaining('00:30 JST'), findsOneWidget);
    expect(find.text('dans 1 h 0 min'), findsOneWidget);
    expect(find.text(S.current.Kit_Status_Watching), findsOneWidget);
    clock.dispose();
  });

  testWidgets('no status badge when the list is unknown', (tester) async {
    final clock = ValueNotifier<int>(0);
    await _pump(
      tester,
      const Locale('en'),
      EpisodeTile(
        entry: entry(status: 'watching'),
        timezone: TimezonePref.utc,
        clock: clock,
        showStatus: false,
        onOpen: () {},
        onAddToCalendar: () {},
      ),
    );
    expect(find.text('Watching'), findsNothing);
    expect(find.textContaining('15:30 UTC'), findsOneWidget);
    clock.dispose();
  });

  testWidgets('day strip selects a day on tap and labels today', (tester) async {
    final days = [
      for (var i = 0; i < 7; i++) CalendarDay(DateTime.utc(2026, 10, 27 + i), const []),
    ];
    int? picked;
    await _pump(tester, const Locale('en'), DayStrip(days: days, selected: 0, onSelected: (i) => picked = i));
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('30'));
    expect(picked, 3);
  });
}
