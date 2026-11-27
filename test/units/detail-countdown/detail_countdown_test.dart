import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/header/next_episode.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/next_episode_card.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));

  test("DailyAL's format: two digits, empty units left out, seconds always", () {
    expect(dalCountdown(const Duration(days: 6, hours: 6, minutes: 49, seconds: 29)), '06d · 06h · 49m · 29s');
    expect(dalCountdown(const Duration(minutes: 3, seconds: 5)), '03m · 05s');
    expect(dalCountdown(const Duration(days: 1, seconds: 9)), '01d · 09s');
  });

  testWidgets('ticks every second, then says it airs, then goes', (tester) async {
    var now = DateTime(2026, 11, 21, 12);
    final next = NextEpisode(20, now.add(const Duration(seconds: 2)));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: Scaffold(body: NextEpisodeCard(episode: next, now: () => now)),
    ));
    expect(find.text('02s'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('01s'), findsOneWidget);

    now = now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(S.current.Dc_Airing_Now), findsOneWidget);

    now = now.add(const Duration(hours: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Card), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
