class ForumUser {
  final int? id;
  final String? name;
  final String? forumAvatar;

  ForumUser({this.id, this.name, this.forumAvatar});

  factory ForumUser.fromJson(Map<String, dynamic> json) {
    return ForumUser(
      id: json['id'] as int?,
      name: json['name'] as String?,
      forumAvatar: json['forum_avator'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (forumAvatar != null) 'forum_avator': forumAvatar,
      };
}
