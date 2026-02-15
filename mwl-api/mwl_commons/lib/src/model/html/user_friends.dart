class UserFriendsList {
  final List<Friend> friends;

  UserFriendsList({required this.friends});

  factory UserFriendsList.fromJson(Map<String, dynamic> json) {
    var friendsJson = json['friends'] as List<dynamic>;
    var friends = friendsJson.map((item) => Friend.fromJson(item as Map<String, dynamic>)).toList();
    return UserFriendsList(friends: friends);
  }

  Map<String, dynamic> toJson() {
    return {
      'friends': friends.map((friend) => friend.toJson()).toList(),
    };
  }
}


class Friend {
  final User user;
  final String lastOnline;
  final String friendSince;

  Friend({
    required this.user,
    required this.lastOnline,
    required this.friendSince,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      user: User.fromJson(json['user']),
      lastOnline: json['lastOnline'] as String,
      friendSince: json['friendSince'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'lastOnline': lastOnline,
      'friendSince': friendSince,
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
      url: json['url'] as String,
      imageUrl: json['imageUrl'] as String,
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
