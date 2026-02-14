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
  // Manga-specific fields
  final int? numVolumes;
  final int? numChapters;
  final List<MalAuthor>? authors;
  final List<MalSerialization>? serialization;

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
    this.numVolumes,
    this.numChapters,
    this.authors,
    this.serialization,
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
      numVolumes: json['num_volumes'],
      numChapters: json['num_chapters'],
      authors: (json['authors'] as List<dynamic>?)
          ?.map((a) => MalAuthor.fromJson(a))
          .toList(),
      serialization: (json['serialization'] as List<dynamic>?)
          ?.map((s) => MalSerialization.fromJson(s))
          .toList(),
    );
  }

  /// Factory from Jikan full anime data (used as fallback for getAnimeDetails)
  factory MalAnime.fromJikanFullById(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>?;
    final jpgImages = images?['jpg'] as Map<String, dynamic>?;

    return MalAnime(
      id: json['mal_id'] as int,
      title: json['title'] as String? ?? '',
      mainPicture: Picture(
        medium: jpgImages?['image_url'] as String?,
        large: jpgImages?['large_image_url'] as String?,
      ),
      alternativeTitles: AlternativeTitles(
        en: json['title_english'] as String?,
        ja: json['title_japanese'] as String?,
        synonyms: (json['title_synonyms'] as List<dynamic>?)?.cast<String>(),
      ),
      startDate: json['aired']?['from'] as String?,
      endDate: json['aired']?['to'] as String?,
      synopsis: json['synopsis'] as String?,
      mean: (json['score'] as num?)?.toDouble(),
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      numListUsers: json['members'] as int?,
      numScoringUsers: json['scored_by'] as int?,
      mediaType: json['type'] as String?,
      status: json['status'] as String?,
      genres: [
        ..._jikanGenres(json['genres']),
        ..._jikanGenres(json['themes']),
        ..._jikanGenres(json['explicit_genres']),
        ..._jikanGenres(json['demographics']),
      ],
      numEpisodes: json['episodes'] as int?,
      startSeason: json['season'] != null
          ? Season(season: json['season'], year: json['year'] ?? 0)
          : null,
      broadcast: json['broadcast'] != null
          ? Broadcast(
              dayOfTheWeek:
                  (json['broadcast']['day'] as String?)?.toLowerCase() ?? '',
              startTime: json['broadcast']['time'] as String? ?? '',
            )
          : null,
      source: json['source'] as String?,
      averageEpisodeDuration: _parseDuration(json['duration'] as String?),
      rating: json['rating'] as String?,
      studios: (json['studios'] as List<dynamic>?)
          ?.map((s) => Studio(
                id: s['mal_id'] as int? ?? 0,
                name: s['name'] as String? ?? '',
              ))
          .toList(),
    );
  }

  static List<Genre> _jikanGenres(List<dynamic>? list) {
    if (list == null) return [];
    return list
        .map((g) => Genre(
              id: g['mal_id'] as int? ?? 0,
              name: g['name'] as String? ?? '',
            ))
        .toList();
  }

  static int? _parseDuration(String? duration) {
    if (duration == null) return null;
    final digits = duration.replaceAll(RegExp(r'\D'), '');
    return int.tryParse(digits);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (mainPicture != null) 'main_picture': mainPicture!.toJson(),
      if (alternativeTitles != null)
        'alternative_titles': alternativeTitles!.toJson(),
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (synopsis != null) 'synopsis': synopsis,
      if (mean != null) 'mean': mean,
      if (rank != null) 'rank': rank,
      if (popularity != null) 'popularity': popularity,
      if (numListUsers != null) 'num_list_users': numListUsers,
      if (numScoringUsers != null) 'num_scoring_users': numScoringUsers,
      if (nsfw != null) 'nsfw': nsfw,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (mediaType != null) 'media_type': mediaType,
      if (status != null) 'status': status,
      if (genres != null) 'genres': genres!.map((g) => g.toJson()).toList(),
      if (myListStatus != null) 'my_list_status': myListStatus!.toJson(),
      if (numEpisodes != null) 'num_episodes': numEpisodes,
      if (startSeason != null) 'start_season': startSeason!.toJson(),
      if (broadcast != null) 'broadcast': broadcast!.toJson(),
      if (source != null) 'source': source,
      if (averageEpisodeDuration != null)
        'average_episode_duration': averageEpisodeDuration,
      if (rating != null) 'rating': rating,
      if (pictures != null)
        'pictures': pictures!.map((p) => p.toJson()).toList(),
      if (background != null) 'background': background,
      if (relatedAnime != null)
        'related_anime': relatedAnime!.map((r) => r.toJson()).toList(),
      if (relatedManga != null)
        'related_manga': relatedManga!.map((r) => r.toJson()).toList(),
      if (recommendations != null)
        'recommendations': recommendations!.map((r) => r.toJson()).toList(),
      if (studios != null)
        'studios': studios!.map((s) => s.toJson()).toList(),
      if (statistics != null) 'statistics': statistics!.toJson(),
      if (openingSongs != null)
        'opening_themes': openingSongs!.map((t) => t.toJson()).toList(),
      if (endingSongs != null)
        'ending_themes': endingSongs!.map((t) => t.toJson()).toList(),
      if (numVolumes != null) 'num_volumes': numVolumes,
      if (numChapters != null) 'num_chapters': numChapters,
      if (authors != null)
        'authors': authors!.map((a) => a.toJson()).toList(),
      if (serialization != null)
        'serialization': serialization!.map((s) => s.toJson()).toList(),
    };
  }
}

class Picture {
  final String? medium;
  final String? large;

  Picture({this.medium, this.large});

  factory Picture.fromJson(Map<String, dynamic> json) {
    return Picture(
      medium: json['medium'] as String?,
      large: json['large'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (medium != null) 'medium': medium,
      if (large != null) 'large': large,
    };
  }
}

class AlternativeTitles {
  final List<String>? synonyms;
  final String? en;
  final String? ja;

  AlternativeTitles({this.synonyms, this.en, this.ja});

  factory AlternativeTitles.fromJson(Map<String, dynamic> json) {
    return AlternativeTitles(
      synonyms: (json['synonyms'] as List<dynamic>?)?.cast<String>(),
      en: json['en'] as String?,
      ja: json['ja'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (synonyms != null) 'synonyms': synonyms,
      if (en != null) 'en': en,
      if (ja != null) 'ja': ja,
    };
  }
}

class Genre {
  final int id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
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
      status: json['status'] ?? '',
      score: json['score'] ?? 0,
      numEpisodesWatched: json['num_episodes_watched'] ?? 0,
      isRewatching: json['is_rewatching'] ?? false,
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'score': score,
      'num_episodes_watched': numEpisodesWatched,
      'is_rewatching': isRewatching,
      'updated_at': updatedAt,
    };
  }
}

class Season {
  final String season;
  final int year;

  Season({required this.season, required this.year});

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      season: json['season'] ?? '',
      year: json['year'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'season': season, 'year': year};
  }
}

class Broadcast {
  final String dayOfTheWeek;
  final String startTime;

  Broadcast({required this.dayOfTheWeek, required this.startTime});

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      dayOfTheWeek: json['day_of_the_week'] ?? '',
      startTime: json['start_time'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_the_week': dayOfTheWeek,
      'start_time': startTime,
    };
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
      relationType: json['relation_type'] ?? '',
      relationTypeFormatted: json['relation_type_formatted'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node': animenode.toJson(),
      'relation_type': relationType,
      'relation_type_formatted': relationTypeFormatted,
    };
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
      relationType: json['relation_type'] ?? '',
      relationTypeFormatted: json['relation_type_formatted'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node': manganode.toJson(),
      'relation_type': relationType,
      'relation_type_formatted': relationTypeFormatted,
    };
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
      numRecommendations: json['num_recommendations'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node': animenode.toJson(),
      'num_recommendations': numRecommendations,
    };
  }
}

class Studio {
  final int id;
  final String name;

  Studio({required this.id, required this.name});

  factory Studio.fromJson(Map<String, dynamic> json) {
    return Studio(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
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
      numListUsers: json['num_list_users'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toJson(),
      'num_list_users': numListUsers,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'watching': watching,
      'completed': completed,
      'on_hold': onHold,
      'dropped': dropped,
      'plan_to_watch': planToWatch,
    };
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

class MalAuthorNode {
  final int id;
  final String firstName;
  final String lastName;

  MalAuthorNode({required this.id, required this.firstName, required this.lastName});

  factory MalAuthorNode.fromJson(Map<String, dynamic> json) {
    return MalAuthorNode(
      id: json['id'] as int? ?? 0,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
  };
}

class MalAuthor {
  final MalAuthorNode author;
  final String role;

  MalAuthor({required this.author, required this.role});

  factory MalAuthor.fromJson(Map<String, dynamic> json) {
    return MalAuthor(
      author: MalAuthorNode.fromJson(json['node'] as Map<String, dynamic>? ?? {}),
      role: json['role'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'node': author.toJson(),
    'role': role,
  };
}

class MalSerialization {
  final int id;
  final String name;

  MalSerialization({required this.id, required this.name});

  factory MalSerialization.fromJson(Map<String, dynamic> json) {
    final node = json['node'] as Map<String, dynamic>? ?? {};
    return MalSerialization(
      id: node['id'] as int? ?? 0,
      name: node['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'node': {'id': id, 'name': name},
  };
}

// This class is used to display a simple data card that can come from both MAL and Jikan
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
  final int? numVolumes;
  final String? startDate;
  final String? endDate;
  final String? mediaType;
  final String? status;
  final MyListStatus? myListStatus;
  final Broadcast? broadcast;
  final List<String>? genres;

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
    this.numVolumes,
    this.startDate,
    this.endDate,
    this.mediaType,
    this.status,
    this.myListStatus,
    this.broadcast,
    this.genres,
  });

  // Factory from Jikan API response
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
      mediaType: json['type'] as String?, // Jikan uses 'type' for mediaType
      status: json['status'] as String?,
      broadcast: json['broadcast'] != null &&
              json['broadcast']['day'] != null
          ? Broadcast(
              dayOfTheWeek:
                  (json['broadcast']['day'] as String).toLowerCase(),
              startTime: json['broadcast']['time'] as String? ?? '',
            )
          : null,
      genres: [
        ...(json['genres'] as List<dynamic>? ?? [])
            .map((g) => g['name'] as String),
        ...(json['themes'] as List<dynamic>? ?? [])
            .map((g) => g['name'] as String),
      ],
    );
  }

  // Factory from MAL API response
  factory Anime.fromMAlJson(Map<String, dynamic> json) {
    final mainPicture = json['main_picture'] as Map<String, dynamic>?;
    return Anime(
      id: json['id'] as int,
      title: json['title'] as String,
      imageUrl: mainPicture?['large'] as String? ??
          mainPicture?['medium'] as String? ??
          '',
      score: (json['mean'] ?? 0.0).toDouble(),
      members: (json['num_list_users'] ?? 0).toInt(),
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      synopsis: json['synopsis'] as String?,
      numEpisodes: json['num_episodes'] as int?,
      numVolumes: json['num_volumes'] as int?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
      mediaType: json['media_type'] as String?,
      status: json['status'] as String?,
      myListStatus: json['my_list_status'] != null
          ? MyListStatus.fromJson(json['my_list_status'])
          : null,
      broadcast: json['broadcast'] != null
          ? Broadcast.fromJson(json['broadcast'])
          : null,
      genres: (json['genres'] as List<dynamic>?)
          ?.map((g) => g['name'] as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'main_picture': {'large': imageUrl, 'medium': imageUrl},
      'mean': score,
      'num_list_users': members,
      'rank': rank,
      'popularity': popularity,
      'synopsis': synopsis,
      'num_episodes': numEpisodes,
      if (numVolumes != null) 'num_volumes': numVolumes,
      'start_date': startDate,
      'end_date': endDate,
      'media_type': mediaType,
      'status': status,
      'my_list_status': myListStatus?.toJson(),
      if (broadcast != null) 'broadcast': broadcast!.toJson(),
      if (genres != null)
        'genres': genres!.map((g) => {'name': g}).toList(),
    };
  }
}
