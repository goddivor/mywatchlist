enum LinkType {
  resources,
  availableAt,
  streaming,
  otherLists,
}

class AnimeDetailHtml {
  final String? title;
  final String? mainPicture;
  final Trailer? trailer;
  final List<Link>? availableAt;
  final List<Link>? resources;
  final List<Link>? streamingPlatforms;
  final List<AdaptNode>? adaptation;
  final List<CharactersVoiceActors>? charactersVoiceActors;
  final List<MangaCharacters>? mangaCharacters;
  final List<CharacterNode>? staff;
  final List<InterestStack>? interestStacks;
  final List<AdditionalTitle>? additionalTitles;

  /// "Favorites" count of the page's Statistics block; null when absent.
  final int? favorites;

  /// Producers and licensors (anime only), linked to `/anime/producer/<id>`.
  final List<Link>? producers;
  final List<Link>? licensors;

  /// Themes and demographics, which API v2 merges into `genres`
  /// (`/anime|manga/genre/<id>`).
  final List<Link>? themes;
  final List<Link>? demographics;

  AnimeDetailHtml({
    this.title,
    this.mainPicture,
    this.trailer,
    this.availableAt,
    this.resources,
    this.streamingPlatforms,
    this.adaptation,
    this.charactersVoiceActors,
    this.mangaCharacters,
    this.staff,
    this.interestStacks,
    this.additionalTitles,
    this.favorites,
    this.producers,
    this.licensors,
    this.themes,
    this.demographics,
  });

  static List<Link>? _links(dynamic json) => (json as List?)
      ?.whereType<Map>()
      .map((item) => Link.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  factory AnimeDetailHtml.fromJson(Map<String, dynamic> json) {
    return AnimeDetailHtml(
      title: json['title'] as String?,
      mainPicture: json['mainPicture'] as String?,
      trailer: Trailer.fromJson(json['trailer'] as Map<String, dynamic>),
      availableAt: (json['availableAt'] as List?)
          ?.map((item) => Link.fromJson(item))
          .toList(),
      resources: (json['resources'] as List)
          .map((item) => Link.fromJson(item))
          .toList(),
      streamingPlatforms: (json['streamingPlatforms'] as List?)
          ?.map((item) => Link.fromJson(item))
          .toList(),
      adaptation: (json['adaptation'] as List?)
          ?.map((item) => AdaptNode.fromJson(item))
          .toList(),
      charactersVoiceActors: (json['charactersVoiceActors'] as List?)
          ?.map((item) => CharactersVoiceActors.fromJson(item))
          .toList(),
      mangaCharacters: (json['mangaCharacters'] as List?)
          ?.map((item) => MangaCharacters.fromJson(item))
          .toList(),
      staff: (json['staff'] as List?)
          ?.map((item) => CharacterNode.fromJson(item))
          .toList(),
      interestStacks: (json['interestStacks'] as List?)
          ?.map((item) => InterestStack.fromJson(item))
          .toList(),
      additionalTitles: (json['additionalTitles'] as List?)
          ?.map((item) => AdditionalTitle.fromJson(item))
          .toList(),
      favorites: (json['favorites'] as num?)?.toInt(),
      producers: _links(json['producers']),
      licensors: _links(json['licensors']),
      themes: _links(json['themes']),
      demographics: _links(json['demographics']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'mainPicture': mainPicture,
      'trailer': trailer?.toJson(),
      'availableAt': availableAt?.map((item) => item.toJson()).toList(),
      'resources': resources?.map((item) => item.toJson()).toList(),
      'streamingPlatforms':
          streamingPlatforms?.map((item) => item.toJson()).toList(),
      'adaptation': adaptation?.map((item) => item.toJson()).toList(),
      'charactersVoiceActors':
          charactersVoiceActors?.map((item) => item.toJson()).toList(),
      'mangaCharacters': mangaCharacters?.map((item) => item.toJson()).toList(),
      'staff': staff?.map((item) => item.toJson()).toList(),
      'interestStacks': interestStacks?.map((item) => item.toJson()).toList(),
      'additionalTitles': additionalTitles?.map((item) => item.toJson()).toList(),
      'favorites': favorites,
      'producers': producers?.map((item) => item.toJson()).toList(),
      'licensors': licensors?.map((item) => item.toJson()).toList(),
      'themes': themes?.map((item) => item.toJson()).toList(),
      'demographics': demographics?.map((item) => item.toJson()).toList(),
    };
  }
}

/// Left-column facts of an anime/manga page (`HtmlParsers.parseDetailSidebar`).
class DetailSidebar {
  final int? favorites;
  final List<Link> producers;
  final List<Link> licensors;
  final List<Link> themes;
  final List<Link> demographics;

  const DetailSidebar({
    this.favorites,
    this.producers = const [],
    this.licensors = const [],
    this.themes = const [],
    this.demographics = const [],
  });
}

class AdaptNode {
  final String image;
  final String relation;
  final Link animeTitle;

  AdaptNode({
    required this.image,
    required this.relation,
    required this.animeTitle,
  });

  factory AdaptNode.fromJson(Map<String, dynamic> json) {
    return AdaptNode(
      image: json['image'],
      relation: json['relation'],
      animeTitle: Link.fromJson(json['animeTitle']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image': image,
      'relation': relation,
      'animeTitle': animeTitle.toJson(),
    };
  }
}

class InterestStack {
  final String? url;
  final String? title;
  final List<String>? imageUrls;
  final String? username;
  final int? entries;
  final int? reStacks;
  final String? description;
  final String? updatedAt;

  InterestStack({
    this.url,
    this.title,
    this.imageUrls,
    this.username,
    this.entries,
    this.reStacks,
    this.description,
    this.updatedAt,
  });

  factory InterestStack.fromJson(Map<String, dynamic> json) {
    return InterestStack(
      url: json['url'],
      title: json['title'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      username: json['username'],
      entries: json['entries'],
      reStacks: json['reStacks'],
      description: json['description'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'title': title,
      'imageUrls': imageUrls,
      'username': username,
      'entries': entries,
      'reStacks': reStacks,
      'description': description,
      'updatedAt': updatedAt,
    };
  }
}

class MangaCharacters {
  final CharacterNode character;

  MangaCharacters({required this.character});

  factory MangaCharacters.fromJson(Map<String, dynamic> json) {
    return MangaCharacters(
      character: CharacterNode.fromJson(json['character']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'character': character.toJson(),
    };
  }
}

class CharactersVoiceActors {
  final CharacterNode character;
  final CharacterNode voiceActor;

  CharactersVoiceActors({
    required this.character,
    required this.voiceActor,
  });

  factory CharactersVoiceActors.fromJson(Map<String, dynamic> json) {
    return CharactersVoiceActors(
      character: CharacterNode.fromJson(json['character']),
      voiceActor: CharacterNode.fromJson(json['voiceActor']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'character': character.toJson(),
      'voiceActor': voiceActor.toJson(),
    };
  }
}

class CharacterNode {
  final String image;
  final Link name;
  final String role;

  CharacterNode({
    required this.image,
    required this.name,
    required this.role,
  });

  factory CharacterNode.fromJson(Map<String, dynamic> json) {
    return CharacterNode(
      image: json['image'],
      name: Link.fromJson(json['name']),
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image': image,
      'name': name.toJson(),
      'role': role,
    };
  }
}

class Trailer {
  final String? title;
  final String? url;

  Trailer({this.title, this.url});

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      title: json['title'],
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
    };
  }
}

class Link {
  final String name;
  final String url;
  final LinkType? linkType;
  final String? imageUrl;

  Link({
    required this.name,
    required this.url,
    this.linkType,
    this.imageUrl,
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      linkType: _parseLinkType(json['linkType']),
      imageUrl: json['imageUrl'],
    );
  }

  static LinkType? _parseLinkType(dynamic linkTypeValue) {
    if (linkTypeValue == null) return null;

    try {
      if (linkTypeValue is String) {
        final cleanValue = linkTypeValue.replaceFirst('LinkType.', '');
        return LinkType.values.firstWhere(
          (e) => e.name == cleanValue || e.toString() == linkTypeValue,
          orElse: () => LinkType.otherLists,
        );
      } else if (linkTypeValue is int && linkTypeValue < LinkType.values.length) {
        return LinkType.values[linkTypeValue];
      }
    } catch (_) {}

    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'linkType': linkType?.name,
      'imageUrl': imageUrl,
    };
  }
}

class AdditionalTitle {
  final String title;
  final String language;

  AdditionalTitle({
    required this.title,
    required this.language,
  });

  factory AdditionalTitle.fromJson(Map<String, dynamic> json) {
    return AdditionalTitle(
      title: json['title'] as String,
      language: json['language'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'language': language,
    };
  }
}
