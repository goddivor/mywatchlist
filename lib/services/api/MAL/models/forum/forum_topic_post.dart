import 'forum_user.dart';

class ForumTopicPost {
  final int? id;
  final int? number;
  final DateTime? createdAt;
  final ForumUser? createdBy;
  final String? body;
  final String? signature;

  ForumTopicPost({
    this.id,
    this.number,
    this.createdAt,
    this.createdBy,
    this.body,
    this.signature,
  });

  factory ForumTopicPost.fromJson(Map<String, dynamic> json) {
    return ForumTopicPost(
      id: json['id'] as int?,
      number: json['number'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      createdBy: json['created_by'] != null
          ? ForumUser.fromJson(json['created_by'] as Map<String, dynamic>)
          : null,
      body: json['body'] as String?,
      signature: json['signature'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (number != null) 'number': number,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (createdBy != null) 'created_by': createdBy!.toJson(),
        if (body != null) 'body': body,
        if (signature != null) 'signature': signature,
      };

  @override
  String toString() {
    return '${createdBy?.name ?? "Unknown"} - ${createdAt?.toLocal() ?? ""}\n${body ?? ""}\n';
  }
}
