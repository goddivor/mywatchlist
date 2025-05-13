import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart';

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
  });

  factory AnimeDetailHtml.fromJson(Map<String, dynamic> json) {
    return AnimeDetailHtml(
      title: json['title'] as String?,
      mainPicture: json['mainPicture'] as String?,
      trailer: Trailer.fromJson(json['trailer'] as Map<String, dynamic>) ,
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
    };
  }
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

  InterestStack({
    this.url,
    this.title,
    this.imageUrls,
    this.username,
    this.entries,
    this.reStacks,
  });

  factory InterestStack.fromJson(Map<String, dynamic> json) {
    return InterestStack(
      url: json['url'],
      title: json['title'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      username: json['username'],
      entries: json['entries'],
      reStacks: json['reStacks'],
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

  // Helper method to safely parse LinkType
  static LinkType? _parseLinkType(dynamic linkTypeValue) {
    if (linkTypeValue == null) return null;
    
    try {
      // Handle string representation
      if (linkTypeValue is String) {
        // Remove "LinkType." prefix if present
        final cleanValue = linkTypeValue.replaceFirst('LinkType.', '');
        
        // Try to find the matching enum value
        return LinkType.values.firstWhere(
          (e) => e.name == cleanValue || e.toString() == linkTypeValue,
          orElse: () => LinkType.otherLists, // Default value
        );
      }
      // Handle integer representation (if needed)
      else if (linkTypeValue is int && linkTypeValue < LinkType.values.length) {
        return LinkType.values[linkTypeValue];
      }
    } catch (e) {
      print('Error parsing LinkType: $e');
    }
    
    // Return default value if parsing fails
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'linkType': linkType?.name, // Use .name instead of toString()
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