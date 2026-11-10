import 'sub_board.dart';

class Board {
  final int? id;
  final String? title;
  final String? description;
  final List<SubBoard>? subBoards;

  Board({this.id, this.title, this.description, this.subBoards});

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as int?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      subBoards: (json['subboards'] as List<dynamic>?)
          ?.map((e) => SubBoard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (subBoards != null)
          'subboards': subBoards!.map((e) => e.toJson()).toList(),
      };
}
