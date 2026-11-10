import '../paging.dart';
import 'forum_topics_data.dart';

class ForumTopics {
  final List<ForumTopicsData>? data;
  final Paging? paging;

  ForumTopics({this.data, this.paging});

  factory ForumTopics.fromJson(Map<String, dynamic> json) {
    return ForumTopics(
      data: (json['data'] as List<dynamic>?)
          ?.map((e) => ForumTopicsData.fromJson(e as Map<String, dynamic>))
          .toList(),
      paging: json['paging'] != null
          ? Paging.fromJson(json['paging'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (data != null) 'data': data!.map((e) => e.toJson()).toList(),
        if (paging != null) 'paging': paging!.toJson(),
      };
}
