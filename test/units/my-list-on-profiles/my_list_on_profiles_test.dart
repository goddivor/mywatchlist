import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/list_section.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/user/list/cards/my_list_mark.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Another user's anime list: three titles, MAL's answer shape.
String _theirList() => jsonEncode({
      'data': [
        for (final (id, title) in [(1, 'Frieren'), (2, 'Dandadan'), (3, 'Monogatari')])
          {
            'node': {'id': id, 'title': title, 'media_type': 'tv', 'num_episodes': 12, 'status': 'finished_airing'},
            'list_status': {'status': 'completed', 'score': 9, 'num_episodes_watched': 12},
          },
      ],
      'paging': {},
    });

Future<PreferencesBloc> _prefs({bool on = true}) async {
  SharedPreferences.setMockInitialValues({});
  final store = PreferencesStore(await SharedPreferences.getInstance());
  await store.write(const AppPreferences().copyWith(
    general: const GeneralPreferences().copyWith(showMyListOnProfiles: on),
  ));
  final bloc = PreferencesBloc(store: store);
  addTearDown(bloc.close);
  return bloc;
}

Future<void> _pump(WidgetTester tester, PreferencesBloc prefs, ListStatusCache mine) async {
  await tester.pumpWidget(BlocProvider.value(
    value: prefs,
    child: MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(
        // The profile's scroll view, which the tab plugs into.
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: const SliverToBoxAdapter(child: SizedBox(height: 1)),
            ),
          ],
          body: ListSection(
          username: 'Ren',
          anime: const ListStats(),
          manga: const ListStats(),
          myList: mine,
          adapter: MalUserListAdapter(
            username: 'Ren',
            get: (_) async => http.Response(_theirList(), 200),
            mangaStats: (_) async => null,
          ),
        ),
        ),
      ),
    ),
  ));
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() => S.load(const Locale('en')));

  test('the setting is on by default and survives a save', () {
    const d = GeneralPreferences();
    expect(d.showMyListOnProfiles, isTrue);
    final off = d.copyWith(showMyListOnProfiles: false);
    expect(GeneralPreferences.fromJson(off.toJson()).showMyListOnProfiles, isFalse);
  });

  testWidgets('my mark: status and score of my own entry, nothing when not in my list', (tester) async {
    final mine = ListStatusCache(saveDelay: const Duration(days: 1));
    mine.put(1, const CachedListStatus(status: 'watching', score: 8, progress: 3));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [S.delegate],
      home: Scaffold(
        body: Column(children: [
          MyListMark(id: 1, category: 'anime', cache: mine),
          MyListMark(id: 2, category: 'anime', cache: mine),
        ]),
      ),
    ));
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('8')), findsOneWidget);
    await tester.pump(const Duration(days: 2));
  });

  testWidgets("another user's list: my marks, then only what we share", (tester) async {
    final mine = ListStatusCache(saveDelay: const Duration(days: 1));
    mine.put(2, const CachedListStatus(status: 'watching', score: 7, progress: 5));
    await _pump(tester, await _prefs(), mine);
    expect(find.text('Frieren'), findsWidgets);
    // Only Dandadan is in my list: one mark.
    expect(find.byKey(const ValueKey('my-list-anime-2')), findsWidgets);
    expect(find.byKey(const ValueKey('my-list-anime-1')), findsNothing);

    await tester.tap(find.byTooltip(S.current.Mlp_Compare));
    await tester.pumpAndSettle();
    expect(find.text(S.current.Mlp_Count(S.current.Mlp_Common, 1)), findsOneWidget);
    expect(find.text(S.current.Mlp_Count(S.current.Mlp_Missing, 2)), findsOneWidget);
    await tester.tap(find.text(S.current.Mlp_Count(S.current.Mlp_Common, 1)));
    await tester.pumpAndSettle();
    expect(find.text('Dandadan'), findsWidgets);
    expect(find.text('Frieren'), findsNothing);
    await tester.pump(const Duration(days: 2));
  });

  testWidgets('with the setting off, no mark and no compare button', (tester) async {
    final mine = ListStatusCache(saveDelay: const Duration(days: 1));
    mine.put(2, const CachedListStatus(status: 'watching'));
    await _pump(tester, await _prefs(on: false), mine);
    expect(find.text('Frieren'), findsWidgets);
    expect(find.byType(MyListMark), findsNothing);
    expect(find.byTooltip(S.current.Mlp_Compare), findsNothing);
    await tester.pump(const Duration(days: 2));
  });
}
