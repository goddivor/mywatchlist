class UserHistoryList {
  final List<UserHistory> histories;

  UserHistoryList({required this.histories});

  // Méthode pour convertir un JSON en UserHistoryList
  factory UserHistoryList.fromJson(List<dynamic> json) {
    var histories = json.map((item) => UserHistory.fromJson(item as Map<String, dynamic>)).toList();
    return UserHistoryList(histories: histories);
  }

 // Méthode pour convertir UserHistoryList en JSON
  Map<String, dynamic> toJson() {
    return {
      'histories': histories.map((history) => history.toJson()).toList(),
    };
  }
}


class UserHistory {
  final int id;
  final String title;
  final String history;
  final String? category;
  final String time;

  UserHistory({
    required this.id,
    required this.title,
    required this.history,
    required this.category,
    required this.time,
  });

  factory UserHistory.fromJson(Map<String, dynamic> json) {
    return UserHistory(
      id: json['id'] as int,
      title: json['title'] as String,
      history: json['history'] as String,
      category: json['category'] as String?,
      time: json['time'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'history': history,
      'category': category,
      'time': time,
    };
  }
}
