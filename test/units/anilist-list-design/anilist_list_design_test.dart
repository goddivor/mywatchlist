import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_list_look.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_list_tab.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_list_view.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';

// Fakes only: the AniList answer is a saved response read from disk, every write lands in a
// fake client, nothing reaches AniList and no account is written.

Map<String, dynamic> _saved({String format = 'POINT_100'}) {
  final json = jsonDecode(File('test/units/anilist-list-design/media_list_collection.json')
      .readAsStringSync()) as Map<String, dynamic>;
  final collection = json['data']['MediaListCollection'] as Map<String, dynamic>;
  (collection['user']['mediaListOptions'] as Map<String, dynamic>)['scoreFormat'] = format;
  return json;
}

AnilistListService _service({String format = 'POINT_100'}) => AnilistListService(
      client: AnilistGraphql(
        sender: (body, {required auth}) async =>
            http.Response(jsonEncode(_saved(format: format)), 200),
        mutationSender: (body, {required auth}) async =>
            throw StateError('the list never writes by itself'),
      ),
      owner: () => 'me',
      titleLang: () => 'ro',
    );

class _FakeSync implements TrackerEntryClient {
  final writes = <SyncEntry>[];
  @override
  AccountType get tracker => AccountType.anilist;
  @override
  bool supports({required bool isAnime}) => true;
  @override
  Future<SyncEntry?> read(String mediaId, {required bool isAnime, int? malId}) async => null;
  @override
  Future<SyncEntry> write(String mediaId, SyncEntry entry,
      {required bool isAnime, int? malId}) async {
    writes.add(entry);
    return entry;
  }

  @override
  Future<void> delete(String mediaId, {required bool isAnime, int? malId}) async {}
  @override
  Future<String?> findByMalId(int malId, {required bool isAnime}) async => null;
}

AnilistUserListAdapter _adapter(AnilistListService service, {_FakeSync? sync}) =>
    AnilistUserListAdapter(
      service: service,
      sync: TrackerSyncService(clients: {AccountType.anilist: sync ?? _FakeSync()}),
      clock: () => DateTime(2026, 10, 29),
      opener: (context, {required category, required id}) async {},
    );

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    );

final _noActions = EntryActions(
  onOpen: (_) {},
  onEdit: (_) {},
  onStep: (_, __) {},
  canStep: (_) => true,
  busy: ValueNotifier(const <int>{}),
);

/// Lets the status cache's delayed save run before the test ends.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('score display rules', () {
    test('the user score follows the account format', () {
      String? text(AnilistScoreFormat f, int raw) => anilistUserScoreText(raw, f)?.text;
      expect(text(AnilistScoreFormat.point100, 73), '73');
      expect(text(AnilistScoreFormat.point10Decimal, 85), '8.5');
      expect(text(AnilistScoreFormat.point10Decimal, 80), '8');
      expect(text(AnilistScoreFormat.point10, 73), '7');
      final stars = anilistUserScoreText(85, AnilistScoreFormat.point5)!;
      expect(stars.text, '4');
      expect(stars.icon, Icons.star_rounded);
      expect(stars.spoken, '4 out of 5 stars');
      final face = anilistUserScoreText(85, AnilistScoreFormat.point3)!;
      expect(face.icon, Icons.sentiment_satisfied_alt_rounded);
      expect(anilistUserScoreText(30, AnilistScoreFormat.point3)!.icon,
          Icons.sentiment_dissatisfied_rounded);
      expect(anilistUserScoreText(0, AnilistScoreFormat.point100), isNull, reason: '0 = not scored');
    });

    test('community scores are percentages with anilist.co faces', () {
      const e = ListEntryView(id: 1, category: 'anime', title: 'T', meanScore: 8.2);
      expect(anilistPercentOf(e), 82);
      expect(anilistPercentText(e)!.text, '82%');
      expect(anilistPercentIcon(82), Icons.sentiment_satisfied_alt_rounded);
      expect(anilistPercentIcon(60), Icons.sentiment_neutral_rounded);
      expect(anilistPercentIcon(40), Icons.sentiment_dissatisfied_rounded);
      expect(anilistPercentText(const ListEntryView(id: 2, category: 'anime', title: 'T')),
          isNull);
    });
  });

  group('adapter look on the saved response', () {
    test('scores, words and marks are AniList\'s', () async {
      final service = _service();
      final adapter = _adapter(service);
      final rows = await service.all('anime');
      final frieren = rows.firstWhere((e) => e.id == 1);
      expect(frieren.score, 7, reason: 'the shared row keeps a rounded 0-10');
      expect(adapter.userScore(frieren)!.text, '73', reason: 'POINT_100 from scoreRaw');
      expect(adapter.meanScore(frieren)!.text, '80%');
      expect(adapter.statusLabel(ListEntryStatus.onHold, isAnime: true), 'Paused');
      expect(adapter.statusLabel(ListEntryStatus.planned, isAnime: true), 'Planning');
      final badges = adapter.cardBadges(frieren);
      expect(badges.map((b) => b.icon), [
        Icons.sticky_note_2_outlined,
        Icons.lock_outline_rounded,
        Icons.flag_outlined,
      ]);
      expect(badges.first.detail, 'Watch with subs');
      expect(adapter.fillsEpisodeLength, isTrue);
    });

    test('another score format changes every score', () async {
      final service = _service(format: 'POINT_5');
      final adapter = _adapter(service);
      final rows = await service.all('anime');
      final mushishi = rows.firstWhere((e) => e.id == 3);
      expect(adapter.scoreFormatOf('anime'), AnilistScoreFormat.point5);
      expect(adapter.userScore(mushishi)!.text, '4');
      expect(adapter.userScore(rows.firstWhere((e) => e.id == 2)), isNull);
    });
  });

  group('quick +1', () {
    test('the last episode completes, or only moves the progress when told so', () async {
      final sync = _FakeSync();
      final service = _service();
      final adapter = _adapter(service, sync: sync);
      final rows = await service.all('anime');
      final dandadan = rows.firstWhere((e) => e.id == 2);
      expect(adapter.completesOnStep(dandadan, 1), isTrue);
      expect(adapter.completesOnStep(dandadan, -1), isFalse);

      final only = await adapter.step(dandadan, 1, complete: false);
      expect(sync.writes.last.status, 'watching');
      expect(sync.writes.last.progress, 12);
      expect(only.status, ListEntryStatus.current);

      final done = await adapter.step(dandadan, 1);
      expect(sync.writes.last.status, 'completed');
      expect(done.listFinishDate, '2026-10-29');
      expect(sync.writes.every((w) => w.score == null), isTrue, reason: 'never the score');
    });

    test('the first episode of a Planning entry starts it today', () async {
      final sync = _FakeSync();
      final service = _service();
      final adapter = _adapter(service, sync: sync);
      final monster = (await service.all('anime')).firstWhere((e) => e.id == 4);
      final started = await adapter.step(monster, 1);
      expect(sync.writes.last.status, 'watching');
      expect(sync.writes.last.startDate, '2026-10-29');
      expect(started.listStartDate, '2026-10-29');

      // An entry that already has a start date keeps it (nothing sent).
      await adapter.step(started, 1);
      expect(sync.writes.last.startDate, isNull);
    });
  });

  group('AniList row', () {
    Future<void> pumpRow(WidgetTester tester, ListEntryView e, AnilistListEntry? d,
        {AnilistScoreFormat format = AnilistScoreFormat.point100,
        bool compact = false,
        bool showStatus = false,
        double textScale = 1}) async {
      await tester.pumpWidget(_app(
        Center(
          child: SizedBox(
            width: 360,
            height: anilistRowExtent(compact: compact, scaler: TextScaler.linear(textScale)),
            child: AnilistEntryRow(
              entry: e,
              detail: d,
              format: format,
              compact: compact,
              actions: _noActions,
              style: EntryCardStyle(showStatus: showStatus),
              now: DateTime.utc(2026, 10, 29),
            ),
          ),
        ),
        textScale: textScale,
      ));
    }

    testWidgets('score in the account format, % and the label rail', (tester) async {
      final service = _service();
      final rows = await tester.runAsync(() => service.all('anime'));
      final frieren = rows!.firstWhere((e) => e.id == 1);
      final detail = service.detailOf('anime', 1);
      await pumpRow(tester, frieren, detail, showStatus: true);
      expect(find.text('73'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      final rail = find.textContaining('2 behind', findRichText: true);
      expect(rail, findsOneWidget);
      expect(find.textContaining('TV', findRichText: true), findsWidgets);
      expect(find.textContaining('Watching', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stars and faces are drawn, not numbers', (tester) async {
      final service = _service(format: 'POINT_5');
      final rows = await tester.runAsync(() => service.all('anime'));
      final mushishi = rows!.firstWhere((e) => e.id == 3);
      await pumpRow(tester, mushishi, service.detailOf('anime', 3),
          format: AnilistScoreFormat.point5);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);

      await pumpRow(tester, mushishi, service.detailOf('anime', 3),
          format: AnilistScoreFormat.point3);
      expect(find.byIcon(Icons.sentiment_satisfied_alt_rounded), findsWidgets);
    });

    testWidgets('fits 360 dp in both densities, large text included', (tester) async {
      final service = _service();
      final rows = await tester.runAsync(() => service.all('anime'));
      for (final e in rows!) {
        for (final compact in [false, true]) {
          await pumpRow(tester, e, service.detailOf('anime', e.id),
              compact: compact, showStatus: true, textScale: 1.3);
          expect(tester.takeException(), isNull, reason: '${e.title} compact=$compact');
        }
      }
    });
  });

  group('list view', () {
    Future<(AnilistUserListAdapter, _FakeSync)> pumpList(WidgetTester tester) async {
      final sync = _FakeSync();
      final service = _service();
      final adapter = _adapter(service, sync: sync);
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(AnilistListView(
        adapter: adapter,
        titleBuilder: (context, categorySwitch) => categorySwitch,
        cache: ListStatusCache(),
      )));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      return (adapter, sync);
    }

    testWidgets('sections in the account order with custom lists, AniList scores in the rows',
        (tester) async {
      await pumpList(tester);
      for (final label in ['All', 'Watching', 'Completed', 'Paused', 'Planning', 'Favourites']) {
        expect(find.textContaining(label), findsWidgets, reason: label);
      }
      // The section adapters carry AniList's look: 73 (POINT_100), not the rounded 7.
      expect(find.text('73'), findsOneWidget);
      expect(find.text('7'), findsNothing);
      expect(find.text('80%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _settle(tester);
    });

    testWidgets('the +1 to the last episode asks first; "Only +1" does not complete',
        (tester) async {
      final (_, sync) = await pumpList(tester);
      final dandadanRow = find.ancestor(
          of: find.text('Dandadan'), matching: find.byType(AnilistEntryRow));
      final plus = find.descendant(
          of: dandadanRow, matching: find.byTooltip(S.current.UserList_Plus_One));
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(find.text(S.current.Ald_Complete_Title), findsOneWidget);
      expect(sync.writes, isEmpty, reason: 'nothing is written before the answer');

      await tester.tap(find.text(S.current.Ald_Complete_Only_Progress));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
      expect(sync.writes.single.status, 'watching');
      expect(sync.writes.single.progress, 12);
      await _settle(tester);
    });
  });
}
