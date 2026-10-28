import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/cross_tracker_widget.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../edit-sheet/fixtures.dart';
import '../sync-dialog/fakes.dart';

/// In-memory MAL list: nothing leaves the test.
class _FakeEntries implements ListEntryService {
  _FakeEntries({this.editable = true, this.onList = true});

  final bool editable;
  final bool onList;
  final patches = <EntryPatch>[];

  @override
  bool get canEdit => editable;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) async {
    final json = completedAnimeJson();
    if (!onList) json.remove('my_list_status');
    return EditableContent.fromMalJson(json, isAnime: isAnime);
  }

  @override
  Future<EntryUpdate> update(int id,
      {required bool isAnime,
      required EntryPatch patch,
      ListEntry? previous}) async {
    patches.add(patch);
    final entry = ListEntry(
      status: patch.status ?? previous?.status ?? '',
      score: patch.score ?? previous?.score ?? 0,
      progress: patch.progress ?? previous?.progress ?? 0,
    );
    return EntryUpdate(entry, entry);
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) async {}
}

/// A tracker client counting its reads; never reaches a tracker.
class _CountingClient extends FakeClient {
  _CountingClient() : super(const SyncEntry(status: 'watching', progress: 3), found: '77');
  int reads = 0;

  @override
  Future<SyncEntry?> read(String mediaId,
      {required bool isAnime, int? malId}) {
    reads++;
    return super.read(mediaId, isAnime: isAnime, malId: malId);
  }
}

const _fab = ValueKey('close-fab');

/// The tonal delete button (a private `FilledButton` subclass).
final _deleteButton = find.ancestor(
  of: find.text('Delete from List'),
  matching: find.byWidgetPredicate((w) => w is FilledButton),
);

/// The detail screen's layout: the panel floats 70 px above the bottom, the
/// close FAB sits at the end, the phone has a gesture bar.
Future<void> _pump(
  WidgetTester tester, {
  required _FakeEntries entries,
  required TrackerSyncService sync,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  tester.view.viewPadding = const FakeViewPadding(bottom: 132);
  tester.view.padding = const FakeViewPadding(bottom: 132);
  addTearDown(tester.view.reset);
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
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton(
          key: _fab,
          onPressed: () {},
          child: const Icon(Icons.close),
        ),
        body: Stack(
          children: [
            const SizedBox.expand(),
            Positioned(
              left: 0,
              right: 0,
              bottom: 70,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ContentEditWidget(
                        id: 5114,
                        category: 'anime',
                        service: entries,
                      ),
                      CrossTrackerWidget(
                        malId: 5114,
                        title: 'Fullmetal Alchemist: Brotherhood',
                        category: 'anime',
                        malStatus: 'completed',
                        malScore: 10,
                        malProgress: 64,
                        service: sync,
                        trackers: const [AccountType.anilist],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

TrackerSyncService _sync(_CountingClient client) => TrackerSyncService(
    clients: {AccountType.anilist: client}, mal: FakeMal(null));

void _expectClearOfFab(WidgetTester tester, Finder target) {
  final fab = tester.getRect(find.byKey(_fab));
  final rect = tester.getRect(target);
  expect(rect.overlaps(fab), isFalse,
      reason: 'the close FAB $fab covers $rect');
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).first;
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(state.position.maxScrollExtent);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => S.load(const Locale('en')));

  testWidgets('one compact card: other trackers only behind More options',
      (tester) async {
    final client = _CountingClient();
    await _pump(tester, entries: _FakeEntries(), sync: _sync(client));

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Delete from List'), findsOneWidget);
    expect(find.text('Other trackers'), findsNothing);
    expect(find.byKey(const ValueKey('cross-tracker-card')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(client.finds + client.reads, 0, reason: 'nothing loads on open');

    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('edit-other-trackers')), findsOneWidget);
    expect(client.finds + client.reads, 0,
        reason: 'the section loads only once opened');

    final header = find.text('Other trackers');
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(client.reads, 1);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    // The summary line of the old panel is gone.
    expect(find.textContaining('MyAnimeList ·'), findsNothing);

    await _scrollToEnd(tester);
    _expectClearOfFab(tester, _deleteButton);
    await tester.ensureVisible(find.text('Sync'));
    await tester.pumpAndSettle();
    _expectClearOfFab(tester, find.text('Sync'));
  });

  testWidgets('closed sheet: the FAB never covers its bottom row',
      (tester) async {
    await _pump(tester,
        entries: _FakeEntries(), sync: _sync(_CountingClient()));
    _expectClearOfFab(
        tester, _deleteButton);
    _expectClearOfFab(tester, find.text('More options'));
  });

  testWidgets(
      'not on the list: trackers get their own collapsed card, clear of the FAB',
      (tester) async {
    final client = _CountingClient();
    await _pump(tester,
        entries: _FakeEntries(onList: false), sync: _sync(client));

    expect(find.text('Add to List'), findsOneWidget);
    expect(find.byKey(const ValueKey('cross-tracker-card')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(client.finds + client.reads, 0);

    await tester.tap(find.text('Other trackers'));
    await tester.pumpAndSettle();
    expect(client.reads, 1);
    await _scrollToEnd(tester);
    _expectClearOfFab(tester, find.text('Sync'));
  });

  testWidgets('sync, edit and the section title are in French',
      (tester) async {
    await _pump(tester,
        entries: _FakeEntries(),
        sync: _sync(_CountingClient()),
        locale: const Locale('fr', 'FR'));
    await tester.tap(find.text('Plus d’options'));
    await tester.pumpAndSettle();
    final header = find.text('Autres services de suivi');
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(find.text('Synchroniser'), findsOneWidget);
    expect(find.text('Supprimer de la liste'), findsOneWidget);
    for (final english in ['Other trackers', 'Sync', 'Delete from List']) {
      expect(find.text(english), findsNothing, reason: english);
    }
  });
}
