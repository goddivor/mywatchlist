import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/Jikan/mal_news_page.dart';
import 'package:mywatchlist/widgets/MAL/home/show_news.dart';

import '../../helpers/no_network.dart';
import '../../helpers/pump_app.dart';

/// Part of https://myanimelist.net/anime/1/_/news (Cowboy Bebop), as served on 2026-10-28.
String _fixture() => File('test/units/detail-polish/fixtures/mal_news_page.html').readAsStringSync();

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group("MyAnimeList's news page", () {
    test('every article becomes a news card in the Jikan shape', () {
      final news = parseMalNewsPage(_fixture()).map(AnimeNews.fromJson).toList();
      expect(news.length, 3);
      final first = news.first;
      expect(first.malId, 69976885);
      expect(first.title, 'North American Anime & Manga Releases for October');
      expect(first.excerpt, startsWith('Here are the North American anime, manga'));
      expect(first.excerpt, isNot(contains('read more')));
      expect(first.authorUsername, 'Aiimee');
      expect(first.comments, 1);
      expect(DateTime.parse(first.date!), DateTime(2023, 10, 10, 6, 34));
      expect(first.images?.jpg?.imageUrl, startsWith('https://cdn.myanimelist.net/r/100x156/'));
      expect(news[1].comments, 3);
      // An article without its date line is still listed.
      expect(news[2].title, 'North American Anime & Manga Releases for September');
      expect(news[2].date, isNull);
    });

    test('a page without articles gives an empty list', () {
      expect(parseMalNewsPage('<html><body><h2>News</h2><p>No news.</p></body></html>'), isEmpty);
    });

    test('anime and manga pages', () {
      expect(MalNewsPage.url(1, 'anime').toString(), 'https://myanimelist.net/anime/1/_/news');
      expect(MalNewsPage.url(2, 'manga').toString(), 'https://myanimelist.net/manga/2/_/news');
    });

    test('fetch parses the downloaded page and reports a refused one', () async {
      final ok = MockClient((_) async => http.Response(_fixture(), 200));
      expect((await MalNewsPage.fetch(1, 'anime', client: ok)).length, 3);
      final refused = MockClient((_) async => http.Response('', 503));
      await expectLater(MalNewsPage.fetch(1, 'anime', client: refused), throwsA(isA<http.ClientException>()));
    });
  });

  testWidgets('News section: Jikan down, the cards come from MyAnimeList', (tester) async {
    final original = JikanClient.instance;
    addTearDown(() {
      JikanClient.instance = original;
      JikanFallbacks.reset();
      ShowAnimeNews.resetLoader();
    });
    JikanClient.instance = JikanClient(
      client: MockClient((_) async => throw http.ClientException('Connection timed out')),
      minInterval: Duration.zero,
    );
    JikanFallbacks.news = (id, category) async =>
        parseMalNewsPage(_fixture()).map(AnimeNews.fromJson).toList();
    await pumpInApp(tester, const SingleChildScrollView(child: ShowAnimeNews(animeId: 1)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('North American Anime & Manga Releases for October'), findsOneWidget);
    expect(find.text(S.current.Dp_News_Failed), findsNothing);
  });
}
