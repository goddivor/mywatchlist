class ForumTopicOptions {
  final int? id;
  final String? text;
  final int? votes;

  ForumTopicOptions({this.id, this.text, this.votes});

  factory ForumTopicOptions.fromJson(Map<String, dynamic> json) {
    return ForumTopicOptions(
      id: json['id'] as int?,
      text: json['text'] as String?,
      votes: json['votes'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (text != null) 'text': text,
        if (votes != null) 'votes': votes,
      };
}

class ForumTopicPoll {
  final int? id;
  final String? question;
  final bool? close;
  final List<ForumTopicOptions>? options;

  ForumTopicPoll({this.id, this.question, this.close, this.options});

  factory ForumTopicPoll.fromJson(Map<String, dynamic> json) {
    return ForumTopicPoll(
      id: json['id'] as int?,
      question: json['question'] as String?,
      close: json['close'] as bool?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => ForumTopicOptions.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (question != null) 'question': question,
        if (close != null) 'close': close,
        if (options != null)
          'options': options!.map((e) => e.toJson()).toList(),
      };
}
