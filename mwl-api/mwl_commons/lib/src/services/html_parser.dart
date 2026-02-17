// ignore_for_file: unused_element

import 'package:html/dom.dart';
import 'package:html_unescape/html_unescape_small.dart';

import '../constants/constant.dart';
import '../model/html/anime_detailed_html.dart';
import '../model/html/anime_featured.dart';
import '../model/html/anime_featured_tags.dart';
import '../model/html/anime_news_featured.dart';
import '../model/html/anime_news_tags.dart';
import '../model/html/genre.dart';
import '../model/html/paging.dart';
import '../model/html/user_friends.dart';
import '../model/html/user_history.dart';
import '../model/mal_user_search.dart';
import '../util/extensions.dart';

class HtmlParsers {
  static final unescape = HtmlUnescape();

  static String getImageUrlByQuality(
      Element? imageElement, String imageQuality) {
    String imageUrl = '';

    if (imageElement != null) {
      if (imageElement.attributes.containsKey('data-srcset')) {
        var srcset = imageElement.attributes['data-srcset']!;
        var srcsetUrls =
            srcset.split(',').map((e) => e.trim().split(' ')[0]).toList();

        imageUrl = srcsetUrls.firstWhere((url) => url.contains(imageQuality),
            orElse: () => '');
      } else if (imageElement.attributes.containsKey('data-src')) {
        imageUrl = imageElement.attributes['data-src']!;
      } else if (imageElement.attributes.containsKey('src')) {
        imageUrl = imageElement.attributes['src']!;
      }
    }

    return imageUrl;
  }

  static String getOriginalImageQuality(
      Element? imageElement, String imageQuality) {
    String imageUrl = '';

    if (imageElement != null) {
      imageUrl = imageElement.attributes['data-src'] ??
          imageElement.attributes['src'] ??
          '';
    }

    if (imageUrl.isNotEmpty) {
      imageUrl = stripImageResize(imageUrl);
    }

    return imageUrl;
  }

  static String stripImageResize(String url) {
    url = url.replaceAll(RegExp(r'/r/\d+x\d+/'), '/');

    int queryIndex = url.indexOf('?');
    if (queryIndex != -1) {
      url = url.substring(0, queryIndex);
    }

    return url;
  }

  // Parse anime news or featured articles
  static AnimeNewsOrFeaturedResult parseAnimeNewsOrFeatured(
      Document document) {
    var newsElements = document.querySelectorAll('.news-unit');

    var newsItems = newsElements
        .map((element) {
          var linkElement = element.querySelector('.title a');
          var title = linkElement != null ? linkElement.text.trim() : '';
          var url =
              linkElement != null ? linkElement.attributes['href']!.trim() : '';

          int id = 0;
          if (url.startsWith(Constants.malnewsUrl)) {
            id = int.parse(
                url.replaceFirst('${Constants.malnewsUrl}/', '').split('/')[0]);
          } else if (url.startsWith(Constants.malfeaturedUrl)) {
            id = int.parse(url
                .replaceFirst('${Constants.malfeaturedUrl}/', '')
                .split('/')[0]);
          }

          var textElement = element.querySelector('.text');
          var text = textElement != null ? textElement.text.trim() : '';

          var tags = '';
          var tagElements =
              element.querySelectorAll('.information .tags a');
          if (tagElements.isEmpty) {
            tagElements = element.querySelectorAll('.information .tags .tag');
          }
          tags = tagElements.map((e) => e.text.trim()).join(', ');

          var imageElement = element.querySelector('.image-link img');
          var imageQuality = 'r/100x156';
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
            return null;
          }
        })
        .where((element) => element != null)
        .cast<AnimeNewsOrFeaturedItem>()
        .toList();

    var paging = Paging(previous: '', next: '');
    var paginationElement = document.querySelector('.pagination.ac');

    if (paginationElement != null) {
      var currentPageElement =
          paginationElement.querySelector('.link.current');
      var nextPageElement = currentPageElement?.nextElementSibling;

      var currentPage =
          currentPageElement?.attributes['href']?.trim() ?? '';
      var nextPage = nextPageElement != null
          ? nextPageElement.attributes['href']?.trim()
          : null;

      paging = Paging(previous: currentPage, next: nextPage);
    }

    return AnimeNewsOrFeaturedResult(
        newsorfeatured: newsItems, paging: paging);
  }

  // Parse anime featured tags
  static AnimefeaturedTagsResult parseAnimeFeaturedTags(Document document) {
    var tagContainer = document.querySelector('.news-tags-table');

    var tagElements =
        tagContainer?.querySelectorAll('.tag-list a.tag-name-link');

    var tags = tagElements?.map((element) {
          var url = element.attributes['href']!.trim();
          var name =
              element.querySelector('span.tag-name')?.text.trim() ?? '';

          return AnimeFeaturedTag(url: url, name: name);
        }).toList() ??
        [];

    return AnimefeaturedTagsResult(tags: tags);
  }

  // Parse anime news tags
  static AnimeNewsTagsResult parseAnimeNewsTags(Document document) {
    var menuCategoryTags = document.querySelector('.menu-category-tags');

    var categoryElements =
        menuCategoryTags?.querySelectorAll('.btn-category');

    var listCategory = categoryElements?.map((element) {
          return element.attributes['data-id']!.trim();
        }).toList() ??
        [];

    var categories = <AnimeNewsTagCat>[];

    for (var category in listCategory) {
      var categoryElement = document.getElementById(category);

      if (categoryElement != null) {
        var categoryName =
            categoryElement.querySelector('.news-tags-header')?.text.trim() ??
                '';

        var tagElements =
            categoryElement.querySelectorAll('.news-tags-table tr');
        var tags = tagElements.map((tagElement) {
          var nameElement = tagElement.querySelector('.tag-name a');
          var descriptionElement =
              tagElement.querySelector('.tag-description span');

          var url = nameElement?.attributes['href']?.trim() ?? '';
          var name = nameElement?.text.trim() ?? '';
          var description = descriptionElement?.text.trim() ?? '';

          return AnimeNewsTag(
              url: url, name: name, description: description);
        }).toList();

        categories.add(
            AnimeNewsTagCat(categoryName: categoryName, tags: tags));
      }
    }

    return AnimeNewsTagsResult(categories: categories);
  }

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
        .first;
    var linkElements = availableAtElement.querySelectorAll('a.ga-click');

    return linkElements.map((e) {
      var name = e.querySelector('.caption')?.text.trim() ?? '';
      var url = e.attributes['href']?.trim() ?? '';
      var imageUrl =
          e.querySelector('img')?.attributes['src']?.trim() ?? '';
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
      var name = e.querySelector('.caption')?.text.trim() ?? '';
      var url = e.attributes['href']?.trim() ?? '';
      var imageUrl =
          e.querySelector('img')?.attributes['src']?.trim() ?? '';
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
      var name = e.querySelector('.caption')?.text.trim() ?? '';
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
    var adaptationElements =
        document.querySelectorAll('.entries-tile .entry');

    return adaptationElements
        .where((e) => e.text.contains('Adaptation'))
        .map((e) {
      var imageElement = e.querySelector('.image img');
      var imageQuality = 'r/50x70';

      var image =
          getOriginalImageQuality(imageElement, imageQuality).trim();

      var relationElement = e.querySelector('.content .relation');
      var relation = relationElement?.text.trim() ?? '';

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
    var characterList =
        document.querySelector('.detail-characters-list.clearfix');
    if (characterList == null) {
      return [];
    }

    var leftColumn = characterList.querySelector('.left-column');
    var rightColumn = characterList.querySelector('.left-right');

    List<MangaCharacters> extractMangaCharacters(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<MangaCharacters> mangaCharactersList = [];
      const imageQuality = 'r/42x62';

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 2) {
          continue;
        }

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

        mangaCharactersList.add(MangaCharacters(character: character));
      }

      return mangaCharactersList;
    }

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
    var characterList =
        document.querySelector('.detail-characters-list.clearfix');
    if (characterList == null) {
      return [];
    }

    var leftColumn = characterList.querySelector('.left-column');
    var rightColumn = characterList.querySelector('.left-right');

    List<CharactersVoiceActors> extractCharactersVoiceActors(
        Element column) {
      var rows = column.querySelectorAll('table tr');
      List<CharactersVoiceActors> characterVoiceActorsList = [];

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 3) {
          continue;
        }

        var imageQuality = 'r/42x62';
        var characterElement = tds[0].querySelector('.picSurround img');
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

        var voiceActorNameElement = tds[2].querySelector('td.va-t a');
        var voiceActorName = Link(
          name: voiceActorNameElement?.text.trim() ?? '',
          url: voiceActorNameElement?.attributes['href']?.trim() ?? '',
        );
        var voiceActorRole =
            tds[2].querySelector('td.va-t small')?.text.trim() ?? '';
        var voiceActorElement = tds[2].querySelector('.picSurround img');
        var voiceActorImage =
            getOriginalImageQuality(voiceActorElement, imageQuality)
                .trim();

        var voiceActor = CharacterNode(
          image: voiceActorImage,
          name: voiceActorName,
          role: voiceActorRole,
        );

        characterVoiceActorsList.add(CharactersVoiceActors(
          character: character,
          voiceActor: voiceActor,
        ));
      }

      return characterVoiceActorsList;
    }

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
    var staffList =
        document.querySelectorAll('.detail-characters-list.clearfix');
    if (staffList.length < 2) {
      return [];
    }
    var secondStaffList = staffList[1];

    var leftColumn = secondStaffList.querySelector('.left-column');
    var rightColumn = secondStaffList.querySelector('.left-right');

    List<CharacterNode> extractStaff(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<CharacterNode> staffListResult = [];

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 2) {
          continue;
        }

        var imageQuality = 'r/42x62';
        var staffElement = tds[0].querySelector('.picSurround img');
        var staffImage =
            getOriginalImageQuality(staffElement, imageQuality).trim();

        var staffNameElement = tds[1].querySelector('a');
        var staffName = Link(
          name: staffNameElement?.text.trim() ?? '',
          url: staffNameElement?.attributes['href']?.trim() ?? '',
        );
        var staffRole =
            tds[1].querySelector('.spaceit_pad small')?.text.trim() ?? '';

        var staffMember = CharacterNode(
          image: staffImage,
          name: staffName,
          role: staffRole,
        );

        staffListResult.add(staffMember);
      }

      return staffListResult;
    }

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
      var urlElement = e.querySelector('a');
      var url = urlElement?.attributes['href']?.trim() ?? '';

      var titleElement = e.querySelector('.title a');
      var title = titleElement?.text.trim() ?? '';

      var imageElements = e.querySelectorAll('.img .edge img');
      var imageUrls = imageElements
          .map((img) => img.attributes['src']?.trim() ?? '')
          .toList();

      var authorElement = e.querySelector('.tag a');
      var username = authorElement?.text.trim() ?? '';

      var statElement = e.querySelector('.foot .stat');
      var statsText = statElement?.text.trim() ?? '';
      int? entries = _getBeforeInt(statsText, endPattern: 'Entries');
      int? reStacks = _getBeforeInt(statsText,
          endPattern: 'Restacks', startPattern: '·');

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

      if (language.toLowerCase() == 'english') continue;

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
          startIndex =
              startPattern != null ? (startIndex + 1) : startIndex;
          return text.substring(startIndex, endIndex).trim();
        }
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  static String _getText(Element element, String selector) {
    return _escape(element.querySelector(selector)?.text ?? '');
  }

  static String _escape(String? text) {
    return unescape.convert(text?.trim() ?? '');
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
      streamingPlatforms: type == ContentType.anime
          ? _getStreamingPlatforms(document)
          : null,
      adaptation: _getAdaptation(document),
      charactersVoiceActors: type == ContentType.anime
          ? _getCharactersVoiceActors(document)
          : null,
      mangaCharacters: type == ContentType.manga
          ? _getMangaCharacters(document)
          : null,
      staff: type == ContentType.anime ? _getStaff(document) : null,
      interestStacks: _getInterestStacks(document),
      additionalTitles: _getAdditionalTitles(document),
    );
  }

  // Parse user history page
  static UserHistoryList parseUserHistory(Document? document) {
    final content =
        document?.body?.querySelector('.history_content_wrapper');
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
              int.tryParse(
                  Uri.tryParse(url)?.queryParameters['id'] ?? '') ??
              0;
          final category = url.contains('anime')
              ? 'anime'
              : (url.contains('manga') ? 'manga' : null);
          final title = a?.text.trim() ?? '';

          final borderClassTd = e.querySelector('td.borderClass');
          final timeElement =
              e.querySelectorAll('td.borderClass').elementAt(1);

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
      final username =
          element.querySelector('.title a')?.text.trim() ?? '';
      final url = userElement?.attributes['href'] ?? '';
      final imageUrl =
          userElement?.querySelector('img')?.attributes['src'] ?? '';

      final dataElements =
          element.querySelectorAll('.data .fn-grey2');
      final lastOnline = dataElements.isNotEmpty
          ? dataElements.first.text.trim()
          : '';
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
            final uri =
                Uri.tryParse(element.attributes['href'] ?? '');
            final id =
                int.tryParse(uri?.pathSegments.elementAt(2) ?? '');
            final linkText = element.text.trim();
            final name = linkText.getAlphabets();
            final count = int.tryParse(
                linkText.replaceAll(RegExp(r'\D'), ''));

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
            final uri =
                Uri.tryParse(element.attributes['href'] ?? '');
            final id =
                int.tryParse(uri?.pathSegments.elementAt(2) ?? '');
            final linkText = element.text.trim();
            final name = linkText.getAlphabets();
            final count = int.tryParse(
                linkText.replaceAll(RegExp(r'\D'), ''));

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

  // Parse anime featured articles for a specific content
  static AnimeFeaturedResult parseAnimeFeaturedArticles(Document document) {
    var featuredElements =
        document.querySelectorAll('.news-unit.clearfix');

    var featuredArticles = featuredElements
        .map((element) {
          try {
            var titleElement = element.querySelector('.title a');
            var title = titleElement?.text.trim() ?? '';
            var url = titleElement?.attributes['href']?.trim() ?? '';

            var textElement = element.querySelector('.text');
            var text = textElement?.text.trim() ?? '';

            var imageElement = element.querySelector('.image-link img') ??
                element.querySelector('.picSurround img');
            var imageUrl = imageElement?.attributes['data-src'] ??
                imageElement?.attributes['src'] ??
                '';

            var authorElement =
                element.querySelector('.information .info a');
            var author = authorElement?.text.trim() ?? '';
            var authorUrl =
                authorElement?.attributes['href']?.trim() ?? '';

            var viewsElement =
                element.querySelector('.information .pv');
            var viewsText = viewsElement?.text.trim() ?? '0';
            var cleanViewsText =
                viewsText.replaceAll(',', '');
            var viewsMatch =
                RegExp(r'(\d+)').firstMatch(cleanViewsText);
            var views = viewsMatch != null
                ? int.tryParse(viewsMatch.group(1) ?? '0') ?? 0
                : 0;

            List<String> tags = [];

            var linkedTagElements = element
                .querySelectorAll('.tags .tags-inner a.tag');
            for (var tag in linkedTagElements) {
              tags.add(tag.text.trim());
            }

            var nonLinkedTagElements = element.querySelectorAll(
                '.tags .tags-inner-attributes span.tag');
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
            logMwl('Error parsing featured article: $e');
            return null;
          }
        })
        .where((element) => element != null)
        .cast<AnimeFeatured>()
        .toList();

    return AnimeFeaturedResult(featuredArticles: featuredArticles);
  }

  /// Parse MAL's /clubs.php page to extract club listings.
  static Map<String, dynamic> parseClubList(Document document) {
    final clubs = <Map<String, dynamic>>[];

    try {
      final tableClass = document.getElementsByClassName('club-list');
      if (tableClass.isNotEmpty) {
        final rows =
            tableClass.first.getElementsByClassName('table-data');
        for (final row in rows) {
          final tdList = row.getElementsByTagName('td');
          if (tdList.isEmpty) continue;

          int? clubId;
          String? clubName, desc, imgUrl, noOfMembers, lastPostBy,
              lastPostTime;

          try {
            final firstTd = tdList.first;

            try {
              final img = firstTd.getElementsByTagName('img');
              if (img.isNotEmpty) {
                imgUrl = img.first.attributes['data-srcset'] ?? '';
                if (imgUrl.contains('1x,') && imgUrl.contains('2x')) {
                  imgUrl = imgUrl.substring(
                      imgUrl.indexOf('1x,') + 3,
                      imgUrl.indexOf(' 2x'));
                  imgUrl = imgUrl.trim();
                } else {
                  imgUrl = img.first.attributes['src'];
                }
              }
            } catch (_) {}

            try {
              final dom = firstTd.getElementsByClassName('fw-b');
              if (dom.isNotEmpty) {
                clubName = dom.first.text.trim();
                final cUrl = dom.first.attributes['href'] ?? '';
                if (cUrl.contains('cid=')) {
                  clubId = int.tryParse(
                      cUrl.substring(cUrl.indexOf('cid=') + 4));
                }
              }
            } catch (_) {}

            try {
              final descEl = firstTd
                  .getElementsByClassName('pt4 pb4 word-break');
              if (descEl.isNotEmpty) {
                desc = descEl.first.text.trim();
              }
            } catch (_) {}

            if (tdList.length >= 2) {
              noOfMembers = tdList.elementAt(1).text.trim();
            }

            if (tdList.length >= 3) {
              final thirdTd = tdList.elementAt(2);
              try {
                final diIb =
                    thirdTd.getElementsByClassName('di-ib');
                if (diIb.isNotEmpty) {
                  lastPostTime = diIb.first.text.trim();
                }
              } catch (_) {}
              try {
                final aTag = thirdTd.getElementsByTagName('a');
                if (aTag.isNotEmpty) {
                  lastPostBy = aTag.first.text.trim();
                }
              } catch (_) {}
            }
          } catch (_) {}

          clubs.add({
            'id': clubId,
            'name': clubName ?? '',
            'imgUrl': imgUrl,
            'desc': desc ?? '',
            'members': noOfMembers ?? '',
            'lastPostBy': lastPostBy,
            'lastPostTime': lastPostTime,
          });
        }
      } else {
        final rows = document
            .querySelectorAll('.normal_header ~ table tr');
        for (final row in rows) {
          final cells = row.getElementsByTagName('td');
          if (cells.length >= 2) {
            final link = cells[0].querySelector('a');
            if (link != null) {
              final href = link.attributes['href'] ?? '';
              final idMatch =
                  RegExp(r'cid=(\d+)').firstMatch(href);
              clubs.add({
                'id': idMatch != null
                    ? int.tryParse(idMatch.group(1)!)
                    : null,
                'name': link.text.trim(),
                'members':
                    cells.length >= 3 ? cells[2].text.trim() : '',
              });
            }
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
      final items = document.querySelectorAll(
          '.normal_header ~ ol li, .user-clubs li, li');
      for (final item in items) {
        final link = item.querySelector('a');
        if (link != null) {
          final href = link.attributes['href'] ?? '';
          if (href.contains('clubs.php') || href.contains('/clubs/')) {
            final idMatch =
                RegExp(r'cid=(\d+)').firstMatch(href);
            clubs.add({
              'id': idMatch != null
                  ? int.tryParse(idMatch.group(1)!)
                  : null,
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
      final rows = document.querySelectorAll('td.borderClass');
      for (final row in rows) {
        final link = row.querySelector('a');
        final img = row.querySelector('img');
        final infoDiv =
            row.querySelector('.information, .fn-grey4');

        if (link != null) {
          final href = link.attributes['href'] ?? '';
          if (href.contains('/profile/')) {
            final username =
                href.split('/profile/').last.replaceAll('/', '');
            users.add(MalUserNode(
              username:
                  username.isNotEmpty ? username : link.text.trim(),
              imageUrl: img?.attributes['data-src'] ??
                  img?.attributes['src'],
              lastOnline: infoDiv?.text.trim(),
            ));
          }
        }
      }

      if (users.isEmpty) {
        final anchors =
            document.querySelectorAll('a[href*="/profile/"]');
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
  ///
  /// Returns a map with keys: id, category, title, summary, content (body HTML),
  /// tags, postedBy, postedDate, views, topicId, relatedDatabaseEntries,
  /// relatedArticles, relatedNews.
  static Map<String, dynamic> parseFeaturedArticle(
      Document document, int id,
      {String category = "featured"}) {
    final result = <String, dynamic>{
      'id': id,
      'category': category,
      'title': '',
      'summary': '',
      'content': '',
      'tags': <String>[],
      'postedBy': '',
      'postedDate': '',
      'views': '',
      'topicId': null,
      'relatedDatabaseEntries': <String, List<Map<String, dynamic>>>{},
      'relatedArticles': <Map<String, dynamic>>[],
      'relatedNews': <String, List<Map<String, dynamic>>>{},
    };

    try {
      // --- Main container ---
      final container = document.querySelector('.news-container');
      if (container != null) {
        result['title'] =
            container.querySelector('.title')?.text.trim() ?? '';
        result['summary'] =
            container.querySelector('.summary')?.text.trim() ?? '';

        // Tags
        final tagsEl = container.querySelector('.tags');
        if (tagsEl != null) {
          final tagList = tagsEl.getElementsByClassName('tag');
          final tags = <String>[];
          for (final tagE in tagList) {
            final t = tagE.text.trim();
            if (t.isNotEmpty) tags.add(t);
          }
          result['tags'] = tags;
        }

        // News info block: author, date, views / comments
        final newsInfoEl = container.querySelector('.news-info-block');
        if (newsInfoEl != null) {
          final infoEl = newsInfoEl.querySelector('.information');
          if (infoEl != null) {
            // Author is the first <a> in the information block
            result['postedBy'] =
                infoEl.querySelector('a')?.text.trim() ?? '';

            if (category == 'featured') {
              // For featured articles, views is in the <b> tag
              result['views'] =
                  infoEl.querySelector('b')?.text.trim() ?? '';
            } else {
              // For news, comment count & topicId from .comment link
              final commentEl = infoEl.querySelector('.comment');
              if (commentEl != null) {
                // Extract only digits from the comment text
                result['views'] =
                    commentEl.text.replaceAll(RegExp(r'[^0-9]'), '');
                // Extract topicId from the comment href
                final href = commentEl.attributes['href'] ?? '';
                final uri = Uri.tryParse(href);
                if (uri != null) {
                  // Try query parameter first (forum links)
                  final topicParam = uri.queryParameters['topicid'];
                  if (topicParam != null) {
                    result['topicId'] = int.tryParse(topicParam);
                  } else if (uri.pathSegments.isNotEmpty) {
                    // Fall back to path-based ID extraction
                    for (int i = 0; i < uri.pathSegments.length; i++) {
                      if (uri.pathSegments[i] == 'forum' &&
                          i + 1 < uri.pathSegments.length) {
                        result['topicId'] =
                            int.tryParse(uri.pathSegments[i + 1]);
                        break;
                      }
                    }
                  }
                }
              }
            }

            // Posted date: text before "|", minus "by <author>"
            final infoText = infoEl.text;
            final pipeIndex = infoText.indexOf('|');
            if (pipeIndex > 0) {
              var dateStr = infoText.substring(0, pipeIndex);
              final postedBy = result['postedBy'] as String;
              if (postedBy.isNotEmpty) {
                dateStr = dateStr.replaceAll('by $postedBy', '');
              }
              result['postedDate'] = dateStr.trim();
            }
          }
        }

        // Body content HTML
        result['content'] =
            container.querySelector('.content')?.innerHtml ?? '';
      }

      // --- Related database entries (table after .mt24 element) ---
      final mt24 = document.querySelector('.mt24');
      if (mt24 != null) {
        final table = mt24.nextElementSibling;
        if (table != null) {
          final trList = table.getElementsByTagName('tr');
          if (trList.isNotEmpty) {
            final relEntries = <String, List<Map<String, dynamic>>>{};
            for (final tr in trList) {
              final tdList = tr.getElementsByTagName('td');
              if (tdList.length == 2) {
                final cat = _getCategory(tdList.first.text);
                if (cat != null && cat.isNotEmpty) {
                  final nodes = <Map<String, dynamic>>[];
                  final anchors = tdList[1].getElementsByTagName('a');
                  for (final a in anchors) {
                    var href = a.attributes['href'] ?? '';
                    if (href.isNotEmpty) {
                      // Extract ID: remove trailing slug, get numeric segment
                      if (href.contains('/')) {
                        href = href.substring(0, href.lastIndexOf('/'));
                      }
                      if (href.contains('/')) {
                        href = href.substring(href.lastIndexOf('/') + 1);
                      }
                      final entryId = int.tryParse(href);
                      if (entryId != null) {
                        nodes.add({
                          'id': entryId,
                          'title': a.text.trim(),
                        });
                      }
                    }
                  }
                  if (nodes.isNotEmpty) {
                    relEntries[cat] = nodes;
                  }
                }
              }
            }
            result['relatedDatabaseEntries'] = relEntries;
          }
        }
      }

      // --- Related articles from "news-list" container ---
      result['relatedArticles'] = _parseFeaturedList(
        document.querySelector('.news-list'),
        category: category,
        unitClass: 'news-unit',
        rightClass: 'news-unit-right',
        infoClass: 'information',
        isSideBlock: false,
      );

      // --- Related news from "news-side-block" elements ---
      final newsBlocks =
          document.getElementsByClassName('news-side-block');
      final relatedNews = <String, List<Map<String, dynamic>>>{};
      for (final block in newsBlocks) {
        final header = block.querySelector('.header');
        if (header != null) {
          final headerText = header.text.trim();
          final items = _parseFeaturedList(
            block,
            category: 'news',
            unitClass: 'clearfix',
            rightClass: 'spaceit',
            infoClass: 'lightLink',
            isSideBlock: true,
          );
          if (items.isNotEmpty) {
            relatedNews[headerText] = items;
          }
        }
      }
      result['relatedNews'] = relatedNews;
    } catch (e) {
      // Return partial results on error
    }

    return result;
  }

  /// Categorize database entry type from table cell text.
  static String? _getCategory(String text) {
    if (text.trim().isEmpty) return null;
    final lower = text.trim().toLowerCase();
    if (lower.contains('anime')) return 'anime';
    if (lower.contains('manga')) return 'manga';
    if (lower.contains('people')) return 'person';
    if (lower.contains('character')) return 'character';
    return null;
  }

  /// Parse a list of featured/news items from a container element.
  ///
  /// Handles both the main "news-list" container and side-block layouts.
  static List<Map<String, dynamic>> _parseFeaturedList(
    Element? container, {
    required String category,
    required String unitClass,
    required String rightClass,
    required String infoClass,
    required bool isSideBlock,
  }) {
    if (container == null) return [];
    final list = <Map<String, dynamic>>[];
    try {
      var units = container.getElementsByClassName(unitClass);
      // For side blocks, filter to only elements that contain a .clearfix child
      if (isSideBlock) {
        units = units
            .where((el) => el.querySelector('.clearfix') != null)
            .toList();
      }

      for (final unit in units) {
        int? itemId;
        String? imgUrl;

        // Extract ID and image from the first <a> tag
        final anchor = unit.querySelector('a');
        if (anchor != null) {
          var href = anchor.attributes['href'] ?? '';
          if (href.isNotEmpty) {
            if (category == 'featured') {
              // Remove trailing slug for featured
              if (href.contains('/')) {
                href = href.substring(0, href.lastIndexOf('/'));
              }
            }
            if (href.contains('/')) {
              href = href.substring(href.lastIndexOf('/') + 1);
            }
            itemId = int.tryParse(href);
          }
          final img = anchor.querySelector('img');
          if (img != null) {
            if (category == 'featured' || isSideBlock) {
              imgUrl = img.attributes['data-src'] ?? img.attributes['src'];
            } else {
              imgUrl = (img.attributes['src'] ?? '')
                  .replaceAll('r/100x156/', '');
            }
          }
        }

        // Right section: title, summary, info, tags
        final right = unit.querySelector('.$rightClass');
        final info = right?.querySelector('.$infoClass');

        // Tags
        final tags = <String>[];
        final tagsEl = right?.querySelector('.tags');
        if (tagsEl != null) {
          for (final tag in tagsEl.getElementsByClassName('tag')) {
            final t = tag.text.trim();
            if (t.isNotEmpty) tags.add(t);
          }
        }

        if (itemId != null) {
          list.add({
            'id': itemId,
            'title': isSideBlock
                ? (right?.text.trim() ?? '')
                : (right?.querySelector('.title')?.text.trim() ?? ''),
            'imageUrl': imgUrl ?? '',
            'summary':
                right?.querySelector('.text')?.text.trim() ?? '',
            'author': isSideBlock
                ? (info?.text.trim() ?? '')
                : (info?.querySelector('.info')?.querySelector('a')?.text
                        .trim() ??
                    ''),
            'views': info
                    ?.querySelector('.di-tc')
                    ?.querySelector('b')
                    ?.text
                    .trim() ??
                '',
            'tags': tags,
          });
        }
      }
    } catch (e) {
      // Return partial list on error
    }
    return list;
  }

  /// Parse forum topics from MAL HTML page.
  static Map<String, dynamic> parseForumTopicsHtml(Document document) {
    final topics = <Map<String, dynamic>>[];

    try {
      // New MAL HTML: table#forumTopics with tr[data-topic-id]
      var rows = document.querySelectorAll(
          '#forumTopics tr[data-topic-id]');
      // Fallback to old selectors
      if (rows.isEmpty) {
        rows = document.querySelectorAll(
            '.forum-topic-list tr, table.forum_border_around tr');
      }

      for (final row in rows) {
        final cells = row.getElementsByTagName('td');
        if (cells.length < 3) continue;

        // Try data-topic-id attribute first
        int? topicId;
        final dataTopicId = row.attributes['data-topic-id'];
        if (dataTopicId != null) {
          topicId = int.tryParse(dataTopicId);
        }

        // TD layout: [0]=watch icon, [1]=title+author, [2]=replies, [3]=last post
        final titleCell = cells.length > 1 ? cells[1] : cells[0];
        final link = titleCell.querySelector('a');
        if (link == null) continue;

        // Extract topic ID from href if not found in attribute
        if (topicId == null) {
          final href = link.attributes['href'] ?? '';
          final topicIdMatch =
              RegExp(r'topicid=(\d+)').firstMatch(href);
          topicId = topicIdMatch != null
              ? int.tryParse(topicIdMatch.group(1)!)
              : null;
        }

        // Extract title
        final title = link.text.trim();

        // Extract created_by from span.forum_postusername
        String? createdBy;
        try {
          final userSpan =
              titleCell.querySelector('.forum_postusername a');
          createdBy = userSpan?.text.trim();
        } catch (_) {}

        // Extract replies from TD[2] (strip commas)
        String? replies;
        if (cells.length > 2) {
          replies = cells[2].text.trim().replaceAll(',', '');
        }

        // Extract last post info from TD[3]
        String? lastPostBy;
        String? lastPostTime;
        if (cells.length > 3) {
          try {
            final lastTd = cells[3];
            final lastPostLink = lastTd.querySelector('a');
            if (lastPostLink != null) {
              final href = lastPostLink.attributes['href'] ?? '';
              if (href.contains('/profile/')) {
                lastPostBy = lastPostLink.text.trim();
              }
            }
            // Time is the text after <br>
            final tdHtml = lastTd.innerHtml;
            final brIndex = tdHtml.indexOf('<br');
            if (brIndex != -1) {
              final afterBr = tdHtml.substring(
                  tdHtml.indexOf('>', brIndex) + 1);
              // Strip tags and get plain text
              lastPostTime = afterBr
                  .replaceAll(RegExp(r'<[^>]*>'), '')
                  .trim();
            }
          } catch (_) {}
        }

        topics.add({
          'id': topicId,
          'title': title,
          'created_by': createdBy ?? '',
          'replies': replies ?? '',
          'last_post_created_by': lastPostBy ?? '',
          'last_post': lastPostTime ?? '',
        });
      }
    } catch (e) {
      // Partial results
    }

    return {'data': topics};
  }

  /// Parse interest stack search results from MAL HTML.
  static List<Map<String, dynamic>> parseInterestStackSearch(
      Document document) {
    final stacks = <Map<String, dynamic>>[];

    try {
      final items =
          document.querySelectorAll('.search-list .column-item');
      for (final e in items) {
        int? id;
        try {
          final anchor = e.querySelector('a');
          if (anchor != null) {
            final href = anchor.attributes['href'] ?? '';
            final match =
                RegExp(r'/stacks/(\d+)').firstMatch(href);
            if (match != null) {
              id = int.tryParse(match.group(1)!);
            }
          }
        } catch (_) {}

        final title =
            e.querySelector('.detail .title')?.text.trim() ?? '';

        final username =
            e.querySelector('.detail .tag a')?.text.trim();

        final description = e.querySelector('.text')?.text.trim();

        final statText =
            e.querySelector('.detail .stat')?.text ?? '';
        int? entries;
        int? reStacks;
        try {
          final entriesMatch =
              RegExp(r'(\d+)\s*Entries').firstMatch(statText);
          if (entriesMatch != null) {
            entries = int.tryParse(entriesMatch.group(1)!);
          }
          final restacksMatch =
              RegExp(r'(\d+)\s*Restacks').firstMatch(statText);
          if (restacksMatch != null) {
            reStacks = int.tryParse(restacksMatch.group(1)!);
          }
        } catch (_) {}

        final imageUrls = e
            .querySelectorAll('.img .edge img')
            .map((f) =>
                f.attributes['data-src'] ?? f.attributes['src'])
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList();

        stacks.add({
          'id': id,
          'url': id != null
              ? '${Constants.malBaseUrl}/stacks/$id'
              : null,
          'title': title,
          'username': username,
          'description': description,
          'entries': entries,
          'reStacks': reStacks,
          'imageUrls': imageUrls,
        });
      }
    } catch (_) {}

    return stacks;
  }

  /// Parses interest stacks from a content stacks page
  /// (`/{anime|manga}/{id}/_/stacks`).
  ///
  /// Same structure as search but uses `.stacks .column-item` selector.
  static List<Map<String, dynamic>> parseInterestStackContent(
      Document document) {
    return _parseInterestStackColumnItems(
        document.querySelectorAll('.stacks .column-item'));
  }

  /// Shared parser for `.column-item` interest stack elements.
  static List<Map<String, dynamic>> _parseInterestStackColumnItems(
      List<Element> items) {
    final stacks = <Map<String, dynamic>>[];
    for (final e in items) {
      try {
        int? id;
        String? url;
        final anchor = e.querySelector('a');
        if (anchor != null) {
          final href = anchor.attributes['href'] ?? '';
          url = href;
          final match = RegExp(r'/stacks/(\d+)').firstMatch(href);
          if (match != null) {
            id = int.tryParse(match.group(1)!);
          }
        }

        final title = e.querySelector('.detail .title')?.text.trim() ?? '';
        final username = e.querySelector('.detail .tag a')?.text.trim();
        final description = e.querySelector('.text')?.text.trim();

        final statText = e.querySelector('.detail .stat')?.text ?? '';
        int? entries;
        int? reStacks;
        final entriesMatch =
            RegExp(r'(\d+)\s*Entries').firstMatch(statText);
        if (entriesMatch != null) {
          entries = int.tryParse(entriesMatch.group(1)!);
        }
        // Try .foot .stack-balloon first (content page), then stat text
        final balloonText =
            e.querySelector('.foot .stack-balloon')?.text.trim();
        if (balloonText != null) {
          reStacks = int.tryParse(balloonText);
        }
        if (reStacks == null) {
          final restacksMatch =
              RegExp(r'(\d+)\s*Restacks').firstMatch(statText);
          if (restacksMatch != null) {
            reStacks = int.tryParse(restacksMatch.group(1)!);
          }
        }

        // updatedAt from stat text (after '·')
        String? updatedAt;
        if (statText.contains('·')) {
          updatedAt = statText.split('·').last.trim();
        }

        final imageUrls = e
            .querySelectorAll('.img .edge img')
            .map((f) => f.attributes['data-src'] ?? f.attributes['src'])
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList();

        stacks.add({
          'id': id,
          'url': url,
          'title': title,
          'username': username,
          'description': description,
          'entries': entries,
          'reStacks': reStacks,
          'updatedAt': updatedAt,
          'imageUrls': imageUrls,
        });
      } catch (_) {
        continue;
      }
    }
    return stacks;
  }

  /// Parses a MAL interest stack detail page (`/stacks/{id}`).
  ///
  /// Follows the same approach as DailyAL's `interestStackDetailedFromHtml`.
  static Map<String, dynamic> parseInterestStackDetail(Document document) {
    final result = <String, dynamic>{};

    try {
      final sd = document.querySelector('.stacks-detail');
      if (sd == null) return result;

      // --- Parse entries from seasonal view (.seasonal-anime-list) ---
      final entries = <Map<String, dynamic>>[];
      final entryElements =
          sd.querySelectorAll('.seasonal-anime-list .seasonal-anime');
      // Fallback to tile view if seasonal view not found
      final elements = entryElements.isNotEmpty
          ? entryElements
          : sd.querySelectorAll('.seasonal-anime');
      final isSeasonalView = entryElements.isNotEmpty;

      for (final e in elements) {
        try {
          // Extract MAL ID from title or image link
          int? malId;
          String? category;
          final titleAnchor = e.querySelector('.link-title') ??
              e.querySelector('.title a') ??
              e.querySelector('.image a');
          if (titleAnchor != null) {
            final href = titleAnchor.attributes['href'] ?? '';
            final animeMatch =
                RegExp(r'/anime/(\d+)').firstMatch(href);
            final mangaMatch =
                RegExp(r'/manga/(\d+)').firstMatch(href);
            if (animeMatch != null) {
              malId = int.tryParse(animeMatch.group(1)!);
              category = 'anime';
            } else if (mangaMatch != null) {
              malId = int.tryParse(mangaMatch.group(1)!);
              category = 'manga';
            }
          }

          if (malId == null) continue;

          // Title
          final entryTitle = e.querySelector('.link-title')?.text.trim() ??
              e.querySelector('.title a')?.text.trim() ??
              '';

          // English subtitle
          final enTitle =
              e.querySelector('.h3_anime_subtitle')?.text.trim();

          // Image
          final imgEl = e.querySelector('.image img');
          final imageUrl = imgEl?.attributes['data-src'] ??
              imgEl?.attributes['src'] ??
              '';

          // Production source info (media type, status, additional)
          final prodsrc =
              e.querySelectorAll('.prodsrc .info .item');
          final mediaType = prodsrc.tryAt()?.text.trim() ?? '';
          final status = prodsrc.tryAt(1)?.text.trim() ?? '';
          final additionalInfo = prodsrc.tryAt(2)?.text
                  .trim()
                  .replaceAll('\n', '')
                  .replaceAll(' ', '')
                  .replaceFirst(',', ', ') ??
              '';

          // Score
          double? score;
          String? members;
          if (isSeasonalView) {
            score = double.tryParse(
                e.querySelector('.information .score')?.text.trim() ?? '');
            members =
                _escape(e.querySelector('.information .member')?.text.trim() ?? '');
          } else {
            score = double.tryParse(
                e.querySelector('.stars')?.text.trim() ?? '');
            members =
                _escape(e.querySelector('.users')?.text.trim() ?? '');
          }

          // Synopsis
          final synopsis =
              _escape(e.querySelector('.synopsis .preline')?.text ?? '');

          // Genres
          final genres = e
              .querySelectorAll('.genres .genre')
              .map((g) {
                int? genreId;
                final href = g.querySelector('a')?.attributes['href'] ?? '';
                final match =
                    RegExp(r'/genre/(\d+)').firstMatch(href);
                if (match != null) {
                  genreId = int.tryParse(match.group(1)!);
                }
                return <String, dynamic>{
                  'id': genreId,
                  'name': g.text.trim(),
                };
              })
              .toList();

          // Category info fallback for tile view
          final categoryText =
              e.querySelector('.category')?.text.trim() ?? '';

          entries.add({
            'malId': malId,
            'title': entryTitle,
            'enTitle': enTitle,
            'imageUrl': imageUrl,
            'category': category,
            'mediaType':
                mediaType.isNotEmpty ? mediaType : categoryText,
            'status': status,
            'additionalInfo': additionalInfo,
            'score': score,
            'members': members,
            'synopsis': synopsis,
            'genres': genres,
          });
        } catch (_) {
          continue;
        }
      }

      // --- Parse username and dates from .information ---
      final String? username =
          sd.querySelector('.information a')?.text.trim();
      // Remove <a> and <span> to isolate raw date text
      sd.querySelector('.information a')?.remove();
      sd.querySelector('.information span')?.remove();
      final information =
          sd.querySelector('.information')?.text.trim() ?? '';

      // createdAt is text before '|', updatedAt is text after '|'
      final createdAt = _getBefore(information, endPattern: '|');
      final updatedAt = _getBefore(information, startPattern: '|');

      // --- Build node ---
      result['title'] = _escape(
          sd.querySelector('h2.title')?.text.trim() ?? '');
      result['description'] =
          _escape(sd.querySelector('.introduction')?.text ?? '');
      result['username'] = username;
      result['entries'] = entries.length;
      result['reStacks'] = int.tryParse(
          sd.querySelector('.stack-balloon p')?.text.trim() ?? '');
      result['updatedAt'] = updatedAt;
      result['createdAt'] = createdAt;
      result['items'] = entries;

      // --- Images from the stack header ---
      result['imageUrls'] = sd
          .querySelectorAll('.img .edge img')
          .map((e) => e.attributes['data-src'] ?? e.attributes['src'])
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();

      // --- Parse related stacks from .content-right .side-list ---
      // Index 0: "More Like This" (similar stacks)
      // Index 1: "Challenge Interest Stacks"
      // Index 2: "MyAnimeList Interest Stacks"
      final sideLists =
          document.querySelectorAll('.content-right .side-list');
      result['similarStacks'] =
          _parseInterestStacksFromSideList(sideLists.tryAt());
      result['myAnimeListStacks'] =
          _parseInterestStacksFromSideList(sideLists.tryAt(2));
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  /// Parses interest stacks from a `.side-list` element (similar/MAL stacks).
  static List<Map<String, dynamic>> _parseInterestStacksFromSideList(
      Element? element) {
    if (element == null) return [];
    return element
        .querySelectorAll('.column-item')
        .map((e) {
          // Extract ID from anchor href
          int? id;
          String? url;
          final anchor = e.querySelector('a');
          if (anchor != null) {
            final href = anchor.attributes['href'] ?? '';
            url = href;
            final match = RegExp(r'/stacks/(\d+)').firstMatch(href);
            if (match != null) {
              id = int.tryParse(match.group(1)!);
            }
          }

          final title =
              _getText(e, '.detail .title');
          final username = e
                  .querySelector('.detail .by')
                  ?.nextElementSibling
                  ?.text
                  .trim() ??
              '';

          final img = e.querySelector('img');
          final imageUrl =
              img?.attributes['src'] ?? img?.attributes['data-src'];

          final statText =
              e.querySelector('.detail span')?.text ?? '';

          return {
            'id': id,
            'url': url,
            'title': title,
            'username': username,
            'imageUrls': imageUrl != null ? [imageUrl] : <String>[],
            'entries': _getBeforeInt(statText, endPattern: 'Entries'),
            'reStacks': _getBeforeInt(statText,
                endPattern: 'Restacks', startPattern: '·'),
          };
        })
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Recommendations
  // ---------------------------------------------------------------------------

  /// Parse the user recommendations page for a specific anime/manga.
  ///
  /// URL: `/{category}/{id}/_/userrecs`
  static List<Map<String, dynamic>> getRecommendations(Document doc) {
    return doc
        .querySelectorAll('div.borderClass')
        .where((e) => e.className == 'borderClass')
        .map((e) {
      final pic = e.querySelector('.picSurround');
      final titleStrong = e.querySelector('td a strong');
      final textElements = e.querySelectorAll('.detail-user-recs-text');
      final moreLink =
          e.querySelector('.js-similar-recommendations-button strong');
      return <String, dynamic>{
        'relatedNode': _getNodeFromPicElement(pic, titleStrong?.text.trim()),
        'count': int.tryParse(moreLink?.text.trim() ?? '0'),
        'recommendations': textElements.map((textEle) {
          final text = unescape
              .convert(textEle.text.replaceFirst('read more', '').trim());
          final sibs = textEle.nextElementSibling?.querySelectorAll('a');
          final reportSib =
              sibs != null && sibs.isNotEmpty ? sibs.first : null;
          return <String, dynamic>{
            'text': text,
            'id': _getQueryParam(reportSib?.attributes['href'], 'id'),
            'username': sibs != null && sibs.length > 1
                ? sibs.elementAt(1).text.trim()
                : null,
          };
        }).toList(),
      };
    }).toList();
  }

  /// Extract a node (id, title, image, category) from a `.picSurround` element.
  ///
  /// [externalTitle] is used when the title is in a sibling element (e.g.
  /// recommendations page where the title `<strong>` is outside `.picSurround`).
  static Map<String, dynamic> _getNodeFromPicElement(
      Element? ele, [String? externalTitle]) {
    final anchor = ele?.querySelector('a');
    final img = ele?.querySelector('img');
    final href = anchor?.attributes['href'] ?? '';

    int? id;
    String? category;
    final match = RegExp(r'/(anime|manga)/(\d+)').firstMatch(href);
    if (match != null) {
      category = match.group(1);
      id = int.tryParse(match.group(2)!);
    }

    final imageUrl =
        img?.attributes['data-src'] ?? img?.attributes['src'] ?? '';
    final srcSet = img?.attributes['data-srcset']?.split(',') ?? [];
    String? medImage, largeImage;
    if (srcSet.isNotEmpty) {
      medImage = srcSet.first.replaceFirst('1x', '').trim();
      largeImage = srcSet.length > 1
          ? srcSet[1].replaceFirst('2x', '').trim()
          : medImage;
    } else {
      medImage = imageUrl;
      largeImage = imageUrl;
    }

    // Use external title first, then fallback to anchor text or img alt.
    final anchorText = anchor?.text.trim();
    final altText = img?.attributes['alt']?.trim().replaceFirst(
        RegExp(r'^(Anime|Manga):\s*'), '');
    final nodeTitle = (externalTitle != null && externalTitle.isNotEmpty)
        ? externalTitle
        : (anchorText != null && anchorText.isNotEmpty)
            ? anchorText
            : altText;

    return <String, dynamic>{
      'id': id,
      'title': nodeTitle,
      'mainPicture': <String, dynamic>{
        'medium': medImage,
        'large': largeImage,
      },
      'nodeCategory': category,
    };
  }

  /// Extract an int query parameter from a URL string.
  static int? _getQueryParam(String? url, String key) {
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final value = uri.queryParameters[key];
    return value != null ? int.tryParse(value) : null;
  }
}
