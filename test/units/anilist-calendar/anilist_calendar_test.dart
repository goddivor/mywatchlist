import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/calendar/anilist_calendar_page.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

import '../../helpers/no_network.dart';

// Shapes follow AniList's `airingSchedules` answer; every request goes to a fake sender.

Map<String, dynamic> _row(int id, int airingAt, {String? status, bool adult = false}) => {
      'episode': id,
      'airingAt': airingAt,
      'media': {
        'id': id,
        'type': 'ANIME',
        'format': 'TV',
        'status': 'RELEASING',
        'episodes': 12,
        'isAdult': adult,
        'title': {'romaji': 'Show $id'},
        'coverImage': {'large': 'https://x/$id.jpg'},
        if (status != null) 'mediaListEntry': {'status': status},
      },
    };

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  test('day bounds follow the time zone setting', () {
    final day = DateTime(2026, 11, 25);
    expect(anilistDayStart(day, TimezonePref.utc), DateTime.utc(2026, 11, 25));
    expect(anilistDayStart(day, TimezonePref.jst), DateTime.utc(2026, 11, 24, 15));
    expect(anilistInZone(DateTime.utc(2026, 11, 24, 16), TimezonePref.jst), DateTime.utc(2026, 11, 25, 1));
  });

  test('statuses map to the list colours, REPEATING as watching', () {
    expect(anilistListStatus('CURRENT'), ListEntryStatus.current);
    expect(anilistListStatus('REPEATING'), ListEntryStatus.current);
    expect(anilistListStatus('PLANNING'), ListEntryStatus.planned);
    expect(anilistListStatus('PAUSED'), ListEntryStatus.onHold);
    expect(anilistListStatus(null), isNull);
  });

  test('a schedule page keeps the list status, drops adult titles, reads hasNextPage', () {
    final page = AnilistDiscoverService.parseSchedulePage({
      'Page': {
        'pageInfo': {'hasNextPage': true},
        'airingSchedules': [_row(1, 1764000000, status: 'CURRENT'), _row(2, 1764003600, adult: true), _row(3, 1764007200)],
      },
    });
    expect(page.items.map((a) => a.media.id), [1, 3]);
    expect(page.items.first.listStatus, 'CURRENT');
    expect(page.items.last.listStatus, isNull);
    expect(page.hasNext, isTrue);
  });

  testWidgets('the calendar pages through the day; My list keeps watching and planning', (tester) async {
    final day = DateTime.utc(2026, 11, 25);
    final t = day.millisecondsSinceEpoch ~/ 1000;
    final queries = <(bool auth, int page)>[];
    final gql = AnilistGraphql(sender: (body, {required auth}) async {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final page = (json['variables'] as Map)['page'] as int;
      queries.add((auth, page));
      final rows = page == 1
          ? [_row(1, t + 3600, status: 'CURRENT'), _row(2, t + 7200)]
          : [_row(3, t + 10800, status: 'PLANNING'), _row(4, t + 14400, status: 'COMPLETED')];
      return http.Response(
          jsonEncode({
            'data': {
              'Page': {'pageInfo': {'hasNextPage': page == 1}, 'airingSchedules': rows},
              'Viewer': {'options': {'displayAdultContent': false}},
            },
          }),
          200);
    });
    final service = AnilistDiscoverService(client: gql, signedIn: () => true, appAdult: () => false);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: AnilistCalendarPage(
        service: service,
        zone: TimezonePref.utc,
        now: () => day.add(const Duration(hours: 2, minutes: 30)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(queries.where((q) => q.$2 > 0).map((q) => q.$2).toSet(), {1, 2}, reason: 'both pages read');
    expect(find.text('Show 1'), findsOneWidget);
    expect(find.text('Show 3'), findsOneWidget);
    expect(find.text('Show 2'), findsNothing, reason: 'not on the list');
    expect(find.text('Show 4'), findsNothing, reason: 'completed is not "my list"');
    expect(find.text('Ep. 1 / 12'), findsOneWidget);

    await tester.tap(find.text('All anime'));
    await tester.pumpAndSettle();
    expect(find.text('Show 2'), findsOneWidget);
    expect(find.text('Show 4'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
  });
}
