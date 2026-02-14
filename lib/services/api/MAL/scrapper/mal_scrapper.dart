import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/models/all_search_result.dart';
import 'package:mywatchlist/services/api/MAL/models/mal_user_search.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/http_connect.dart';
import 'package:mywatchlist/utils/url_formatter.dart';

class MalScraper {
  // Get anime news by scraping HTML
  Future<List<Map<String, String>>> getNews() async {
    final response = await http.get(Uri.parse(Constants.malnewsUrl));

    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      var newsElements = document.querySelectorAll('.news-unit');

      return newsElements
          .map((element) {
            // Extract title
            var linkElement = element.querySelector('.title a');
            var title = linkElement != null ? linkElement.text.trim() : '';

            // Extract text
            var textElement = element.querySelector('.text');
            var text = textElement != null ? textElement.text.trim() : '';

            // Extract tags
            var tagElements = element.querySelectorAll('.information .tags a');
            var tags = tagElements.map((e) => e.text.trim()).join(', ');

            // Extract image
            var imageElement = element.querySelector('.image-link img');
            var srcset = imageElement != null
                ? imageElement.attributes['srcset'] ?? ''
                : '';
            var imageUrl = '';

            if (srcset.isNotEmpty) {
              var srcsetUrls =
                  srcset.split(',').map((e) => e.trim().split(' ')[0]).toList();
              var largeImageUrl = srcsetUrls.firstWhere(
                  (url) => url.contains('r/200x312'),
                  orElse: () => '');
              imageUrl = largeImageUrl;
            }

            if (imageUrl.isNotEmpty) {
              return {
                'title': title,
                'text': text,
                'tags': tags,
                'imageUrl': imageUrl,
              };
            } else {
              return null; // Skip news with invalid image URLs
            }
          })
          .where((element) => element != null)
          .toList()
          .cast<Map<String, String>>();
    } else {
      throw Exception('Failed to load news');
    }
  }

  // Get anime news
  Future<Map<String, dynamic>?> getAnimeNews(
      {String animenewslink = Constants.malnewsUrl}) async {
    final newsContent = await HttpConnect.htmlPage(
      animenewslink,
      HtmlParsers.parseAnimeNewsOrFeatured,
    );
    return newsContent;
  }

  // Get anime featured articles
  Future<Map<String, dynamic>?> getAnimeFeatured(
      {String animefeaturedlink = Constants.malfeaturedUrl}) async {
    final featuredContent = await HttpConnect.htmlPage(
      animefeaturedlink,
      HtmlParsers.parseAnimeNewsOrFeatured,
    );
    return featuredContent;
  }

  // Get anime news or featured articles
  Future<Map<String, dynamic>?> getAnimeNewsOrFeatured(
      String newsorfeaturedlink) async {
    final newsorfeaturedContent = await HttpConnect.htmlPage(
      newsorfeaturedlink,
      HtmlParsers.parseAnimeNewsOrFeatured,
    );
    return newsorfeaturedContent;
  }

  // Get anime featured tags list
  Future<Map<String, dynamic>?> getAnimeFeaturedTagsList() async {
    final featuredTagsContent = await HttpConnect.htmlPage(
      Constants.malfeaturedTagsUrl,
      HtmlParsers.parseAnimeFeaturedTags,
    );
    return featuredTagsContent;
  }

  // Get anime news tags list
  Future<Map<String, dynamic>?> getAnimeNewsTagsList() async {
    final newsTagsContent = await HttpConnect.htmlPage(
      Constants.malnewsTagsUrl,
      HtmlParsers.parseAnimeNewsTags,
    );
    return newsTagsContent;
  }

  // Get anime/manga detailed info by content id (HTML scraping)
  Future<Map<String, dynamic>?> getAnimeDetailedHtml(
      ContentType type, int animeId) async {
    String baseurl = type == ContentType.anime
        ? Constants.malanimeUrl
        : Constants.malmangaUrl;
    final animeContent = await HttpConnect.htmlPage(
      '$baseurl/$animeId',
      (param0) => HtmlParsers.parseAnimeDetailedHtml(param0, type: type),
    );
    return animeContent;
  }

  // Get user history by username
  Future<Map<String, dynamic>?> getUserHistory(String username) async {
    final String userHistoryUrl = '${Constants.maluserHistoryUrl}/$username';
    final userHistoryContent = await HttpConnect.htmlPage(
      userHistoryUrl,
      HtmlParsers.parseUserHistory,
    );
    return userHistoryContent;
  }

  // Get user friends list by username with pagination support
  Future<Map<String, dynamic>?> getUserFriends(String username, {bool fetchAll = false}) async {
    final String baseUrl = '${Constants.maluserProfileUrl}/$username/friends';

    if (!fetchAll) {
      return await HttpConnect.htmlPage(baseUrl, HtmlParsers.parseUserFriends);
    }

    // Paginate through all friends pages
    List<dynamic> allFriends = [];
    int offset = 0;
    const int pageSize = 100;

    while (true) {
      final url = offset == 0 ? baseUrl : '$baseUrl?offset=$offset';
      final result = await HttpConnect.htmlPage(url, HtmlParsers.parseUserFriends);
      if (result == null) break;

      final friends = result['friends'] as List? ?? [];
      if (friends.isEmpty) break;

      allFriends.addAll(friends);

      // MAL shows 100 friends per page; if fewer, we've reached the last page
      if (friends.length < pageSize) break;
      offset += pageSize;
    }

    return {'friends': allFriends};
  }

  // Get anime/manga genre list
  Future<Map<String, dynamic>?> getGenreList(ContentType type) async {
    String baseurl = type == ContentType.anime
        ? Constants.malanimeUrl
        : Constants.malmangaUrl;
    final genreListUrl = '$baseurl.php';
    final genreListContent = await HttpConnect.htmlPage(
      genreListUrl,
      HtmlParsers.parseGenres,
    );
    return genreListContent;
  }

  // Get studio list (producers for anime, magazines for manga)
  Future<Map<String, dynamic>?> getStudioList(ContentType type) async {
    String baseurl = type == ContentType.anime
        ? Constants.malproducerUrl
        : Constants.malmagazineUrl;
    final studioListContent = await HttpConnect.htmlPage(
      baseurl,
      HtmlParsers.parseProducer,
    );
    return studioListContent;
  }

  // Get featured articles for a specific anime
  Future<Map<String, dynamic>?> getAnimeFeaturedArticles(
      int animeId, String animeName, {String category = "anime"}) async {
    final formattedName = animeName.formatForUrl();
    final baseUrl = category == "manga" ? Constants.malmangaUrl : Constants.malanimeUrl;
    final featuredUrl =
        '$baseUrl/$animeId/$formattedName/featured';

    final featuredContent = await HttpConnect.htmlPage(
      featuredUrl,
      HtmlParsers.parseAnimeFeaturedArticles,
    );

    return featuredContent;
  }

  /// Search all MAL categories at once (HTML scraping /search/all).
  Future<AllSearchResult?> searchAllCategories(String query) async {
    try {
      final url =
          'https://myanimelist.net/search/all?q=${Uri.encodeComponent(query)}&cat=all';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        return HtmlParsers.parseAllSearchResults(document);
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Get paginated club list (HTML scraping /clubs.php).
  Future<Map<String, dynamic>?> getClubs({int page = 1}) async {
    final clubsContent = await HttpConnect.htmlPage(
      'https://myanimelist.net/clubs.php?p=$page',
      HtmlParsers.parseClubList,
    );
    return clubsContent;
  }

  /// Search clubs by name (HTML scraping /clubs.php).
  Future<Map<String, dynamic>?> searchClubs(String query,
      {int page = 1}) async {
    final clubsContent = await HttpConnect.htmlPage(
      'https://myanimelist.net/clubs.php?action=find&q=${Uri.encodeComponent(query)}&p=$page',
      HtmlParsers.parseClubList,
    );
    return clubsContent;
  }

  /// Get clubs for a specific user (HTML scraping /profile/{username}/clubs).
  Future<Map<String, dynamic>?> getUserClubs(String username) async {
    final clubsContent = await HttpConnect.htmlPage(
      '${Constants.maluserProfileUrl}/$username/clubs',
      HtmlParsers.parseUserClubs,
    );
    return clubsContent;
  }

  /// Get a featured article by ID and title (HTML scraping).
  Future<Map<String, dynamic>?> getFeaturedArticle(int id, String? title,
      {String category = "featured"}) async {
    String url = 'https://myanimelist.net/$category/$id';
    if (category == 'featured' && title != null) {
      url = '$url/${title.formatForUrl()}';
    }
    final content = await HttpConnect.htmlPage(
      url,
      (doc) => HtmlParsers.parseFeaturedArticle(doc, id, category: category),
    );
    return content;
  }

  /// Search for MAL users by username (HTML scraping).
  Future<MalUserSearchResult?> searchUser(String query,
      {int offset = 0}) async {
    try {
      final url =
          'https://myanimelist.net/users.php?cat=user&q=${Uri.encodeComponent(query)}&show=$offset';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        return HtmlParsers.parseUserSearch(document);
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }
}
