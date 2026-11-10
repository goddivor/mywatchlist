import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';

import '../../helpers/html_fixtures.dart';

/// One anime result of /search/all in MAL's old layout: type and count on one line.
const _oldFormat = '''
<html><body><article>
<div class="list di-t w100">
  <div class="picSurround di-tc thumb">
    <a href="https://myanimelist.net/anime/52991/Sousou_no_Frieren">
      <img data-src="https://cdn.myanimelist.net/r/100x140/images/anime/1015/138006.jpg">
    </a>
  </div>
  <div class="information di-tc va-t pt4 pl8">
    <a href="https://myanimelist.net/anime/52991/Sousou_no_Frieren">Sousou no Frieren</a>
    <div class="pt8 fs10 lh14 fn-grey4">
      <a href="https://myanimelist.net/topanime.php?type=tv">TV</a> (28 eps)<br>
      Scored 9.24<br>
      1,537,256 members<br>
    </div>
  </div>
</div>
</article></body></html>
''';

void main() {
  group('parseInfoLines', () {
    test('reads the current layout, type and count on two lines', () {
      final info = HtmlParsersApp.parseInfoLines(
          ['TV', '(28 eps)', 'Scored 9.24', '1,537,256 members']);
      expect(info.mediaType, 'TV');
      expect(info.count, 28);
      expect(info.score, 9.24);
      expect(info.members, 1537256);
    });

    test('reads the old layout, type and count on one line', () {
      final info =
          HtmlParsersApp.parseInfoLines(['TV (28 eps)', 'Scored 9.24', '1,537,256 members']);
      expect(info.mediaType, 'TV');
      expect(info.count, 28);
      expect(info.score, 9.24);
      expect(info.members, 1537256);
    });

    test('does not depend on the order of the lines', () {
      final info = HtmlParsersApp.parseInfoLines(
          ['630,307 members', 'Scored 8.84', 'TV', '(10 eps)']);
      expect(info.mediaType, 'TV');
      expect(info.count, 10);
      expect(info.score, 8.84);
      expect(info.members, 630307);
    });

    test('leaves missing or unknown values null', () {
      final info = HtmlParsersApp.parseInfoLines(['TV', 'Scored N/A', '118,321 members']);
      expect(info.mediaType, 'TV');
      expect(info.count, isNull);
      expect(info.score, isNull);
      expect(info.members, 118321);

      final unknownCount = HtmlParsersApp.parseInfoLines(['ONA', '(? eps)']);
      expect(unknownCount.mediaType, 'ONA');
      expect(unknownCount.count, isNull);
      expect(unknownCount.members, isNull);

      final empty = HtmlParsersApp.parseInfoLines(const []);
      expect(empty.mediaType, isNull);
      expect(empty.score, isNull);
    });

    test('reads manga volumes', () {
      final info = HtmlParsersApp.parseInfoLines(['Manga (15 vols)', 'Scored 8.87', '180,041 members']);
      expect(info.mediaType, 'Manga');
      expect(info.count, 15);
      expect(info.score, 8.87);
      expect(info.members, 180041);
    });
  });

  group('parseAllSearchResults', () {
    test('reads a fresh MAL page (2026-10-28)', () {
      final doc = htmlFixture(
          File('test/units/explore-crash/fixtures/mal_search_all_frieren_2026-10-28.html')
              .readAsStringSync());
      final result = HtmlParsersApp.parseAllSearchResults(doc);

      final anime = result.categories['anime']!;
      final frieren = anime.firstWhere((a) => a.id == 52991);
      expect(frieren.title, 'Sousou no Frieren');
      expect(frieren.mediaType, 'TV');
      expect(frieren.numEpisodes, 28);
      expect(frieren.score, 9.24);
      expect(frieren.members, 1537256);

      final second = anime.firstWhere((a) => a.id == 59978);
      expect(second.numEpisodes, 10);
      expect(second.score, 8.84);
      expect(second.members, 630307);

      final manga = result.categories['manga']!.firstWhere((m) => m.id == 126287);
      expect(manga.mediaType, 'Manga');
      expect(manga.numEpisodes, 15);
      expect(manga.score, 8.87);
      expect(manga.members, 180041);
    });

    test('still reads the old layout', () {
      final result = HtmlParsersApp.parseAllSearchResults(htmlFixture(_oldFormat));
      final frieren = result.categories['anime']!.single;
      expect(frieren.id, 52991);
      expect(frieren.title, 'Sousou no Frieren');
      expect(frieren.mediaType, 'TV');
      expect(frieren.numEpisodes, 28);
      expect(frieren.score, 9.24);
      expect(frieren.members, 1537256);
    });
  });
}
