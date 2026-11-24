import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart' hide SimklFormat;
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';

/// Fake signed-in Simkl: answers by path and keeps every request with its JSON body. Never
/// touches a real account.
class _Account {
  final Map<String, Object? Function(Uri uri)> routes;
  final List<({String path, Object? body})> calls = [];
  _Account(this.routes);

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) async => send(_Http(this), 'token'),
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
  );

  List<({String path, Object? body})> writes() => [
        for (final c in calls)
          if (c.body != null) c,
      ];
}

class _Http extends http.BaseClient {
  _Http(this.account);
  final _Account account;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final text = request is http.Request ? request.body : '';
    account.calls.add((path: request.url.path, body: text.isEmpty ? null : jsonDecode(text)));
    final route = account.routes[request.url.path];
    final bytes = utf8.encode(jsonEncode(route == null ? {} : route(request.url)));
    return http.StreamedResponse(Stream.value(bytes), 200, headers: {'content-type': 'application/json'});
  }
}

/// Two seasons of 2 episodes and a special, out of order.
const _episodes = [
  SimklEpisode(title: 'b', season: 2, number: 1),
  SimklEpisode(title: 'sp', season: 0, number: 1, isSpecial: true),
  SimklEpisode(title: 'a', season: 1, number: 1),
  SimklEpisode(title: 'a2', season: 1, number: 2),
  SimklEpisode(title: 'b2', season: 2, number: 2),
];

final _now = DateTime.utc(2026, 10, 29, 12);

/// The calendar page of [kind] over [account]'s list, with one listed title (id 1, "Mine").
Widget _calendar(_Account account, SimklKind kind, Map<String, dynamic> airing) {
  final file = jsonEncode({
    'calendar': [airing],
    'metadata': {
      '1': {'title': 'Mine', 'ids': {'simkl_id': 1}},
    },
  });
  final cdn = SimklCdn(
    get: (uri, headers) async => http.Response.bytes(utf8.encode(file), 200),
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
  );
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: SimklCalendarPage(
      kind: kind,
      service: SimklDiscoverService(client: account.client, cdn: cdn, signedIn: () => false),
      listService: SimklListService(
        kind: kind,
        client: account.client,
        clock: () => _now,
        owner: () => 'me',
        episodes: (_) async => _episodes,
      ),
      now: () => _now,
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await S.load(const Locale('en'));
  });

  test('a Simkl movie list has no watching or on hold tab; shows and anime keep every tab', () {
    final adapter = SimklUserListAdapter(owner: () => 'me');
    expect(adapter.statusTabs('movie'), [
      null,
      ListEntryStatus.completed,
      ListEntryStatus.dropped,
      ListEntryStatus.planned,
    ]);
    expect(adapter.statusTabs('tv'), userListTabs);
    expect(adapter.statusTabs('anime'), userListTabs);
  });

  test('a show episode is placed in the watch order, specials left out', () async {
    final account = _Account({});
    final service = SimklListService(
      kind: SimklKind.tv,
      client: account.client,
      episodes: (_) async => _episodes,
    );
    const entry = ListEntryView(id: 1, title: 'Mine', category: 'tv');
    expect(await service.watchOrderOf(entry, 2, 1), 3);
    expect(await service.watchOrderOf(entry, 1, 1), 1);
    expect(await service.watchOrderOf(entry, 3, 1), isNull);
  });

  group('calendar long press on shows and movies', () {
    testWidgets('a show episode is marked by season and number after the confirmation',
        (tester) async {
      final account = _Account({
        '/sync/activities': (_) => {},
        '/sync/all-items/shows': (_) => {
              'shows': [
                {
                  'status': 'watching',
                  'watched_episodes_count': 1,
                  'total_episodes_count': 4,
                  'not_aired_episodes_count': 0,
                  'show': {
                    'title': 'Mine',
                    'ids': {'simkl': 1},
                  },
                },
              ],
            },
        '/sync/history': (_) => {'added': {}},
      });
      await tester.pumpWidget(_calendar(account, SimklKind.tv, {
        'simkl_id': 1,
        'date': '2026-10-29T11:00:00Z',
        'episode': {'season': 2, 'episode': 1},
      }));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(account.writes(), isEmpty, reason: 'nothing is written before the confirmation');
      await tester.tap(find.text('Mark S2E1 watched'));
      await tester.pumpAndSettle();
      final write = account.writes().single;
      expect(write.path, '/sync/history');
      expect(write.body, {
        'shows': [
          {
            'ids': {'simkl': 1},
            'seasons': [
              {
                'number': 1,
                'episodes': [
                  {'number': 2},
                ],
              },
              {
                'number': 2,
                'episodes': [
                  {'number': 1},
                ],
              },
            ],
          },
        ],
      });
    });

    testWidgets('a released movie on the list is marked watched', (tester) async {
      final account = _Account({
        '/sync/activities': (_) => {},
        '/sync/all-items/movies': (_) => {
              'movies': [
                {
                  'status': 'plantowatch',
                  'movie': {
                    'title': 'Mine',
                    'ids': {'simkl': 1},
                  },
                },
              ],
            },
        '/sync/history': (_) => {'added': {}},
      });
      await tester.pumpWidget(_calendar(account, SimklKind.movie, {
        'simkl_id': 1,
        'date': '2026-10-29T11:00:00Z',
      }));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Mine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as watched'));
      await tester.pumpAndSettle();
      final write = account.writes().single;
      expect(write.path, '/sync/history');
      expect(write.body, {
        'movies': [
          {
            'ids': {'simkl': 1},
          },
        ],
      });
    });
  });
}
