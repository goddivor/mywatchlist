import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' hide Constants, ContentType;
import 'package:mywatchlist/services/api/mwl_api.dart';

import '../../helpers/html_fixtures.dart';
import '../../helpers/no_network.dart';

String _fixture(String name) =>
    File('test/units/profile-tabs/fixtures/$name').readAsStringSync();

void main() {
  setUpAll(() {
    forbidNetwork();
    dotenv.testLoad(fileInput: 'MAL_CLIENT_ID=cid');
  });

  group('global recommendations (saved MAL page)', () {
    test('every block reads as a liked/recommended pair with its reason and author', () {
      final recs = PageParsers.parseRecentRecommendations(
        htmlFixture(_fixture('recommendations_feed.html')),
        'anime',
      );
      expect(recs, hasLength(3));
      final first = recs.first;
      expect(first.id, 226469);
      expect(first.category, 'anime');
      expect(first.source.id, 486);
      expect(first.source.title, 'Kino no Tabi: The Beautiful World');
      expect(first.recommended.id, 35838);
      expect(first.recommended.title, 'Shoujo Shuumatsu Ryokou');
      expect(first.source.image?.medium, startsWith('https://cdn.myanimelist.net/images/anime/'));
      expect(first.source.image?.large, contains('/r/100x140/'));
      expect(first.username, 'Anonymous_Llama');
      expect(first.timeAdded, '4 hours ago');
      expect(first.text, startsWith('Both shows have interesting settings'));
      expect(first.text, contains("Kino's Journey"));
    });

    test('round trips through JSON and a page without blocks is empty', () {
      final recs = PageParsers.parseRecentRecommendations(
        htmlFixture(_fixture('recommendations_feed.html')),
        'anime',
      );
      final back = GlobalRecommendationHtml.fromJson(recs.first.toJson());
      expect(back.recommended.id, recs.first.recommended.id);
      expect(PageParsers.parseRecentRecommendations(htmlFixture('<p>nothing</p>'), 'anime'),
          isEmpty);
    });
  });

  group('interest stacks listing (saved MAL page)', () {
    test('parseInterestStackSearch reads the /stacks/search cards', () {
      final stacks =
          HtmlParsers.parseInterestStackSearch(htmlFixture(_fixture('stacks_search.html')));
      expect(stacks, isNotEmpty);
      final first = InterestStack.fromJson(stacks.first);
      expect(first.url, startsWith('https://myanimelist.net/stacks/'));
      expect(first.title, isNotEmpty);
      expect(first.username, isNotNull);
      expect(first.entries, greaterThan(0));
      expect(first.imageUrls, isNotEmpty);
    });
  });

  group('client methods', () {
    test('return null, quickly, when the backend cannot answer', () async {
      final clock = Stopwatch()..start();
      expect(
        await MwlApi.i.getGlobalRecommendations(
            category: 'manga', fromCache: false, timeout: const Duration(seconds: 2)),
        isNull,
      );
      expect(
        await MwlApi.i.getInterestStackList(
            stackType: 'anime', fromCache: false, timeout: const Duration(seconds: 2)),
        isNull,
      );
      expect(clock.elapsed, lessThan(const Duration(seconds: 6)));
    });
  });
}
