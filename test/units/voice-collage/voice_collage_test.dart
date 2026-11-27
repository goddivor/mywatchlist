import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/voice_collage_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/character_page.dart';

List<VoiceRole> _roles(int n) => [
      for (var i = 0; i < n; i++)
        VoiceRole(characterId: i, name: 'Family, Given $i', anime: 'Show $i', role: i.isEven ? 'Main' : 'Supporting'),
    ];

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    await S.load(const Locale('en'));
  });

  test('names as fan collages print them', () {
    expect(givenName('Saitou, Ena'), 'Ena');
    expect(givenName('Megumin'), 'Megumin');
    expect(naturalName('Takahashi, Rie'), 'Rie Takahashi');
    expect(naturalName('Megumin'), 'Megumin');
  });

  test("MAL's birthday as Jikan's date", () {
    expect(malBirthday('Feb  27, 1994'), '1994-02-27T00:00:00+00:00');
    expect(malBirthday('Feb 27'), '2000-02-27T00:00:00+00:00');
    expect(malBirthday('Unknown'), isNull);
    expect(malBirthday(null), isNull);
  });

  test('every role gets a cell around the actor, the nearest first, above too', () {
    for (final n in [0, 1, 12, 160, 161]) {
      final l = CollageLayout.of(n);
      expect(l.cells.length, n);
      expect(l.cells.toSet().length, n, reason: 'one character per cell');
      expect(l.columns * l.rows >= n + 9, isTrue);
      for (final (c, r) in l.cells) {
        final onActor = c >= l.actorColumn && c < l.actorColumn + 3 && r >= l.actorRow && r < l.actorRow + 3;
        expect(onActor, isFalse);
      }
    }
    final l = CollageLayout.of(160);
    // The first sixteen fill the ring right around the actor, rows above it included.
    final first = l.cells.take(16).toList();
    expect(first.every((p) => p.$1 >= l.actorColumn - 1 && p.$1 <= l.actorColumn + 3 && p.$2 >= l.actorRow - 1 && p.$2 <= l.actorRow + 3), isTrue);
    expect(first.any((p) => p.$2 < l.actorRow), isTrue);
  });

  testWidgets('all roles shown, no main / supporting label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: VoiceCollageScreen(
        personId: 1,
        name: 'Takahashi, Rie',
        birthday: DateTime(1994, 2, 27),
        roles: _roles(160),
      ),
    ));
    await tester.pump();
    expect(find.text('RIE TAKAHASHI'), findsOneWidget);
    expect(find.text('FEBRUARY 27'), findsOneWidget);
    expect(find.text('GIVEN 0'), findsOneWidget);
    expect(find.text('GIVEN 159'), findsOneWidget);
    expect(find.text('SHOW 0'), findsOneWidget);
    expect(find.text(S.current.Vc_Count(160)), findsOneWidget);
    expect(find.text('MAIN'), findsNothing);
    expect(find.text('SUPPORTING'), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip(S.current.Vc_Fit));
    await tester.pump(const Duration(seconds: 1));
  });
}
