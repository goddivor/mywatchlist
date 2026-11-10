import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_episode.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/episodes_page.dart';

void main() {
  final body = File('test/units/mal-episodes/episode_list.html').readAsStringSync();

  setUpAll(() => initializeDateFormatting('en_US'));
  tearDown(MalEpisodesPage.reset);

  test('parses rows of the saved MAL episode page', () {
    final page = parseEpisodeList(body);
    expect(page.episodes, hasLength(2));
    final e = page.episodes.first;
    expect(e.number, 1);
    expect(e.title, 'Asteroid Blues');
    expect(e.japanese, 'アステロイド・ブルース');
    expect(e.aired, DateTime(1998, 10, 24));
    expect(e.score, 4.32);
    expect(e.topicId, 29264);
    expect(e.replies, 244);
    expect(page.total, 26);
    expect(page.offsets, [0, 100]);
    expect(page.hasMore, isTrue);
  });

  test('synopsis is the text after its heading', () {
    const html = '<div><h2>Synopsis</h2>First line.<br>Second.<div>x</div></div>';
    expect(parseEpisodeSynopsis(html), contains('First line.'));
    expect(parseEpisodeSynopsis('<h2>Synopsis</h2><div>y</div>'), isNull);
  });

  test('Jikan flags are merged into the MAL page', () async {
    MalEpisodesPage.parseInline = true;
    MalEpisodesPage.fetch = (_) async => body;
    MalEpisodesPage.jikanPage = (a, b) async => [
          AnimeEpisode(malId: 2, filler: true, recap: false),
        ];
    final page = await MalEpisodesPage.load(1);
    expect(page.episodes[0].filler, isFalse);
    expect(page.episodes[1].filler, isTrue);
  });

  test('falls back to Jikan when MAL fails', () async {
    MalEpisodesPage.parseInline = true;
    MalEpisodesPage.fetch = (_) async => throw Exception('down');
    MalEpisodesPage.jikanPage = (a, b) async => [
          AnimeEpisode(
              malId: 3,
              title: 'T',
              aired: '2020-01-02T00:00:00+00:00',
              forumUrl: 'https://myanimelist.net/forum/?topicid=77'),
        ];
    final page = await MalEpisodesPage.load(5);
    expect(page.episodes.single.number, 3);
    expect(page.episodes.single.topicId, 77);
  });
}
