class UserFriendsList {
  final List<Friend> friends;

  /// MAL's own "more friends to load" flag (new friends page). Null on the old layout, where
  /// a full page (100) is the only hint.
  final bool? hasMore;

  /// Numeric MAL id of the list's owner (new friends page), needed by the "load more"
  /// endpoint `/friends/api/list/<userId>.json`.
  final int? userId;

  UserFriendsList({required this.friends, this.hasMore, this.userId});

  factory UserFriendsList.fromJson(Map<String, dynamic> json) {
    var friendsJson = json['friends'] as List<dynamic>;
    var friends = friendsJson.map((item) => Friend.fromJson(item as Map<String, dynamic>)).toList();
    return UserFriendsList(
      friends: friends,
      hasMore: json['hasMore'] as bool?,
      userId: json['userId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'friends': friends.map((friend) => friend.toJson()).toList(),
      if (hasMore != null) 'hasMore': hasMore,
      if (userId != null) 'userId': userId,
    };
  }
}


class Friend {
  final User user;
  final String lastOnline;
  final String friendSince;

  /// Numeric MAL id of the friend (new friends page only).
  final int? id;

  /// Unix seconds of the friend's last activity (new friends page only; the old page gave
  /// [lastOnline] as text).
  final int? lastActivity;

  /// Unix seconds of the friendship's start (new friends page only).
  final int? timeAdded;

  Friend({
    required this.user,
    required this.lastOnline,
    required this.friendSince,
    this.id,
    this.lastActivity,
    this.timeAdded,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      user: User.fromJson(json['user']),
      lastOnline: json['lastOnline'] as String? ?? '',
      friendSince: json['friendSince'] as String? ?? '',
      id: json['id'] as int?,
      lastActivity: json['lastActivity'] as int?,
      timeAdded: json['timeAdded'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'lastOnline': lastOnline,
      'friendSince': friendSince,
      if (id != null) 'id': id,
      if (lastActivity != null) 'lastActivity': lastActivity,
      if (timeAdded != null) 'timeAdded': timeAdded,
    };
  }
}


class User {
  final String username;
  final String url;
  final String imageUrl;

  User({
    required this.username,
    required this.url,
    required this.imageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] as String,
      url: json['url'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'url': url,
      'imageUrl': imageUrl,
    };
  }
}
