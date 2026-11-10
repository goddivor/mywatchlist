import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_cdn.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart' hide SimklFormat;
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_title_language.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_progress.dart';

// Saved answers of the simkl-cdn-feeds unit (read only).
String fixture(String name) => File('test/units/simkl-cdn-feeds/fixtures/$name').readAsStringSync();

/// Fake signed-in Simkl: answers by path and records every request. Never touches a real account.
class FakeAccount {
  FakeAccount(this.routes);

  final Map<String, Object? Function(http.BaseRequest request)> routes;
  final List<http.BaseRequest> calls = [];
  final List<String> bodies = [];

  late final SimklClient client = SimklClient(
    auth: (send, {idempotent}) async => send(_Client(this), 'token'),
    clientId: () => 'cid',
    appVersion: () async => '1.0.0',
  );

  List<String> get paths => [for (final c in calls) c.url.path];
}

class _Client extends http.BaseClient {
  _Client(this.account);
  final FakeAccount account;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    account.calls.add(request);
    account.bodies.add(request is http.Request ? request.body : '');
    final route = account.routes[request.url.path];
    final body = route == null ? null : route(request);
    return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), route == null ? 404 : 200,
        headers: {'content-type': 'application/json'});
  }
}

Map<String, dynamic> listItem(int id, String status, {int watched = 0, Map<String, dynamic>? next}) => {
      'status': status,
      'watched_episodes_count': watched,
      'total_episodes_count': 12,
      'not_aired_episodes_count': 0,
      'show': {
        'title': 'Title $id',
        'ids': {'simkl': id, 'mal': id + 100},
      },
      if (next != null) 'next_to_watch_info': next,
    };

class _FakeAccountBloc extends Fake implements AccountBloc {
  final _controller = StreamController<AccountState>.broadcast();
  @override
  AccountState state = AccountInitial();
  @override
  Stream<AccountState> get stream => _controller.stream;
  @override
  bool get isClosed => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
    await S.load(const Locale('en'));
  });

  group('CDN fields', () {
    test('trending keeps watchers, drop rate, rank, network and episode total', () {
      final items = parseSimklTrending(fixture('trending_week_100.json'));
      final first = items.first;
      expect(first.watchers, 2522);
      expect(first.dropRate, 0.7);
      expect(first.rank, 382);
      expect(first.totalEpisodes, 10);
      expect(first.network, isNull);
      expect(first.fanartUrl, isNull, reason: 'this title has no fanart');
      final raw = (json.decode(fixture('trending_week_100.json')) as List).cast<Map<String, dynamic>>();
      final withArt = raw.firstWhere((m) => m['fanart'] != null, orElse: () => {});
      if (withArt.isNotEmpty) {
        final media = items.firstWhere((m) => m.simklId == (withArt['ids'] as Map)['simkl_id']);
        expect(media.fanartUrl, 'https://simkl.in/fanart/${withArt['fanart']}_mobile.jpg');
      }
    });

    test('calendar keeps fanart, network, totals and the finale flag', () {
      final items = parseSimklCalendar(fixture('calendar_v2_anime.json'));
      final first = items.first;
      expect(first.fanartUrl, 'https://simkl.in/fanart/20/20767137284708cb2e_mobile.jpg');
      expect(first.network, 'Youku');
      expect(first.totalEpisodes, 26);
      expect(first.watchers, 90);
      expect(first.rank, 5831);
      expect(first.dropRate, 7.1);
      expect(first.finale, isFalse);
      final raw = json.decode(fixture('calendar_v2_anime.json')) as Map<String, dynamic>;
      final finales = (raw['calendar'] as List).where((e) => (e as Map)['finale_type'] != null).length;
      expect(items.where((m) => m.finale).length, finales);
    });

    test('a finale_type on a calendar entry flags only that episode', () {
      final body = jsonEncode({
        'calendar': [
          {'simkl_id': 1, 'date': '2026-10-26T15:00:00Z', 'finale_type': 'series', 'episode': {'episode': 12}},
          {'simkl_id': 1, 'date': '2026-10-19T15:00:00Z', 'finale_type': null, 'episode': {'episode': 11}},
        ],
        'metadata': {
          '1': {'title': 'A', 'ids': {'simkl_id': 1}},
        },
      });
      final items = parseSimklCalendar(body);
      expect(items.map((m) => (m.episode, m.finale)), [(11, false), (12, true)]);
      expect(SimklAiring(items.last).finale, isTrue);
      expect(SimklAiring(items.first).finale, isFalse);
    });

    test('the title language picks the romaji or the original title on read', () async {
      final body = jsonEncode([
        {
          'title': 'Frieren',
          'title_romaji': 'Sousou no Frieren',
          'alt_titles': [
            {'name': '葬送のフリーレン', 'lang': 25, 'type': 'official'}
          ],
          'ids': {'simkl_id': 7},
        },
      ]);
      final cdn = SimklCdn(
        get: (uri, headers) async => http.Response.bytes(utf8.encode(body), 200),
        clientId: () => 'cid',
        appVersion: () async => '1.0.0',
      );
      addTearDown(SimklTitlePreference.reset);
      expect((await cdn.trending(SimklTrendingWindow.week)).single.title, 'Frieren');
      SimklTitlePreference.language = SimklTitleLanguage.romaji;
      expect((await cdn.trending(SimklTrendingWindow.week)).single.title, 'Sousou no Frieren');
      SimklTitlePreference.language = SimklTitleLanguage.original;
      expect((await cdn.trending(SimklTrendingWindow.week)).single.title, '葬送のフリーレン');
    });
  });

  group('title language', () {
    test('anime_title_language is read from the settings, tolerant of its spelling', () {
      UserProfSimkl read(Object? v) => UserProfSimkl.fromJson({
            'user': {'name': 'me'},
            'account': {'id': 1},
            if (v != null) 'anime_title_language': v,
          });
      expect(read('romaji').titleLanguage, SimklTitleLanguage.romaji);
      expect(read('Original').titleLanguage, SimklTitleLanguage.original);
      expect(read('english').titleLanguage, SimklTitleLanguage.english);
      expect(read(null).titleLanguage, SimklTitleLanguage.english);
    });

    test('the title page record follows the language', () {
      final raw = {
        'title': 'Frieren',
        'title_romaji': 'Sousou no Frieren',
        'alt_titles': [
          {'name': '葬送のフリーレン'}
        ],
        'ids': {'simkl': 7},
      };
      expect(SimklTitle.fromJson(raw, language: SimklTitleLanguage.romaji)!.title, 'Sousou no Frieren');
      expect(SimklTitle.fromJson(raw, language: SimklTitleLanguage.original)!.title, '葬送のフリーレン');
      expect(SimklTitle.fromJson(raw, language: SimklTitleLanguage.english)!.title, 'Frieren');
    });
  });

  group('external ids', () {
    final raw = {
      'title': 'Frieren',
      'anime_type': 'tv',
      'ids': {
        'simkl': 1990194,
        'slug': 'sousou-no-frieren',
        'mal': 52991,
        'anilist': '154587',
        'kitsu': '46474',
        'imdb': 'tt22248376',
        'tmdb': '209867',
        'tvdb': '424536',
        'anidb': '17617',
      },
    };

    test('the record keeps every external id, not Simkl\'s own', () {
      final t = SimklTitle.fromJson(raw)!;
      expect(t.externalIds.keys.toSet(), {'mal', 'anilist', 'kitsu', 'imdb', 'tmdb', 'tvdb', 'anidb'});
      expect(t.externalIds['mal'], '52991');
      expect(t.malId, 52991);
    });

    test('the link row names the sites and builds their pages', () {
      final links = simklExternalLinks(SimklTitle.fromJson(raw)!.externalIds, animeType: 'tv');
      expect(links.map((l) => l.name), ['AniList', 'Kitsu', 'MyAnimeList', 'IMDb', 'TMDB', 'TVDB', 'AniDB']);
      expect(links.first.url, 'https://anilist.co/anime/154587');
      expect(links[4].url, 'https://www.themoviedb.org/tv/209867');
      expect(simklExternalLinks({'tmdb': '1'}, animeType: 'movie').single.url, 'https://www.themoviedb.org/movie/1');
      expect(simklExternalLinks(const {}), isEmpty);
    });
  });

  group('next_to_watch_info', () {
    late FakeAccount account;
    late SimklListService service;

    setUp(() {
      account = FakeAccount({
        '/sync/activities': (_) => {
              'anime': {'all': 't1', 'removed_from_list': 'r0'}
            },
        '/sync/all-items/anime': (_) => {
              'anime': [
                listItem(1, 'watching', watched: 3, next: {'title': 'The hunt', 'episode': 4, 'date': '2026-10-20T15:00:00Z'}),
                listItem(2, 'watching', watched: 12),
                listItem(3, 'plantowatch'),
              ],
            },
        '/ratings/anime': (_) => [],
      });
      service = SimklListService(client: account.client, owner: () => 'me');
    });

    test('the list is asked for it and the service keeps it', () async {
      await service.anime();
      final pull = account.calls.firstWhere((c) => c.url.path == '/sync/all-items/anime');
      expect(pull.url.queryParameters['next_watch_info'], 'yes');
      final next = service.nextToWatch(1)!;
      expect(next.episode, 4);
      expect(next.title, 'The hunt');
      expect(next.date, DateTime.utc(2026, 10, 20, 15));
      expect(service.nextToWatch(2), isNull);
      expect(service.nextToWatch(3), isNull);
    });

    SimklTitle record() => SimklTitle.fromJson({
          'title': 'T',
          'status': 'ended',
          'total_episodes': 12,
          'ids': {'simkl': 1},
        })!;

    test('the next-episode card uses Simkl\'s answer over the computation', () async {
      await initializeDateFormatting('en');
      final entries = await service.anime();
      final now = DateTime.utc(2026, 10, 29);
      final next = simklNextUp(
        title: record(),
        episodes: const [],
        entry: entries.first,
        now: now,
        info: service.nextToWatch(1),
      )!;
      expect(next.kind, SimklNextKind.watchNext);
      expect(next.episode, 4);
      expect(next.episodeTitle, 'The hunt');
      expect(next.date, DateTime.utc(2026, 10, 20, 15));

      final future = simklNextUp(
        title: record(),
        episodes: const [],
        entry: entries.first,
        now: DateTime.utc(2026, 10, 1),
        info: service.nextToWatch(1),
      )!;
      expect(future.kind, SimklNextKind.upcoming);
    });

    test('an answer about another episode than the progress is not trusted', () async {
      final entries = await service.anime();
      final next = simklNextUp(
        title: record(),
        episodes: const [],
        entry: entries.first.copyWith(progress: 8),
        now: DateTime.utc(2026, 10, 29),
        info: service.nextToWatch(1),
      );
      expect(next?.episode, 9, reason: 'computed from the progress (ended title)');
    });
  });

  group('check-in (fake account)', () {
    late FakeAccount account;
    late DateTime now;
    late SimklListService service;

    setUp(() {
      now = DateTime.utc(2026, 10, 29, 12);
      account = FakeAccount({'/scrobble/checkin': (_) => {'id': 1, 'action': 'checkin'}});
      service = SimklListService(client: account.client, clock: () => now, owner: () => 'me');
    });

    test('posts the anime with its ids and the episode to /scrobble/checkin', () async {
      await service.checkIn(
        simklId: 1990194,
        title: 'Frieren',
        episode: 5,
        year: 2023,
        malId: 52991,
        ids: const {'anilist': '154587', 'mal': '52991'},
      );
      expect(account.paths, ['/scrobble/checkin']);
      expect(account.calls.single.method, 'POST');
      final body = json.decode(account.bodies.single) as Map<String, dynamic>;
      expect(body['anime']['title'], 'Frieren');
      expect(body['anime']['year'], 2023);
      expect(body['anime']['ids'], {'anilist': '154587', 'mal': 52991, 'simkl': 1990194});
      expect(body['episode'], {'season': 1, 'number': 5});
    });

    test('a second check-in inside Simkl\'s 20 second lock is not sent', () async {
      await service.checkIn(simklId: 1, title: 'A', episode: 1);
      now = now.add(const Duration(seconds: 5));
      await expectLater(
        service.checkIn(simklId: 1, title: 'A', episode: 2),
        throwsA(isA<SimklCheckInTooSoon>().having((e) => e.wait.inSeconds, 'wait', 15)),
      );
      expect(account.calls, hasLength(1));
      now = now.add(const Duration(seconds: 16));
      await service.checkIn(simklId: 1, title: 'A', episode: 2);
      expect(account.calls, hasLength(2));
    });

    test('a refused check-in does not hold the lock', () async {
      final failing = FakeAccount({});
      final s = SimklListService(client: failing.client, clock: () => now, owner: () => 'me');
      await expectLater(s.checkIn(simklId: 1, title: 'A', episode: 1), throwsA(isA<SimklHttpError>()));
      await expectLater(s.checkIn(simklId: 1, title: 'A', episode: 1), throwsA(isA<SimklHttpError>()));
      expect(failing.calls, hasLength(2));
    });
  });

  group('calendar route', () {
    testWidgets('a Simkl account opens Simkl\'s calendar', (tester) async {
      final bloc = _FakeAccountBloc()
        ..state = AccountLoaded(
          selectedAccountType: AccountType.simkl,
          profileImageUrl: null,
          availableAccounts: [Account(name: 'me', typeAcc: AccountType.simkl, imageUrl: '')],
        );
      final keep = SimklDiscoverService.instance;
      addTearDown(() => SimklDiscoverService.instance = keep);
      SimklDiscoverService.instance = SimklDiscoverService(
        cdn: SimklCdn(
          get: (uri, headers) async => http.Response.bytes(utf8.encode('{}'), 200),
          clientId: () => 'cid',
          appVersion: () async => '1.0.0',
        ),
        signedIn: () => false,
      );
      await tester.pumpWidget(BlocProvider<AccountBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppRoutes.openCalendar(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SimklCalendarPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('calendar long press', () {
    Future<(FakeAccount, Widget)> build({required int progress}) async {
      final now = DateTime.utc(2026, 10, 29, 12);
      final account = FakeAccount({
        '/sync/activities': (_) => {},
        '/sync/all-items/anime': (_) => {
              'anime': [listItem(1, 'watching', watched: progress)],
            },
        '/ratings/anime': (_) => [],
        '/sync/history': (_) => {'added': {}},
      });
      final calendar = jsonEncode({
        'calendar': [
          {'simkl_id': 1, 'date': '2026-10-29T11:00:00Z', 'episode': {'episode': 3}},
          {'simkl_id': 2, 'date': '2026-10-29T11:00:00Z', 'episode': {'episode': 5}},
        ],
        'metadata': {
          '1': {'title': 'Mine', 'ids': {'simkl_id': 1}},
          '2': {'title': 'Other', 'ids': {'simkl_id': 2}},
        },
      });
      final cdn = SimklCdn(
        get: (uri, headers) async => http.Response.bytes(utf8.encode(calendar), 200),
        clientId: () => 'cid',
        appVersion: () async => '1.0.0',
      );
      final page = SimklCalendarPage(
        service: SimklDiscoverService(client: account.client, cdn: cdn, signedIn: () => false),
        listService: SimklListService(client: account.client, clock: () => now, owner: () => 'me'),
        now: () => now,
      );
      return (
        account,
        MaterialApp(
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: S.delegate.supportedLocales,
          home: page,
        ),
      );
    }

    testWidgets('long press on an aired listed episode marks it watched after the viewer confirms', (tester) async {
      await initializeDateFormatting('en');
      await S.load(const Locale('en'));
      final (account, app) = await build(progress: 2);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      expect(find.text('Mine'), findsOneWidget);
      await tester.longPress(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(account.calls.where((c) => c.method == 'POST'), isEmpty, reason: 'nothing is written before the confirmation');
      await tester.tap(find.text('Mark Ep. 3 watched'));
      await tester.pumpAndSettle();
      final writes = account.calls.where((c) => c.method == 'POST').toList();
      expect(writes.map((c) => c.url.path), ['/sync/history']);
      expect(find.text('Ep. 3 marked watched'), findsOneWidget);
    });

    testWidgets('an episode already watched, or a title off the list, has no long press action', (tester) async {
      await initializeDateFormatting('en');
      await S.load(const Locale('en'));
      final (account, app) = await build(progress: 3);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Mine'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mark Ep.'), findsNothing);
      expect(account.calls.where((c) => c.method == 'POST'), isEmpty);
    });
  });
}
