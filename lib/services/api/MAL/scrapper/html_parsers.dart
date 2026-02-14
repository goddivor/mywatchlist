// ignore_for_file: unused_element

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' hide Genre;
import 'package:mywatchlist/services/api/MAL/models/all_search_result.dart';
import 'package:mywatchlist/services/api/MAL/models/mal_user_search.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_featured.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_featured_tags.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_tags.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/genre.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/paging.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_history.dart';
import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart';

class HtmlParsers {
  static final unescape = HtmlUnescape();

  static String getImageUrlByQuality(
      Element? imageElement, String imageQuality) {
    // Initialize empty image URL
    String imageUrl = '';

    // Check if the element is not null
    if (imageElement != null) {
      // Check if the 'data-srcset' attribute is present
      if (imageElement.attributes.containsKey('data-srcset')) {
        // Extract 'srcset' and transform it into a list of URLs
        var srcset = imageElement.attributes['data-srcset']!;
        var srcsetUrls =
            srcset.split(',').map((e) => e.trim().split(' ')[0]).toList();

        // Find the first URL matching the requested quality
        imageUrl = srcsetUrls.firstWhere((url) => url.contains(imageQuality),
            orElse: () => '');
      } else if (imageElement.attributes.containsKey('data-src')) {
        // If 'srcset' is not available, use 'data-src'
        imageUrl = imageElement.attributes['data-src']!;
      } else if (imageElement.attributes.containsKey('src')) {
        // If 'data-src' is not available, use 'src'
        imageUrl = imageElement.attributes['src']!;
      }
    }

    // Return the image URL (or empty string if none found)
    return imageUrl;
  }

  static String getOriginalImageQuality(
      Element? imageElement, String imageQuality) {
    // Initialize image URL variable
    String imageUrl = '';

    // Check if the element is not null
    if (imageElement != null) {
      // Check if 'data-src' attribute exists, otherwise use 'src'
      imageUrl = imageElement.attributes['data-src'] ??
          imageElement.attributes['src'] ??
          '';
    }

    // If a valid URL is found, modify it to get original quality
    if (imageUrl.isNotEmpty) {
      imageUrl = stripImageResize(imageUrl);
    }

    // Return the modified URL or empty string if none found
    return imageUrl;
  }

  /// Strips the `/r/NxN/` resize prefix from MAL CDN image URLs to get the
  /// original quality image. Also removes query parameters.
  /// Example: `.../r/42x62/images/...?s=abc` → `.../images/...`
  static String stripImageResize(String url) {
    // Remove any /r/{width}x{height}/ resize prefix
    url = url.replaceAll(RegExp(r'/r/\d+x\d+/'), '/');

    // Remove URL query parameters (everything after '?')
    int queryIndex = url.indexOf('?');
    if (queryIndex != -1) {
      url = url.substring(0, queryIndex);
    }

    return url;
  }

  // Parse anime news or featured articles
  static AnimeNewsOrFeaturedResult parseAnimeNewsOrFeatured(Document document) {
    var newsElements = document.querySelectorAll('.news-unit');

    var newsItems = newsElements
        .map((element) {
          // Get the title and URL
          var linkElement = element.querySelector('.title a');
          var title = linkElement != null ? linkElement.text.trim() : '';
          var url =
              linkElement != null ? linkElement.attributes['href']!.trim() : '';

          // Extract the ID from the URL
          int id = 0;
          if (url.startsWith(Constants.malnewsUrl)) {
            id = int.parse(
                url.replaceFirst('${Constants.malnewsUrl}/', '').split('/')[0]);
          } else if (url.startsWith(Constants.malfeaturedUrl)) {
            id = int.parse(url
                .replaceFirst('${Constants.malfeaturedUrl}/', '')
                .split('/')[0]);
          }

          // Get the text
          var textElement = element.querySelector('.text');
          var text = textElement != null ? textElement.text.trim() : '';

          // Get the tags
          var tags = '';
          var tagElements =
              element.querySelectorAll('.information .tags a'); // Linked tags
          if (tagElements.isEmpty) {
            // Fallback: tags in spans
            tagElements = element.querySelectorAll('.information .tags .tag');
          }
          tags = tagElements.map((e) => e.text.trim()).join(', ');

          // Get the image
          var imageElement = element.querySelector('.image-link img');
          var imageQuality = 'r/100x156'; // Image quality x1; 'r/200x312' x2
          var imageUrl = getOriginalImageQuality(imageElement, imageQuality);

          if (imageUrl.isNotEmpty) {
            return AnimeNewsOrFeaturedItem(
              id: id,
              title: title,
              text: text,
              tags: tags,
              imageUrl: imageUrl,
              url: url,
            );
          } else {
            return null; // Skip news with invalid image URLs
          }
        })
        .where((element) => element != null)
        .cast<AnimeNewsOrFeaturedItem>()
        .toList();

    // Parse pagination
    var paging = Paging(previous: '', next: ''); // Default values
    var paginationElement = document.querySelector('.pagination.ac');

    if (paginationElement != null) {
      var currentPageElement = paginationElement.querySelector('.link.current');
      var nextPageElement = currentPageElement?.nextElementSibling;

      var currentPage = currentPageElement?.attributes['href']?.trim() ?? '';
      var nextPage = nextPageElement != null
          ? nextPageElement.attributes['href']?.trim()
          : null;

      paging = Paging(previous: currentPage, next: nextPage);
    }

    return AnimeNewsOrFeaturedResult(newsorfeatured: newsItems, paging: paging);
  }

  // Parse anime featured tags
  static AnimefeaturedTagsResult parseAnimeFeaturedTags(Document document) {
    // Get the tags container
    var tagContainer = document.querySelector('.news-tags-table');

    // Get all tag links
    var tagElements =
        tagContainer?.querySelectorAll('.tag-list a.tag-name-link');

    // Build the tags list
    var tags = tagElements?.map((element) {
          var url = element.attributes['href']!.trim();
          var name = element.querySelector('span.tag-name')?.text.trim() ?? '';

          return AnimeFeaturedTag(url: url, name: name);
        }).toList() ??
        [];

    return AnimefeaturedTagsResult(tags: tags);
  }

  // Parse anime news tags
  static AnimeNewsTagsResult parseAnimeNewsTags(Document document) {
    // Get the tag categories container
    var menuCategoryTags = document.querySelector('.menu-category-tags');

    // Get all category elements
    var categoryElements = menuCategoryTags?.querySelectorAll('.btn-category');

    // Build category list from data-id attributes
    var listCategory = categoryElements?.map((element) {
          return element.attributes['data-id']!.trim();
        }).toList() ??
        [];

    // List to store categories and their tags
    var categories = <AnimeNewsTagCat>[];

    // Iterate through each category
    for (var category in listCategory) {
      var categoryElement = document.getElementById(category);

      if (categoryElement != null) {
        // Get the category name
        var categoryName =
            categoryElement.querySelector('.news-tags-header')?.text.trim() ??
                '';

        // Get all tags for this category
        var tagElements =
            categoryElement.querySelectorAll('.news-tags-table tr');
        var tags = tagElements.map((tagElement) {
          var nameElement = tagElement.querySelector('.tag-name a');
          var descriptionElement =
              tagElement.querySelector('.tag-description span');

          var url = nameElement?.attributes['href']?.trim() ?? '';
          var name = nameElement?.text.trim() ?? '';
          var description = descriptionElement?.text.trim() ?? '';

          return AnimeNewsTag(url: url, name: name, description: description);
        }).toList();

        // Add the category with its tags
        categories.add(AnimeNewsTagCat(categoryName: categoryName, tags: tags));
      }
    }

    return AnimeNewsTagsResult(categories: categories);
  }

  // Helper method to extract title from document
  static _getTitle(Document document, ContentType type) {
    if (type case ContentType.anime) {
      var titleElement = document.querySelector('.title-name strong');
      return titleElement?.text.trim() ?? '';
    } else if (type case ContentType.manga) {
      var titleElement =
          document.querySelector('.h1.edit-info span[itemprop="name"]');
      return titleElement?.text.trim() ?? '';
    } else {
      return null;
    }
  }

  static String _getMainPicture(Document document) {
    var pictureElement =
        document.querySelector('.leftside img[itemprop="image"]');
    return pictureElement?.attributes['data-src']?.trim() ?? '';
  }

  static Trailer _getTrailer(Document document) {
    var trailerElement = document.querySelector('.video-promotion a');
    var url = trailerElement?.attributes['href']?.trim() ?? '';
    var titleElement = trailerElement?.querySelector('.title');
    var title = titleElement?.text.trim() ?? '';

    return Trailer(title: title, url: url);
  }

  static List<Link> _getAvailableAtLinks(Document document) {
    var availableAtElement = document
        .querySelectorAll('.external_links')
        .first; // First .external_links block
    var linkElements = availableAtElement.querySelectorAll('a.ga-click');

    return linkElements.map((e) {
      var name = e.querySelector('.caption')?.text.trim() ??
          ''; // Link text is in div.caption
      var url = e.attributes['href']?.trim() ?? '';
      var imageUrl = e.querySelector('img')?.attributes['src']?.trim() ??
          ''; // Get image URL if it exists
      return Link(
        name: name,
        url: url,
        imageUrl: imageUrl,
        linkType: LinkType.availableAt,
      );
    }).toList();
  }

  static List<Link> _getResourceLinks(Document document) {
    var externalLinksBlocks = document.querySelectorAll('.external_links');
    if (externalLinksBlocks.length < 2) return [];
    var resourceElement = externalLinksBlocks.elementAt(1);
    var linkElements = resourceElement.querySelectorAll('a.ga-click');

    return linkElements.map((e) {
      var name = e.querySelector('.caption')?.text.trim() ??
          ''; // Link text is in div.caption
      var url = e.attributes['href']?.trim() ?? '';
      var imageUrl = e.querySelector('img')?.attributes['src']?.trim() ??
          ''; // Get image URL if it exists
      return Link(
        name: name,
        url: url,
        imageUrl: imageUrl,
        linkType: LinkType.resources,
      );
    }).toList();
  }

  static List<Link> _getStreamingPlatforms(Document document) {
    var streamingElements =
        document.querySelectorAll('.broadcasts .broadcast a');

    return streamingElements.map((e) {
      var name = e.querySelector('.caption')?.text.trim() ??
          ''; // Link text is in div.caption
      var title = e.attributes['title'] ?? e.text.trim();
      var url = e.attributes['href']?.trim() ?? '';
      return Link(
        name: name,
        url: url,
        imageUrl: getDomainAsset(title),
        linkType: LinkType.streaming,
      );
    }).toList();
  }

  static List<AdaptNode> _getAdaptation(Document document) {
    var adaptationElements = document.querySelectorAll('.entries-tile .entry');

    return adaptationElements
        .where((e) => e.text.contains('Adaptation'))
        .map((e) {
      // Get the adaptation image
      var imageElement = e.querySelector('.image img');
      var imageQuality =
          'r/50x70'; // Image quality x1; 'r/100x140' for x2

      var image = getOriginalImageQuality(imageElement, imageQuality).trim();

      // Get the relation (e.g., "Adaptation (Manga)")
      var relationElement = e.querySelector('.content .relation');
      var relation = relationElement?.text.trim() ?? '';

      // Get the adaptation title
      var titleElement = e.querySelector('.content .title a');
      var animeTitle = Link(
        name: titleElement?.text.trim() ?? '',
        url: titleElement?.attributes['href']?.trim() ?? '',
      );

      return AdaptNode(
        image: image,
        relation: relation,
        animeTitle: animeTitle,
      );
    }).toList();
  }

  static List<MangaCharacters> _getMangaCharacters(Document document) {
    // Select the first `.detail-characters-list.clearfix`
    var characterList =
        document.querySelector('.detail-characters-list.clearfix');
    if (characterList == null) {
      return [];
    }

    // Get both columns if they exist
    var leftColumn = characterList.querySelector('.left-column');
    var rightColumn = characterList.querySelector('.left-right');

    // Extract characters from table rows
    List<MangaCharacters> extractMangaCharacters(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<MangaCharacters> mangaCharactersList = [];
      const imageQuality = 'r/42x62';

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 2) {
          continue; // Ensure there are exactly 2 columns (td)
        }

        // Extract character info — strip resize prefix to get original quality
        var characterElement = tds[0].querySelector('.picSurround img');
        var characterImage =
            getOriginalImageQuality(characterElement, imageQuality).trim();
        var characterNameElement = tds[1].querySelector('a');
        var characterName = Link(
          name: characterNameElement?.text.trim() ?? '',
          url: characterNameElement?.attributes['href']?.trim() ?? '',
        );
        var characterRole =
            tds[1].querySelector('.spaceit_pad small')?.text.trim() ?? '';

        var character = CharacterNode(
          image: characterImage,
          name: characterName,
          role: characterRole,
        );

        // Add character to the list
        mangaCharactersList.add(MangaCharacters(character: character));
      }

      return mangaCharactersList;
    }

    // Extract data from both columns if they exist
    List<MangaCharacters> mangaCharactersList = [];
    if (leftColumn != null) {
      mangaCharactersList.addAll(extractMangaCharacters(leftColumn));
    }
    if (rightColumn != null) {
      mangaCharactersList.addAll(extractMangaCharacters(rightColumn));
    }

    return mangaCharactersList;
  }

  static List<CharactersVoiceActors> _getCharactersVoiceActors(
      Document document) {
    // Select the first `.detail-characters-list.clearfix`
    var characterList =
        document.querySelector('.detail-characters-list.clearfix');
    if (characterList == null) {
      return [];
    }

    // Get both columns if they exist
    var leftColumn = characterList.querySelector('.left-column');
    var rightColumn = characterList.querySelector('.left-right');

    // Extract characters and voice actors from table rows
    List<CharactersVoiceActors> extractCharactersVoiceActors(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<CharactersVoiceActors> characterVoiceActorsList = [];

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 3) {
          continue; // Ensure there are exactly 3 columns (td)
        }

        // Extract character info
        // var characterImage = tds[0]
        //         .querySelector('.picSurround img')
        //         ?.attributes['data-src']
        //         ?.trim() ??
        //     '';
        var imageQuality =
            'r/42x62'; // Image quality x1; double for x2
        var characterElement = tds[0].querySelector('.picSurround img');
        // var characterImage = getImageUrlByQuality(characterElement, imageQuality).trim();
        var characterImage =
            getOriginalImageQuality(characterElement, imageQuality).trim();

        var characterNameElement = tds[1].querySelector('h3 a');
        var characterName = Link(
          name: characterNameElement?.text.trim() ?? '',
          url: characterNameElement?.attributes['href']?.trim() ?? '',
        );
        var characterRole =
            tds[1].querySelector('.spaceit_pad small')?.text.trim() ?? '';

        var character = CharacterNode(
          image: characterImage,
          name: characterName,
          role: characterRole,
        );

        // Extract voice actor info
        var voiceActorNameElement = tds[2].querySelector('td.va-t a');
        var voiceActorName = Link(
          name: voiceActorNameElement?.text.trim() ?? '',
          url: voiceActorNameElement?.attributes['href']?.trim() ?? '',
        );
        var voiceActorRole =
            tds[2].querySelector('td.va-t small')?.text.trim() ?? '';
        // var voiceActorImage = tds[2]
        //         .querySelector('.picSurround img')
        //         ?.attributes['data-src']
        //         ?.trim() ??
        //     '';
        var voiceActorElement = tds[2].querySelector('.picSurround img');
        // var voiceActorImage = getImageUrlByQuality(voiceActorElement, imageQuality).trim();
        var voiceActorImage =
            getOriginalImageQuality(voiceActorElement, imageQuality).trim();

        var voiceActor = CharacterNode(
          image: voiceActorImage,
          name: voiceActorName,
          role: voiceActorRole,
        );

        // Add the character/voice actor pair to the list
        characterVoiceActorsList.add(CharactersVoiceActors(
          character: character,
          voiceActor: voiceActor,
        ));
      }

      return characterVoiceActorsList;
    }

    // Extract data from both columns if they exist
    List<CharactersVoiceActors> charactersVoiceActorsList = [];
    if (leftColumn != null) {
      charactersVoiceActorsList
          .addAll(extractCharactersVoiceActors(leftColumn));
    }
    if (rightColumn != null) {
      charactersVoiceActorsList
          .addAll(extractCharactersVoiceActors(rightColumn));
    }

    return charactersVoiceActorsList;
  }

  static List<CharacterNode> _getStaff(Document document) {
    // Select the second `.detail-characters-list.clearfix`
    var staffList =
        document.querySelectorAll('.detail-characters-list.clearfix');
    if (staffList.length < 2) {
      return []; // Ensure there are at least two elements
    }
    var secondStaffList = staffList[1]; // Second element in the list

    // Get both columns if they exist
    var leftColumn = secondStaffList.querySelector('.left-column');
    var rightColumn = secondStaffList.querySelector('.left-right');

    // Extract staff members from table rows
    List<CharacterNode> extractStaff(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<CharacterNode> staffListResult = [];

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 2) {
          continue; // Ensure there are exactly 2 columns (td)
        }

        // Extract staff member image
        var imageQuality =
            'r/42x62'; // Image quality x1; double for x2
        var staffElement = tds[0].querySelector('.picSurround img');
        // var staffImage = getImageUrlByQuality(staffElement, imageQuality).trim();
        var staffImage =
            getOriginalImageQuality(staffElement, imageQuality).trim();

        // Extract name, URL and role of the staff member
        var staffNameElement = tds[1].querySelector('a');
        var staffName = Link(
          name: staffNameElement?.text.trim() ?? '',
          url: staffNameElement?.attributes['href']?.trim() ?? '',
        );
        var staffRole =
            tds[1].querySelector('.spaceit_pad small')?.text.trim() ?? '';

        // Create a CharacterNode object for the staff member
        var staffMember = CharacterNode(
          image: staffImage,
          name: staffName,
          role: staffRole,
        );

        // Add the staff member to the results list
        staffListResult.add(staffMember);
      }

      return staffListResult;
    }

    // Extract data from both columns if they exist
    List<CharacterNode> staffListResult = [];
    if (leftColumn != null) {
      staffListResult.addAll(extractStaff(leftColumn));
    }
    if (rightColumn != null) {
      staffListResult.addAll(extractStaff(rightColumn));
    }

    return staffListResult;
  }

  static List<InterestStack> _getInterestStacks(Document document) {
    var stackElements =
        document.querySelectorAll('.detail-stack-block .column-item');

    return stackElements.map((e) {
      // Get the stack URL
      var urlElement = e.querySelector('a');
      var url = urlElement?.attributes['href']?.trim() ?? '';

      // Get the stack title
      var titleElement = e.querySelector('.title a');
      var title = titleElement?.text.trim() ?? '';

      // Get images associated with the stack
      var imageElements = e.querySelectorAll('.img .edge img');
      var imageUrls = imageElements
          .map((img) => img.attributes['src']?.trim() ?? '')
          .toList();

      // Get the stack author
      var authorElement = e.querySelector('.tag a');
      var username = authorElement?.text.trim() ?? '';

      // Get the stack statistics (Entries and Restacks)
      var statElement = e.querySelector('.foot .stat');
      var statsText = statElement?.text.trim() ?? '';
      int? entries = _getBeforeInt(statsText, endPattern: 'Entries');
      int? reStacks =
          _getBeforeInt(statsText, endPattern: 'Restacks', startPattern: '·');

      // Return an InterestStack object
      return InterestStack(
        url: url,
        title: title,
        imageUrls: imageUrls,
        username: username,
        entries: entries,
        reStacks: reStacks,
      );
    }).toList();
  }

  static List<AdditionalTitle> _getAdditionalTitles(Document document) {
    var alternativeTitlesElement =
        document.querySelector('.js-alternative-titles');
    if (alternativeTitlesElement == null) {
      return [];
    }

    var titleElements =
        alternativeTitlesElement.querySelectorAll('.spaceit_pad');
    List<AdditionalTitle> additionalTitles = [];

    for (var titleElement in titleElements) {
      var languageElement = titleElement.querySelector('.dark_text');
      if (languageElement == null) continue;

      var language = languageElement.text.trim().replaceAll(':', '');

      // Skip English titles
      if (language.toLowerCase() == 'english') continue;

      // Get the title text by removing the language part
      var fullText = titleElement.text.trim();
      var title = fullText.replaceFirst('$language:', '').trim();

      if (title.isNotEmpty) {
        additionalTitles.add(AdditionalTitle(
          title: title,
          language: language,
        ));
      }
    }

    return additionalTitles;
  }

  static int? _getBeforeInt(String text,
      {String? endPattern, String? startPattern}) {
    return int.tryParse(
        _getBefore(text, endPattern: endPattern, startPattern: startPattern) ??
            '');
  }

  static String? _getBefore(
    String text, {
    String? endPattern,
    String? startPattern,
  }) {
    try {
      text = unescape.convert(text);
      int startIndex = 0;
      startIndex = text.indexOf(startPattern ?? '');
      if (startIndex != -1) {
        int endIndex;
        endIndex = text.indexOf(endPattern ?? '');
        if (endIndex != -1) {
          startIndex = startPattern != null ? (startIndex + 1) : startIndex;
          return text.substring(startIndex, endIndex).trim();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    return null;
  }

  static String _getText(Element element, String selector) {
    return _escape(element.querySelector(selector)?.text ?? '');
  }

  static String _escape(String? text) {
    return unescape.convert(text?.trim() ?? '');
  }

  T? queryParamsUri<T>(Uri? uri, String key, [T? defaultValue]) {
    if (uri == null) return defaultValue;
    final value = uri.queryParameters[key];
    if (value == null || value == 'null') return defaultValue;
    if (T == bool) {
      return (value == 'true'
          ? true
          : value == 'false'
              ? false
              : defaultValue) as T?;
    } else if (T == int) {
      return (int.tryParse(value) ?? defaultValue) as T?;
    } else {
      try {
        return value as T?;
      } catch (e) {
        return defaultValue;
      }
    }
  }

  T? queryParamsUrl<T>(String? url, String key, [T? defaultValue]) {
    if (url == null) return null;
    return queryParamsUri(Uri.tryParse(url), key, defaultValue);
  }

  // Parse anime/manga details page
  static AnimeDetailHtml parseAnimeDetailedHtml(Document document,
      {ContentType type = ContentType.anime}) {
    return AnimeDetailHtml(
      title: _getTitle(document, type),
      mainPicture: _getMainPicture(document),
      trailer: type == ContentType.anime ? _getTrailer(document) : null,
      availableAt: _getAvailableAtLinks(document),
      resources: _getResourceLinks(document),
      streamingPlatforms:
          type == ContentType.anime ? _getStreamingPlatforms(document) : null,
      adaptation: _getAdaptation(document),
      charactersVoiceActors: type == ContentType.anime
          ? _getCharactersVoiceActors(document)
          : null,
      mangaCharacters:
          type == ContentType.manga ? _getMangaCharacters(document) : null,
      staff: type == ContentType.anime ? _getStaff(document) : null,
      interestStacks: _getInterestStacks(document),
      additionalTitles: _getAdditionalTitles(document),
    );
  }

  // Parse user history page
  static UserHistoryList parseUserHistory(Document? document) {
    final content = document?.body?.querySelector('.history_content_wrapper');
    if (content == null) {
      return UserHistoryList(histories: []);
    }

    final histories = content
        .querySelectorAll('tr')
        .where((e) =>
            e.querySelector('.normal_header') == null &&
            e.querySelector('td.borderClass') != null)
        .map((e) {
          final a = e.querySelector('a');
          final url = a?.attributes['href'] ?? '';
          final id =
              int.tryParse(Uri.tryParse(url)?.queryParameters['id'] ?? '') ?? 0;
          final category = url.contains('anime')
              ? 'anime'
              : (url.contains('manga') ? 'manga' : null);
          final title = a?.text.trim() ?? '';

          final borderClassTd = e.querySelector('td.borderClass');
          final timeElement = e.querySelectorAll('td.borderClass').elementAt(1);

          // Remove the 'a' tag from 'td.borderClass' to get only the text
          borderClassTd?.querySelector('a')?.remove();
          final historyText =
              borderClassTd?.text.trim().replaceAll('\n', ' ') ?? '';
          final history = historyText
              .split(' ')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join(' ');

          final time = unescape.convert(timeElement.text.trim());

          return UserHistory(
            id: id,
            title: title,
            history: history,
            category: category,
            time: time,
          );
        })
        .where((e) => e.id != 0)
        .toList();

    return UserHistoryList(histories: histories);
  }

  // Parse user friends list page
  static UserFriendsList parseUserFriends(Document? document) {
    final friendsContainer = document?.body?.querySelector('.friend');
    if (friendsContainer == null) {
      return UserFriendsList(friends: []);
    }

    final friends =
        friendsContainer.querySelectorAll('.boxlist').map((element) {
      final userElement = element.querySelector('a');
      final username = element.querySelector('.title a')?.text.trim() ?? '';
      final url = userElement?.attributes['href'] ?? '';
      final imageUrl =
          userElement?.querySelector('img')?.attributes['src'] ?? '';

      final dataElements = element.querySelectorAll('.data .fn-grey2');
      final lastOnline =
          dataElements.isNotEmpty ? dataElements.first.text.trim() : '';
      final friendSince =
          dataElements.length > 1 ? dataElements[1].text.trim() : '';

      final user = User(
        username: username,
        url: url,
        imageUrl: imageUrl,
      );

      return Friend(
        user: user,
        lastOnline: lastOnline,
        friendSince: friendSince,
      );
    }).toList();

    return UserFriendsList(friends: friends);
  }

  // Parse MAL genre page
  static GenreCategoryList parseGenres(Document document) {
    final types = ['Genres', 'Explicit Genres', 'Themes', 'Demographics'];

    final categories = document
        .querySelectorAll('.genre-link')
        .sublist(0, 4)
        .asMap()
        .entries
        .map((e) {
      final genres = e.value
          .querySelectorAll('a')
          .map((element) {
            final uri = Uri.tryParse(element.attributes['href'] ?? '');
            final id = int.tryParse(uri?.pathSegments.elementAt(2) ?? '');
            final linkText = element.text.trim();
            final name = linkText
                .getAlphabets(); // Extract alphabetic characters using String extension
            final count = int.tryParse(linkText.replaceAll(
                RegExp(r'\D'), '')); // Extract digits as count

            if (id == null || name.isEmpty) return null;

            return Genre(
              id: id,
              name: name,
              count: count,
            );
          })
          .where((genre) => genre != null)
          .cast<Genre>()
          .toList();

      return GenreCategory(
        type: types[e.key],
        genres: genres,
      );
    }).toList();

    return GenreCategoryList(categories: categories);
  }

  // Parse anime producer/magazine page
  static GenreCategoryList parseProducer(Document document) {
    const characters = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final types = characters.split('');

    final categories = document
        .querySelectorAll('.genre-link')
        .sublist(0, types.length)
        .asMap()
        .entries
        .map((e) {
      final genres = e.value
          .querySelectorAll('a')
          .map((element) {
            final uri = Uri.tryParse(element.attributes['href'] ?? '');
            final id = int.tryParse(uri?.pathSegments.elementAt(2) ?? '');
            final linkText = element.text.trim();
            final name = linkText
                .getAlphabets(); // Extract alphabetic characters using String extension
            final count = int.tryParse(linkText.replaceAll(
                RegExp(r'\D'), '')); // Extract digits as count

            if (id == null || name.isEmpty) return null;

            return Genre(
              id: id,
              name: name,
              count: count,
            );
          })
          .where((genre) => genre != null)
          .cast<Genre>()
          .toList();

      return GenreCategory(
        type: types[e.key],
        genres: genres,
      );
    }).toList();

    return GenreCategoryList(categories: categories);
  }

// Helper function to parse the anime featured articles
  static AnimeFeaturedResult parseAnimeFeaturedArticles(Document document) {
    var featuredElements = document.querySelectorAll('.news-unit.clearfix');

    var featuredArticles = featuredElements
        .map((element) {
          try {
            // Get the title and URL
            var titleElement = element.querySelector('.title a');
            var title = titleElement?.text.trim() ?? '';
            var url = titleElement?.attributes['href']?.trim() ?? '';

            // Get the text
            var textElement = element.querySelector('.text');
            var text = textElement?.text.trim() ?? '';

            // Get the image URL
            var imageElement = element.querySelector('.image-link img');
            var imageUrl = imageElement?.attributes['data-src'] ??
                imageElement?.attributes['src'] ??
                '';

            // Get the author info
            var authorElement = element.querySelector('.information .info a');
            var author = authorElement?.text.trim() ?? '';
            var authorUrl = authorElement?.attributes['href']?.trim() ?? '';

            // Get views count - Handling commas in numbers (e.g., 55,578)
            var viewsElement = element.querySelector('.information .pv');
            var viewsText = viewsElement?.text.trim() ?? '0';
            var cleanViewsText = viewsText.replaceAll(',', ''); // Remove commas
            var viewsMatch = RegExp(r'(\d+)').firstMatch(cleanViewsText);
            var views = viewsMatch != null
                ? int.tryParse(viewsMatch.group(1) ?? '0') ?? 0
                : 0;

            // Get tags - Handle both linked and non-linked tags
            List<String> tags = [];

            // Handle linked tags
            var linkedTagElements =
                element.querySelectorAll('.tags .tags-inner a.tag');
            for (var tag in linkedTagElements) {
              tags.add(tag.text.trim());
            }

            // Handle non-linked tags (like "Spoiler")
            var nonLinkedTagElements = element
                .querySelectorAll('.tags .tags-inner-attributes span.tag');
            for (var tag in nonLinkedTagElements) {
              tags.add(tag.text.trim());
            }

            return AnimeFeatured(
              title: title,
              text: text,
              url: url,
              imageUrl: imageUrl,
              author: author,
              authorUrl: authorUrl,
              views: views,
              tags: tags,
            );
          } catch (e) {
            debugPrint('Error parsing featured article: $e');
            return null;
          }
        })
        .where((element) => element != null)
        .cast<AnimeFeatured>()
        .toList();

    return AnimeFeaturedResult(featuredArticles: featuredArticles);
  }

  /// Parse MAL's /search/all page to extract results from all categories.
  static AllSearchResult parseAllSearchResults(Document document) {
    final categories = <String, List<Anime>>{};

    for (final type in AllSearchResult.allTypes) {
      categories[type] = [];
    }

    try {
      final articles = document.getElementsByTagName('article');
      for (final article in articles) {
        final items = article.getElementsByClassName('list');
        String? category;
        final List<Anime> data = [];

        for (final item in items) {
          int? id;
          String title = 'Unknown';
          String? imageUrl;
          String? mediaType;
          int? numEpisodes;
          double? mean;
          int? numListUsers;

          // Extract picture and link
          final picSurround = item.getElementsByClassName('picSurround');
          if (picSurround.isNotEmpty) {
            final anchors = picSurround.first.getElementsByTagName('a');
            if (anchors.isNotEmpty) {
              final href = anchors.first.attributes['href'];
              if (href != null) {
                category ??= _getCategoryFromUrl(href);
                id = _extractIdFromUrl(href, category ?? '');
              }
              // Extract image
              final imgs = picSurround.first.getElementsByTagName('img');
              if (imgs.isNotEmpty) {
                final imgAttr = ['news', 'featured'].contains(category)
                    ? 'src'
                    : 'data-src';
                imageUrl = imgs.first.attributes[imgAttr]
                    ?.replaceAll('r/100x140/', '')
                    .replaceAll('r/50x50/', '');
              }
            }
          }

          // Extract info
          final infoList = item.getElementsByClassName('information');
          if (infoList.isNotEmpty) {
            final anchors = infoList.first.getElementsByTagName('a');
            if (anchors.isNotEmpty) {
              title = anchors.first.text.trim();
            }
            // Parse metadata for anime/manga
            final metaList = infoList.first.getElementsByClassName('fn-grey4');
            if (metaList.isNotEmpty && ['anime', 'manga'].contains(category)) {
              final infoText = metaList.first.text.trim();
              final lines = infoText
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();
              if (lines.isNotEmpty) {
                mediaType =
                    lines.first.replaceAll(RegExp(r'[^a-zA-Z]'), '').trim();
              }
              if (lines.length >= 2) {
                numEpisodes =
                    int.tryParse(lines[0].replaceAll(RegExp(r'\D'), ''));
                mean =
                    double.tryParse(lines[1].replaceAll('Scored', '').trim());
              }
              if (lines.length >= 3) {
                numListUsers =
                    int.tryParse(lines[2].replaceAll(RegExp(r'\D'), ''));
              }
            }
          }

          if (id != null) {
            data.add(Anime(
              id: id,
              title: title,
              imageUrl: imageUrl ?? '',
              score: mean ?? 0.0,
              members: numListUsers ?? 0,
              mediaType: mediaType,
              numEpisodes: numEpisodes,
            ));
          }
        }

        if (category != null &&
            AllSearchResult.allTypes.contains(category) &&
            !categories.containsKey(category)) {
          categories[category] = data;
        } else if (category != null &&
            categories.containsKey(category) &&
            categories[category]!.isEmpty) {
          categories[category] = data;
        }
      }
    } catch (e) {
      // Silently fail - return partial results
    }

    return AllSearchResult(categories: categories);
  }

  static String? _getCategoryFromUrl(String href) {
    if (href.contains('/anime/')) return 'anime';
    if (href.contains('/manga/')) return 'manga';
    if (href.contains('/character/')) return 'character';
    if (href.contains('/people/')) return 'person';
    if (href.contains('/forum/')) return 'forum';
    if (href.contains('/clubs.php')) return 'club';
    if (href.contains('/featured/')) return 'featured';
    if (href.contains('/news/')) return 'news';
    return null;
  }

  static int? _extractIdFromUrl(String href, String category) {
    try {
      if (['news', 'featured'].contains(category)) {
        final match = RegExp(r'/(?:news|featured)/(\d+)').firstMatch(href);
        return match != null ? int.tryParse(match.group(1)!) : null;
      } else if (['forum', 'club'].contains(category)) {
        final match =
            RegExp(r'[?&](?:topicid|cid|id)=(\d+)').firstMatch(href);
        if (match != null) return int.tryParse(match.group(1)!);
        // Fallback: last number in URL
        final numMatch = RegExp(r'(\d+)').allMatches(href).lastOrNull;
        return numMatch != null ? int.tryParse(numMatch.group(1)!) : null;
      } else {
        // anime, manga, character, person: /type/ID/name
        final trimmed =
            href.endsWith('/') ? href.substring(0, href.length - 1) : href;
        final lastSlash = trimmed.lastIndexOf('/');
        final segment = trimmed.substring(lastSlash + 1);
        final parsed = int.tryParse(segment);
        if (parsed != null) return parsed;
        // Try second-to-last segment
        final beforeLast = trimmed.substring(0, lastSlash);
        final prevSlash = beforeLast.lastIndexOf('/');
        return int.tryParse(beforeLast.substring(prevSlash + 1));
      }
    } catch (_) {}
    return null;
  }

  /// Parse MAL's /clubs.php page to extract club listings.
  static Map<String, dynamic> parseClubList(Document document) {
    final clubs = <Map<String, dynamic>>[];

    try {
      final rows = document.querySelectorAll('.normal_header ~ table tr');
      for (final row in rows) {
        final cells = row.getElementsByTagName('td');
        if (cells.length >= 2) {
          final link = cells[0].querySelector('a');
          if (link != null) {
            final href = link.attributes['href'] ?? '';
            final idMatch = RegExp(r'cid=(\d+)').firstMatch(href);
            clubs.add({
              'id': idMatch != null ? int.tryParse(idMatch.group(1)!) : null,
              'name': link.text.trim(),
              'members': cells.length >= 3 ? cells[2].text.trim() : '',
            });
          }
        }
      }
    } catch (e) {
      // Partial results
    }

    return {'clubs': clubs};
  }

  /// Parse MAL's /profile/{username}/clubs page.
  static Map<String, dynamic> parseUserClubs(Document document) {
    final clubs = <Map<String, dynamic>>[];

    try {
      final items = document
          .querySelectorAll('.normal_header ~ ol li, .user-clubs li, li');
      for (final item in items) {
        final link = item.querySelector('a');
        if (link != null) {
          final href = link.attributes['href'] ?? '';
          if (href.contains('clubs.php') || href.contains('/clubs/')) {
            final idMatch = RegExp(r'cid=(\d+)').firstMatch(href);
            clubs.add({
              'id': idMatch != null ? int.tryParse(idMatch.group(1)!) : null,
              'name': link.text.trim(),
            });
          }
        }
      }
    } catch (e) {
      // Partial results
    }

    return {'clubs': clubs};
  }

  /// Parse MAL's /users.php search results page.
  static MalUserSearchResult parseUserSearch(Document document) {
    final users = <MalUserNode>[];

    try {
      // Fallback: look for user listing pattern
      final rows = document.querySelectorAll('td.borderClass');
      for (final row in rows) {
        final link = row.querySelector('a');
        final img = row.querySelector('img');
        final infoDiv = row.querySelector('.information, .fn-grey4');

        if (link != null) {
          final href = link.attributes['href'] ?? '';
          if (href.contains('/profile/')) {
            final username =
                href.split('/profile/').last.replaceAll('/', '');
            users.add(MalUserNode(
              username: username.isNotEmpty ? username : link.text.trim(),
              imageUrl:
                  img?.attributes['data-src'] ?? img?.attributes['src'],
              lastOnline: infoDiv?.text.trim(),
            ));
          }
        }
      }

      // If no results from table, try direct anchor patterns
      if (users.isEmpty) {
        final anchors = document.querySelectorAll('a[href*="/profile/"]');
        final seen = <String>{};
        for (final a in anchors) {
          final href = a.attributes['href'] ?? '';
          final username =
              href.split('/profile/').last.replaceAll('/', '');
          if (username.isNotEmpty && !seen.contains(username)) {
            seen.add(username);
            users.add(MalUserNode(
              username: username,
              imageUrl: a.querySelector('img')?.attributes['src'],
            ));
          }
        }
      }
    } catch (e) {
      // Partial results
    }

    return MalUserSearchResult(users: users);
  }

  /// Parse a single MAL featured article page.
  static Map<String, dynamic> parseFeaturedArticle(Document document, int id,
      {String category = "featured"}) {
    final result = <String, dynamic>{'id': id, 'category': category};

    try {
      // Title
      final titleEl =
          document.querySelector('h1.title, .news-info-block h1, h1');
      result['title'] = titleEl?.text.trim() ?? '';

      // Content
      final contentEl = document.querySelector(
          '.news-container .content, .article-body, .usertext');
      result['content'] = contentEl?.innerHtml ?? '';
      result['contentText'] = contentEl?.text.trim() ?? '';

      // Image
      final imgEl =
          document.querySelector('.news-container img, .article-body img');
      result['imageUrl'] = imgEl?.attributes['src'] ?? '';

      // Author
      final authorEl = document
          .querySelector('.news-info-block .information a, .author a');
      result['author'] = authorEl?.text.trim() ?? '';

      // Date
      final dateEl =
          document.querySelector('.news-info-block .information, .date');
      result['date'] = dateEl?.text.trim() ?? '';

      // Tags
      final tagEls =
          document.querySelectorAll('.tags a, .information .tags a');
      result['tags'] = tagEls.map((t) => t.text.trim()).toList();
    } catch (e) {
      // Partial results
    }

    return result;
  }

  /// Parse forum topics from MAL HTML page (fallback when API is unavailable).
  static Map<String, dynamic> parseForumTopicsHtml(Document document) {
    final topics = <Map<String, dynamic>>[];

    try {
      final rows = document.querySelectorAll(
          '.forum-topic-list tr, table.forum_border_around tr');
      for (final row in rows) {
        final cells = row.getElementsByTagName('td');
        if (cells.length >= 4) {
          final titleCell = cells[1];
          final link = titleCell.querySelector('a');
          if (link != null) {
            final href = link.attributes['href'] ?? '';
            final topicIdMatch =
                RegExp(r'topicid=(\d+)').firstMatch(href);

            topics.add({
              'id': topicIdMatch != null
                  ? int.tryParse(topicIdMatch.group(1)!)
                  : null,
              'title': link.text.trim(),
              'created_by':
                  cells.length > 2 ? cells[2].text.trim() : '',
              'replies':
                  cells.length > 3 ? cells[3].text.trim() : '',
              'last_post':
                  cells.length > 4 ? cells[4].text.trim() : '',
            });
          }
        }
      }
    } catch (e) {
      // Partial results
    }

    return {'data': topics};
  }
}
