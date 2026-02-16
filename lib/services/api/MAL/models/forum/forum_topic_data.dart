import '../paging.dart';
import 'forum_topic_poll.dart';
import 'forum_topic_post.dart';

class ForumTopicData {
  final List<ForumTopicPost>? posts;
  final String? title;
  final Paging? paging;
  final ForumTopicPoll? poll;

  ForumTopicData({this.posts, this.title, this.paging, this.poll});

  factory ForumTopicData.fromJson(Map<String, dynamic> json) {
    return ForumTopicData(
      posts: (json['posts'] as List<dynamic>?)
          ?.map((e) => ForumTopicPost.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String?,
      paging: json['paging'] != null
          ? Paging.fromJson(json['paging'] as Map<String, dynamic>)
          : null,
      poll: json['poll'] != null
          ? ForumTopicPoll.fromJson(json['poll'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (posts != null) 'posts': posts!.map((e) => e.toJson()).toList(),
        if (title != null) 'title': title,
        if (paging != null) 'paging': paging!.toJson(),
        if (poll != null) 'poll': poll!.toJson(),
      };
}
