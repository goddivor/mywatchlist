class MalAnime {
  final int id;
  final String title;
  final Picture? mainPicture;
  final AlternativeTitles? alternativeTitles;
  final String? startDate;
  final String? endDate;
  final String? synopsis;
  final double? mean;
  final int? rank;
  final int? popularity;
  final int? numListUsers;
  final int? numScoringUsers;
  final String? nsfw;
  final String? createdAt;
  final String? updatedAt;
  final String? mediaType;
  final String? status;
  final List<Genre>? genres;
  final MyListStatus? myListStatus;
  final int? numEpisodes;
  final Season? startSeason;
  final Broadcast? broadcast;
  final String? source;
  final int? averageEpisodeDuration;
  final String? rating;
  final List<Picture>? pictures;
  final String? background;
  final List<RelatedAnime>? relatedAnime;
  final List<RelatedManga>? relatedManga;
  final List<Recommendation>? recommendations;
  final List<Studio>? studios;
  final Statistics? statistics;
  final List<ThemeSong>? openingSongs;
  final List<ThemeSong>? endingSongs;

  MalAnime({
    required this.id,
    required this.title,
    this.mainPicture,
    this.alternativeTitles,
    this.startDate,
    this.endDate,
    this.synopsis,
    this.mean,
    this.rank,
    this.popularity,
    this.numListUsers,
    this.numScoringUsers,
    this.nsfw,
    this.createdAt,
    this.updatedAt,
    this.mediaType,
    this.status,
    this.genres,
    this.myListStatus,
    this.numEpisodes,
    this.startSeason,
    this.broadcast,
    this.source,
    this.averageEpisodeDuration,
    this.rating,
    this.pictures,
    this.background,
    this.relatedAnime,
    this.relatedManga,
    this.recommendations,
    this.studios,
    this.statistics,
    this.openingSongs,
    this.endingSongs,
  });

  factory MalAnime.fromJson(Map<String, dynamic> json) {
    return MalAnime(
      id: json['id'],
      title: json['title'],
      mainPicture: json['main_picture'] != null
          ? Picture.fromJson(json['main_picture'])
          : null,
      alternativeTitles: json['alternative_titles'] != null
          ? AlternativeTitles.fromJson(json['alternative_titles'])
          : null,
      startDate: json['start_date'],
      endDate: json['end_date'],
      synopsis: json['synopsis'],
      mean: (json['mean'] as num?)?.toDouble(),
      rank: json['rank'],
      popularity: json['popularity'],
      numListUsers: json['num_list_users'],
      numScoringUsers: json['num_scoring_users'],
      nsfw: json['nsfw'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      mediaType: json['media_type'],
      status: json['status'],
      genres: (json['genres'] as List<dynamic>?)
          ?.map((genre) => Genre.fromJson(genre))
          .toList(),
      myListStatus: json['my_list_status'] != null
          ? MyListStatus.fromJson(json['my_list_status'])
          : null,
      numEpisodes: json['num_episodes'],
      startSeason: json['start_season'] != null
          ? Season.fromJson(json['start_season'])
          : null,
      broadcast: json['broadcast'] != null
          ? Broadcast.fromJson(json['broadcast'])
          : null,
      source: json['source'],
      averageEpisodeDuration: json['average_episode_duration'],
      rating: json['rating'],
      pictures: (json['pictures'] as List<dynamic>?)
          ?.map((picture) => Picture.fromJson(picture))
          .toList(),
      background: json['background'],
      relatedAnime: (json['related_anime'] as List<dynamic>?)
          ?.map((anime) => RelatedAnime.fromJson(anime))
          .toList(),
      relatedManga: (json['related_manga'] as List<dynamic>?)
          ?.map((manga) => RelatedManga.fromJson(manga))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>?)
          ?.map((recommendation) => Recommendation.fromJson(recommendation))
          .toList(),
      studios: (json['studios'] as List<dynamic>?)
          ?.map((studio) => Studio.fromJson(studio))
          .toList(),
      statistics: json['statistics'] != null
          ? Statistics.fromJson(json['statistics'])
          : null,
      openingSongs: List.from(json["opening_themes"] ?? [])
          .map((e) => ThemeSong.fromJson(e))
          .toList(),
      endingSongs: List.from(json["ending_themes"] ?? [])
          .map((e) => ThemeSong.fromJson(e))
          .toList(),
    );
  }
}

class Picture {
  final String medium;
  final String large;

  Picture({required this.medium, required this.large});

  factory Picture.fromJson(Map<String, dynamic> json) {
    return Picture(
      medium: json['medium'],
      large: json['large'],
    );
  }
}

class AlternativeTitles {
  final List<String> synonyms;
  final String en;
  final String ja;

  AlternativeTitles({
    required this.synonyms,
    required this.en,
    required this.ja,
  });

  factory AlternativeTitles.fromJson(Map<String, dynamic> json) {
    return AlternativeTitles(
      synonyms: List<String>.from(json['synonyms']),
      en: json['en'],
      ja: json['ja'],
    );
  }
}

class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'],
      name: json['name'],
    );
  }
}

class MyListStatus {
  final String status;
  final int score;
  final int numEpisodesWatched;
  final bool isRewatching;
  final String updatedAt;

  MyListStatus({
    required this.status,
    required this.score,
    required this.numEpisodesWatched,
    required this.isRewatching,
    required this.updatedAt,
  });

  factory MyListStatus.fromJson(Map<String, dynamic> json) {
    return MyListStatus(
      status: json['status'],
      score: json['score'],
      numEpisodesWatched: json['num_episodes_watched'],
      isRewatching: json['is_rewatching'],
      updatedAt: json['updated_at'],
    );
  }
}

class Season {
  final String season;
  final int year;

  Season({required this.season, required this.year});

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      season: json['season'],
      year: json['year'],
    );
  }
}

class Broadcast {
  final String dayOfTheWeek;
  final String startTime;

  Broadcast({required this.dayOfTheWeek, required this.startTime});

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      dayOfTheWeek: json['day_of_the_week'],
      startTime: json['start_time'],
    );
  }
}

class RelatedAnime {
  final Anime animenode;
  final String relationType;
  final String relationTypeFormatted;

  RelatedAnime({
    required this.animenode,
    required this.relationType,
    required this.relationTypeFormatted,
  });

  factory RelatedAnime.fromJson(Map<String, dynamic> json) {
    return RelatedAnime(
      animenode: Anime.fromMAlJson(json['node']),
      relationType: json['relation_type'],
      relationTypeFormatted: json['relation_type_formatted'],
    );
  }
}

class RelatedManga {
  final Anime manganode;
  final String relationType;
  final String relationTypeFormatted;

  RelatedManga({
    required this.manganode,
    required this.relationType,
    required this.relationTypeFormatted,
  });

  factory RelatedManga.fromJson(Map<String, dynamic> json) {
    return RelatedManga(
      manganode: Anime.fromMAlJson(json['node']),
      relationType: json['relation_type'],
      relationTypeFormatted: json['relation_type_formatted'],
    );
  }
}

class Recommendation {
  final Anime animenode;
  final int numRecommendations;

  Recommendation({
    required this.animenode,
    required this.numRecommendations,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      animenode: Anime.fromMAlJson(json['node']),
      numRecommendations: json['num_recommendations'],
    );
  }
}

class Studio {
  final int id;
  final String name;

  Studio({required this.id, required this.name});

  factory Studio.fromJson(Map<String, dynamic> json) {
    return Studio(
      id: json['id'],
      name: json['name'],
    );
  }
}

class Statistics {
  final Status status;
  final int numListUsers;

  Statistics({
    required this.status,
    required this.numListUsers,
  });

  factory Statistics.fromJson(Map<String, dynamic> json) {
    return Statistics(
      status: Status.fromJson(json['status']),
      numListUsers: json['num_list_users'],
    );
  }
}

class Status {
  final dynamic watching;
  final dynamic completed;
  final dynamic onHold;
  final dynamic dropped;
  final dynamic planToWatch;

  const Status({
    required this.watching,
    required this.completed,
    required this.onHold,
    required this.dropped,
    required this.planToWatch,
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      watching: json['watching'],
      completed: json['completed'],
      onHold: json['on_hold'],
      dropped: json['dropped'],
      planToWatch: json['plan_to_watch'],
    );
  }
}

class ThemeSong {
  final int? id;
  final int? animeId;
  final String? name;

  ThemeSong({this.id, this.animeId, this.name});

  factory ThemeSong.fromJson(Map<String, dynamic>? json) {
    return json != null
        ? ThemeSong(
            id: json["id"], name: json["text"], animeId: json["anime_id"])
        : ThemeSong();
  }

  Map<String, dynamic> toJson() {
    return {"text": name, "id": id, "anime_id": animeId};
  }
}


//cette classe est utiliser uniquement pour afficher un card simple de donner pouvant a la fois provenir de MAL et Jikan
class Anime {
  final int id;
  final String title;
  final String imageUrl;
  final double score;
  final int members;
  final int? rank;
  final int? popularity;
  final String? synopsis;
  final int? numEpisodes;
  final String? startDate;
  final String? endDate;
  final String? mediaType;
  final String? status;
  final MyListStatus? myListStatus;

  Anime({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.score,
    required this.members,
    this.rank,
    this.popularity,
    this.synopsis,
    this.numEpisodes,
    this.startDate,
    this.endDate,
    this.mediaType,
    this.status,
    this.myListStatus,
  });

  // Formateur Jikan
  factory Anime.fromJikanJson(Map<String, dynamic> json) {
    return Anime(
      id: json['mal_id'] as int,
      title: json['title'] as String,
      imageUrl: json['images']['jpg']['large_image_url'] as String,
      score: (json['score'] ?? 0.0).toDouble(),
      members: (json['members'] ?? 0).toInt(),
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      synopsis: json['synopsis'] as String?,
      numEpisodes: json['episodes'] as int?,
      startDate: json['aired']['from'] as String?,
      endDate: json['aired']['to'] as String?,
      mediaType: json['type'] as String?, // Jikan utilise 'type' pour mediaType
      status: json['status'] as String?,
    );
  }

  // Formateur MAL
  factory Anime.fromMAlJson(Map<String, dynamic> json) {
    return Anime(
      id: json['id'] as int,
      title: json['title'] as String,
      imageUrl: json['main_picture']['large'] as String,
      score: (json['mean'] ?? 0.0).toDouble(),
      members: (json['num_list_users'] ?? 0).toInt(),
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      synopsis: json['synopsis'] as String?,
      numEpisodes: json['num_episodes'] as int?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      mediaType: json['media_type'] as String?,
      status: json['status'] as String?,
      myListStatus: json['my_list_status'] != null
          ? MyListStatus.fromJson(json['my_list_status'])
          : null,
    );
  }
}