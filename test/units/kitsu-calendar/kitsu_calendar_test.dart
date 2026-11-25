import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/widgets/Kitsu/calendar/kitsu_calendar_page.dart';

import '../../helpers/no_network.dart';

// Shapes follow Kitsu's `/library-entries?include=anime` answer (2026-11-25); no request is sent.

Map<String, dynamic> _answer({bool next = false}) => {
      'data': [
        for (final (id, status) in [(1, 'current'), (2, 'planned'), (3, 'current')])
          {
            'id': '10$id',
            'type': 'libraryEntries',
            'attributes': {'status': status, 'progress': id},
            'relationships': {
              'anime': {
                'data': {'type': 'anime', 'id': '$id'}
              }
            },
          },
      ],
      'included': [
        {
          'id': '1',
          'type': 'anime',
          'attributes': {
            'canonicalTitle': 'One Piece',
            'titles': {'en_jp': 'One Piece'},
            'status': 'current',
            'nextRelease': '2026-11-29T09:30:00.000+09:00',
          },
        },
        {
          'id': '2',
          'type': 'anime',
          'attributes': {
            'canonicalTitle': 'Frieren',
            'titles': {'en_jp': 'Sousou no Frieren'},
            'status': 'current',
            'episodeCount': 28,
            'nextRelease': '2026-11-25T23:00:00.000+09:00',
          },
        },
        {
          'id': '3',
          'type': 'anime',
          'attributes': {'canonicalTitle': 'Finished', 'status': 'finished', 'nextRelease': null},
        },
      ],
      'links': {if (next) 'next': 'https://kitsu.app/api/edge/library-entries?page[offset]=3'},
    };

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  test('only titles with a next release, in UTC, with their library status', () {
    final (items, hasNext, count) = KitsuLibrary.parseCalendarPage(_answer(next: true), titleLang: 'ro');
    expect(items.map((i) => i.entry.title), ['One Piece', 'Sousou no Frieren']);
    expect(items.first.nextRelease, DateTime.utc(2026, 11, 29, 0, 30));
    expect(items.last.entry.total, 28);
    expect(hasNext, isTrue);
    expect(count, 3);
  });

  test('items are grouped by local day', () {
    final (items, _, _) = KitsuLibrary.parseCalendarPage(_answer(), titleLang: 'ro');
    final local = items.last.nextRelease.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    expect(kitsuCalendarOn(items, day).map((i) => i.entry.title), contains('Sousou no Frieren'));
  });

  testWidgets('the day strip counts releases and a day lists them', (tester) async {
    final (items, _, _) = KitsuLibrary.parseCalendarPage(_answer(), titleLang: 'ro');
    final frieren = items.last.nextRelease.toLocal();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: KitsuCalendarPage(
        source: () async => items,
        now: () => DateTime(frieren.year, frieren.month, frieren.day, 0, 1),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Today · 1'), findsOneWidget);
    expect(find.text('Sousou no Frieren'), findsOneWidget);
    expect(find.text('${S.current.Edit_Plan_To_Watch} · 2 / 28'), findsOneWidget);
    expect(find.text('One Piece'), findsNothing);
  });
}
