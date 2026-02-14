/// Result from searching MAL users via HTML scraping (/users.php).
class MalUserSearchResult {
  final List<MalUserNode> users;

  MalUserSearchResult({this.users = const []});

  factory MalUserSearchResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MalUserSearchResult();
    final list = json['users'] as List<dynamic>? ?? [];
    return MalUserSearchResult(
      users: list
          .map((item) => MalUserNode.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users': users.map((u) => u.toJson()).toList(),
    };
  }
}

/// A single user result from MAL user search.
class MalUserNode {
  final String username;
  final String? imageUrl;
  final String? lastOnline;

  MalUserNode({
    required this.username,
    this.imageUrl,
    this.lastOnline,
  });

  factory MalUserNode.fromJson(Map<String, dynamic> json) {
    return MalUserNode(
      username: json['username'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      lastOnline: json['lastOnline'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (lastOnline != null) 'lastOnline': lastOnline,
    };
  }
}
