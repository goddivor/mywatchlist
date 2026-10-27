import 'common.dart';
import 'json_utils.dart';

/// A voice actor credited on a character of a content's characters page.
class VoiceActorHtml {
  final int id;
  final String name;
  final String? language;
  final ImageSet? image;

  const VoiceActorHtml({
    required this.id,
    required this.name,
    this.language,
    this.image,
  });

  factory VoiceActorHtml.fromJson(Map<String, dynamic> json) => VoiceActorHtml(
        id: asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        language: json['language'] as String?,
        image: asMap(json['image']) == null
            ? null
            : ImageSet.fromJson(asMap(json['image'])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'image': image?.toJson(),
      };
}

/// One character of `/{anime|manga}/{id}/_/characters`.
class ContentCharacterHtml {
  final int id;
  final String name;

  /// `Main` or `Supporting`.
  final String? role;
  final int favorites;
  final ImageSet? image;
  final List<VoiceActorHtml> voiceActors;

  const ContentCharacterHtml({
    required this.id,
    required this.name,
    this.role,
    this.favorites = 0,
    this.image,
    this.voiceActors = const [],
  });

  factory ContentCharacterHtml.fromJson(Map<String, dynamic> json) =>
      ContentCharacterHtml(
        id: asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        role: json['role'] as String?,
        favorites: asInt(json['favorites']) ?? 0,
        image: asMap(json['image']) == null
            ? null
            : ImageSet.fromJson(asMap(json['image'])),
        voiceActors: asList(json['voiceActors'], VoiceActorHtml.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'favorites': favorites,
        'image': image?.toJson(),
        'voiceActors': voiceActors.map((e) => e.toJson()).toList(),
      };
}

/// One staff member of an anime's characters page.
class StaffMemberHtml {
  final int id;
  final String name;

  /// Comma-separated positions, e.g. `Director, Storyboard`.
  final String? role;
  final ImageSet? image;

  const StaffMemberHtml({
    required this.id,
    required this.name,
    this.role,
    this.image,
  });

  factory StaffMemberHtml.fromJson(Map<String, dynamic> json) =>
      StaffMemberHtml(
        id: asInt(json['id']) ?? 0,
        name: json['name'] as String? ?? '',
        role: json['role'] as String?,
        image: asMap(json['image']) == null
            ? null
            : ImageSet.fromJson(asMap(json['image'])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'image': image?.toJson(),
      };
}

/// Full characters and staff page of an anime or a manga.
class ContentCharactersHtml {
  final List<ContentCharacterHtml> characters;
  final List<StaffMemberHtml> staff;

  const ContentCharactersHtml({
    this.characters = const [],
    this.staff = const [],
  });

  factory ContentCharactersHtml.fromJson(Map<String, dynamic>? json) =>
      ContentCharactersHtml(
        characters: asList(json?['characters'], ContentCharacterHtml.fromJson),
        staff: asList(json?['staff'], StaffMemberHtml.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'characters': characters.map((e) => e.toJson()).toList(),
        'staff': staff.map((e) => e.toJson()).toList(),
      };
}

/// One row of the top characters (`character.php`) or top people
/// (`people.php`) ranking.
class RankedPersonHtml {
  final int id;
  final int? rank;
  final String name;

  /// Name in the original script, without the surrounding parentheses.
  final String? otherName;
  final ImageSet? image;
  final int? favorites;

  /// People only.
  final String? birthday;

  /// Characters only.
  final List<MalNodeRef> animeography;

  /// Characters only.
  final List<MalNodeRef> mangaography;

  const RankedPersonHtml({
    required this.id,
    required this.name,
    this.rank,
    this.otherName,
    this.image,
    this.favorites,
    this.birthday,
    this.animeography = const [],
    this.mangaography = const [],
  });

  factory RankedPersonHtml.fromJson(Map<String, dynamic> json) =>
      RankedPersonHtml(
        id: asInt(json['id']) ?? 0,
        rank: asInt(json['rank']),
        name: json['name'] as String? ?? '',
        otherName: json['otherName'] as String?,
        image: asMap(json['image']) == null
            ? null
            : ImageSet.fromJson(asMap(json['image'])),
        favorites: asInt(json['favorites']),
        birthday: json['birthday'] as String?,
        animeography: asList(json['animeography'], MalNodeRef.fromJson),
        mangaography: asList(json['mangaography'], MalNodeRef.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rank': rank,
        'name': name,
        'otherName': otherName,
        'image': image?.toJson(),
        'favorites': favorites,
        'birthday': birthday,
        'animeography': animeography.map((e) => e.toJson()).toList(),
        'mangaography': mangaography.map((e) => e.toJson()).toList(),
      };
}
