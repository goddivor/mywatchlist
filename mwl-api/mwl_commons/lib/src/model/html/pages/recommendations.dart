import 'common.dart';
import 'json_utils.dart';

/// One recommendation of MAL's global feed (`recommendations.php?s=recentrecs`): "if you
/// liked [source], then you might like [recommended]", with the reason a user wrote.
class GlobalRecommendationHtml {
  /// Id of the recommendation (the "report" link), null when the page gives none.
  final int? id;

  /// `anime` or `manga`.
  final String category;
  final MalNodeRef source;
  final MalNodeRef recommended;

  /// The user's explanation, line breaks kept.
  final String? text;
  final String? username;

  /// MAL's wording: `4 hours ago`.
  final String? timeAdded;

  const GlobalRecommendationHtml({
    this.id,
    required this.category,
    required this.source,
    required this.recommended,
    this.text,
    this.username,
    this.timeAdded,
  });

  factory GlobalRecommendationHtml.fromJson(Map<String, dynamic> json) =>
      GlobalRecommendationHtml(
        id: asInt(json['id']),
        category: (json['category'] as String?) ?? 'anime',
        source: MalNodeRef.fromJson(asMap(json['source'])),
        recommended: MalNodeRef.fromJson(asMap(json['recommended'])),
        text: json['text'] as String?,
        username: json['username'] as String?,
        timeAdded: json['timeAdded'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'source': source.toJson(),
        'recommended': recommended.toJson(),
        'text': text,
        'username': username,
        'timeAdded': timeAdded,
      };
}
