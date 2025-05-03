class JikanAnime {
  final int? malId;
  final String? url;
  final Images? images;
  final Trailer? trailer;
  final bool? approved;
  final List<Title>? titles;
  final String? title;
  final String? titleEnglish;
  final String? titleJapanese;
  final List<String>? titleSynonyms;
  final String? type;
  final String? source;
  final int? episodes;
  final String? status;
  final bool? airing;
  final Aired? aired;
  final String? duration;
  final String? rating;
  final double? score;
  final int? scoredBy;
  final int? rank;
  final int? popularity;
  final int? members;
  final int? favorites;
  final String? synopsis;
  final String? background;
  final String? season;
  final int? year;
  final Broadcast? broadcast;
  final List<Producer>? producers;
  final List<Producer>? licensors;
  final List<Producer>? studios;
  final List<Genre>? genres;
  final List<Genre>? explicitGenres;
  final List<Genre>? themes;
  final List<Genre>? demographics;
  final List<Relation>? relations;
  final Theme? theme;
  final List<External>? external;
  final List<Streaming>? streaming;

  JikanAnime({
    this.malId,
    this.url,
    this.images,
    this.trailer,
    this.approved,
    this.titles,
    this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.titleSynonyms,
    this.type,
    this.source,
    this.episodes,
    this.status,
    this.airing,
    this.aired,
    this.duration,
    this.rating,
    this.score,
    this.scoredBy,
    this.rank,
    this.popularity,
    this.members,
    this.favorites,
    this.synopsis,
    this.background,
    this.season,
    this.year,
    this.broadcast,
    this.producers,
    this.licensors,
    this.studios,
    this.genres,
    this.explicitGenres,
    this.themes,
    this.demographics,
    this.relations,
    this.theme,
    this.external,
    this.streaming,
  });

  factory JikanAnime.fromJson(Map<String, dynamic> json) {
    return JikanAnime(
      malId: json['mal_id'],
      url: json['url'],
      images: json['images'] != null ? Images.fromJson(json['images']) : null,
      trailer: json['trailer'] != null ? Trailer.fromJson(json['trailer']) : null,
      approved: json['approved'],
      titles: json['titles'] != null ? (json['titles'] as List).map((e) => Title.fromJson(e)).toList() : null,
      title: json['title'],
      titleEnglish: json['title_english'],
      titleJapanese: json['title_japanese'],
      titleSynonyms: json['title_synonyms'] != null ? List<String>.from(json['title_synonyms']) : null,
      type: json['type'],
      source: json['source'],
      episodes: json['episodes'],
      status: json['status'],
      airing: json['airing'],
      aired: json['aired'] != null ? Aired.fromJson(json['aired']) : null,
      duration: json['duration'],
      rating: json['rating'],
      score: json['score']?.toDouble(),
      scoredBy: json['scored_by'],
      rank: json['rank'],
      popularity: json['popularity'],
      members: json['members'],
      favorites: json['favorites'],
      synopsis: json['synopsis'],
      background: json['background'],
      season: json['season'],
      year: json['year'],
      broadcast: json['broadcast'] != null ? Broadcast.fromJson(json['broadcast']) : null,
      producers: json['producers'] != null ? (json['producers'] as List).map((e) => Producer.fromJson(e)).toList() : null,
      licensors: json['licensors'] != null ? (json['licensors'] as List).map((e) => Producer.fromJson(e)).toList() : null,
      studios: json['studios'] != null ? (json['studios'] as List).map((e) => Producer.fromJson(e)).toList() : null,
      genres: json['genres'] != null ? (json['genres'] as List).map((e) => Genre.fromJson(e)).toList() : null,
      explicitGenres: json['explicit_genres'] != null ? (json['explicit_genres'] as List).map((e) => Genre.fromJson(e)).toList() : null,
      themes: json['themes'] != null ? (json['themes'] as List).map((e) => Genre.fromJson(e)).toList() : null,
      demographics: json['demographics'] != null ? (json['demographics'] as List).map((e) => Genre.fromJson(e)).toList() : null,
      relations: json['relations'] != null ? (json['relations'] as List).map((e) => Relation.fromJson(e)).toList() : null,
      theme: json['theme'] != null ? Theme.fromJson(json['theme']) : null,
      external: json['external'] != null ? (json['external'] as List).map((e) => External.fromJson(e)).toList() : null,
      streaming: json['streaming'] != null ? (json['streaming'] as List).map((e) => Streaming.fromJson(e)).toList() : null,
    );
  }
}

// Subclasses updated similarly with nullable fields
class Images {
  final ImageFormat? jpg;
  final ImageFormat? webp;

  Images({this.jpg, this.webp});

  factory Images.fromJson(Map<String, dynamic> json) {
    return Images(
      jpg: json['jpg'] != null ? ImageFormat.fromJson(json['jpg']) : null,
      webp: json['webp'] != null ? ImageFormat.fromJson(json['webp']) : null,
    );
  }
}

class ImageFormat {
  final String? imageUrl;
  final String? smallImageUrl;
  final String? largeImageUrl;

  ImageFormat({this.imageUrl, this.smallImageUrl, this.largeImageUrl});

  factory ImageFormat.fromJson(Map<String, dynamic> json) {
    return ImageFormat(
      imageUrl: json['image_url'],
      smallImageUrl: json['small_image_url'],
      largeImageUrl: json['large_image_url'],
    );
  }
}

class Trailer {
  final String? youtubeId;
  final String? url;
  final String? embedUrl;

  Trailer({this.youtubeId, this.url, this.embedUrl});

  factory Trailer.fromJson(Map<String, dynamic> json) {
    return Trailer(
      youtubeId: json['youtube_id'],
      url: json['url'],
      embedUrl: json['embed_url'],
    );
  }
}

class Title {
  final String? type;
  final String? title;

  Title({this.type, this.title});

  factory Title.fromJson(Map<String, dynamic> json) {
    return Title(
      type: json['type'],
      title: json['title'],
    );
  }
}

class Aired {
  final String? from;
  final String? to;
  final Prop? prop;

  Aired({this.from, this.to, this.prop});

  factory Aired.fromJson(Map<String, dynamic> json) {
    return Aired(
      from: json['from'],
      to: json['to'],
      prop: json['prop'] != null ? Prop.fromJson(json['prop']) : null,
    );
  }
}

class Prop {
  final Date? from;
  final Date? to;

  Prop({this.from, this.to});

  factory Prop.fromJson(Map<String, dynamic> json) {
    return Prop(
      from: json['from'] != null ? Date.fromJson(json['from']) : null,
      to: json['to'] != null ? Date.fromJson(json['to']) : null,
    );
  }
}

class Date {
  final int? day;
  final int? month;
  final int? year;

  Date({this.day, this.month, this.year});

  factory Date.fromJson(Map<String, dynamic> json) {
    return Date(
      day: json['day'],
      month: json['month'],
      year: json['year'],
    );
  }
}

class Broadcast {
  final String? day;
  final String? time;
  final String? timezone;
  final String? string;

  Broadcast({this.day, this.time, this.timezone, this.string});

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      day: json['day'],
      time: json['time'],
      timezone: json['timezone'],
      string: json['string'],
    );
  }
}

class Producer {
  final int? malId;
  final String? type;
  final String? name;
  final String? url;

  Producer({this.malId, this.type, this.name, this.url});

  factory Producer.fromJson(Map<String, dynamic> json) {
    return Producer(
      malId: json['mal_id'],
      type: json['type'],
      name: json['name'],
      url: json['url'],
    );
  }
}

class Genre {
  final int? malId;
  final String? type;
  final String? name;
  final String? url;

  Genre({this.malId, this.type, this.name, this.url});

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      malId: json['mal_id'],
      type: json['type'],
      name: json['name'],
      url: json['url'],
    );
  }
}

class Relation {
  final String? relation;
  final List<Entry>? entry;

  Relation({this.relation, this.entry});

  factory Relation.fromJson(Map<String, dynamic> json) {
    return Relation(
      relation: json['relation'],
      entry: json['entry'] != null ? (json['entry'] as List).map((e) => Entry.fromJson(e)).toList() : null,
    );
  }
}

class Entry {
  final int? malId;
  final String? type;
  final String? name;
  final String? url;

  Entry({this.malId, this.type, this.name, this.url});

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      malId: json['mal_id'],
      type: json['type'],
      name: json['name'],
      url: json['url'],
    );
  }
}

class Theme {
  final List<String>? openings;
  final List<String>? endings;

  Theme({this.openings, this.endings});

  factory Theme.fromJson(Map<String, dynamic> json) {
    return Theme(
      openings: json['openings'] != null ? List<String>.from(json['openings']) : null,
      endings: json['endings'] != null ? List<String>.from(json['endings']) : null,
    );
  }
}

class External {
  final String? name;
  final String? url;

  External({this.name, this.url});

  factory External.fromJson(Map<String, dynamic> json) {
    return External(
      name: json['name'],
      url: json['url'],
    );
  }
}

class Streaming {
  final String? name;
  final String? url;

  Streaming({this.name, this.url});

  factory Streaming.fromJson(Map<String, dynamic> json) {
    return Streaming(
      name: json['name'],
      url: json['url'],
    );
  }
}
