import 'common.dart';
import 'json_utils.dart';

/// One review (`.review-element`) of a review list page.
class ReviewHtml {
  /// Review id, read from the reaction buttons.
  final int? id;
  final String? username;
  final ImageSet? userPicture;

  /// Date shown on the review, e.g. `Oct 27, 2026`.
  final String? timeAdded;

  /// Reviewer's score, as shown (`7`).
  final String? overallRating;
  final String? reviewText;

  /// `Recommended`, `Mixed Feelings`, `Not Recommended`, `Preliminary`…
  final List<String> tags;

  /// Reaction name to count (`Nice`, `Love it`, `Funny`, …).
  final Map<String, int> reactions;

  /// Reviewed anime or manga (only on the all-reviews page).
  final MalNodeRef? relatedNode;

  const ReviewHtml({
    this.id,
    this.username,
    this.userPicture,
    this.timeAdded,
    this.overallRating,
    this.reviewText,
    this.tags = const [],
    this.reactions = const {},
    this.relatedNode,
  });

  factory ReviewHtml.fromJson(Map<String, dynamic> json) => ReviewHtml(
        id: asInt(json['id']),
        username: json['username'] as String?,
        userPicture: asMap(json['userPicture']) == null
            ? null
            : ImageSet.fromJson(asMap(json['userPicture'])),
        timeAdded: json['timeAdded'] as String?,
        overallRating: json['overallRating'] as String?,
        reviewText: json['reviewText'] as String?,
        tags: (json['tags'] as List?)?.whereType<String>().toList() ?? const [],
        reactions: (asMap(json['reactions']) ?? const {})
            .map((k, v) => MapEntry(k, asInt(v) ?? 0)),
        relatedNode: asMap(json['relatedNode']) == null
            ? null
            : MalNodeRef.fromJson(asMap(json['relatedNode'])),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'userPicture': userPicture?.toJson(),
        'timeAdded': timeAdded,
        'overallRating': overallRating,
        'reviewText': reviewText,
        'tags': tags,
        'reactions': reactions,
        'relatedNode': relatedNode?.toJson(),
      };
}

/// One row of a MAL forum topic table (`#forumTopics tr`).
class ForumTopicHtml {
  final int id;
  final String? title;
  final String? createdBy;
  final String? createdTime;
  final int? replies;
  final String? lastPostBy;
  final String? lastPostTime;

  const ForumTopicHtml({
    required this.id,
    this.title,
    this.createdBy,
    this.createdTime,
    this.replies,
    this.lastPostBy,
    this.lastPostTime,
  });

  factory ForumTopicHtml.fromJson(Map<String, dynamic> json) => ForumTopicHtml(
        id: asInt(json['id']) ?? 0,
        title: json['title'] as String?,
        createdBy: json['createdBy'] as String?,
        createdTime: json['createdTime'] as String?,
        replies: asInt(json['replies']),
        lastPostBy: json['lastPostBy'] as String?,
        lastPostTime: json['lastPostTime'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdBy': createdBy,
        'createdTime': createdTime,
        'replies': replies,
        'lastPostBy': lastPostBy,
        'lastPostTime': lastPostTime,
      };
}

/// A comment of a club page.
class ClubCommentHtml {
  final int id;
  final MalUserRef? by;

  /// Date as shown, e.g. `Oct 8, 8:34 AM`.
  final String? longAgo;

  /// Comment body as HTML.
  final String? content;

  const ClubCommentHtml({
    required this.id,
    this.by,
    this.longAgo,
    this.content,
  });

  factory ClubCommentHtml.fromJson(Map<String, dynamic> json) =>
      ClubCommentHtml(
        id: asInt(json['id']) ?? 0,
        by: asMap(json['by']) == null
            ? null
            : MalUserRef.fromJson(asMap(json['by'])),
        longAgo: json['longAgo'] as String?,
        content: json['content'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'by': by?.toJson(),
        'longAgo': longAgo,
        'content': content,
      };
}

/// A staff member of a club (`Xinil (President)`).
class ClubStaffHtml {
  final MalUserRef user;
  final String? position;

  const ClubStaffHtml({required this.user, this.position});

  factory ClubStaffHtml.fromJson(Map<String, dynamic> json) => ClubStaffHtml(
        user: MalUserRef.fromJson(asMap(json['user'])),
        position: json['position'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'position': position,
      };
}

/// Right column of a club page.
class ClubDetailsHtml {
  final ImageSet? picture;
  final int? members;
  final int? pictures;
  final String? category;
  final String? created;
  final List<ClubStaffHtml> staff;
  final List<MalNodeRef> animeRelations;
  final List<MalNodeRef> mangaRelations;
  final List<MalNodeRef> characterRelations;

  const ClubDetailsHtml({
    this.picture,
    this.members,
    this.pictures,
    this.category,
    this.created,
    this.staff = const [],
    this.animeRelations = const [],
    this.mangaRelations = const [],
    this.characterRelations = const [],
  });

  factory ClubDetailsHtml.fromJson(Map<String, dynamic>? json) =>
      ClubDetailsHtml(
        picture: asMap(json?['picture']) == null
            ? null
            : ImageSet.fromJson(asMap(json?['picture'])),
        members: asInt(json?['members']),
        pictures: asInt(json?['pictures']),
        category: json?['category'] as String?,
        created: json?['created'] as String?,
        staff: asList(json?['staff'], ClubStaffHtml.fromJson),
        animeRelations: asList(json?['animeRelations'], MalNodeRef.fromJson),
        mangaRelations: asList(json?['mangaRelations'], MalNodeRef.fromJson),
        characterRelations:
            asList(json?['characterRelations'], MalNodeRef.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'picture': picture?.toJson(),
        'members': members,
        'pictures': pictures,
        'category': category,
        'created': created,
        'staff': staff.map((e) => e.toJson()).toList(),
        'animeRelations': animeRelations.map((e) => e.toJson()).toList(),
        'mangaRelations': mangaRelations.map((e) => e.toJson()).toList(),
        'characterRelations':
            characterRelations.map((e) => e.toJson()).toList(),
      };
}

/// A club page (`clubs.php?cid=<id>`).
class ClubPageHtml {
  final String? title;

  /// Club description as HTML.
  final String? information;
  final List<MalUserRef> members;
  final List<ImageSet> pictures;
  final List<ForumTopicHtml> forumTopics;
  final List<ClubCommentHtml> comments;
  final ClubDetailsHtml details;

  const ClubPageHtml({
    this.title,
    this.information,
    this.members = const [],
    this.pictures = const [],
    this.forumTopics = const [],
    this.comments = const [],
    this.details = const ClubDetailsHtml(),
  });

  factory ClubPageHtml.fromJson(Map<String, dynamic>? json) => ClubPageHtml(
        title: json?['title'] as String?,
        information: json?['information'] as String?,
        members: asList(json?['members'], MalUserRef.fromJson),
        pictures: asList(json?['pictures'], ImageSet.fromJson),
        forumTopics: asList(json?['forumTopics'], ForumTopicHtml.fromJson),
        comments: asList(json?['comments'], ClubCommentHtml.fromJson),
        details: ClubDetailsHtml.fromJson(asMap(json?['details'])),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'information': information,
        'members': members.map((e) => e.toJson()).toList(),
        'pictures': pictures.map((e) => e.toJson()).toList(),
        'forumTopics': forumTopics.map((e) => e.toJson()).toList(),
        'comments': comments.map((e) => e.toJson()).toList(),
        'details': details.toJson(),
      };
}

/// The "about me" block of a user profile.
class UserAboutHtml {
  /// About text as HTML; null when the user wrote none.
  final String? about;

  /// True when the profile uses the "modern" custom layout.
  final bool modern;

  const UserAboutHtml({this.about, this.modern = false});

  factory UserAboutHtml.fromJson(Map<String, dynamic>? json) => UserAboutHtml(
        about: json?['about'] as String?,
        modern: json?['modern'] == true,
      );

  Map<String, dynamic> toJson() => {'about': about, 'modern': modern};
}
