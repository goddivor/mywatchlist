import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';
import 'package:mywatchlist/widgets/user/contenteditwidget.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

/// In-memory tracker: answers like MAL (the whole entry after each write).
class _FakeService implements ListEntryService {
  _FakeService(this.json, {required this.isAnime});

  Map<String, dynamic> json;
  final bool isAnime;
  bool editable = true;
  Object? loadError;
  Object? updateError;
  int loads = 0;
  final patches = <EntryPatch>[];

  @override
  bool get canEdit => editable;

  @override
  Future<EditableContent> load(int id, {required bool isAnime}) async {
    loads++;
    if (loadError != null) throw loadError!;
    return EditableContent.fromMalJson(json, isAnime: isAnime);
  }

  @override
  Future<EntryUpdate> update(int id,
      {required bool isAnime,
      required EntryPatch patch,
      ListEntry? previous}) async {
    patches.add(patch);
    if (updateError != null) throw updateError!;
    final p = previous ?? ListEntry(status: patch.status ?? '');
    final entry = ListEntry(
      status: patch.status ?? p.status,
      score: patch.score ?? p.score,
      progress: patch.progress ?? p.progress,
      volumes: patch.volumes ?? p.volumes,
      isRepeating: patch.isRepeating ?? p.isRepeating,
      timesRepeated: patch.timesRepeated ?? p.timesRepeated,
      repeatValue: patch.repeatValue ?? p.repeatValue,
      priority: patch.priority ?? p.priority,
      startDate: patch.startDate ?? p.startDate,
      finishDate: patch.finishDate ?? p.finishDate,
      tags: patch.tags?.split(',') ?? p.tags,
      comments: patch.comments ?? p.comments,
    );
    return EntryUpdate(entry, entry);
  }

  @override
  Future<void> delete(int id, {required bool isAnime}) async {}
}

final _now = DateTime(2026, 10, 27, 15);

Future<void> _pump(
  WidgetTester tester,
  _FakeService service, {
  String category = 'anime',
  PreferencesBloc? prefs,
  Locale locale = const Locale('en'),
  PrivateNotesStore? notes,
}) async {
  await S.load(locale);
  Widget sheet = ContentEditWidget(
    id: 5114,
    category: category,
    service: service,
    notesStore: notes,
    clock: () => _now,
  );
  final app = MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: sheet)),
  );
  await tester.pumpWidget(
      prefs == null ? app : BlocProvider.value(value: prefs, child: app));
  await tester.pumpAndSettle();
}

Future<PreferencesBloc> _prefsBloc(
    AppPreferences Function(AppPreferences) edit) async {
  SharedPreferences.setMockInitialValues({});
  final store = PreferencesStore(await SharedPreferences.getInstance());
  await store.write(edit(const AppPreferences()));
  final bloc = PreferencesBloc(store: store);
  addTearDown(bloc.close);
  return bloc;
}

Future<void> _openAdvanced(WidgetTester tester) async {
  await tester.tap(find.text('More options'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'a completed anime shows its real status, score, progress and dates',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final service = _FakeService(completedAnimeJson(), isAnime: true);
    await _pump(tester, service);

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('10 · Masterpiece'), findsOneWidget);
    expect(find.text('of 64'), findsOneWidget);
    final bar = find.byKey(const ValueKey('edit-episode-bar'));
    expect(bar, findsOneWidget);

    await _openAdvanced(tester);
    expect(find.text('Jan 5, 2019'), findsOneWidget);
    expect(find.text('2019-03'), findsOneWidget,
        reason: 'partial date as on MAL');
    expect(find.text('High'), findsWidgets);

    await tester.tap(find.text('Others'));
    await tester.pumpAndSettle();
    expect(find.text('Great\nshow "FMA"'), findsOneWidget);
    expect(find.text('shounen, Tom & Jerry'), findsOneWidget);

    await tester.tap(find.text('Rewatch'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsWidgets);
    expect(find.text('High'), findsWidgets);
  });

  testWidgets('a manga shows its chapters and volumes', (tester) async {
    final service = _FakeService(readingMangaJson(), isAnime: false);
    await _pump(tester, service, category: 'manga');

    expect(find.text('Reading'), findsOneWidget);
    final chapters = tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('edit-progress')),
        matching: find.byType(TextField)));
    final volumes = tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('edit-volumes')),
        matching: find.byType(TextField)));
    expect(chapters.controller!.text, '112');
    expect(volumes.controller!.text, '12');
  });

  testWidgets('the last episode completes with a finish date, start date kept',
      (tester) async {
    final json = completedAnimeJson();
    (json['my_list_status'] as Map)
      ..['status'] = 'watching'
      ..['num_episodes_watched'] = 63
      ..remove('finish_date');
    final service = _FakeService(json, isAnime: true);
    await _pump(tester, service);

    await tester.tap(find.byTooltip('Type a number'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase'));
    await tester.pumpAndSettle();

    final patch = service.patches.single;
    expect(patch.progress, 64);
    expect(patch.status, 'completed');
    expect(patch.finishDate, '2026-10-27');
    expect(patch.startDate, isNull);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('auto dates off: completing sends no date', (tester) async {
    final prefs = await _prefsBloc((p) =>
        p.copyWith(general: p.general.copyWith(autoAddStartEndDate: false)));
    final json = completedAnimeJson();
    (json['my_list_status'] as Map)
      ..['status'] = 'watching'
      ..remove('finish_date');
    final service = _FakeService(json, isAnime: true);
    await _pump(tester, service, prefs: prefs);

    await tester.tap(find.text('Watching'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();
    expect(service.patches.single.status, 'completed');
    expect(service.patches.single.finishDate, isNull);
  });

  testWidgets('adding uses the default status of the preferences',
      (tester) async {
    final prefs = await _prefsBloc((p) => p.copyWith(
        content: p.content.copyWith(defaultAnimeAddStatus: 'plan_to_watch')));
    final json = completedAnimeJson()..remove('my_list_status');
    final service = _FakeService(json, isAnime: true);
    await _pump(tester, service, prefs: prefs);

    await tester.tap(find.text('Add to List'));
    await tester.pumpAndSettle();
    expect(service.patches.single.status, 'plan_to_watch');
    expect(find.text('Plan to watch'), findsOneWidget);
  });

  testWidgets('a load error shows a retry, never an endless spinner',
      (tester) async {
    final service = _FakeService(completedAnimeJson(), isAnime: true)
      ..loadError = const EntryLoadFailed('HTTP 500');
    await _pump(tester, service);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Couldn't load your list entry."), findsOneWidget);

    service.loadError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.loads, 2);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('an expired MAL session says so', (tester) async {
    final service = _FakeService(completedAnimeJson(), isAnime: true)
      ..loadError = const MalSessionExpired();
    await _pump(tester, service);
    expect(find.textContaining('session has expired'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a write on a dead session switches to the expired state',
      (tester) async {
    final service = _FakeService(completedAnimeJson(), isAnime: true);
    await _pump(tester, service);
    service.updateError = const MalSessionExpired();
    await tester.tap(find.bySemanticsLabel('5, Average'));
    await tester.pumpAndSettle();
    expect(find.textContaining('session has expired'), findsWidgets);
  });

  testWidgets('another tracker selected: explains instead of loading',
      (tester) async {
    final service = _FakeService(completedAnimeJson(), isAnime: true)
      ..editable = false;
    await _pump(tester, service);
    expect(service.loads, 0);
    expect(find.textContaining('MyAnimeList account'), findsOneWidget);
  });

  testWidgets('the private note is shown with the preference and saved',
      (tester) async {
    final prefs = await _prefsBloc(
        (p) => p.copyWith(content: p.content.copyWith(showPrivateNotes: true)));
    final notes = PrivateNotesStore();
    await notes.write(5114, 'anime', 'Watch the dub');
    final service = _FakeService(completedAnimeJson(), isAnime: true);
    await _pump(tester, service, prefs: prefs, notes: notes);
    await _openAdvanced(tester);

    final field = find.byKey(const ValueKey('edit-private-note'));
    await tester.ensureVisible(field);
    expect(find.text('Watch the dub'), findsOneWidget);
    await tester.enterText(field, 'Watch the sub');
    await tester.pump(const Duration(seconds: 1));
    expect(await notes.read(5114, 'anime'), 'Watch the sub');
  });

  testWidgets('no private note without the preference', (tester) async {
    final service = _FakeService(completedAnimeJson(), isAnime: true);
    await _pump(tester, service);
    await _openAdvanced(tester);
    expect(find.byKey(const ValueKey('edit-private-note')), findsNothing);
  });

  testWidgets('the sheet is fully French in French', (tester) async {
    final service = _FakeService(completedAnimeJson(), isAnime: true);
    await _pump(tester, service, locale: const Locale('fr', 'FR'));
    await tester.tap(find.text('Plus d’options'));
    await tester.pumpAndSettle();
    expect(find.text('Terminé'), findsOneWidget);
    expect(find.text('sur 64'), findsOneWidget);
    expect(find.text('Revisionnage'), findsOneWidget);
    for (final english in [
      'Completed',
      'More options',
      'Fewer options',
      'Rewatch',
      'of 64',
      'Episodes',
    ]) {
      expect(find.text(english), findsNothing, reason: english);
    }
    await S.load(const Locale('en'));
  });
}
