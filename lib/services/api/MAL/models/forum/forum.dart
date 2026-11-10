import 'board.dart';

class Forum {
  final String? title;
  final List<Board>? boards;

  Forum({this.title, this.boards});

  factory Forum.fromJson(Map<String, dynamic> json) {
    return Forum(
      title: json['title'] as String?,
      boards: (json['boards'] as List<dynamic>?)
          ?.map((e) => Board.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (boards != null)
          'boards': boards!.map((e) => e.toJson()).toList(),
      };
}
