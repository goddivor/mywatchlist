// ignore_for_file: unused_element

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_featured.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_featured_tags.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_tags.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/genre.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/paging.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_friends.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_history.dart';
import 'package:mywatchlist/widgets/media_platforms.dart';

class HtmlParsers {
  static final unescape = HtmlUnescape();

  static String getImageUrlByQuality(
      Element? imageElement, String imageQuality) {
    // Initialiser une variable vide pour l'URL de l'image
    String imageUrl = '';

    // Vérifier que l'élément n'est pas null
    if (imageElement != null) {
      // Vérifier si l'attribut 'data-srcset' est présent
      if (imageElement.attributes.containsKey('data-srcset')) {
        // Extraire 'srcset' et le transformer en une liste d'URLs
        var srcset = imageElement.attributes['data-srcset']!;
        var srcsetUrls =
            srcset.split(',').map((e) => e.trim().split(' ')[0]).toList();

        // Trouver la première URL qui correspond à la qualité demandée
        imageUrl = srcsetUrls.firstWhere((url) => url.contains(imageQuality),
            orElse: () => '');
      } else if (imageElement.attributes.containsKey('data-src')) {
        // Si 'srcset' n'est pas disponible, utiliser 'data-src'
        imageUrl = imageElement.attributes['data-src']!;
      } else if (imageElement.attributes.containsKey('src')) {
        // Si 'data-src' n'est pas disponible, utiliser 'src'
        imageUrl = imageElement.attributes['src']!;
      }
    }

    // Retourner l'URL de l'image (ou une chaîne vide si aucune URL n'est trouvée)
    return imageUrl;
  }

  static String getOriginalImageQuality(
      Element? imageElement, String imageQuality) {
    // Initialiser une variable pour stocker l'URL de l'image
    String imageUrl = '';

    // Vérifier si l'élément n'est pas null
    if (imageElement != null) {
      // Vérifier si l'attribut 'data-src' existe, sinon utiliser 'src'
      imageUrl = imageElement.attributes['data-src'] ??
          imageElement.attributes['src'] ??
          '';
    }

    // Si une URL valide est trouvée, on procède à la modification
    if (imageUrl.isNotEmpty) {
      // Remplacer l'imageQuality par une chaîne vide
      imageUrl = imageUrl.replaceAll(imageQuality, '');

      // Récupérer la partie avant le premier '?' (paramètres URL)
      int queryIndex = imageUrl.indexOf('?');
      if (queryIndex != -1) {
        imageUrl = imageUrl.substring(0, queryIndex);
      }
    }

    // Retourner l'URL modifiée ou vide si aucune URL n'est trouvée
    return imageUrl;
  }

  //method to parse anime news or featured
  static AnimeNewsOrFeaturedResult parseAnimeNewsOrFeatured(Document document) {
    var newsElements = document.querySelectorAll('.news-unit');

    var newsItems = newsElements
        .map((element) {
          // Récupérer le titre et l'URL
          var linkElement = element.querySelector('.title a');
          var title = linkElement != null ? linkElement.text.trim() : '';
          var url =
              linkElement != null ? linkElement.attributes['href']!.trim() : '';

          // Extraire l'ID à partir de l'URL
          int id = 0;
          if (url.startsWith(Constants.malnewsUrl)) {
            id = int.parse(
                url.replaceFirst('${Constants.malnewsUrl}/', '').split('/')[0]);
          } else if (url.startsWith(Constants.malfeaturedUrl)) {
            id = int.parse(url
                .replaceFirst('${Constants.malfeaturedUrl}/', '')
                .split('/')[0]);
          }

          // Récupérer le texte
          var textElement = element.querySelector('.text');
          var text = textElement != null ? textElement.text.trim() : '';

          // Récupérer les tags
          var tags = '';
          var tagElements =
              element.querySelectorAll('.information .tags a'); // Premier cas
          if (tagElements.isEmpty) {
            // Deuxième cas où les tags sont dans des spans
            tagElements = element.querySelectorAll('.information .tags .tag');
          }
          tags = tagElements.map((e) => e.text.trim()).join(', ');

          // Récupérer l'image
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

    // Parsing de la pagination
    var paging = Paging(previous: '', next: ''); // Valeurs par défaut
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

  //method to parse anime featured tags...
  static AnimefeaturedTagsResult parseAnimeFeaturedTags(Document document) {
    // Récupérer le conteneur des tags
    var tagContainer = document.querySelector('.news-tags-table');

    // Récupérer tous les liens de tags
    var tagElements =
        tagContainer?.querySelectorAll('.tag-list a.tag-name-link');

    // Construire la liste des tags
    var tags = tagElements?.map((element) {
          var url = element.attributes['href']!.trim();
          var name = element.querySelector('span.tag-name')?.text.trim() ?? '';

          return AnimeFeaturedTag(url: url, name: name);
        }).toList() ??
        [];

    // Retourner le résultat
    return AnimefeaturedTagsResult(tags: tags);
  }

  //method to parse anime news tag...
  static AnimeNewsTagsResult parseAnimeNewsTags(Document document) {
    // Récupérer le conteneur des catégories de tags
    var menuCategoryTags = document.querySelector('.menu-category-tags');

    // Récupérer tous les éléments de catégorie
    var categoryElements = menuCategoryTags?.querySelectorAll('.btn-category');

    // Construire la liste des catégories à partir des data-id
    var listCategory = categoryElements?.map((element) {
          return element.attributes['data-id']!.trim();
        }).toList() ??
        [];

    // Liste pour stocker les catégories et leurs tags
    var categories = <AnimeNewsTagCat>[];

    // Parcourir chaque catégorie
    for (var category in listCategory) {
      var categoryElement = document.getElementById(category);

      if (categoryElement != null) {
        // Récupérer le nom de la catégorie
        var categoryName =
            categoryElement.querySelector('.news-tags-header')?.text.trim() ??
                '';

        // Récupérer tous les tags de cette catégorie
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

        // Ajouter la catégorie avec ses tags à la liste des catégories
        categories.add(AnimeNewsTagCat(categoryName: categoryName, tags: tags));
      }
    }

    // Retourner le résultat
    return AnimeNewsTagsResult(categories: categories);
  }

  //another methods here...
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
        .first; // Le premier .external_links
    var linkElements = availableAtElement.querySelectorAll('a.ga-click');

    return linkElements.map((e) {
      var name = e.querySelector('.caption')?.text.trim() ??
          ''; // Le texte du lien est dans la div.caption
      var url = e.attributes['href']?.trim() ?? '';
      var imageUrl = e.querySelector('img')?.attributes['src']?.trim() ??
          ''; // Récupérer l'URL de l'image si elle existe
      return Link(
        name: name,
        url: url,
        imageUrl: imageUrl,
        linkType: LinkType.availableAt, // Ajouter le type de lien
      );
    }).toList();
  }

  static List<Link> _getResourceLinks(Document document) {
    var resourceElement = document
        .querySelectorAll('.external_links')
        .elementAt(1); // Le second .external_links
    var linkElements = resourceElement.querySelectorAll('a.ga-click');

    return linkElements.map((e) {
      var name = e.querySelector('.caption')?.text.trim() ??
          ''; // Le texte du lien est dans la div.caption
      var url = e.attributes['href']?.trim() ?? '';
      var imageUrl = e.querySelector('img')?.attributes['src']?.trim() ??
          ''; // Récupérer l'URL de l'image si elle existe
      return Link(
        name: name,
        url: url,
        imageUrl: imageUrl,
        linkType: LinkType.resources, // Ajouter le type de lien
      );
    }).toList();
  }

  static List<Link> _getStreamingPlatforms(Document document) {
    var streamingElements =
        document.querySelectorAll('.broadcasts .broadcast a');

    return streamingElements.map((e) {
      var name = e.querySelector('.caption')?.text.trim() ??
          ''; // Le texte du lien est dans la div.caption
      var title = e.attributes['title'] ?? e.text.trim();
      var url = e.attributes['href']?.trim() ?? '';
      // var imageUrl = e.querySelector('img')?.attributes['src']?.trim() ??
      ''; // Récupérer l'URL de l'image si elle existe
      return Link(
        name: name,
        url: url,
        imageUrl: getDomainAsset(title),
        linkType: LinkType.streaming, // Ajouter le type de lien
      );
    }).toList();
  }

  static List<AdaptNode> _getAdaptation(Document document) {
    var adaptationElements = document.querySelectorAll('.entries-tile .entry');

    return adaptationElements
        .where((e) => e.text.contains('Adaptation'))
        .map((e) {
      // Récupérer l'image de l'adaptation
      var imageElement = e.querySelector('.image img');
      var imageQuality =
          'r/50x70'; // Qualité de l'image rendu x2; 'r/50x70' rendu x1

      // var image = getImageUrlByQuality(imageElement, imageQuality).trim();
      var image = getOriginalImageQuality(imageElement, imageQuality).trim();
      // var image = imageElement?.attributes['data-src']?.trim() ?? '';

      // Récupérer la relation (par exemple, "Adaptation (Manga)")
      var relationElement = e.querySelector('.content .relation');
      var relation = relationElement?.text.trim() ?? '';

      // Récupérer le titre de l'adaptation
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
    // Sélectionner le premier `.detail-characters-list.clearfix`
    var characterList =
        document.querySelector('.detail-characters-list.clearfix');
    if (characterList == null) {
      return [];
    }

    // Vérifier et récupérer les deux colonnes s'ils existent
    var leftColumn = characterList.querySelector('.left-column');
    var rightColumn = characterList.querySelector('.left-right');

    // Fonction pour extraire les personnages et acteurs à partir des lignes `tr`
    List<MangaCharacters> extractMangaCharacters(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<MangaCharacters> mangaCharactersList = [];

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 2) {
          continue; // S'assurer qu'il y a bien 3 colonnes (td)
        }

        //Extraire les informations du personnage
        var characterImage = tds[0]
                .querySelector('.picSurround img')
                ?.attributes['data-src']
                ?.trim() ??
            '';
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

        //Ajouter les peronnage a la liste
        mangaCharactersList.add(MangaCharacters(character: character));
      }

      return mangaCharactersList;
    }

    // Extraire les données des deux colonnes s'ils existent
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
    // Sélectionner le premier `.detail-characters-list.clearfix`
    var characterList =
        document.querySelector('.detail-characters-list.clearfix');
    if (characterList == null) {
      return [];
    }

    // Vérifier et récupérer les deux colonnes s'ils existent
    var leftColumn = characterList.querySelector('.left-column');
    var rightColumn = characterList.querySelector('.left-right');

    // Fonction pour extraire les personnages et acteurs de voix à partir des lignes `tr`
    List<CharactersVoiceActors> extractCharactersVoiceActors(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<CharactersVoiceActors> characterVoiceActorsList = [];

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 3) {
          continue; // S'assurer qu'il y a bien 3 colonnes (td)
        }

        // Extraire les informations du personnage
        // var characterImage = tds[0]
        //         .querySelector('.picSurround img')
        //         ?.attributes['data-src']
        //         ?.trim() ??
        //     '';
        var imageQuality =
            'r/42x62'; // image quality rendu x2; 'r/42x62' rendu x1
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

        // Extraire les informations de l'acteur de voix
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

        // Ajouter le pair personnage/acteur à la liste
        characterVoiceActorsList.add(CharactersVoiceActors(
          character: character,
          voiceActor: voiceActor,
        ));
      }

      return characterVoiceActorsList;
    }

    // Extraire les données des deux colonnes s'ils existent
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
    // Sélectionner le deuxième `.detail-characters-list.clearfix`
    var staffList =
        document.querySelectorAll('.detail-characters-list.clearfix');
    if (staffList.length < 2) {
      return []; // S'assurer qu'il y a au moins deux éléments
    }
    var secondStaffList = staffList[1]; // Le deuxième élément dans la liste

    // Vérifier et récupérer les deux colonnes s'ils existent
    var leftColumn = secondStaffList.querySelector('.left-column');
    var rightColumn = secondStaffList.querySelector('.left-right');

    // Fonction pour extraire les membres du staff à partir des lignes `tr`
    List<CharacterNode> extractStaff(Element column) {
      var rows = column.querySelectorAll('table tr');
      List<CharacterNode> staffListResult = [];

      for (var row in rows) {
        var tds = row.querySelectorAll('td.borderClass');
        if (tds.length != 2) {
          continue; // S'assurer qu'il y a bien 2 colonnes (td)
        }

        // Extraire l'image du membre du staff
        var imageQuality =
            'r/42x62'; // Image quality rendu x2; 'r/42x62" rendu x1
        var staffElement = tds[0].querySelector('.picSurround img');
        // var staffImage = getImageUrlByQuality(staffElement, imageQuality).trim();
        var staffImage =
            getOriginalImageQuality(staffElement, imageQuality).trim();

        // Extraire le nom, l'URL et le rôle du membre du staff
        var staffNameElement = tds[1].querySelector('a');
        var staffName = Link(
          name: staffNameElement?.text.trim() ?? '',
          url: staffNameElement?.attributes['href']?.trim() ?? '',
        );
        var staffRole =
            tds[1].querySelector('.spaceit_pad small')?.text.trim() ?? '';

        // Créer un objet CharacterNode pour le membre du staff
        var staffMember = CharacterNode(
          image: staffImage,
          name: staffName,
          role: staffRole,
        );

        // Ajouter le membre du staff à la liste des résultats
        staffListResult.add(staffMember);
      }

      return staffListResult;
    }

    // Extraire les données des deux colonnes s'ils existent
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
      // Récupérer l'URL du stack
      var urlElement = e.querySelector('a');
      var url = urlElement?.attributes['href']?.trim() ?? '';

      // Récupérer le titre du stack
      var titleElement = e.querySelector('.title a');
      var title = titleElement?.text.trim() ?? '';

      // Récupérer les images associées au stack
      var imageElements = e.querySelectorAll('.img .edge img');
      var imageUrls = imageElements
          .map((img) => img.attributes['src']?.trim() ?? '')
          .toList();

      // Récupérer l'auteur du stack
      var authorElement = e.querySelector('.tag a');
      var username = authorElement?.text.trim() ?? '';

      // Récupérer les statistiques du stack (Entries et Restacks)
      var statElement = e.querySelector('.foot .stat');
      var statsText = statElement?.text.trim() ?? '';
      int? entries = _getBeforeInt(statsText, endPattern: 'Entries');
      int? reStacks =
          _getBeforeInt(statsText, endPattern: 'Restacks', startPattern: '·');

      // Retourner un objet InterestStack
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

  //method to parse anime details...
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

  //method to parse user history...
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

  //method to parse user friends list...
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

  //method to parse mal genre...
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
                .getAlphabets(); // Extract a specific fonction on the extension strings...
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

  //method to parse anime producer
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
                .getAlphabets(); // Extract a specific fonction on the extension strings...
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
}
