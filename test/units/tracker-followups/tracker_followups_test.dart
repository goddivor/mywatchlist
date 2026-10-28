import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/notifications/notification_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../anilist-pages/anilist_pages_test.dart' show entry, fakeGql, media;
import '../kitsu-pages/kitsu_fakes.dart';
import '../notifications/fakes.dart';

/// Fakes only: no editor opens, no tracker is written.
Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (c) {
      context = c;
      return const SizedBox();
    }),
  ));
  return context;
}

class _Tracker extends ChangeNotifier {
  AccountType feed = AccountType.myanimelist;
  void poke() => notifyListeners();
  void switchTo(AccountType next) {
    feed = next;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a removed entry leaves the list', () {
    testWidgets('AniList: ListEditRemoved and the kept list forgets the row', (tester) async {
      final service = AnilistListService(
        client: fakeGql([
          entry(media(1, mal: 1), 'CURRENT'),
          entry(media(2, mal: 2), 'COMPLETED'),
        ]),
        owner: () => 'me',
        titleLang: () => 'en',
      );
      final adapter = AnilistUserListAdapter(
        service: service,
        editor: (context, view, initial) async => SyncEntry.removed,
      );
      final context = await _context(tester);
      final all = (await tester.runAsync(() => service.all('anime')))!;
      expect(all.length, 2);

      final result = await tester.runAsync(() => adapter.edit(context, all.first));
      expect(result, isA<ListEditRemoved>());
      final after = (await tester.runAsync(() => service.all('anime')))!;
      expect(after.map((e) => e.id), [all.last.id]);
    });

    testWidgets('AniList: a saved entry is still an update', (tester) async {
      final service = AnilistListService(
        client: fakeGql([entry(media(1, mal: 1), 'CURRENT')]),
        owner: () => 'me',
        titleLang: () => 'en',
      );
      final adapter = AnilistUserListAdapter(
        service: service,
        editor: (context, view, initial) async =>
            const SyncEntry(status: 'completed', progress: 12),
      );
      final context = await _context(tester);
      final all = (await tester.runAsync(() => service.all('anime')))!;
      final result = await tester.runAsync(() => adapter.edit(context, all.first));
      expect(result, isA<ListEditUpdated>());
    });

    testWidgets('Kitsu: ListEditRemoved', (tester) async {
      final fake = FakeKitsu((r) async => jsonResponse({'data': []}));
      final adapter = KitsuUserListAdapter(
        library: KitsuLibrary(http: fake.kitsu, owner: () => 'me'),
        owner: () => 'me',
        editor: (context, view, initial) async => SyncEntry.removed,
      );
      final context = await _context(tester);
      const view = ListEntryView(
          id: 5, category: 'anime', title: 'Five', status: ListEntryStatus.current, progress: 2);
      final result = await tester.runAsync(() => adapter.edit(context, view));
      expect(result, isA<ListEditRemoved>());
      expect(fake.requests, isEmpty, reason: 'the fake editor wrote nothing');
    });
  });

  test('the Simkl list page has one category and no title workaround', () {
    final source = File('lib/pages/Simkl/simkl_user_page.dart').readAsStringSync();
    expect(source, contains("categories: const ['anime']"));
    expect(source, isNot(contains('keepSwitch')));
    expect(source, isNot(contains('defaultCategory')));
  });

  group('switching the account that feeds the reminders', () {
    late FakeBackend backend;
    late _Tracker tracker;
    late NotificationPreferences prefs;

    NotificationService build() => NotificationService(
          backend: backend,
          texts: const FakeTexts(),
          readPrefs: () => prefs,
          clock: () => DateTime.utc(2026, 10, 27, 12),
          debounce: const Duration(milliseconds: 10),
          loadCandidates: () async => const [],
          loadEpisodes: () async => const [],
          fetchCover: (_, __) async => null,
          trackerChanges: tracker,
          readFeedTracker: () => tracker.feed,
        );

    setUp(() {
      backend = FakeBackend();
      tracker = _Tracker();
      prefs = NotificationPreferences(subscribedAt: DateTime.utc(2026, 10, 1));
    });

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

    test('a switch after a run reschedules once', () async {
      final service = build();
      await service.init();
      await service.scheduleAll(force: true);
      expect(backend.cancelAllCalls, 1);

      tracker.switchTo(AccountType.anilist);
      await settle();
      expect(backend.cancelAllCalls, 2);

      tracker.poke();
      await settle();
      expect(backend.cancelAllCalls, 2, reason: 'same account, nothing to redo');
      service.dispose();
    });

    test('startup loading the saved tracker does not force a run', () async {
      final service = build();
      await service.init();
      tracker.switchTo(AccountType.kitsu);
      await settle();
      expect(backend.cancelAllCalls, 0, reason: 'never run yet: the startup refresh decides');
      service.dispose();
    });

    test('each real switch re-plans from its own account', () async {
      final service = build();
      await service.init();
      await service.scheduleAll(force: true);
      tracker.switchTo(AccountType.anilist);
      await settle();
      tracker.switchTo(AccountType.myanimelist);
      await settle();
      expect(backend.cancelAllCalls, 3);
      service.dispose();
    });

    test('with reminders off a switch schedules nothing', () async {
      prefs = const NotificationPreferences();
      final service = build();
      await service.init();
      tracker.switchTo(AccountType.simkl);
      await settle();
      expect(backend.cancelAllCalls, 0);
      service.dispose();
    });
  });
}
