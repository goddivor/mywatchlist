import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/http_connect.dart';

class MalScraper {
  //get anime news by html
  Future<List<Map<String, String>>> getNews() async {
    final response = await http.get(Uri.parse(Constants.malnewsUrl));

    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      var newsElements = document.querySelectorAll('.news-unit');

      return newsElements
          .map((element) {
            // Récupérer le titre
            var linkElement = element.querySelector('.title a');
            var title = linkElement != null ? linkElement.text.trim() : '';

            // Récupérer le texte
            var textElement = element.querySelector('.text');
            var text = textElement != null ? textElement.text.trim() : '';

            // Récupérer les tags
            var tagElements = element.querySelectorAll('.information .tags a');
            var tags = tagElements.map((e) => e.text.trim()).join(', ');

            // Récupérer l'image
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

  //this method is for getting anime news
  Future<Map<String, dynamic>?> getAnimeNews(
      {String animenewslink = Constants.malnewsUrl}) async {
    final newsContent = await HttpConnect.htmlPage(
      animenewslink,
      HtmlParsers.parseAnimeNewsOrFeatured,
    );
    return newsContent;
  }

  //thid method is for getting anime featured
  Future<Map<String, dynamic>?> getAnimeFeatured(
      {String animefeaturedlink = Constants.malfeaturedUrl}) async {
    final featuredContent = await HttpConnect.htmlPage(
      animefeaturedlink,
      HtmlParsers.parseAnimeNewsOrFeatured,
    );
    return featuredContent;
  }

  //thid method is for getting anime news or featured
  Future<Map<String, dynamic>?> getAnimeNewsOrFeatured(
      String newsorfeaturedlink) async {
    final newsorfeaturedContent = await HttpConnect.htmlPage(
      newsorfeaturedlink,
      HtmlParsers.parseAnimeNewsOrFeatured,
    );
    return newsorfeaturedContent;
  }

  //thid method is for getting anime featured tags list
  Future<Map<String, dynamic>?> getAnimeFeaturedTagsList() async {
    final featuredTagsContent = await HttpConnect.htmlPage(
      Constants.malfeaturedTagsUrl,
      HtmlParsers.parseAnimeFeaturedTags,
    );
    return featuredTagsContent;
  }

  //this method is for getting anime news tags list
  Future<Map<String, dynamic>?> getAnimeNewsTagsList() async {
    final newsTagsContent = await HttpConnect.htmlPage(
      Constants.malnewsTagsUrl,
      HtmlParsers.parseAnimeNewsTags,
    );
    return newsTagsContent;
  }

  //this method is for getting anime detailed by anime id
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

  //this method is for getting user history by username
  Future<Map<String, dynamic>?> getUserHistory(String username) async {
    final String userHistoryUrl = '${Constants.maluserHistoryUrl}/$username';
    final userHistoryContent = await HttpConnect.htmlPage(
      userHistoryUrl,
      HtmlParsers.parseUserHistory,
    );
    return userHistoryContent;
  }

  //this method is for getting user frends (cette method est a revoir pour recuperer toute la liste)
  Future<Map<String, dynamic>?> getUserFriends(String username) async {
    final String userFriendsUrl =
        '${Constants.maluserProfileUrl}/$username/friends';
    final userFriendsContent = await HttpConnect.htmlPage(
      userFriendsUrl,
      HtmlParsers.parseUserFriends,
    );
    return userFriendsContent;
  }

  //this method is for getting anime / manga genre List
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

  //this method is for getting anime studio (producer pour anime/mangazine pour manga) list
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
}
