import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/user/sync/sync_dialog.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';

import 'fakes.dart';

Future<SyncDialogResult?> Function() _open(
  WidgetTester tester,
  TrackerSyncService service, {
  Locale locale = const Locale('en'),
}) {
  SyncDialogResult? result;
  var closed = false;
  return () async {
    await S.load(locale);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showSyncDialog(
                context,
                service: service,
                tracker: AccountType.anilist,
                trackerId: '1',
                malId: 5,
                category: 'anime',
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    return closed ? result : null;
  };
}

void main() {
  TrackerSyncService make(FakeClient c, FakeMal m) =>
      TrackerSyncService(clients: {AccountType.anilist: c}, mal: m);

  testWidgets('shows both directions with what each side holds',
      (tester) async {
    final service = make(
      FakeClient(const SyncEntry(status: 'completed', score: 7.5, progress: 12)),
      FakeMal(const SyncEntry(status: 'watching', score: 8, progress: 3)),
    );
    await _open(tester, service)();
    // Loading first: a spinner on each direction.
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    await tester.pumpAndSettle();

    expect(find.text('Sync with AniList'), findsOneWidget);
    expect(find.text('MyAnimeList to AniList'), findsOneWidget);
    expect(find.text('AniList to MyAnimeList'), findsOneWidget);
    expect(find.text('Watching · 8 · Ep. 3'), findsOneWidget);
    expect(find.text('Completed · 7.5 · Ep. 12'), findsOneWidget);
    // The decimal AniList score is rounded on MyAnimeList: say so.
    expect(find.textContaining('7.5 becomes 8'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('a tap runs the direction and closes with the outcome',
      (tester) async {
    final other = FakeClient(const SyncEntry(status: 'watching'));
    final service = make(other,
        FakeMal(const SyncEntry(status: 'completed', score: 9, progress: 12)));
    SyncDialogResult? result;
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await S.load(const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showSyncDialog(context,
              service: service,
              tracker: AccountType.anilist,
              trackerId: '1',
              malId: 5,
              category: 'anime'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MyAnimeList to AniList'));
    await tester.pumpAndSettle();

    expect(other.writes.single.score, 9);
    expect(result!.direction, SyncDirection.malToTracker);
    expect(result!.cancelled, isFalse);
    expect(find.text('Sync with AniList'), findsNothing);
  });

  testWidgets('Cancel closes the dialog and nothing is written',
      (tester) async {
    final other = FakeClient(const SyncEntry(status: 'watching'));
    final service =
        make(other, FakeMal(const SyncEntry(status: 'completed')));
    await _open(tester, service)();
    await tester.pump(); // still loading
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sync with AniList'), findsNothing);
    expect(other.writes, isEmpty);
  });

  testWidgets('an entry missing on one side disables that direction',
      (tester) async {
    final other = FakeClient(const SyncEntry(status: 'watching'));
    final service = make(other, FakeMal(null));
    await _open(tester, service)();
    await tester.pumpAndSettle();
    expect(find.text('Not on your MyAnimeList list'), findsOneWidget);
    await tester.tap(find.text('MyAnimeList to AniList'));
    await tester.pumpAndSettle();
    expect(other.writes, isEmpty);
    expect(find.text('Sync with AniList'), findsOneWidget);
  });

  testWidgets('the dialog is fully translated in French', (tester) async {
    final service = make(
      FakeClient(const SyncEntry(status: 'completed')),
      FakeMal(const SyncEntry(status: 'watching')),
    );
    await _open(tester, service, locale: const Locale('fr', 'FR'))();
    await tester.pumpAndSettle();
    expect(find.text('Synchroniser avec AniList'), findsOneWidget);
    expect(find.text('MyAnimeList vers AniList'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.textContaining('Choisissez le côté'), findsOneWidget);
  });
}
