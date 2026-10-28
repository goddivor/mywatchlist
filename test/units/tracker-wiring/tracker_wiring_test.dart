import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_entry_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync-dialog/fakes.dart';
import '../user-list-mal/fixtures.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: home),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => LanguageBloc.apply('en'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('notification source', () {
    bool connected(AccountType t) => true;
    bool none(AccountType t) => false;

    test('AniList, Kitsu and Simkl feed the planner when active and connected', () {
      for (final t in [AccountType.anilist, AccountType.kitsu, AccountType.simkl]) {
        expect(NotificationService.candidateTracker(t, connected), t);
      }
    });

    test('a disconnected tracker, MAL and none fall back to MyAnimeList', () {
      expect(NotificationService.candidateTracker(AccountType.anilist, none),
          AccountType.myanimelist);
      expect(NotificationService.candidateTracker(AccountType.myanimelist, connected),
          AccountType.myanimelist);
      expect(NotificationService.candidateTracker(AccountType.none, connected),
          AccountType.myanimelist);
    });
  });

  group('tracker entry editor, remove from list', () {
    Future<SyncEntry?> open(WidgetTester tester, FakeClient client,
        {SyncEntry? initial, bool allowRemove = true}) async {
      SyncEntry? result;
      var closed = false;
      final service = TrackerSyncService(
        clients: {AccountType.anilist: client},
        mal: FakeMal(null),
      );
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showTrackerEntryEditor(
              context,
              service: service,
              tracker: AccountType.anilist,
              trackerId: '9',
              malId: 5,
              category: 'anime',
              initial: initial,
              allowRemove: allowRemove,
            );
            closed = true;
          },
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(closed, isFalse);
      return result;
    }

    testWidgets('no remove button for a new entry', (tester) async {
      await open(tester, FakeClient(null));
      expect(find.text('Remove from list'), findsNothing);
    });

    testWidgets('cancelling the confirmation keeps the entry', (tester) async {
      final client = FakeClient(const SyncEntry(status: 'watching'));
      await open(tester, client, initial: const SyncEntry(status: 'watching'));
      await tester.ensureVisible(find.text('Remove from list'));
      await tester.tap(find.text('Remove from list'));
      await tester.pumpAndSettle();
      expect(find.text('Remove this entry from AniList?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(client.entry, isNotNull);
      expect(find.text('Remove from list'), findsOneWidget);
    });

    testWidgets('confirming deletes the entry and pops the removed marker', (tester) async {
      final client = FakeClient(const SyncEntry(status: 'watching'));
      SyncEntry? popped;
      final service = TrackerSyncService(
        clients: {AccountType.anilist: client},
        mal: FakeMal(null),
      );
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => popped = await showTrackerEntryEditor(
            context,
            service: service,
            tracker: AccountType.anilist,
            trackerId: '9',
            malId: 5,
            category: 'anime',
            initial: const SyncEntry(status: 'watching'),
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove from list'));
      await tester.tap(find.text('Remove from list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(client.entry, isNull);
      expect(popped, isNotNull);
      expect(popped!.isRemoved, isTrue);
      expect(const SyncEntry(status: 'watching', entryId: '12').isRemoved, isFalse);
    });

    testWidgets('allowRemove false hides the button', (tester) async {
      await open(tester, FakeClient(null),
          initial: const SyncEntry(status: 'watching'), allowRemove: false);
      expect(find.text('Remove from list'), findsNothing);
    });
  });

  group('UserListView categories', () {
    late ListStatusCache cache;
    setUp(() => cache = ListStatusCache(saveDelay: const Duration(days: 1)));
    tearDown(() => cache.dispose());

    Future<void> pump(WidgetTester tester, List<String> categories) async {
      await tester.pumpWidget(_app(UserListView(
        adapter: FakeListAdapter([]),
        cache: cache,
        categories: categories,
        titleBuilder: (context, categorySwitch) => categorySwitch,
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('both categories show the switch', (tester) async {
      await pump(tester, const ['anime', 'manga']);
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.text('Manga'), findsOneWidget);
      cache.resetForTest();
    });

    testWidgets('a single category hides the switch', (tester) async {
      await pump(tester, const ['anime']);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      cache.resetForTest();
    });
  });

  group('MAL-only note', () {
    tearDown(() async => UserManager.instance.setCurrentTracker(AccountType.myanimelist));

    test('applies to every tracker but MyAnimeList', () {
      expect(PrefSubtitle.noteApplies(AccountType.myanimelist), isFalse);
      expect(PrefSubtitle.noteApplies(AccountType.none), isFalse);
      for (final t in [AccountType.anilist, AccountType.kitsu, AccountType.simkl]) {
        expect(PrefSubtitle.noteApplies(t), isTrue);
      }
    });

    testWidgets('shown on AniList, translated, hidden on MyAnimeList', (tester) async {
      await tester.pumpWidget(_app(const PrefSubtitle(text: 'Hide adult titles', malOnly: true)));
      expect(find.textContaining('MyAnimeList only'), findsNothing);
      await tester.runAsync(() => UserManager.instance.setCurrentTracker(AccountType.anilist));
      await tester.pump();
      expect(find.text('MyAnimeList only: no effect on AniList.'), findsOneWidget);
      expect(find.text('Hide adult titles'), findsOneWidget);

      await LanguageBloc.apply('fr_FR');
      addTearDown(() => LanguageBloc.apply('en'));
      await tester.pumpWidget(_app(const PrefSubtitle(text: 'x', malOnly: true),
          locale: const Locale('fr', 'FR')));
      expect(find.text('Réservé à MyAnimeList : sans effet sur AniList.'), findsOneWidget);
    });
  });
}
