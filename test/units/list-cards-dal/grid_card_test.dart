import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

ListEntryView _entry(
  int id, {
  String title = 'Frieren',
  ListEntryStatus? status = ListEntryStatus.current,
  int progress = 4,
  int total = 12,
  double? mean = 8.1,
  ReleaseState release = ReleaseState.finished,
  String? releaseStart,
  List<String> genres = const ['Adventure', 'Drama', 'Fantasy', 'Shounen'],
}) =>
    ListEntryView(
      id: id,
      malId: id,
      category: 'anime',
      title: title,
      status: status,
      progress: progress,
      total: total,
      meanScore: mean,
      mediaType: 'tv',
      releaseState: release,
      releaseStart: releaseStart,
      genres: genres,
    );

class _Recorder {
  final opened = <int>[];
  final edited = <int>[];

  late final actions = EntryActions(
    onOpen: (e) => opened.add(e.id),
    onEdit: (e) => edited.add(e.id),
    onStep: null,
    canStep: (_) => false,
    busy: ValueNotifier(const <int>{}),
  );
}

Future<void> _pumpGrid(
  WidgetTester tester,
  List<ListEntryView> entries,
  _Recorder rec, {
  DisplaySubType subType = DisplaySubType.comfortable,
  Locale locale = const Locale('en'),
  double textScale = 1,
  double extent = 250,
  int columns = 3,
  PreferencesBloc? prefs,
}) async {
  Widget grid = GridView.builder(
    padding: const EdgeInsets.all(10),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent: extent,
      crossAxisSpacing: 8,
      mainAxisSpacing: 10,
    ),
    itemCount: entries.length,
    itemBuilder: (context, i) => EntryGridCard(
      key: ValueKey(entries[i].id),
      entry: entries[i],
      subType: subType,
      actions: rec.actions,
      style: const EntryCardStyle(),
      now: DateTime(2026, 10, 27),
    ),
  );
  if (prefs != null) grid = BlocProvider.value(value: prefs, child: grid);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: const Size(400, 800), textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: grid),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('grid card shows score, status chip, one-line title and genres', (tester) async {
    final rec = _Recorder();
    await _pumpGrid(tester, [_entry(1)], rec);

    expect(find.text('8.10'), findsOneWidget);
    expect(find.text('CW'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    final title = tester.widget<Text>(find.text('Frieren'));
    expect(title.maxLines, 1);
    // DailyAL shows the first three genres.
    expect(find.text('Adventure, Drama, Fantasy'), findsOneWidget);
    // No progress text on the grid card.
    expect(find.textContaining('/ 12'), findsNothing);

    await tester.tap(find.byType(GridCardBar));
    await tester.pumpAndSettle();
    expect(rec.edited, [1]);
    await tester.tap(find.text('Frieren'));
    await tester.pumpAndSettle();
    expect(rec.opened, [1]);
    await tester.longPress(find.byType(EntryCover));
    await tester.pumpAndSettle();
    expect(rec.edited, [1, 1]);
  });

  testWidgets('a missing mean score shows a dash', (tester) async {
    await _pumpGrid(tester, [_entry(1, mean: null)], _Recorder());
    expect(find.text('-'), findsOneWidget);
  });

  testWidgets('every card of a row has the same cover height whatever the title', (tester) async {
    await _pumpGrid(
      tester,
      [
        _entry(1, title: 'K'),
        _entry(2, title: 'A very long title that would wrap on two or even three lines in a cell'),
        _entry(3, title: 'Mid length title here'),
      ],
      _Recorder(),
    );
    final heights = tester
        .widgetList(find.byType(EntryCover))
        .map((w) => tester.getSize(find.byWidget(w)).height)
        .toSet();
    expect(heights.length, 1);
    final cards = tester
        .widgetList(find.byType(EntryGridCard))
        .map((w) => tester.getSize(find.byWidget(w)).height)
        .toSet();
    expect(cards, {250});
  });

  testWidgets('large text scale never overflows the smallest grid height', (tester) async {
    await _pumpGrid(tester, [_entry(1, title: 'A long title for the overflow check')], _Recorder(),
        textScale: 2, extent: 160, columns: 6);
    expect(tester.takeException(), isNull);
    await _pumpGrid(tester, [_entry(1)], _Recorder(),
        subType: DisplaySubType.compact, textScale: 2, extent: 160, columns: 6);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hide score hides the mean behind a tap to reveal', (tester) async {
    final bloc = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
    addTearDown(bloc.close);
    bloc.add(ContentPreferencesChanged((p) => p.copyWith(hideScore: true)));
    await tester.pumpAndSettle();
    await _pumpGrid(tester, [_entry(1)], _Recorder(), prefs: bloc);
    expect(find.text('8.10'), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.text('8.10'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('French labels on the grid card', (tester) async {
    await _pumpGrid(
      tester,
      [
        _entry(1),
        _entry(2, status: ListEntryStatus.completed, progress: 12),
        _entry(3, status: ListEntryStatus.planned, progress: 0),
      ],
      _Recorder(),
      locale: const Locale('fr', 'FR'),
    );
    expect(find.text('EC'), findsOneWidget);
    expect(find.text('FIN'), findsOneWidget);
    expect(find.text('PRÉ'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('12 épisodes diffusés, 8 épisodes non vus')), findsOneWidget);
  });

  group('episode badges', () {
    testWidgets('grid: blue released and red unseen', (tester) async {
      await _pumpGrid(tester, [_entry(1, progress: 4)], _Recorder());
      expect(find.text('12'), findsOneWidget);
      expect(find.text('+8'), findsOneWidget);
    });

    testWidgets('grid: only red when nothing is watched, nothing when caught up', (tester) async {
      await _pumpGrid(
        tester,
        [_entry(1, progress: 0), _entry(2, progress: 12, status: ListEntryStatus.completed)],
        _Recorder(),
      );
      expect(find.text('+12'), findsOneWidget);
      expect(find.text('12'), findsNothing);
      expect(find.textContaining('+'), findsOneWidget);
    });

    testWidgets('cover only and compact grids show both badges', (tester) async {
      for (final subType in [DisplaySubType.cover_only_grid, DisplaySubType.compact]) {
        await _pumpGrid(tester, [_entry(1, progress: 4)], _Recorder(), subType: subType);
        expect(find.text('12'), findsOneWidget, reason: '$subType');
        expect(find.text('+8'), findsOneWidget, reason: '$subType');
      }
    });

    testWidgets('a list row printing the progress shows only the red badge', (tester) async {
      final rec = _Recorder();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: ListView(
            itemExtent: listRowExtent(DisplaySubType.comfortable),
            children: [
              EntryListTile(
                entry: _entry(1, progress: 4),
                subType: DisplaySubType.comfortable,
                actions: rec.actions,
                style: const EntryCardStyle(),
                now: DateTime(2026, 10, 27),
                locale: 'en',
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('4 / 12 ep.'), findsOneWidget);
      expect(find.text('+8'), findsOneWidget);
      expect(find.text('12'), findsNothing);
    });

    testWidgets('the calendar schedule gives the aired count of an airing anime', (tester) async {
      final previous = AiringSchedule.instance;
      addTearDown(() => AiringSchedule.instance = previous);
      final next = DateTime.now().toUtc().add(const Duration(days: 2));
      AiringSchedule.instance = AiringSchedule(
        fetcher: ({required bool fromCache}) async => [
          LiveChartEpisode(timestamp: next.millisecondsSinceEpoch ~/ 1000, episode: 7, malId: 1),
        ],
      );
      await _pumpGrid(
        tester,
        [
          _entry(1, progress: 2, total: 0, release: ReleaseState.releasing, releaseStart: '2026-09-01'),
        ],
        _Recorder(),
      );
      // Episode 7 airs next: 6 aired, 2 watched.
      expect(find.text('6'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
    });
  });

  group('released count', () {
    tearDown(() => AiringSchedule.instance.reset());

    test('weekly estimate for an airing tv series with a known total', () {
      final e = _entry(99, progress: 1, release: ReleaseState.releasing, releaseStart: '2026-10-04');
      expect(e.releasedCount(DateTime(2026, 10, 27)), 4);
      expect(e.unseenCount(DateTime(2026, 10, 27)), 3);
    });

    test('unknown when the estimate passes the total or the total is unknown', () {
      final late = _entry(99, total: 2, release: ReleaseState.releasing, releaseStart: '2026-09-01');
      expect(late.releasedCount(DateTime(2026, 10, 27)), isNull);
      final open = _entry(99, total: 0, release: ReleaseState.releasing, releaseStart: '2026-09-01');
      expect(open.releasedCount(DateTime(2026, 10, 27)), isNull);
      expect(open.unseenCount(DateTime(2026, 10, 27)), 0);
    });

    test('finished: the total, when known', () {
      expect(_entry(99).releasedCount(DateTime(2026, 10, 27)), 12);
      expect(_entry(99, total: 0).releasedCount(DateTime(2026, 10, 27)), isNull);
    });
  });

  test('statuses read their colours from the theme tokens', () {
    expect(ListEntryStatus.values.map((s) => s.tone).toSet().length, 5);
  });
}
