import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../user-list-mal/fixtures.dart';

ListEntryView _anime(
  int id, {
  ListEntryStatus? status = ListEntryStatus.current,
  int progress = 0,
  int total = 12,
  int seconds = 1440,
  int score = 0,
  double? mean,
  String title = 'T',
  ReleaseState releaseState = ReleaseState.finished,
  BroadcastSlot? broadcast,
  int priority = 0,
  int rewatched = 0,
}) =>
    ListEntryView(
      id: id,
      category: 'anime',
      title: title,
      status: status,
      progress: progress,
      total: total,
      episodeSeconds: seconds,
      score: score,
      meanScore: mean,
      mediaType: 'tv',
      releaseState: releaseState,
      broadcast: broadcast,
      priority: priority,
      timesRewatched: rewatched,
      genres: const ['Action', 'Drama'],
    );

/// A tracker with its own wording, scores, badges and follow-up, fakes only.
class _HookedTracker extends FakeListAdapter {
  _HookedTracker(super.all);

  final List<(ListEntryView, ListEntryView)> followUps = [];

  @override
  AccountType get tracker => AccountType.kitsu;

  @override
  String statusLabel(ListEntryStatus status, {required bool isAnime}) =>
      status == ListEntryStatus.planned ? 'Want to watch' : super.statusLabel(status, isAnime: isAnime);

  @override
  String statusShortLabel(ListEntryStatus status, {required bool isAnime}) => 'K${status.index}';

  @override
  ListScoreText? userScore(ListEntryView entry) =>
      entry.score > 0 ? ListScoreText('${entry.score * 10}pts', spoken: 'Rated ${entry.score}') : null;

  @override
  ListScoreText? meanScore(ListEntryView entry) =>
      entry.meanScore == null ? null : ListScoreText('${(entry.meanScore! * 10).round()}%');

  @override
  List<ListCardBadge> cardBadges(ListEntryView entry) => [
        if (entry.id == 1)
          const ListCardBadge(icon: Icons.chat_bubble_rounded, label: 'So good', detail: 'Your reaction: So good'),
      ];

  @override
  Future<ListEntryView?> afterStep(BuildContext context, ListEntryView saved,
      {required ListEntryView before}) async {
    followUps.add((before, saved));
    // The tracker's prompt answered: a rating lands on the row.
    return saved.copyWith(score: 9);
  }
}

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

final _actions = EntryActions(
  onOpen: (_) {},
  onEdit: (_) {},
  onStep: null,
  canStep: (_) => false,
  busy: ValueNotifier(const <int>{}),
);

Widget _scoped(ListEntryLook look, Widget child) => ListEntryLookScope(look: look, child: child);

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('look hooks on the cards', () {
    final look = _HookedTracker(const []);

    Widget row(ListEntryView entry, {ListEntryLook? with_}) {
      final tile = SizedBox(
        width: 400,
        height: listRowExtent(DisplaySubType.comfortable),
        child: EntryListTile(
          entry: entry,
          subType: DisplaySubType.comfortable,
          actions: _actions,
          style: const EntryCardStyle(),
          now: DateTime.utc(2026, 10, 29),
          locale: 'en',
        ),
      );
      return with_ == null ? tile : _scoped(with_, tile);
    }

    testWidgets('the status pill uses the tracker wording', (tester) async {
      await tester.pumpWidget(_app(row(_anime(2, status: ListEntryStatus.planned), with_: look)));
      expect(find.text('Want to watch'), findsOneWidget);
      await tester.pumpWidget(_app(row(_anime(2, status: ListEntryStatus.planned))));
      expect(find.text('Want to watch'), findsNothing);
      expect(find.text('Plan to watch'), findsOneWidget);
    });

    testWidgets('user and community scores use the tracker display', (tester) async {
      await tester.pumpWidget(_app(row(_anime(2, score: 8, mean: 8.4), with_: look)));
      expect(find.text('80pts'), findsOneWidget);
      expect(find.text('84%'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Rated 8')), findsOneWidget);
      // Defaults: MyAnimeList's 0-10 and two decimals.
      await tester.pumpWidget(_app(row(_anime(2, score: 8, mean: 8.4))));
      expect(find.text('8'), findsOneWidget);
      expect(find.text('8.40'), findsOneWidget);
    });

    testWidgets('card badges show on rows and grid covers', (tester) async {
      await tester.pumpWidget(_app(row(_anime(1), with_: look)));
      expect(find.text('So good'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      await tester.pumpWidget(_app(_scoped(
          look,
          SizedBox(
            width: 160,
            height: 280,
            child: EntryGridCard(
              entry: _anime(1),
              subType: DisplaySubType.comfortable,
              actions: _actions,
              style: const EntryCardStyle(),
              now: DateTime.utc(2026, 10, 29),
            ),
          ))));
      expect(find.byIcon(Icons.chat_bubble_rounded), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Your reaction: So good')), findsOneWidget);
      // No badge for an entry the tracker does not mark.
      await tester.pumpWidget(_app(row(_anime(2), with_: look)));
      expect(find.byIcon(Icons.chat_bubble_rounded), findsNothing);
    });

    testWidgets('the grid bar and edit button use the hooks', (tester) async {
      await tester.pumpWidget(_app(_scoped(
          look,
          Column(children: [
            GridCardBar(entry: _anime(2, mean: 7.9), onEdit: () {}),
            GridEditButton(entry: _anime(2, score: 7), onEdit: () {}),
          ]))));
      expect(find.text('K0'), findsOneWidget);
      expect(find.text('79%'), findsOneWidget);
      expect(find.text('70pts'), findsOneWidget);
    });
  });

  group('UserListView with a hooked adapter', () {
    late ListStatusCache cache;
    setUp(() => cache = ListStatusCache(saveDelay: const Duration(days: 1)));
    tearDown(() => cache.dispose());

    testWidgets('tab labels come from the adapter', (tester) async {
      await tester.pumpWidget(_app(UserListView(
        adapter: _HookedTracker([_anime(1, status: ListEntryStatus.planned, title: 'Mushishi')]),
        cache: cache,
        titleBuilder: (context, categorySwitch) => categorySwitch,
      )));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(TabBar), matching: find.text('Want to watch')),
          findsOneWidget);
      expect(find.descendant(of: find.byType(TabBar), matching: find.text('Plan to watch')),
          findsNothing);
      cache.resetForTest();
    });

    testWidgets('a quick +1 calls afterStep with a context and applies its answer',
        (tester) async {
      final adapter = _HookedTracker([_anime(5, progress: 11, title: 'Last one')]);
      await tester.pumpWidget(_app(UserListView(
        adapter: adapter,
        cache: cache,
        titleBuilder: (context, categorySwitch) => categorySwitch,
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      expect(adapter.steps, [(5, 1)]);
      expect(adapter.followUps, hasLength(1));
      expect(adapter.followUps.single.$1.progress, 11);
      expect(adapter.followUps.single.$2.progress, 12);
      // The follow-up's rating is on the row.
      expect(find.text('90pts'), findsWidgets);
      cache.resetForTest();
    });
  });

  group('time line', () {
    test('only the MyAnimeList adapter declares the episode length by default', () {
      expect(MalUserListAdapter(get: (_) => throw UnimplementedError()).fillsEpisodeLength, isTrue);
      expect(FakeListAdapter(const []).fillsEpisodeLength, isFalse);
      expect(SimklUserListAdapter(service: SimklListService(), owner: () => 'me').fillsEpisodeLength,
          isFalse);
    });

    test('MyAnimeList line unchanged; the legacy ListTimeSummary.of agrees without rewatches', () {
      final entries = [_anime(1, progress: 2), _anime(2, status: ListEntryStatus.planned)];
      final left = listTimeSummary(entries, ListEntryStatus.planned)!;
      expect(left.label(), 'Time left: 8 h 48 min');
      expect(ListTimeSummary.of(entries, ListEntryStatus.planned)!.label(), left.label());
    });

    test('an airing show without an episode total marks the time left partial', () {
      final airing = _anime(3, total: 0, progress: 4, releaseState: ReleaseState.releasing);
      expect(airing.timeLeft, isNull);
      expect(airing.hasUnknownTimeLeft, isTrue);
      final summary = listTimeSummary([_anime(1, progress: 2), airing], ListEntryStatus.current)!;
      expect(summary.total, const Duration(minutes: 24 * 10));
      expect(summary.partial, isTrue);
      expect(summary.label(), 'Time left: 4 h 0 min+');
      // Watched tabs count the progress, which is known.
      final done = _anime(4, status: ListEntryStatus.completed, total: 0, progress: 3);
      expect(listTimeSummary([done], ListEntryStatus.completed)!.partial, isFalse);
    });
  });

  group('row layout', () {
    testWidgets('two-line titles with every badge and an airing line never overflow',
        (tester) async {
      final entry = _anime(
        1,
        title: 'Re:Zero kara Hajimeru Isekai Seikatsu 4th Season with a very long subtitle',
        mean: 8.7,
        score: 9,
        rewatched: 2,
        priority: 2,
        releaseState: ReleaseState.releasing,
        broadcast: const BroadcastSlot(DateTime.saturday, 23 * 60),
      );
      for (final sub in [DisplaySubType.comfortable, DisplaySubType.spacious]) {
        for (final scale in [1.0, 1.3, 1.6]) {
          await tester.pumpWidget(_app(
            _scoped(
                _HookedTracker(const []),
                SizedBox(
                  width: 360,
                  height: listRowExtent(sub),
                  child: EntryListTile(
                    entry: entry,
                    subType: sub,
                    actions: _actions,
                    style: const EntryCardStyle(showPriority: true, showAiringInfo: true),
                    now: DateTime.utc(2026, 10, 29),
                    locale: 'en',
                  ),
                )),
            textScale: scale,
          ));
          expect(tester.takeException(), isNull, reason: '$sub at $scale');
          expect(find.textContaining('Re:Zero'), findsOneWidget);
        }
      }
    });
  });

  group('Simkl scores', () {
    final simkl = SimklUserListAdapter(service: SimklListService(), owner: () => 'me');

    test('user and community scores are out of 10', () {
      expect(simkl.userScore(_anime(1, score: 8))!.text, '8/10');
      expect(simkl.userScore(_anime(1)), isNull);
      expect(simkl.meanScore(_anime(1, mean: 8.21))!.text, '8.21/10');
      expect(simkl.meanScore(_anime(1)), isNull);
    });
  });
}
