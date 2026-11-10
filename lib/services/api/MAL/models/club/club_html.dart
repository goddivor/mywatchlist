/// Represents a club parsed from MAL's HTML page.
class ClubHtml {
  final int? id;
  final String? name;
  final String? imgUrl;
  final String? desc;
  final String? members;
  final String? lastPostBy;
  final String? lastPostTime;

  ClubHtml({
    this.id,
    this.name,
    this.imgUrl,
    this.desc,
    this.members,
    this.lastPostBy,
    this.lastPostTime,
  });

  factory ClubHtml.fromJson(Map<String, dynamic> json) {
    return ClubHtml(
      id: json['id'] as int?,
      name: json['name'] as String?,
      imgUrl: json['imgUrl'] as String?,
      desc: json['desc'] as String?,
      members: json['members'] as String?,
      lastPostBy: json['lastPostBy'] as String?,
      lastPostTime: json['lastPostTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (name != null) 'name': name,
        if (imgUrl != null) 'imgUrl': imgUrl,
        if (desc != null) 'desc': desc,
        if (members != null) 'members': members,
        if (lastPostBy != null) 'lastPostBy': lastPostBy,
        if (lastPostTime != null) 'lastPostTime': lastPostTime,
      };
}

/// Wraps a list of clubs parsed from HTML.
class ClubListHtml {
  final List<ClubHtml>? clubs;

  ClubListHtml({this.clubs});

  factory ClubListHtml.fromJson(Map<String, dynamic> json) {
    final clubsList = json['clubs'] as List<dynamic>?;
    return ClubListHtml(
      clubs: clubsList
          ?.map((e) => ClubHtml.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (clubs != null) 'clubs': clubs!.map((c) => c.toJson()).toList(),
      };
}
