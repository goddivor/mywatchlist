import 'forum_topics_data.dart';
import 'forum_user.dart';

/// Forum topic data parsed from HTML (fallback when API unavailable).
class ForumHtml extends ForumTopicsData {
  final int? topicId;
  final String? createdByName;
  final String? createdTime;
  final String? lastPostBy;
  final String? lastPostTime;
  final String? replies;

  ForumHtml({
    this.topicId,
    this.createdByName,
    this.createdTime,
    this.lastPostBy,
    this.lastPostTime,
    this.replies,
  }) : super(
          id: topicId,
          createdBy: ForumUser(name: createdByName),
          numberOfPosts:
              replies != null ? int.tryParse(replies) : null,
          lastPostCreatedBy: ForumUser(name: lastPostBy),
        );

  factory ForumHtml.fromJson(Map<String, dynamic> json) {
    return ForumHtml(
      topicId: json['topicId'] as int?,
      createdByName: json['createdByName'] as String?,
      createdTime: json['createdTime'] as String?,
      lastPostBy: json['lastPostBy'] as String?,
      lastPostTime: json['lastPostTime'] as String?,
      replies: json['replies'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        if (topicId != null) 'topicId': topicId,
        if (title != null) 'title': title,
        if (createdByName != null) 'createdByName': createdByName,
        if (createdTime != null) 'createdTime': createdTime,
        if (lastPostBy != null) 'lastPostBy': lastPostBy,
        if (lastPostTime != null) 'lastPostTime': lastPostTime,
        if (replies != null) 'replies': replies,
      };
}
