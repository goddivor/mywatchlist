import 'forum_user.dart';

class ForumTopicsData {
  final int? id;
  final String? title;
  final DateTime? createdAt;
  final ForumUser? createdBy;
  final int? numberOfPosts;
  final DateTime? lastPostCreatedAt;
  final ForumUser? lastPostCreatedBy;
  final bool? isLocked;
  /// Raw text for last post time (e.g. "10 minutes ago", "Yesterday, 3:33 PM")
  final String? lastPostTimeText;

  ForumTopicsData({
    this.id,
    this.title,
    this.createdAt,
    this.createdBy,
    this.numberOfPosts,
    this.lastPostCreatedAt,
    this.lastPostCreatedBy,
    this.isLocked,
    this.lastPostTimeText,
  });

  factory ForumTopicsData.fromJson(Map<String, dynamic> json) {
    // Handle created_by: can be a Map (API) or String (HTML parser)
    ForumUser? createdBy;
    if (json['created_by'] is Map<String, dynamic>) {
      createdBy = ForumUser.fromJson(json['created_by'] as Map<String, dynamic>);
    } else if (json['created_by'] is String) {
      final name = json['created_by'] as String;
      createdBy = name.isNotEmpty ? ForumUser(name: name) : null;
    }

    // Handle last_post_created_by: can be a Map (API) or String (HTML parser)
    ForumUser? lastPostCreatedBy;
    if (json['last_post_created_by'] is Map<String, dynamic>) {
      lastPostCreatedBy = ForumUser.fromJson(
          json['last_post_created_by'] as Map<String, dynamic>);
    } else if (json['last_post_created_by'] is String) {
      final name = json['last_post_created_by'] as String;
      lastPostCreatedBy = name.isNotEmpty ? ForumUser(name: name) : null;
    }

    // Handle number_of_posts: API uses 'number_of_posts', HTML parser uses 'replies'
    int? numberOfPosts = json['number_of_posts'] as int?;
    if (numberOfPosts == null && json['replies'] != null) {
      numberOfPosts = int.tryParse(json['replies'].toString());
    }

    // Handle last_post_created_at: API uses ISO string, HTML parser uses 'last_post'
    DateTime? lastPostCreatedAt;
    String? lastPostTimeText;
    if (json['last_post_created_at'] != null) {
      lastPostCreatedAt =
          DateTime.tryParse(json['last_post_created_at'] as String);
    }
    if (json['last_post'] is String) {
      final raw = json['last_post'] as String;
      lastPostCreatedAt ??= DateTime.tryParse(raw);
      // Store raw text for display (e.g. "10 minutes ago", "Yesterday")
      if (raw.isNotEmpty) lastPostTimeText = raw;
    }

    return ForumTopicsData(
      id: json['id'] as int?,
      title: json['title'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      createdBy: createdBy,
      numberOfPosts: numberOfPosts,
      lastPostCreatedAt: lastPostCreatedAt,
      lastPostCreatedBy: lastPostCreatedBy,
      isLocked: json['is_locked'] as bool?,
      lastPostTimeText: lastPostTimeText,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (title != null) 'title': title,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (createdBy != null) 'created_by': createdBy!.toJson(),
        if (numberOfPosts != null) 'number_of_posts': numberOfPosts,
        if (lastPostCreatedAt != null)
          'last_post_created_at': lastPostCreatedAt!.toIso8601String(),
        if (lastPostCreatedBy != null)
          'last_post_created_by': lastPostCreatedBy!.toJson(),
        if (isLocked != null) 'is_locked': isLocked,
      };
}
