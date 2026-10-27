/// Shared value types returned by the MAL page parsers.
library;

import 'json_utils.dart';

/// A picture in two sizes, as MAL serves it through `data-srcset`
/// (`medium` is the 1x image, `large` the 2x one).
class ImageSet {
  final String? medium;
  final String? large;

  const ImageSet({this.medium, this.large});

  /// The best available URL.
  String? get best => large ?? medium;

  bool get isEmpty => medium == null && large == null;

  factory ImageSet.fromJson(Map<String, dynamic>? json) => ImageSet(
        medium: json?['medium'] as String?,
        large: json?['large'] as String?,
      );

  Map<String, dynamic> toJson() => {'medium': medium, 'large': large};
}

/// A link to a MAL entity (anime, manga, character, person, club…).
class MalNodeRef {
  final int? id;
  final String? title;

  /// `anime`, `manga`, `character`, `people`, `club`, … when known.
  final String? category;
  final ImageSet? image;

  const MalNodeRef({this.id, this.title, this.category, this.image});

  factory MalNodeRef.fromJson(Map<String, dynamic>? json) => MalNodeRef(
        id: asInt(json?['id']),
        title: json?['title'] as String?,
        category: json?['category'] as String?,
        image: asMap(json?['image']) == null
            ? null
            : ImageSet.fromJson(asMap(json?['image'])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'image': image?.toJson(),
      };
}

/// A MAL user as shown in member lists, comments and club staff.
class MalUserRef {
  final String username;
  final ImageSet? image;

  const MalUserRef({required this.username, this.image});

  factory MalUserRef.fromJson(Map<String, dynamic>? json) => MalUserRef(
        username: json?['username'] as String? ?? '',
        image: asMap(json?['image']) == null
            ? null
            : ImageSet.fromJson(asMap(json?['image'])),
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'image': image?.toJson(),
      };
}
