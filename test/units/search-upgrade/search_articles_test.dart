import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_service.dart';
import 'package:mywatchlist/screens/search/search_articles_parser.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';

AnimeNewsOrFeaturedResult _fixture(String name) {
  final body = File('test/units/search-upgrade/fixtures/mal_$name.html').readAsStringSync();
  return parseLatestArticles(body);
}

void main() {
  tearDown(SearchService.reset);

  test('news and featured are browsable with no text and no tag', () {
    expect(SearchCategory.isBrowsable(SearchCategory.news), isTrue);
    expect(SearchCategory.isBrowsable(SearchCategory.featured), isTrue);
    expect(SearchCategory.isBrowsable(SearchCategory.anime), isFalse);
  });

  test('the saved pages give the newest articles, once each, with a next page', () {
    for (final name in ['featured', 'news', 'featured_2026_11', 'news_2026_11']) {
      final result = _fixture(name);
      final ids = result.newsorfeatured.map((e) => e.id).toList();
      expect(ids.length, greaterThanOrEqualTo(10), reason: name);
      expect(ids.toSet().length, ids.length, reason: name);
      expect(result.newsorfeatured.first.title, isNotEmpty);
      expect(result.newsorfeatured.first.url, contains('/${name.split('_').first}/'));
      expect(result.newsorfeatured.first.imageUrl, startsWith('https://'));
      expect(result.paging.next, isNotEmpty, reason: name);
    }
  });

  test('the November 2026 pages: every row of the first list, the featured cards, page 2 next', () {
    final news = _fixture('news_2026_11');
    expect(news.newsorfeatured.length, 20);
    expect(news.newsorfeatured.first.title, "'Tamon-kun Ima Docchi!?' Second Season in Production");
    expect(news.newsorfeatured.first.tags, 'Adapts Manga, New Anime');
    expect(news.newsorfeatured.first.text, startsWith('The F/ACE First Live'));
    expect(news.paging.next, 'https://myanimelist.net/news?p=2');
    final featured = _fixture('featured_2026_11');
    expect(featured.newsorfeatured.length, greaterThanOrEqualTo(20));
    expect(featured.newsorfeatured.first.id, 2422);
    expect(featured.newsorfeatured.first.imageUrl, startsWith('https://cdn.myanimelist.net/'));
    expect(featured.paging.next, 'https://myanimelist.net/featured?p=2');
  });

  for (final category in [SearchCategory.featured, SearchCategory.news]) {
    test('$category with no tag and no text returns the latest articles', () async {
      final saved = _fixture(category);
      expect(saved.newsorfeatured, isNotEmpty);
      String? askedTag = 'unset';
      String? askedQuery;
      SearchService.articleFetch = ({required category, required query, tag, required page}) async {
        askedTag = tag;
        askedQuery = query;
        return saved;
      };
      final page = await const SearchService().search(SearchRequest(category: category, query: ''));
      expect(page.hasResults, isTrue);
      expect(page.articles, isNotEmpty);
      expect(askedTag, isNull);
      expect(askedQuery, '');
    });
  }
}
