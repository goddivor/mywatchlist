import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_api/client/http_connect.dart';
import 'package:mwl_commons/mwl_commons.dart'
    show AnimeDetailHtml, HtmlParsers, Trailer;
import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_meta.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/media_section.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/episodes_page.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/MAL/content/more_info_widget.dart';

import '../../helpers/html_fixtures.dart';
import '../../helpers/pump_app.dart';

/// Trimmed copies of MyAnimeList's pages of Shingeki no Kyojin (anime 16498)
/// and Berserk (manga 2), fetched anonymously on 2026-10-29: the left column
/// (Information, Statistics) and the promotion video.
String _fixture(String name) =>
    File('test/units/mal-detail-sidebar/fixtures/$name').readAsStringSync();

MalAnime _anime({
  MyListStatus? entry,
  int? episodes = 25,
  String? nsfw,
  String? createdAt,
  List<Genre>? genres,
}) =>
    MalAnime(
      id: 16498,
      title: 'Shingeki no Kyojin',
      numEpisodes: episodes,
      myListStatus: entry,
      nsfw: nsfw,
      createdAt: createdAt,
      genres: genres,
    );

MyListStatus _entry(String status, int watched, {bool rewatching = false}) =>
    MyListStatus(
      status: status,
      score: 0,
      numEpisodesWatched: watched,
      isRewatching: rewatching,
      updatedAt: '2026-10-01T10:00:00+00:00',
    );

DetailData _data(MalAnime content, {String category = 'anime', Map<String, dynamic>? html}) =>
    DetailData(
      id: content.id,
      category: category,
      content: content,
      html: html,
      state: DetailLoadState.loaded,
    );

void main() {
  setUpAll(() async => S.load(const Locale('en')));
  setUp(Preferences.reset);
  tearDown(MalEpisodesPage.reset);

  group('sidebar parser', () {
    test('anime: favorites, producers, licensors, themes, demographic', () {
      final sidebar =
          HtmlParsers.parseDetailSidebar(htmlFixture(_fixture('anime_16498_2026-10.html')));
      expect(sidebar.favorites, 193172);
      expect(sidebar.producers.map((l) => l.name), [
        'Production I.G',
        'Dentsu',
        'Mainichi Broadcasting System',
        'Pony Canyon',
        'Kodansha',
        'Pony Canyon Enterprises',
      ]);
      expect(sidebar.producers.first.url,
          'https://myanimelist.net/anime/producer/10/Production_IG');
      expect(sidebar.licensors.single.name, 'Funimation');
      expect(sidebar.themes.map((l) => l.name), ['Gore', 'Military', 'Survival']);
      expect(sidebar.demographics.single.name, 'Shounen');
      expect(sidebar.demographics.single.url, contains('/anime/genre/27/'));
    });

    test('manga: themes and demographic, no producers', () {
      final sidebar =
          HtmlParsers.parseDetailSidebar(htmlFixture(_fixture('manga_2_2026-10.html')));
      expect(sidebar.favorites, 139884);
      expect(sidebar.producers, isEmpty);
      expect(sidebar.themes.map((l) => l.name), ['Gore', 'Military', 'Psychological']);
      expect(sidebar.demographics.single.name, 'Seinen');
    });

    test('a page without the column gives nothing and does not throw', () {
      final sidebar = HtmlParsers.parseDetailSidebar(htmlFixture('<p>Maintenance</p>'));
      expect(sidebar.favorites, isNull);
      expect(sidebar.themes, isEmpty);
    });

    test('"None found" rows are skipped', () {
      final sidebar = HtmlParsers.parseDetailSidebar(htmlFixture(
          '<div class="leftside"><div class="spaceit_pad"><span class="dark_text">Licensors:</span>'
          'None found, <a href="/dbchanges.php?aid=1&t=addproducers">add some</a></div>'
          '<div class="spaceit_pad"><span class="dark_text">Theme:</span>'
          '<a href="/anime/genre/50/Adult_Cast" title="Adult Cast">Adult Cast</a></div></div>'));
      expect(sidebar.licensors, isEmpty);
      expect(sidebar.themes.single.name, 'Adult Cast');
    });

    test('the page fields cross the backend as JSON and come back', () {
      final json = HttpConnect.parseHtml(
        _fixture('anime_16498_2026-10.html'),
        (doc) => AnimeDetailHtml(
          favorites: HtmlParsers.parseDetailSidebar(doc).favorites,
          themes: HtmlParsers.parseDetailSidebar(doc).themes,
          resources: const [],
          trailer: Trailer(),
        ),
      ) as Map<String, dynamic>;
      expect(json['favorites'], 193172);
      final back = AnimeDetailHtml.fromJson(json);
      expect(back.themes!.map((l) => l.name), ['Gore', 'Military', 'Survival']);
    });
  });

  group('default anime tabs', () {
    test('Episodes comes right after Related', () {
      final order = defaultAnimeTabOrder;
      expect(order.indexOf(TabType.Episodes), order.indexOf(TabType.Related) + 1);
      expect(defaultMangaTabOrder, isNot(contains(TabType.Episodes)));
    });

    test('a saved order from before the section gets it after Related', () {
      final saved = [
        for (final type in defaultAnimeTabOrder)
          if (type != TabType.Episodes) DetailTabPreference(type),
      ];
      final tabs = ContentPreferences.completeTabs(saved, defaultAnimeTabOrder);
      expect(tabs.map((t) => t.tabType), defaultAnimeTabOrder);

      final custom = ContentPreferences.fromJson({
        'animeTabs': [
          {'tabType': 'More_Info', 'visibility': true},
          {'tabType': 'Related', 'visibility': false},
          {'tabType': 'Synopsis', 'visibility': true},
        ],
      }).animeTabs;
      expect(custom.take(4).map((t) => t.tabType),
          [TabType.More_Info, TabType.Related, TabType.Episodes, TabType.Synopsis]);
    });
  });

  group('next episode', () {
    test('only for an anime being watched, on hold or rewatched', () {
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('watching', 7)))), 8);
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('on_hold', 0)))), 1);
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('completed', 25, rewatching: true)))),
          isNull, reason: 'MAL counts a rewatch from 25');
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('completed', 3, rewatching: true)))), 4);
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('completed', 25)))), isNull);
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('plan_to_watch', 0)))), isNull);
      expect(nextEpisodeToWatch(_data(_anime())), isNull, reason: 'not on the MAL list');
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('watching', 25)))), isNull);
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('watching', 30), episodes: 0))), 31,
          reason: 'unknown total');
      expect(nextEpisodeToWatch(_data(_anime(entry: _entry('reading', 3)), category: 'manga')),
          isNull);
    });

    testWidgets('the header shows the number, then the title of the episode list',
        (tester) async {
      MalEpisodesPage.parseInline = true;
      Uri? asked;
      MalEpisodesPage.fetch = (url) async {
        asked = url;
        return '<table class="episode_list"></table>';
      };
      MalEpisodesPage.jikanPage = (id, page) async => throw Exception('offline');
      final data = _data(_anime(entry: _entry('watching', 7)));
      await pumpInApp(tester, SizedBox(width: 200, height: 300, child: DetailHeaderMeta(data: data)));
      expect(find.text(S.current.Dsb_Next_Episode), findsOneWidget);
      expect(find.text(S.current.Dsb_Next_Episode_Number(8)), findsOneWidget);
      await tester.pumpAndSettle();
      expect(asked?.query, 'offset=0');
    });

    test('episode title: English first, then romaji, then Japanese', () {
      const page = EpisodesPage(episodes: [
        EpisodeEntry(number: 8, title: '', romaji: 'Kokoro', japanese: '心'),
        EpisodeEntry(number: 9, title: ''),
      ]);
      expect(episodeTitle(page, 8), 'Kokoro');
      expect(episodeTitle(page, 9), isNull);
      expect(episodeTitle(page, 10), isNull);
    });
  });

  group('header marks', () {
    testWidgets('18+ for black and gray entries, favorites after members', (tester) async {
      await pumpInApp(
          tester,
          SizedBox(
            width: 200,
            height: 300,
            child: DetailHeaderMeta(
                data: _data(_anime(nsfw: 'gray'), html: {'favorites': 193172})),
          ));
      expect(find.text(S.current.Dsb_Adult), findsOneWidget);
      expect(find.text('193,172'), findsOneWidget);

      await pumpInApp(tester,
          SizedBox(width: 200, height: 300, child: DetailHeaderMeta(data: _data(_anime(nsfw: 'white')))));
      expect(find.text(S.current.Dsb_Adult), findsNothing);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    test('card nodes read the MAL and Jikan ratings', () {
      final mal = Anime.fromMAlJson({'id': 1, 'title': 'x', 'nsfw': 'black'});
      expect(mal.isAdult, isTrue);
      expect(Anime.fromMAlJson(mal.toJson()).nsfw, 'black');
      expect(Anime.nsfwFromJikanRating('R+ - Mild Nudity'), 'gray');
      expect(Anime.nsfwFromJikanRating('Rx - Hentai'), 'black');
      expect(Anime.nsfwFromJikanRating('PG-13 - Teens 13 or older'), 'white');
      expect(Anime.nsfwFromJikanRating(null), isNull);
    });
  });

  group('media section', () {
    test('the MAL page PV stands in for Jikan', () {
      final data = _data(_anime(), html: {
        'trailer': {
          'title': 'PV 2',
          'url': 'https://www.youtube-nocookie.com/embed/LHtdKWJdif4?enablejsapi=1',
        },
      });
      final videos = mediaVideos(data)!;
      expect(videos.promo!.single.title, 'PV 2');
      expect(videos.promo!.single.trailer!.embedUrl, contains('LHtdKWJdif4'));
      expect(mediaSection(data), isNotNull);
    });

    test('no PV and no Jikan: no Media section', () {
      final data = _data(_anime(), html: {'trailer': {'title': '', 'url': ''}});
      expect(mediaVideos(data), isNull);
      expect(mediaSection(data), isNull);
    });
  });

  group('more info', () {
    testWidgets('page rows: producers, licensors, themes, demographic, added date',
        (tester) async {
      final doc = htmlFixture(_fixture('anime_16498_2026-10.html'));
      final sidebar = HtmlParsers.parseDetailSidebar(doc);
      final html = HttpConnect.parseHtml(
        _fixture('anime_16498_2026-10.html'),
        (_) => AnimeDetailHtml(
          resources: const [],
          trailer: Trailer(),
          producers: sidebar.producers,
          licensors: sidebar.licensors,
          themes: sidebar.themes,
          demographics: sidebar.demographics,
        ),
      ) as Map<String, dynamic>;
      await pumpInApp(
        tester,
        SingleChildScrollView(
          child: MoreInfoWidget(
            anime: _anime(
              createdAt: '2012-12-05T13:29:26+00:00',
              genres: [Genre(id: 1, name: 'Action'), Genre(id: 58, name: 'Gore')],
            ),
            html: html,
            horizPadding: 8,
          ),
        ),
      );
      expect(find.text(S.current.Dsb_Producers), findsOneWidget);
      expect(find.text('Production I.G'), findsOneWidget);
      expect(find.text(S.current.Dsb_Licensors), findsOneWidget);
      expect(find.text(S.current.Themes), findsOneWidget);
      expect(find.text(S.current.Dsb_Demographic), findsOneWidget);
      expect(find.text('Shounen'), findsOneWidget);
      expect(find.text('Gore'), findsOneWidget, reason: 'a theme, not repeated as a genre');
      expect(find.text('Action'), findsOneWidget);
      expect(find.text(S.current.Dsb_Added_To_Mal), findsOneWidget);
    });
  });
}
