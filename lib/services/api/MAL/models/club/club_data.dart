/// Club detail data parsed from MAL HTML.
class ClubData {
  final String? title;
  final String? information;
  final List<ClubMember>? members;
  final List<ClubForumTopic>? forumTopics;
  final List<ClubComment>? comments;
  final ClubExtra? details;

  ClubData({
    this.title,
    this.information,
    this.members,
    this.forumTopics,
    this.comments,
    this.details,
  });
}

class ClubExtra {
  final String? pictureUrl;
  final int? members;
  final String? category;
  final int? pictures;
  final String? created;
  final List<ClubStaff>? staffs;
  final ClubRelations? clubRelations;

  ClubExtra({
    this.pictureUrl,
    this.members,
    this.category,
    this.pictures,
    this.created,
    this.staffs,
    this.clubRelations,
  });
}

class ClubRelations {
  final List<ClubRelation>? anime;
  final List<ClubRelation>? manga;
  final List<ClubRelation>? character;

  ClubRelations({this.anime, this.manga, this.character});
}

class ClubRelation {
  final int? id;
  final String? title;

  ClubRelation({this.id, this.title});
}

class ClubStaff {
  final ClubMember? user;
  final String? position;

  ClubStaff({this.user, this.position});
}

class ClubMember {
  final String? username;
  final String? imageUrl;

  ClubMember({this.username, this.imageUrl});
}

class ClubComment {
  final int? id;
  final ClubMember? by;
  final String? longAgo;
  final String? content;

  ClubComment({this.id, this.by, this.longAgo, this.content});
}

class ClubForumTopic {
  final int? id;
  final String? title;
  final String? createdBy;
  final String? replies;
  final String? lastPostBy;
  final String? lastPostTime;

  ClubForumTopic({
    this.id,
    this.title,
    this.createdBy,
    this.replies,
    this.lastPostBy,
    this.lastPostTime,
  });
}
