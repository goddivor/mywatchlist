import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show LiveChartEpisode;
import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/actions/detail_actions.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/header/countdown_chip.dart';
import 'package:mywatchlist/screens/MAL/detail/header/detail_header.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_meta.dart';
import 'package:mywatchlist/screens/MAL/detail/header/next_episode.dart';
import 'package:mywatchlist/screens/MAL/detail/tabs_customizer.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

MalAnime _content({String? status, List<Genre>? genres, double? mean = 8.5}) => MalAnime(
      id: 7,
      title: 'Cowboy Bebop: Tengoku no Tobira',
      mean: mean,
      status: status,
      genres: genres,
    );

DetailData _data({String category = 'anime', MalAnime? content, NextEpisode? next}) => DetailData(
      id: 7,
      category: category,
      content: content,
      nextEpisode: next,
      state: content == null ? DetailLoadState.loading : DetailLoadState.loaded,
    );

void main() {
  setUpAll(() async => S.load(const Locale('en')));
  setUp(Preferences.reset);

  group('next episode', () {
    final now = DateTime.utc(2026, 10, 27, 12);
    LiveChartEpisode ep(int mal, int n, DateTime at) =>
        LiveChartEpisode(timestamp: at.millisecondsSinceEpoch ~/ 1000, episode: n, malId: mal);

    test('picks the earliest episode of the title that has not aired', () {
      final list = [
        ep(7, 3, now.subtract(const Duration(days: 1))),
        ep(7, 5, now.add(const Duration(days: 9))),
        ep(7, 4, now.add(const Duration(days: 2))),
        ep(8, 1, now.add(const Duration(hours: 1))),
      ];
      final next = NextEpisodes.pick(list, 7, now)!;
      expect(next.episode, 4);
      expect(next.airingAt, now.add(const Duration(days: 2)));
      expect(NextEpisodes.pick(list, 99, now), isNull);
    });

    test('a failing schedule gives null and is retried', () async {
      NextEpisodes.reset();
      var calls = 0;
      NextEpisodes.source = () async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return [ep(7, 2, DateTime.now().add(const Duration(days: 1)))];
      };
      expect(await NextEpisodes.forMalId(7), isNull);
      expect((await NextEpisodes.forMalId(7))?.episode, 2);
      NextEpisodes.reset();
    });
  });

  group('countdown', () {
    test('leaves out the leading zero units', () {
      expect(formatCountdown(const Duration(days: 2, hours: 3, minutes: 10, seconds: 5)),
          '2d 3h 10m 5s');
      expect(formatCountdown(const Duration(hours: 1, seconds: 4)), '1h 0m 4s');
      expect(formatCountdown(const Duration(seconds: 42)), '42s');
    });

    testWidgets('ticks every second and disappears when the episode aired', (tester) async {
      var now = DateTime.utc(2026, 10, 27, 12);
      final next = NextEpisode(5, now.add(const Duration(seconds: 3)));
      await pumpInApp(tester, CountdownChip(episode: next, now: () => now));
      expect(find.textContaining('Ep. 5'), findsOneWidget);
      expect(find.textContaining('3s'), findsOneWidget);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('1s'), findsOneWidget);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Icon), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('header', () {
    test('reserves the countdown row only for an airing anime with the pref on', () {
      final airing = _data(content: _content(status: 'currently_airing'));
      final done = _data(content: _content(status: 'finished_airing'));
      expect(DetailHeader.reservesCountdown(airing, enabled: true), isTrue);
      expect(DetailHeader.reservesCountdown(airing, enabled: false), isFalse);
      expect(DetailHeader.reservesCountdown(done, enabled: true), isFalse);
      expect(
          DetailHeader.reservesCountdown(
              _data(category: 'manga', content: _content(status: 'currently_airing')),
              enabled: true),
          isFalse);
      expect(DetailHeader.extentFor(airing, topInset: 24, countdown: true),
          greaterThan(DetailHeader.extentFor(done, topInset: 24, countdown: true)));
    });

    test('season names are translated', () {
      expect(seasonName('fall'), 'Fall');
      expect(seasonName('winter'), 'Winter');
    });

    testWidgets('the score shows, or hides behind an eye until tapped', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bloc = PreferencesBloc(store: PreferencesStore(prefs));
      addTearDown(bloc.close);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: Scaffold(
            body: SizedBox(width: 200, child: DetailHeaderMeta(data: _data(content: _content()))),
          ),
        ),
      ));
      expect(find.text('8.50'), findsOneWidget);

      bloc.add(ContentPreferencesChanged((p) => p.copyWith(hideScore: true)));
      await tester.pumpAndSettle();
      expect(find.text('8.50'), findsNothing);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pumpAndSettle();
      expect(find.text('8.50'), findsOneWidget);
      await tester.tap(find.text('8.50'));
      await tester.pumpAndSettle();
      expect(find.text('8.50'), findsNothing);
    });
  });

  group('actions', () {
    test('the page url carries the title slug', () {
      expect(detailPageUrl(_data(content: _content())),
          'https://myanimelist.net/anime/7/Cowboy_Bebop_Tengoku_no_Tobira');
    });

    test('genre filter uses MAL genre names, at most five, no duplicates', () {
      final genres = [
        for (var i = 1; i <= 7; i++) Genre(id: i, name: 'g$i'),
      ];
      final names = genreFilterNames(_data(content: _content(genres: genres)));
      expect(names.length, maxGenreFilters);
      expect(names.toSet().length, names.length);
      expect(genreFilterNames(_data(content: _content())), isEmpty);
    });
  });

  group('customizer', () {
    testWidgets('hiding a section is saved in the contract preference', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bloc = PreferencesBloc(store: PreferencesStore(prefs));
      addTearDown(bloc.close);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(
          value: bloc,
          child: const Scaffold(body: TabsCustomizer(manga: false)),
        ),
      ));
      expect(find.text('Synopsis'), findsOneWidget);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      final first = bloc.state.content.animeTabs.first;
      expect(first.tabType, TabType.Synopsis);
      expect(first.visible, isFalse);

      await tester.tap(find.text(S.current.Dh_Customize_Reset));
      await tester.pumpAndSettle();
      expect(bloc.state.content.animeTabs.first.visible, isTrue);
    });
  });
}
