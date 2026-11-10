import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/anime_graph_builder.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_screen.dart';

import 'fixtures.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [S.delegate],
    supportedLocales: S.delegate.supportedLocales,
    home: const AnimeGraphScreen(id: 1, title: 'Show'),
  ));
}

/// The app's repository with no backend (empty API_URL) and saved MAL answers.
void _useRepository(Future<GraphFetch> Function(int id) fetch) {
  AnimeGraphRepository.instance = AnimeGraphRepository(
    builder: AnimeGraphBuilder(fetch: fetch),
    store: MemoryGraphStore(),
    remote: (_) async => null,
  );
}

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ListStatusCache.instance.resetForTest();
    clearAnimeGraphCache();
  });

  testWidgets('the graph loads without API_URL, built from MAL', (tester) async {
    _useRepository(FakeMal(franchise).call);
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('6 titles'), findsOneWidget);
    expect(find.text('Title 12'), findsOneWidget);
    expect(find.textContaining('limiting requests'), findsNothing);
  });

  testWidgets('shows the titles found while the graph grows', (tester) async {
    final gate = Completer<void>();
    final mal = FakeMal(franchise);
    _useRepository((id) async {
      if (id == 3) await gate.future;
      return mal(id);
    });
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Building the graph'), findsOneWidget);
    expect(find.text('3 titles'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('6 titles'), findsOneWidget);
  });

  testWidgets('a rate limit shows what loaded and offers a retry',
      (tester) async {
    _useRepository(FakeMal(franchise, limitedAt: 3).call);
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('3 titles'), findsOneWidget);
    expect(
        find.text(
            'MyAnimeList is limiting requests: the graph shows what has loaded so far.'),
        findsOneWidget);

    _useRepository(FakeMal(franchise).call);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('6 titles'), findsOneWidget);
    expect(find.textContaining('limiting requests'), findsNothing);
  });

  testWidgets('a rate limit on the title itself asks to wait', (tester) async {
    _useRepository(FakeMal(franchise, limitedAt: 1).call);
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'MyAnimeList is limiting requests. Wait a minute, then try again.'),
        findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a franchise over the bound says so', (tester) async {
    AnimeGraphRepository.instance = AnimeGraphRepository(
      builder: AnimeGraphBuilder(fetch: FakeMal(franchise).call, maxNodes: 4),
      store: MemoryGraphStore(),
      remote: (_) async => null,
    );
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Large franchise: the graph shows its first 4 titles.'),
        findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });
}
