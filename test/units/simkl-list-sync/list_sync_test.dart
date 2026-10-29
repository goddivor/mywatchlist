import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Fake signed-in Simkl: answers by path, records every request. Never touches a real account.
class FakeAccount {
  final Map<String, Object? Function(Uri uri)> routes;
  final List<Uri> calls = [];
  FakeAccount(this.routes);

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) async {
      final fake = _Client(this);
      return send(fake, 'token');
    },
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
  );

  List<String> get paths => [for (final c in calls) c.path];
}

class _Client extends http.BaseClient {
  _Client(this.account);
  final FakeAccount account;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    account.calls.add(request.url);
    final route = account.routes[request.url.path];
    final body = route == null ? null : route(request.url);
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(Stream.value(bytes), route == null ? 404 : 200,
        headers: {'content-type': 'application/json'});
  }
}

Map<String, dynamic> item(int id, String status, {int watched = 0, int total = 12, int? mal}) => {
      'status': status,
      'watched_episodes_count': watched,
      'total_episodes_count': total,
      'not_aired_episodes_count': 0,
      'show': {
        'title': 'Title $id',
        'ids': {'simkl': id, if (mal != null) 'mal': mal},
      },
    };

Map<String, dynamic> activities(String all, {String removed = 'r0'}) => {
      'anime': {'all': all, 'removed_from_list': removed},
    };

void main() {
  late String stamp;
  late String removed;
  late List<Map<String, dynamic>> list;
  late List<Map<String, dynamic>> delta;
  late FakeAccount account;
  late DateTime now;
  late SimklListService service;

  setUp(() {
    stamp = 't1';
    removed = 'r0';
    list = [item(1, 'watching', watched: 3), item(2, 'plantowatch')];
    delta = [];
    now = DateTime.utc(2026, 10, 29, 12);
    account = FakeAccount({
      '/sync/activities': (_) => activities(stamp, removed: removed),
      '/sync/all-items/anime': (u) => {'anime': u.queryParameters.containsKey('date_from') ? delta : list},
      '/ratings/anime': (_) => [
            {'id': 1, 'simkl': {'rating': 8.4, 'votes': 120}},
            {'id': 2, 'simkl': {'rating': 0, 'votes': 0}},
          ],
      '/sync/add-to-list': (_) => {'added': {}},
      '/sync/remove-from-list': (_) => {'deleted': {}},
    });
    service = SimklListService(client: account.client, clock: () => now, owner: () => 'me');
  });

  test('first load: activities, the whole list, then community scores', () async {
    final entries = await service.anime();
    expect(entries.map((e) => e.id), [1, 2]);
    expect(account.paths, ['/sync/activities', '/sync/all-items/anime', '/ratings/anime']);
    expect(account.calls[1].queryParameters.containsKey('date_from'), isFalse);
    expect(entries[0].meanScore, 8.4);
    expect(entries[0].scoringUsers, 120);
    expect(entries[1].meanScore, isNull, reason: 'a title nobody rated has no badge');
  });

  test('nothing changed: only the activities are asked', () async {
    await service.anime();
    account.calls.clear();
    now = now.add(const Duration(minutes: 10));
    final again = await service.anime();
    expect(again.length, 2);
    expect(account.paths, ['/sync/activities']);
    expect(service.fullPulls, 1);
    expect(service.deltaPulls, 0);
  });

  test('inside the ttl nothing is asked at all', () async {
    await service.anime();
    account.calls.clear();
    await service.anime();
    expect(account.calls, isEmpty);
  });

  test('changed entries come with date_from and are merged', () async {
    await service.anime();
    account.calls.clear();
    stamp = 't2';
    delta = [item(2, 'watching', watched: 1), item(3, 'plantowatch')];
    now = now.add(const Duration(minutes: 10));
    final merged = await service.anime();
    expect(merged.map((e) => e.id), [3, 1, 2]);
    expect(merged.firstWhere((e) => e.id == 2).status, ListEntryStatus.current);
    final pull = account.calls.firstWhere((c) => c.path == '/sync/all-items/anime');
    expect(pull.queryParameters['date_from'], 't1');
    expect(service.fullPulls, 1);
    expect(service.deltaPulls, 1);
    expect(merged.firstWhere((e) => e.id == 1).meanScore, 8.4, reason: 'kept entries keep their score');
  });

  test('a removal downloads the list again', () async {
    await service.anime();
    account.calls.clear();
    stamp = 't2';
    removed = 'r1';
    list = [item(1, 'watching')];
    now = now.add(const Duration(minutes: 10));
    final fresh = await service.anime();
    expect(fresh.map((e) => e.id), [1]);
    expect(service.fullPulls, 2);
  });

  test('a write of ours is pulled even when the stamp did not move; a removal reloads', () async {
    final entries = await service.anime();
    delta = [item(2, 'watching', watched: 1)];
    await service.save(entries[1], status: ListEntryStatus.current);
    account.calls.clear();
    final after = await service.anime();
    expect(account.calls.any((c) => c.queryParameters.containsKey('date_from')), isTrue);
    expect(after.firstWhere((e) => e.id == 2).status, ListEntryStatus.current);

    await service.remove(entries[1]);
    account.calls.clear();
    list = [item(1, 'watching', watched: 3)];
    final reloaded = await service.anime();
    expect(reloaded.map((e) => e.id), [1]);
    expect(account.calls.where((c) => c.path == '/sync/all-items/anime').single.queryParameters.containsKey('date_from'),
        isFalse);
  });

  test('without activities the list is still downloaded; without ratings it still shows', () async {
    final broken = FakeAccount({
      '/sync/all-items/anime': (_) => {'anime': list},
    });
    final s = SimklListService(client: broken.client, clock: () => now, owner: () => 'me');
    final entries = await s.anime();
    expect(entries.length, 2);
    expect(entries.first.meanScore, isNull);
  });

  test('another account starts from scratch', () async {
    var who = 'me';
    final s = SimklListService(client: account.client, clock: () => now, owner: () => who);
    await s.anime();
    who = 'you';
    account.calls.clear();
    await s.anime();
    expect(s.fullPulls, 2);
  });

  test('playback sessions: latest first, incomplete ones skipped', () async {
    account.routes['/sync/playback/anime'] = (_) => [
          {
            'progress': 41.5,
            'paused_at': '2026-10-28T10:00:00Z',
            'episode': {'season': 1, 'episode': 4},
            'show': {'title': 'Old', 'ids': {'simkl': 7}},
          },
          {
            'progress': 12,
            'paused_at': '2026-10-29T09:00:00Z',
            'episode': {'episode': 2},
            'show': {'title': 'New', 'ids': {'simkl': 8, 'mal': 80}, 'poster': 'ab/cd'},
          },
          {'progress': 5, 'show': {'ids': {}}},
        ];
    final sessions = await service.playback();
    expect(sessions.map((s) => s.simklId), [8, 7]);
    expect(sessions.first.episode, 2);
    expect(sessions.first.malId, 80);
    expect(sessions.first.posterUrl, 'https://simkl.in/posters/ab/cd_m.jpg');
    expect(sessions.last.progress, 41.5);
  });

  group('airing slot in the time zone setting', () {
    setUpAll(() async {
      await initializeDateFormatting('en');
      await S.load(const Locale('en'));
    });
    const tokyo = SimklAirs(day: 'Sunday', time: '23:15', timezone: 'Asia/Tokyo');

    test('JST keeps the slot and names the zone', () {
      expect(SimklFormat.airs(tokyo, zone: TimezonePref.jst), 'Sunday at 23:15 (JST)');
    });

    test('UTC moves the time back nine hours', () {
      expect(SimklFormat.airs(tokyo, zone: TimezonePref.utc), 'Sunday at 14:15 (UTC)');
    });

    test('local moves the day when the time crosses midnight', () {
      expect(SimklFormat.airs(tokyo, zone: TimezonePref.local, localOffset: () => const Duration(hours: 1)),
          'Sunday at 15:15');
      expect(SimklFormat.airs(tokyo, zone: TimezonePref.local, localOffset: () => const Duration(hours: 5, minutes: 30)),
          'Sunday at 19:45');
      expect(SimklFormat.airs(tokyo, zone: TimezonePref.local, localOffset: () => const Duration(hours: 12)),
          'Monday at 02:15');
      const early = SimklAirs(day: 'Monday', time: '01:00', timezone: 'Asia/Tokyo');
      expect(SimklFormat.airs(early, zone: TimezonePref.utc), 'Sunday at 16:00 (UTC)');
    });

    test('a zone that is not converted is shown as Simkl gives it', () {
      const other = SimklAirs(day: 'Friday', time: '20:00', timezone: 'America/New_York');
      expect(SimklFormat.airs(other, zone: TimezonePref.jst), 'Friday at 20:00 (America/New_York)');
    });
  });
}
