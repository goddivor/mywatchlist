import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/featured_section.dart';

/// Owner's rule: a title without featured articles has no Featured Articles
/// section at all (title row and tab), as in DailyAL.
void main() {
  tearDown(FeaturedArticles.reset);

  test('an empty answer marks the title, so the section is dropped', () async {
    var calls = 0;
    FeaturedArticles.fetch = (id, category, name) async {
      calls++;
      return {'featuredArticles': <dynamic>[]};
    };
    expect(FeaturedArticles.isKnownEmpty(1, 'anime'), isFalse);
    final result = await FeaturedArticles.load(1, 'anime', 'Cowboy Bebop');
    expect(result.featuredArticles, isEmpty);
    expect(FeaturedArticles.isKnownEmpty(1, 'anime'), isTrue);
    expect(FeaturedArticles.isKnownEmpty(1, 'manga'), isFalse);

    // The section body asks again: same answer, no second request.
    await FeaturedArticles.load(1, 'anime', 'Cowboy Bebop');
    expect(calls, 1);
  });

  test('articles keep the section', () async {
    FeaturedArticles.fetch = (id, category, name) async => {
          'featuredArticles': [
            {
              'title': 't',
              'text': 'x',
              'url': 'https://myanimelist.net/featured/1',
              'imageUrl': '',
              'author': 'a',
              'authorUrl': '',
              'views': 1,
              'tags': <String>[],
            },
          ],
        };
    final result = await FeaturedArticles.load(2, 'anime', 'x');
    expect(result.featuredArticles, hasLength(1));
    expect(FeaturedArticles.isKnownEmpty(2, 'anime'), isFalse);
  });

  test('a failed page is not "empty" and is asked again', () async {
    var calls = 0;
    FeaturedArticles.fetch = (id, category, name) async {
      calls++;
      return calls == 1 ? null : {'featuredArticles': <dynamic>[]};
    };
    await expectLater(FeaturedArticles.load(3, 'anime', 'x'), throwsStateError);
    expect(FeaturedArticles.isKnownEmpty(3, 'anime'), isFalse);
    await FeaturedArticles.load(3, 'anime', 'x');
    expect(calls, 2);
    expect(FeaturedArticles.isKnownEmpty(3, 'anime'), isTrue);
  });
}
