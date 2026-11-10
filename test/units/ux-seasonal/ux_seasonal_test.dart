import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplayType;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_data.dart';
import 'package:mywatchlist/screens/seasonal/seasonal_screen.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records the writes; never touches a real list.
class _FakeAdapter extends UserListAdapter {
  final List<(int, int)> steps = [];

  @override
  AccountType get tracker => AccountType.myanimelist;
  @override
  String? get owner => 'tester';
  @override
  int get maxPageSize => 500;
  @override
  List<ListSortOption> sortOptions(String category) => const [];
  @override
  String? apiSort(String category, String sortKey, SortDirection direction) => null;
  @override
  Future<ListPage> fetch({
    required String category,
    required ListEntryStatus? status,
    required int offset,
    required int limit,
    String? apiSort,
  }) async =>
      const ListPage([], hasMore: false);
  @override
  Future<Map<ListEntryStatus, int>?> statusCounts(String category) async => null;
  @override
  void open(BuildContext context, ListEntryView entry) {}
  @override
  Future<ListEditResult> edit(BuildContext context, ListEntryView entry) async =>
      const ListEditUnchanged();
  @override
  bool canStep(ListEntryView entry) => entry.status != null;
  @override
  Future<ListEntryView> step(ListEntryView entry, int delta) async {
    steps.add((entry.id, delta));
    return entry.copyWith(progress: entry.progress + delta);
  }

  @override
  Future<void> signInAgain(BuildContext context) async {}
}

const _watching = ListEntryView(
  id: 1,
  malId: 1,
  category: 'anime',
  title: 'Watched Show',
  meanScore: 8.1,
  total: 12,
  status: ListEntryStatus.current,
  progress: 3,
);

const _notListed = ListEntryView(
  id: 2,
  malId: 2,
  category: 'anime',
  title: 'Other Show',
  meanScore: 7.2,
  total: 24,
);

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('season tabs', () {
    test('newest first, DailyAL order, every season down to 1960', () {
      final tabs = seasonTabs(DateTime(2026, 10, 28));
      expect(tabs.take(5), const [
        SeasonKey(SeasonType.FALL, 2027),
        SeasonKey(SeasonType.SUMMER, 2027),
        SeasonKey(SeasonType.SPRING, 2027),
        SeasonKey(SeasonType.WINTER, 2027),
        SeasonKey(SeasonType.FALL, 2026),
      ]);
      expect(tabs.last, const SeasonKey(SeasonType.WINTER, kFirstSeasonYear));
      expect(tabs.length, (2027 - kFirstSeasonYear + 1) * 4);
      expect(tabs.toSet().length, tabs.length);
    });
  });

  test('seasons open in list rows by default', () {
    expect(SeasonalData.defaults().display.type, DisplayType.list_vert);
  });

  Future<_FakeAdapter> pumpSeason(WidgetTester tester, {required bool signedIn}) async {
    final adapter = _FakeAdapter();
    await tester.pumpWidget(MaterialApp(
      home: SeasonalScreen(
        initial: const SeasonKey(SeasonType.FALL, 2026),
        loader: (season, {bool force = false}) async => [_watching, _notListed],
        adapter: adapter,
        malSignedIn: () => signedIn,
        cache: ListStatusCache(saveDelay: Duration.zero),
      ),
    ));
    await tester.pumpAndSettle();
    return adapter;
  }

  testWidgets('header: "Seasonal" and season tabs, the season named once', (tester) async {
    await pumpSeason(tester, signedIn: false);
    expect(find.text(S.current.Seasonal), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Fall 2026'), findsOneWidget);
    expect(find.byTooltip(S.current.Seasonal_Previous), findsNothing);
    expect(find.text(S.current.Seasonal_Count(2)), findsNothing);
    expect(find.text('Watched Show'), findsOneWidget);
    // Not signed in to MyAnimeList: no list writes offered.
    expect(find.byTooltip(S.current.UserList_Plus_One), findsNothing);
    expect(find.byTooltip(S.current.UserList_Edit_Entry), findsNothing);
  });

  testWidgets('signed in: +1 writes through the adapter and the row follows', (tester) async {
    final adapter = await pumpSeason(tester, signedIn: true);
    expect(find.text(S.current.UserList_Progress_Episodes('3', '12')), findsOneWidget);
    // Only the listed entry can step; both can be edited (the unlisted one to add it).
    expect(find.byTooltip(S.current.UserList_Plus_One), findsOneWidget);
    expect(find.byTooltip(S.current.UserList_Edit_Entry), findsNWidgets(2));

    await tester.tap(find.byTooltip(S.current.UserList_Plus_One));
    await tester.pumpAndSettle();
    expect(adapter.steps, [(1, 1)]);
    expect(find.text(S.current.UserList_Progress_Episodes('4', '12')), findsOneWidget);
  });

  testWidgets('tapping another season tab loads it', (tester) async {
    final asked = <SeasonKey>[];
    await tester.pumpWidget(MaterialApp(
      home: SeasonalScreen(
        initial: const SeasonKey(SeasonType.FALL, 2026),
        loader: (season, {bool force = false}) async {
          asked.add(season);
          return const [_notListed];
        },
        adapter: _FakeAdapter(),
        malSignedIn: () => false,
        cache: ListStatusCache(saveDelay: Duration.zero),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Winter 2027'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Winter 2027'));
    await tester.pumpAndSettle();
    expect(asked, const [SeasonKey(SeasonType.FALL, 2026), SeasonKey(SeasonType.WINTER, 2027)]);
  });
}
