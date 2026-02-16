class SubBoard {
  final int? id;
  final String? title;

  SubBoard({this.id, this.title});

  factory SubBoard.fromJson(Map<String, dynamic> json) {
    return SubBoard(
      id: json['id'] as int?,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (title != null) 'title': title,
      };
}
