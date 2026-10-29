import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/cards/custom_entry_card.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../user-list-mal/fixtures.dart';

ListEntryView _anime(
  int id, {
  ListEntryStatus status = ListEntryStatus.current,
  int progress = 0,
  int total = 12,
  int seconds = 1440,
  int rewatched = 0,
  bool repeating = false,
  String? season,
  int? year,
  List<String> studios = const [],
  String? rating,
  String title = 'T',
}) =>
    ListEntryView(
      id: id,
      malId: id,
      category: 'anime',
      title: title,
      status: status,
      progress: progress,
      total: total,
      episodeSeconds: seconds,
      timesRewatched: rewatched,
      repeating: repeating,
      startSeason: season,
      startSeasonYear: year,
      studios: studios,
      ageRating: rating,
      mediaType: 'tv',
      releaseState: ReleaseState.finished,
    );

/// A non-MyAnimeList tracker; [fills] says whether it declares the episode length.
class _OtherTracker extends FakeListAdapter {
  _OtherTracker(super.all, {required this.fills});
  final bool fills;

  @override
  AccountType get tracker => AccountType.kitsu;

  @override
  bool get fillsEpisodeLength => fills;
}

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: child),
    );

final _actions = EntryActions(
  onOpen: (_) {},
  onEdit: (_) {},
  onStep: null,
  canStep: (_) => false,
  busy: ValueNotifier(const <int>{}),
);

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('time left card field', () {
    test('is a known field, hidden in the default layout, with a label', () {
      final field = ContentCardProps.defaultObject()
          .fields
          .singleWhere((f) => f.type == CustomizableFieldType.time_left);
      expect(field.hidden, isTrue);
      expect(CustomizableFieldType.time_left.label, 'Time left');
      expect(CustomizableFieldType.time_left.description, isNotEmpty);
      // Saved by index: a saved layout reads it back.
      final saved = ContentCardProps.fromJson(
          ContentCardProps.defaultObject().copyWith(fields: [field.copyWith(hidden: false)]).toJson());
      expect(saved.fields.single.type, CustomizableFieldType.time_left);
    });

    Future<void> pumpCard(WidgetTester tester, ListEntryView entry) => tester.pumpWidget(_app(
          CustomEntryCard(
            props: ContentCardProps.defaultObject(),
            fields: const [
              CustomizableField(
                  type: CustomizableFieldType.time_left, position: FieldPosition(top: 10, left: 10)),
            ],
            entry: entry,
            now: DateTime(2026, 10, 29),
            locale: 'en',
            actions: _actions,
          ),
        ));

    testWidgets('renders the time still to watch', (tester) async {
      await pumpCard(tester, _anime(1, progress: 2));
      expect(find.text('4 h 0 min left'), findsOneWidget);
    });

    testWidgets('draws nothing for a completed entry or an unknown length', (tester) async {
      await pumpCard(tester, _anime(1, status: ListEntryStatus.completed, progress: 12));
      expect(find.textContaining('left'), findsNothing);
      await pumpCard(tester, _anime(2, seconds: 0));
      expect(find.textContaining('left'), findsNothing);
    });
  });

  group('filters', () {
    final list = [
      _anime(1, season: 'spring', year: 2024, studios: ['Bones'], rating: 'pg_13'),
      _anime(2, season: 'fall', year: 2023, studios: ['Madhouse', 'MAPPA'], rating: 'r'),
      _anime(3),
    ];
    final manga = [
      const ListEntryView(id: 7, category: 'manga', title: 'M', authors: ['Eiichiro Oda']),
      const ListEntryView(id: 8, category: 'manga', title: 'N', authors: ['Naoki Urasawa']),
    ];

    List<int> ids(List<ListEntryView> from, ListFilter f) =>
        filterEntries(from, f).map((e) => e.id).toList();

    test('facets list the values the entries have', () {
      final facets = {for (final f in facetsFor(list, isAnime: true)) f.key: f};
      expect(facets[ListFacetKeys.season]!.options.map((o) => o.label), ['Spring 2024', 'Fall 2023']);
      expect(facets[ListFacetKeys.studio]!.options.map((o) => o.value), ['Bones', 'Madhouse', 'MAPPA']);
      expect(facets[ListFacetKeys.rating]!.options.map((o) => o.value), ['pg_13', 'r']);
      expect(facets.containsKey(ListFacetKeys.author), isFalse);
      final mangaFacets = facetsFor(manga, isAnime: false).map((f) => f.key);
      expect(mangaFacets, contains(ListFacetKeys.author));
      expect(mangaFacets, isNot(contains(ListFacetKeys.studio)));
    });

    test('season narrows the list', () {
      expect(ids(list, ListFilter.none.toggle(ListFacetKeys.season, '2024:spring')), [1]);
      final excluded = ListFilter.none
          .toggle(ListFacetKeys.season, '2024:spring', allowExclude: true)
          .toggle(ListFacetKeys.season, '2024:spring', allowExclude: true);
      expect(ids(list, excluded), [2, 3]);
    });

    test('studio narrows the list', () {
      expect(ids(list, ListFilter.none.toggle(ListFacetKeys.studio, 'MAPPA')), [2]);
      expect(
          ids(list,
              ListFilter.none.toggle(ListFacetKeys.studio, 'Bones').toggle(ListFacetKeys.studio, 'MAPPA')),
          [1, 2]);
    });

    test('author narrows the list', () {
      expect(ids(manga, ListFilter.none.toggle(ListFacetKeys.author, 'Naoki Urasawa')), [8]);
    });

    test('rating narrows the list', () {
      expect(ids(list, ListFilter.none.toggle(ListFacetKeys.rating, 'r')), [2]);
    });
  });

  group('rewatch badge', () {
    Future<void> pumpRow(WidgetTester tester, ListEntryView entry) => tester.pumpWidget(_app(
          SizedBox(
            height: listRowExtent(DisplaySubType.comfortable),
            child: EntryListTile(
              entry: entry,
              subType: DisplaySubType.comfortable,
              actions: _actions,
              style: const EntryCardStyle(),
              now: DateTime(2026, 10, 29),
              locale: 'en',
            ),
          ),
        ));

    testWidgets('shows "Rewatched ×N" when N > 0', (tester) async {
      await pumpRow(tester, _anime(1, rewatched: 2));
      expect(find.text('Rewatched ×2'), findsOneWidget);
    });

    testWidgets('shows nothing when never rewatched', (tester) async {
      await pumpRow(tester, _anime(1));
      expect(find.textContaining('Rewatched'), findsNothing);
      expect(find.byIcon(Icons.replay_rounded), findsNothing);
    });

    testWidgets('manga says "Reread", grid covers the short form', (tester) async {
      await tester.pumpWidget(_app(const RewatchPill(
          entry: ListEntryView(id: 1, category: 'manga', title: 'M', timesRewatched: 3))));
      expect(find.text('Reread ×3'), findsOneWidget);
      await tester.pumpWidget(_app(RewatchPill(entry: _anime(1, rewatched: 3), short: true)));
      expect(find.text('×3'), findsOneWidget);
      expect(find.bySemanticsLabel('Rewatched ×3'), findsOneWidget);
    });
  });

  group('time watched counts rewatches', () {
    test('completed rewatches add full runs, a rewatch in progress adds the first run', () {
      // 12 episodes of 24 min, watched once then rewatched twice: 3 runs.
      expect(timeWatchedWithRewatches(
              _anime(1, status: ListEntryStatus.completed, progress: 12, rewatched: 2)),
          const Duration(minutes: 24 * 36));
      // Rewatching, at episode 3 of the second run.
      expect(timeWatchedWithRewatches(
              _anime(2, status: ListEntryStatus.completed, progress: 3, repeating: true)),
          const Duration(minutes: 24 * 15));
      // Unknown total: only the progress counts.
      expect(timeWatchedWithRewatches(_anime(3, progress: 5, total: 0, rewatched: 2)),
          const Duration(minutes: 24 * 5));
    });

    test('the tab line uses it; time left ignores rewatches', () {
      final done = [_anime(1, status: ListEntryStatus.completed, progress: 12, rewatched: 1)];
      final watched = listTimeSummary(done, ListEntryStatus.completed)!;
      expect(watched.kind, ListTimeKind.watched);
      expect(watched.total, const Duration(minutes: 24 * 24));
      final left = listTimeSummary([_anime(2, progress: 2, rewatched: 4)], ListEntryStatus.current)!;
      expect(left.total, const Duration(minutes: 24 * 10));
    });
  });

  group('time line for every tracker', () {
    late ListStatusCache cache;
    setUp(() => cache = ListStatusCache(saveDelay: const Duration(days: 1)));
    tearDown(() => cache.dispose());

    Future<void> pumpList(WidgetTester tester, FakeListAdapter adapter) async {
      await tester.pumpWidget(_app(UserListView(
        adapter: adapter,
        cache: cache,
        titleBuilder: (context, categorySwitch) => categorySwitch,
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('a non-MyAnimeList adapter that fills durations gets the line', (tester) async {
      await pumpList(
          tester,
          _OtherTracker([
            _anime(1, status: ListEntryStatus.completed, progress: 12, rewatched: 1, title: 'Monster'),
          ], fills: true));
      expect(find.text('Time watched: 9 h 36 min'), findsOneWidget);
      cache.resetForTest();
    });

    testWidgets('an adapter that does not declare it has no line', (tester) async {
      await pumpList(
          tester,
          _OtherTracker([
            _anime(1, status: ListEntryStatus.completed, progress: 12, title: 'Monster'),
          ], fills: false));
      expect(find.textContaining('Time watched'), findsNothing);
      cache.resetForTest();
    });
  });
}
