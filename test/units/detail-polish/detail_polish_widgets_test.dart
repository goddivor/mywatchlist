import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_fab.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_meta.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/widgets/MAL/content/animestatisticswidget.dart';
import 'package:mywatchlist/widgets/MAL/home/animecharacterwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/show_news.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

AnimeNewsResponse _news(List<AnimeNews> items) => AnimeNewsResponse.fromJson({
      'pagination': {'has_next_page': false},
      'data': [
        for (final n in items) {'mal_id': n.malId, 'title': n.title, 'excerpt': 'x'},
      ],
    });

Future<void> _pumpLocalized(WidgetTester tester, Locale locale, Widget child) async {
  await S.load(locale);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('fr', 'FR')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  ));
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  tearDown(ShowAnimeNews.resetLoader);

  group('News (Cowboy Bebop, Shuiro no Kamen: Jikan down)', () {
    testWidgets('a failing source ends in an error with Retry, and Retry asks again', (tester) async {
      var calls = 0;
      ShowAnimeNews.loader = (id, category, page) async {
        calls++;
        if (calls == 1) throw JikanUnavailable(Uri.parse('https://api.jikan.moe'), 'no answer after 12 s');
        return _news([AnimeNews(malId: 1, title: 'Bebop returns')]);
      };
      await pumpInApp(tester, const SingleChildScrollView(child: ShowAnimeNews(animeId: 1)));
      await _settle(tester);
      expect(find.text(S.current.Dp_News_Failed), findsOneWidget);
      await tester.tap(find.text(S.current.Res_Retry));
      await _settle(tester);
      expect(calls, 2);
      expect(find.text('Bebop returns'), findsOneWidget);
    });

    testWidgets('no news: an empty state, not a skeleton', (tester) async {
      ShowAnimeNews.loader = (id, category, page) async => _news(const []);
      await pumpInApp(tester, const SingleChildScrollView(child: ShowAnimeNews(animeId: 2)));
      await _settle(tester);
      expect(find.text(S.current.Dp_News_Empty), findsOneWidget);
    });
  });

  group('Status colours come from the theme tokens', () {
    testWidgets('the edit button of a watched title is the watching chip colour', (tester) async {
      final content = MalAnime.fromJson({
        'id': 1,
        'title': 'Cowboy Bebop',
        'my_list_status': {
          'status': 'watching',
          'score': 0,
          'num_episodes_watched': 3,
          'is_rewatching': false,
          'updated_at': '2026-10-01T00:00:00+00:00',
        },
      });
      final data = DetailData(id: 1, category: 'anime', content: content, state: DetailLoadState.loaded);
      await pumpInApp(tester, buildDetailFab(data: data, editOpen: false, onPressed: () {})!);
      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      final context = tester.element(find.byType(FloatingActionButton));
      final watching = AppColors.of(context).watching;
      expect(fab.backgroundColor, watching.container);
      expect(fab.foregroundColor, watching.onContainer);
    });

    testWidgets('the Stats chart bars use the five status tokens', (tester) async {
      final stats = Statistics.fromJson({
        'status': {'watching': 10, 'completed': 20, 'on_hold': 3, 'dropped': 2, 'plan_to_watch': 15},
        'num_list_users': 50,
      });
      await pumpInApp(tester, SizedBox(width: 400, child: AnimeStatisticsWidget(stats: stats)));
      final context = tester.element(find.byType(AnimeStatisticsWidget));
      final tokens = AppColors.of(context);
      final barColors = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();
      expect(barColors, [
        tokens.watching.color,
        tokens.completed.color,
        tokens.onHold.color,
        tokens.dropped.color,
        tokens.planned.color,
      ]);
    });
  });

  group('Header', () {
    testWidgets('French numbers use French grouping', (tester) async {
      final content = MalAnime.fromJson({'id': 1, 'title': 'Shuiro no Kamen', 'num_list_users': 2169, 'mean': 6.42});
      await _pumpLocalized(
        tester,
        const Locale('fr', 'FR'),
        SizedBox(
          width: 220,
          child: DetailHeaderMeta(data: DetailData(id: 1, category: 'anime', content: content, state: DetailLoadState.loaded)),
        ),
      );
      final expected = NumberFormat.decimalPattern('fr_FR').format(2169);
      expect(expected, isNot('2,169'));
      expect(find.text(expected), findsOneWidget);
      expect(find.text('6,42'), findsOneWidget);
      await S.load(const Locale('en'));
    });

    test('manga authors never start with a comma', () {
      expect(authorName('', 'Nabana'), 'Nabana');
      expect(authorName('Eiichiro ', 'Oda'), 'Eiichiro Oda');
      expect(authorName('', ''), '');
    });
  });

  group('Characters (DailyAL layout, no shadow behind pictures)', () {
    testWidgets('an anime row shows the character and the voice actor portraits', (tester) async {
      final list = [
        CharactersVoiceActors(
          character: CharacterNode(
            image: 'https://cdn.myanimelist.net/images/characters/1.jpg',
            name: Link(name: 'Spike Spiegel', url: 'https://myanimelist.net/character/1/x'),
            role: 'Main',
          ),
          voiceActor: CharacterNode(
            image: 'https://cdn.myanimelist.net/images/voiceactors/2.jpg',
            name: Link(name: 'Yamadera, Kouichi', url: 'https://myanimelist.net/people/2/x'),
            role: 'Japanese',
          ),
        ),
      ];
      await pumpInApp(tester, SizedBox(width: 400, child: AnimeCharacterWidget(animeCharacterList: list, horizPadding: 0)));
      expect(find.text('Spike Spiegel'), findsOneWidget);
      expect(find.text(S.current.Dp_Role_Main), findsOneWidget);
      expect(find.text(S.current.Dp_Lang_Japanese), findsOneWidget);
      final pictures = tester.widgetList<CastPicture>(find.byType(CastPicture)).toList();
      expect(pictures.length, 2);
      expect(pictures.every((p) => p.width == 100 && p.height == 120), isTrue);
      for (final material in tester.widgetList<Material>(
          find.descendant(of: find.byType(CastPicture), matching: find.byType(Material)))) {
        expect(material.elevation, 0);
      }
      for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(of: find.byType(CastPicture), matching: find.byType(DecoratedBox)))) {
        final d = box.decoration;
        if (d is BoxDecoration) expect(d.boxShadow, anyOf(isNull, isEmpty));
      }
    });

    testWidgets('a missing picture is the round placeholder, never a grey box', (tester) async {
      await pumpInApp(tester, const CastPicture(url: 'https://cdn.myanimelist.net/images/questionmark_23.gif'));
      expect(find.byType(RoundAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
