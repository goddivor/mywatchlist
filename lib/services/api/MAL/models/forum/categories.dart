import 'forum.dart';

class Categories {
  final List<Forum>? forums;

  Categories({this.forums});

  factory Categories.fromJson(Map<String, dynamic> json) {
    return Categories(
      forums: (json['categories'] as List<dynamic>?)
          ?.map((e) => Forum.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (forums != null)
          'categories': forums!.map((e) => e.toJson()).toList(),
      };
}
