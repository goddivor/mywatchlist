import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart' show SyncDates;

int _int(Object? v) => v is num ? v.toInt() : 0;
int? _intOrNull(Object? v) => v is num ? v.toInt() : null;
String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
List<Map<String, dynamic>> _maps(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map<String, dynamic>) e,
    ];
List<Map<String, dynamic>> _edges(Object? connection) =>
    connection is Map ? _maps(connection['edges']) : const [];
List<Map<String, dynamic>> _nodes(Object? connection) =>
    connection is Map ? _maps(connection['nodes']) : const [];
DateTime? _time(Object? v) =>
    v is num && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000, isUtc: true) : null;

/// A small title of AniList (relations, recommendations, the recommend picker).
@immutable
class AnilistTitleRef {
  final int id;

  /// `anime` or `manga`.
  final String category;
  final String title;
  final String? coverUrl;
  final String? format;
  final String? status;
  final int? year;

  /// 0-100 (`weightedScore`), null when unknown.
  final int? score;

  /// The signed-in user's list status (`CURRENT`…), null when not on the list.
  final String? listStatus;

  const AnilistTitleRef({
    required this.id,
    required this.category,
    required this.title,
    this.coverUrl,
    this.format,
    this.status,
    this.year,
    this.score,
    this.listStatus,
  });

  static const String fields = 'id type format status(version: 2) seasonYear '
      'title { userPreferred } coverImage { large } weightedScore mediaListEntry { status }';

  static AnilistTitleRef? fromJson(Object? json) {
    if (json is! Map || json['id'] is! num) return null;
    final title = json['title'];
    final cover = json['coverImage'];
    final entry = json['mediaListEntry'];
    final score = _int(json['weightedScore']);
    return AnilistTitleRef(
      id: _int(json['id']),
      category: json['type'] == 'MANGA' ? 'manga' : 'anime',
      title: title is Map ? _text(title['userPreferred']) ?? '' : '',
      coverUrl: cover is Map ? _text(cover['large']) : null,
      format: _text(json['format']),
      status: _text(json['status']),
      year: _intOrNull(json['seasonYear']),
      score: score > 0 ? score : null,
      listStatus: entry is Map ? _text(entry['status']) : null,
    );
  }
}

/// A person of a title's characters or staff rows (character, voice actor, staff member).
@immutable
class AnilistMediaPerson {
  final int id;
  final String name;
  final String? imageUrl;

  /// `languageV2` of a voice actor.
  final String? language;

  const AnilistMediaPerson({required this.id, required this.name, this.imageUrl, this.language});

  static const String fields = 'id name { userPreferred } image { medium }';

  static AnilistMediaPerson? fromJson(Object? json) {
    if (json is! Map || json['id'] is! num) return null;
    final name = json['name'];
    final image = json['image'];
    return AnilistMediaPerson(
      id: _int(json['id']),
      name: name is Map ? _text(name['userPreferred']) ?? '' : '',
      imageUrl: image is Map ? _text(image['medium']) : null,
      language: _text(json['languageV2']),
    );
  }
}

/// A character of a title: role (`MAIN`, `SUPPORTING`, `BACKGROUND`) and voice actors in the
/// language asked.
@immutable
class AnilistCastEdge {
  final AnilistMediaPerson character;
  final String? role;
  final List<AnilistMediaPerson> voiceActors;

  const AnilistCastEdge({required this.character, this.role, this.voiceActors = const []});

  static AnilistCastEdge? fromJson(Map<String, dynamic> json) {
    final character = AnilistMediaPerson.fromJson(json['node']);
    if (character == null) return null;
    return AnilistCastEdge(
      character: character,
      role: _text(json['role']),
      voiceActors: [
        for (final v in _maps(json['voiceActors']))
          if (AnilistMediaPerson.fromJson(v) case final p?) p,
      ],
    );
  }
}

/// A staff member of a title and their role ("Director", "Original Creator").
@immutable
class AnilistStaffEdge {
  final AnilistMediaPerson person;
  final String? role;
  const AnilistStaffEdge({required this.person, this.role});

  static AnilistStaffEdge? fromJson(Map<String, dynamic> json) {
    final person = AnilistMediaPerson.fromJson(json['node']);
    return person == null ? null : AnilistStaffEdge(person: person, role: _text(json['role']));
  }
}

/// A ranking of a title (`#1 Highest rated all time`, `#3 Most popular 2023`).
@immutable
class AnilistRanking {
  final int rank;

  /// `RATED` or `POPULAR`.
  final String type;
  final String? format;
  final int? year;
  final String? season;
  final bool allTime;

  const AnilistRanking({
    required this.rank,
    required this.type,
    this.format,
    this.year,
    this.season,
    this.allTime = false,
  });

  bool get rated => type == 'RATED';

  /// All time first, then by year, then by season: the order the header picks from.
  int get scope => allTime ? 0 : (season == null ? 1 : 2);
}

/// A tag of a title: rank % (how much it applies), category and spoiler flags.
@immutable
class AnilistMediaTag {
  final int id;
  final String name;
  final String? description;
  final String? category;
  final int rank;
  final bool spoiler;
  final bool adult;

  const AnilistMediaTag({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.rank = 0,
    this.spoiler = false,
    this.adult = false,
  });
}

/// A link of a title (`externalLinks`): streaming site, official page, social account.
@immutable
class AnilistExternalLink {
  final String site;
  final String url;

  /// `INFO`, `STREAMING` or `SOCIAL`.
  final String? type;
  final String? language;

  /// The site's brand colour (`#F88B24`) and icon (a picture URL).
  final String? color;
  final String? icon;
  final String? notes;

  const AnilistExternalLink({
    required this.site,
    required this.url,
    this.type,
    this.language,
    this.color,
    this.icon,
    this.notes,
  });

  bool get streaming => type == 'STREAMING';
}

/// An official episode of a streaming site (`streamingEpisodes`).
@immutable
class AnilistStreamingEpisode {
  final String title;
  final String? thumbnail;
  final String url;
  final String? site;
  const AnilistStreamingEpisode({required this.title, required this.url, this.thumbnail, this.site});

  /// The episode number written in the title ("Episode 7 - …"), null when there is none.
  int? get number {
    final m = RegExp(r'(?:Episode|Ep\.?|#)\s*(\d+)', caseSensitive: false).firstMatch(title);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}

/// A studio of a title; [main] = the animation studio, else a producer.
@immutable
class AnilistMediaStudio {
  final int id;
  final String name;
  final bool main;
  const AnilistMediaStudio({required this.id, required this.name, this.main = false});
}

/// A related title and how it relates (`relationType(version: 2)`: `SEQUEL`, `PREQUEL`…).
@immutable
class AnilistRelation {
  final String type;
  final AnilistTitleRef media;
  const AnilistRelation({required this.type, required this.media});

  /// Prequels and sequels first (AniHyou, Dartotsu), then the source, then the rest.
  int get order => switch (type) {
        'PREQUEL' => 0,
        'SEQUEL' => 1,
        'PARENT' => 2,
        'SOURCE' => 3,
        'ADAPTATION' => 4,
        'SIDE_STORY' => 5,
        _ => 10,
      };
}

/// A recommendation of a title: its community rating and the signed-in user's vote.
@immutable
class AnilistRecommendation {
  final int id;
  final int rating;
  final AnilistRecommendationVote userRating;
  final AnilistTitleRef media;

  const AnilistRecommendation({
    required this.id,
    required this.rating,
    required this.media,
    this.userRating = AnilistRecommendationVote.none,
  });

  static const String fields =
      'id rating userRating mediaRecommendation { ${AnilistTitleRef.fields} }';

  static AnilistRecommendation? fromJson(Map<String, dynamic> json) {
    final media = AnilistTitleRef.fromJson(json['mediaRecommendation']);
    if (media == null) return null;
    return AnilistRecommendation(
      id: _int(json['id']),
      rating: _int(json['rating']),
      media: media,
      userRating: voteOf(json['userRating']),
    );
  }

  static AnilistRecommendationVote voteOf(Object? value) =>
      AnilistRecommendationVote.values.where((v) => v.value == value).firstOrNull ??
      AnilistRecommendationVote.none;

  /// This recommendation once the user voted [vote]: the rating moves by the difference.
  AnilistRecommendation voted(AnilistRecommendationVote vote) {
    int weight(AnilistRecommendationVote v) => switch (v) {
          AnilistRecommendationVote.up => 1,
          AnilistRecommendationVote.down => -1,
          AnilistRecommendationVote.none => 0,
        };
    return AnilistRecommendation(
      id: id,
      rating: rating - weight(userRating) + weight(vote),
      media: media,
      userRating: vote,
    );
  }
}

/// One day (or episode) of a title's activity on AniList (`trends`).
@immutable
class AnilistTrend {
  final DateTime date;
  final int trending;
  final int? averageScore;
  final int? popularity;
  final int? inProgress;
  final int? episode;
  const AnilistTrend({
    required this.date,
    this.trending = 0,
    this.averageScore,
    this.popularity,
    this.inProgress,
    this.episode,
  });
}

/// A followed user's entry on the title, with their own score format.
@immutable
class AnilistFollowingEntry {
  final AnilistSocialUser user;
  final String? status;
  final int progress;

  /// 0-100, 0 = not scored.
  final int scoreRaw;
  final AnilistScoreFormat scoreFormat;

  const AnilistFollowingEntry({
    required this.user,
    this.status,
    this.progress = 0,
    this.scoreRaw = 0,
    this.scoreFormat = AnilistScoreFormat.point10,
  });
}

/// The trailer of a title (YouTube or Dailymotion).
@immutable
class AnilistTrailer {
  final String id;
  final String site;
  final String? thumbnail;
  const AnilistTrailer({required this.id, required this.site, this.thumbnail});

  String get url => site == 'dailymotion'
      ? 'https://www.dailymotion.com/video/$id'
      : 'https://www.youtube.com/watch?v=$id';
}

/// Everything the AniList title page shows, read in one request (`Media(id)`, plus the
/// user's list settings, the followed users' entries and the first threads when signed in).
@immutable
class AnilistMediaDetail {
  final int id;
  final int? malId;

  /// `anime` or `manga`.
  final String category;
  final String? format;
  final String? status;
  final String siteUrl;
  final bool isAdult;

  final String title;
  final String? romaji;
  final String? english;
  final String? native;
  final List<String> synonyms;
  final String? hashtag;

  /// AniList HTML (`asHtml: true`).
  final String? description;

  final String? season;
  final int? seasonYear;

  /// `yyyy-MM-dd`, `yyyy-MM` or `yyyy`.
  final String? startDate;
  final String? endDate;
  final int? episodes;

  /// Minutes per episode.
  final int? duration;
  final int? chapters;
  final int? volumes;
  final String? source;
  final String? country;
  final bool? isLicensed;
  final List<String> genres;

  /// 0-100.
  final int? weightedScore;
  final int? meanScore;
  final int popularity;
  final int favourites;
  final int trending;
  final bool isFavourite;

  final String? bannerUrl;
  final String? coverUrl;
  final String? coverLargeUrl;

  /// `coverImage.color` (`#e4a15d`), the page accent.
  final String? coverColor;
  final AnilistTrailer? trailer;

  final int? nextEpisode;
  final DateTime? nextAiringAt;
  final List<({int episode, DateTime at})> upcoming;

  final List<AnilistRanking> rankings;

  /// Votes per score (10, 20, … 100) and entries per list status (`CURRENT`…).
  final Map<int, int> scoreDistribution;
  final Map<String, int> statusDistribution;
  final List<AnilistMediaTag> tags;
  final List<AnilistExternalLink> links;
  final List<AnilistStreamingEpisode> streamingEpisodes;
  final List<AnilistMediaStudio> studios;
  final List<AnilistStaffEdge> staff;
  final List<AnilistCastEdge> characters;
  final List<AnilistRelation> relations;
  final List<AnilistRecommendation> recommendations;
  final List<AnilistReview> reviews;
  final List<AnilistTrend> trends;

  /// The signed-in user's entry (null when signed out or not on the list) and list settings.
  final AnilistListEntry? entry;
  final AnilistListOptions? listOptions;
  final List<AnilistFollowingEntry> following;
  final List<AnilistThread> threads;
  final bool moreThreads;

  const AnilistMediaDetail({
    required this.id,
    required this.category,
    required this.title,
    required this.siteUrl,
    this.malId,
    this.format,
    this.status,
    this.isAdult = false,
    this.romaji,
    this.english,
    this.native,
    this.synonyms = const [],
    this.hashtag,
    this.description,
    this.season,
    this.seasonYear,
    this.startDate,
    this.endDate,
    this.episodes,
    this.duration,
    this.chapters,
    this.volumes,
    this.source,
    this.country,
    this.isLicensed,
    this.genres = const [],
    this.weightedScore,
    this.meanScore,
    this.popularity = 0,
    this.favourites = 0,
    this.trending = 0,
    this.isFavourite = false,
    this.bannerUrl,
    this.coverUrl,
    this.coverLargeUrl,
    this.coverColor,
    this.trailer,
    this.nextEpisode,
    this.nextAiringAt,
    this.upcoming = const [],
    this.rankings = const [],
    this.scoreDistribution = const {},
    this.statusDistribution = const {},
    this.tags = const [],
    this.links = const [],
    this.streamingEpisodes = const [],
    this.studios = const [],
    this.staff = const [],
    this.characters = const [],
    this.relations = const [],
    this.recommendations = const [],
    this.reviews = const [],
    this.trends = const [],
    this.entry,
    this.listOptions,
    this.following = const [],
    this.threads = const [],
    this.moreThreads = false,
  });

  bool get isAnime => category == 'anime';

  /// Episodes (anime) or chapters (manga); 0 when unknown.
  int get total => (isAnime ? episodes : chapters) ?? 0;

  /// Episodes aired and not yet seen: next episode - 1 - progress (Otraku's "N behind").
  int get behind {
    final e = entry;
    final next = nextEpisode;
    if (e == null || next == null || (e.status != 'CURRENT' && e.status != 'REPEATING')) return 0;
    final n = next - 1 - e.progress;
    return n > 0 ? n : 0;
  }

  /// The official episode after the user's progress, for "Continue watching".
  AnilistStreamingEpisode? get continueEpisode {
    final e = entry;
    if (e == null || !isAnime || streamingEpisodes.isEmpty) return null;
    if (e.status != 'CURRENT' && e.status != 'REPEATING' && e.status != 'PAUSED') return null;
    final want = e.progress + 1;
    for (final ep in streamingEpisodes) {
      if (ep.number == want) return ep;
    }
    return null;
  }

  /// Up to two rankings for the header: the best rated one and the best popular one,
  /// all time first.
  List<AnilistRanking> get topRankings {
    AnilistRanking? best(bool rated) {
      final of = rankings.where((r) => r.rated == rated).toList()
        ..sort((a, b) => a.scope != b.scope ? a.scope.compareTo(b.scope) : a.rank.compareTo(b.rank));
      return of.firstOrNull;
    }

    return [if (best(true) case final r?) r, if (best(false) case final r?) r];
  }

  /// Relations, prequels and sequels first.
  List<AnilistRelation> get sortedRelations =>
      [...relations]..sort((a, b) => a.order.compareTo(b.order));

  AnilistMediaDetail copyWith({
    AnilistListEntry? entry,
    bool clearEntry = false,
    bool? isFavourite,
    int? favourites,
    List<AnilistRecommendation>? recommendations,
  }) =>
      AnilistMediaDetail(
        id: id,
        malId: malId,
        category: category,
        format: format,
        status: status,
        siteUrl: siteUrl,
        isAdult: isAdult,
        title: title,
        romaji: romaji,
        english: english,
        native: native,
        synonyms: synonyms,
        hashtag: hashtag,
        description: description,
        season: season,
        seasonYear: seasonYear,
        startDate: startDate,
        endDate: endDate,
        episodes: episodes,
        duration: duration,
        chapters: chapters,
        volumes: volumes,
        source: source,
        country: country,
        isLicensed: isLicensed,
        genres: genres,
        weightedScore: weightedScore,
        meanScore: meanScore,
        popularity: popularity,
        favourites: favourites ?? this.favourites,
        trending: trending,
        isFavourite: isFavourite ?? this.isFavourite,
        bannerUrl: bannerUrl,
        coverUrl: coverUrl,
        coverLargeUrl: coverLargeUrl,
        coverColor: coverColor,
        trailer: trailer,
        nextEpisode: nextEpisode,
        nextAiringAt: nextAiringAt,
        upcoming: upcoming,
        rankings: rankings,
        scoreDistribution: scoreDistribution,
        statusDistribution: statusDistribution,
        tags: tags,
        links: links,
        streamingEpisodes: streamingEpisodes,
        studios: studios,
        staff: staff,
        characters: characters,
        relations: relations,
        recommendations: recommendations ?? this.recommendations,
        reviews: reviews,
        trends: trends,
        entry: clearEntry ? null : (entry ?? this.entry),
        listOptions: listOptions,
        following: following,
        threads: threads,
        moreThreads: moreThreads,
      );

  /// The `Media(id)` selection of the page. [characters] and [staff] are the first rows only
  /// (their tabs page on); `mediaListEntry` and `isFavourite` answer null / false anonymously.
  static const String fields = '''
    id idMal type format status(version: 2) siteUrl isAdult isFavourite
    title { romaji english native userPreferred } synonyms hashtag description(asHtml: true)
    season seasonYear startDate { year month day } endDate { year month day }
    episodes duration chapters volumes source(version: 3) countryOfOrigin isLicensed genres
    weightedScore meanScore popularity favourites trending
    bannerImage coverImage { extraLarge large color }
    trailer { id site thumbnail }
    nextAiringEpisode { episode airingAt }
    airingSchedule(notYetAired: true, perPage: 5) { nodes { episode airingAt } }
    rankings { rank type format year season allTime }
    stats { scoreDistribution { score amount } statusDistribution { status amount } }
    tags { id name description category rank isGeneralSpoiler isMediaSpoiler isAdult }
    externalLinks { site url type language color icon notes }
    streamingEpisodes { title thumbnail url site }
    studios { edges { isMain node { id name } } }
    staff(perPage: 12, sort: [RELEVANCE, ID]) { edges { role node { ${AnilistMediaPerson.fields} } } }
    characters(perPage: 12, sort: [ROLE, RELEVANCE, ID]) { edges { role
      node { ${AnilistMediaPerson.fields} }
      voiceActors(language: JAPANESE, sort: [RELEVANCE, ID]) { ${AnilistMediaPerson.fields} languageV2 } } }
    relations { edges { relationType(version: 2) node { ${AnilistTitleRef.fields} } } }
    recommendations(perPage: 15, sort: [RATING_DESC, ID]) { nodes { ${AnilistRecommendation.fields} } }
    reviews(perPage: 5, sort: [RATING_DESC, ID]) { nodes {
      id summary score rating ratingAmount private createdAt updatedAt user { ${AnilistSocialUser.fields} } } }
    trends(perPage: 30, sort: DATE_DESC) { nodes { date trending averageScore popularity inProgress episode } }
    mediaListEntry { ${AnilistListWrite.entryFields} }
  ''';

  static AnilistMediaDetail fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? viewer,
    Map<String, dynamic>? following,
    Map<String, dynamic>? threads,
  }) {
    final category = json['type'] == 'MANGA' ? 'manga' : 'anime';
    final isAnime = category == 'anime';
    final titles = json['title'];
    String? title(String key) => titles is Map ? _text(titles[key]) : null;
    final cover = json['coverImage'];
    final trailer = json['trailer'];
    final next = json['nextAiringEpisode'];
    final stats = json['stats'];
    final entryJson = json['mediaListEntry'];
    final id = _int(json['id']);
    final format = _text(json['format']);
    final mainTitle = title('userPreferred') ?? title('romaji') ?? title('english') ?? title('native') ?? '';

    final options = viewer?['mediaListOptions'];
    return AnilistMediaDetail(
      id: id,
      malId: _intOrNull(json['idMal']),
      category: category,
      format: format,
      status: _text(json['status']),
      siteUrl: _text(json['siteUrl']) ?? 'https://anilist.co/$category/$id',
      isAdult: json['isAdult'] == true,
      title: mainTitle,
      romaji: title('romaji'),
      english: title('english'),
      native: title('native'),
      synonyms: [
        for (final s in (json['synonyms'] as List? ?? const []))
          if (_text(s) case final t?) t,
      ],
      hashtag: _text(json['hashtag']),
      description: _text(json['description']),
      season: _text(json['season']),
      seasonYear: _intOrNull(json['seasonYear']),
      startDate: SyncDates.fromFuzzy(json['startDate']),
      endDate: SyncDates.fromFuzzy(json['endDate']),
      episodes: _intOrNull(json['episodes']),
      duration: _intOrNull(json['duration']),
      chapters: _intOrNull(json['chapters']),
      volumes: _intOrNull(json['volumes']),
      source: _text(json['source']),
      country: _text(json['countryOfOrigin']),
      isLicensed: json['isLicensed'] is bool ? json['isLicensed'] as bool : null,
      genres: [
        for (final g in (json['genres'] as List? ?? const []))
          if (_text(g) case final t?) t,
      ],
      weightedScore: _positive(json['weightedScore']) ?? _positive(json['averageScore']),
      meanScore: _positive(json['meanScore']),
      popularity: _int(json['popularity']),
      favourites: _int(json['favourites']),
      trending: _int(json['trending']),
      isFavourite: json['isFavourite'] == true,
      bannerUrl: _text(json['bannerImage']),
      coverUrl: cover is Map ? _text(cover['large']) ?? _text(cover['extraLarge']) : null,
      coverLargeUrl: cover is Map ? _text(cover['extraLarge']) ?? _text(cover['large']) : null,
      coverColor: cover is Map ? _text(cover['color']) : null,
      trailer: trailer is Map && _text(trailer['id']) != null
          ? AnilistTrailer(
              id: _text(trailer['id'])!,
              site: _text(trailer['site']) ?? 'youtube',
              thumbnail: _text(trailer['thumbnail']),
            )
          : null,
      nextEpisode: next is Map ? _intOrNull(next['episode']) : null,
      nextAiringAt: next is Map ? _time(next['airingAt']) : null,
      upcoming: [
        for (final n in _nodes(json['airingSchedule']))
          if (_time(n['airingAt']) case final at?) (episode: _int(n['episode']), at: at),
      ],
      rankings: [
        for (final r in _maps(json['rankings']))
          if (r['rank'] is num && r['type'] is String)
            AnilistRanking(
              rank: _int(r['rank']),
              type: r['type'] as String,
              format: _text(r['format']),
              year: _intOrNull(r['year']),
              season: _text(r['season']),
              allTime: r['allTime'] == true,
            ),
      ],
      scoreDistribution: {
        if (stats is Map)
          for (final s in _maps(stats['scoreDistribution']))
            if (s['score'] is num) _int(s['score']): _int(s['amount']),
      },
      statusDistribution: {
        if (stats is Map)
          for (final s in _maps(stats['statusDistribution']))
            if (s['status'] is String) s['status'] as String: _int(s['amount']),
      },
      tags: [
        for (final t in _maps(json['tags']))
          if (_text(t['name']) case final name?)
            AnilistMediaTag(
              id: _int(t['id']),
              name: name,
              description: _text(t['description']),
              category: _text(t['category']),
              rank: _int(t['rank']),
              spoiler: t['isMediaSpoiler'] == true || t['isGeneralSpoiler'] == true,
              adult: t['isAdult'] == true,
            ),
      ],
      links: [
        for (final l in _maps(json['externalLinks']))
          if (_text(l['site']) case final site?)
            if (_text(l['url']) case final url?)
              AnilistExternalLink(
                site: site,
                url: url,
                type: _text(l['type']),
                language: _text(l['language']),
                color: _text(l['color']),
                icon: _text(l['icon']),
                notes: _text(l['notes']),
              ),
      ],
      streamingEpisodes: [
        for (final e in _maps(json['streamingEpisodes']))
          if (_text(e['url']) case final url?)
            AnilistStreamingEpisode(
              title: _text(e['title']) ?? '',
              url: url,
              thumbnail: _text(e['thumbnail']),
              site: _text(e['site']),
            ),
      ],
      studios: [
        for (final e in _edges(json['studios']))
          if (e['node'] is Map && (e['node'] as Map)['id'] is num)
            AnilistMediaStudio(
              id: _int((e['node'] as Map)['id']),
              name: _text((e['node'] as Map)['name']) ?? '',
              main: e['isMain'] == true,
            ),
      ],
      staff: [
        for (final e in _edges(json['staff']))
          if (AnilistStaffEdge.fromJson(e) case final s?) s,
      ],
      characters: [
        for (final e in _edges(json['characters']))
          if (AnilistCastEdge.fromJson(e) case final c?) c,
      ],
      relations: [
        for (final e in _edges(json['relations']))
          if (AnilistTitleRef.fromJson(e['node']) case final m?)
            AnilistRelation(type: _text(e['relationType']) ?? 'OTHER', media: m),
      ],
      recommendations: [
        for (final n in _nodes(json['recommendations']))
          if (AnilistRecommendation.fromJson(n) case final r?) r,
      ],
      reviews: [
        for (final n in _nodes(json['reviews']))
          if (AnilistReview.fromJson(n) case final r?) r,
      ],
      trends: [
        for (final n in _nodes(json['trends']))
          if (_time(n['date']) case final date?)
            AnilistTrend(
              date: date,
              trending: _int(n['trending']),
              averageScore: _positive(n['averageScore']),
              popularity: _intOrNull(n['popularity']),
              inProgress: _intOrNull(n['inProgress']),
              episode: _intOrNull(n['episode']),
            ),
      ],
      entry: entryJson is Map
          ? AnilistListEntry.fromJson(entryJson, category: category, mediaId: id, format: format)
          : null,
      listOptions: options is Map ? AnilistListOptions.fromJson(options, isAnime: isAnime) : null,
      following: [
        for (final f in (following == null ? const <Map<String, dynamic>>[] : _maps(following['mediaList'])))
          if (AnilistSocialUser.fromJson(f['user']) case final user?)
            AnilistFollowingEntry(
              user: user,
              status: _text(f['status']),
              progress: _int(f['progress']),
              scoreRaw: _int(f['scoreRaw']).clamp(0, 100),
              scoreFormat: AnilistScoreFormat.parse(
                  (f['user'] as Map)['mediaListOptions'] is Map
                      ? ((f['user'] as Map)['mediaListOptions'] as Map)['scoreFormat']
                      : null),
            ),
      ],
      threads: [
        for (final t in (threads == null ? const <Map<String, dynamic>>[] : _maps(threads['threads'])))
          if (t['id'] is num) AnilistThread.fromJson(t),
      ],
      moreThreads: threads?['pageInfo'] is Map &&
          (threads!['pageInfo'] as Map)['hasNextPage'] == true,
    );
  }

  static int? _positive(Object? v) => v is num && v > 0 ? v.toInt() : null;
}

/// A title as the AniList editor edits it: totals, the user's entry and list settings.
@immutable
class AnilistEditTarget {
  final int id;
  final int? malId;
  final String category;
  final String title;
  final String? coverUrl;
  final String? format;
  final int total;
  final int totalVolumes;
  final AnilistListEntry? entry;
  final AnilistListOptions options;

  const AnilistEditTarget({
    required this.id,
    required this.category,
    required this.title,
    this.malId,
    this.coverUrl,
    this.format,
    this.total = 0,
    this.totalVolumes = 0,
    this.entry,
    this.options = const AnilistListOptions(),
  });

  factory AnilistEditTarget.of(AnilistMediaDetail d) => AnilistEditTarget(
        id: d.id,
        malId: d.malId,
        category: d.category,
        title: d.title,
        coverUrl: d.coverUrl,
        format: d.format,
        total: d.total,
        totalVolumes: d.volumes ?? 0,
        entry: d.entry,
        options: d.listOptions ?? const AnilistListOptions(),
      );
}

/// A page of a title's characters or staff.
@immutable
class AnilistPeoplePage<T> {
  final List<T> items;
  final bool hasNext;
  const AnilistPeoplePage(this.items, {required this.hasNext});
}

/// Reads the AniList title page: the whole page in one request (aliases, one rate-limit
/// token), cached 10 minutes; the characters, staff and recommendation tabs page on with
/// their own requests. Every read is public; signed in, the token adds the user's entry,
/// favourite, list settings, votes and the followed users' entries.
class AnilistMediaDetailService {
  AnilistMediaDetailService({
    AnilistGraphql? client,
    bool? signedIn,
    this.ttl = const Duration(minutes: 10),
    DateTime Function()? clock,
  })  : _client = client,
        _signedIn = signedIn,
        _clock = clock ?? DateTime.now;

  /// The service the page uses; tests replace it.
  static AnilistMediaDetailService instance = AnilistMediaDetailService();

  final AnilistGraphql? _client;
  final bool? _signedIn;
  final DateTime Function() _clock;
  final Duration ttl;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  bool get signedIn => _signedIn ?? UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  final Map<int, ({DateTime at, AnilistMediaDetail value})> _cache = {};

  /// The kept page of [id], if any (shown at once while it reloads).
  AnilistMediaDetail? peek(int id) => _cache[id]?.value;

  /// Keeps [detail] (after a write) so the next open shows it.
  void keep(AnilistMediaDetail detail) => _cache[detail.id] = (at: _clock(), value: detail);

  static const String _viewer = 'Viewer { id mediaListOptions { scoreFormat rowOrder '
      'animeList { $_optionFields } mangaList { $_optionFields } } }';
  static const String _optionFields =
      'advancedScoring advancedScoringEnabled customLists sectionOrder splitCompletedSectionByFormat';
  static const String _following = r'Page(perPage: 25) { mediaList(mediaId: $id, '
      'isFollowing: true, sort: UPDATED_TIME_DESC) { status progress '
      'scoreRaw: score(format: POINT_100) user { id name avatar { medium } '
      'mediaListOptions { scoreFormat } } } }';
  static const String _threads = r'Page(perPage: 3) { pageInfo { hasNextPage } '
      r'threads(mediaCategoryId: $id, sort: [IS_STICKY, REPLIED_AT_DESC]) { '
      'id title replyCount viewCount likeCount isSticky isLocked repliedAt createdAt '
      'user { name avatar { medium } } categories { id name } } }';

  /// The page of title [id]; null when AniList has no such title (or hides it).
  Future<AnilistMediaDetail?> detail(int id, {bool force = false}) async {
    final hit = _cache[id];
    if (!force && hit != null && _clock().difference(hit.at) < ttl) return hit.value;
    AnilistBatch result;
    try {
      result = await _read(id, auth: signedIn);
    } on AnilistSessionExpired {
      // A dead session must not hide a public page: read it anonymously.
      result = await _read(id, auth: false);
    }
    final media = result['media'];
    if (media == null) {
      final error = result.errors['media'];
      if (error == null || error.statusCode == 404) return null;
      throw error;
    }
    final found = AnilistMediaDetail.fromJson(
      media,
      viewer: result['viewer'],
      following: result['following'],
      threads: result['threads'],
    );
    keep(found);
    return found;
  }

  Future<AnilistBatch> _read(int id, {required bool auth}) => _gql.batch({
        'media': 'Media(id: \$id) { ${AnilistMediaDetail.fields} }',
        if (auth) 'viewer': _viewer,
        if (auth) 'following': _following,
        'threads': _threads,
      }, variables: {
        'id': GqlVar('Int', id)
      }, auth: auth);

  /// What the AniList editor needs for title [id] (signed in): the title's totals, the
  /// user's whole entry and their list settings, in one request. For editors opened outside
  /// the page (search results).
  Future<AnilistEditTarget> editTarget(int id) async {
    final result = await _gql.batch({
      'media': 'Media(id: \$id) { id idMal type format episodes chapters volumes '
          'title { userPreferred } coverImage { large } '
          'mediaListEntry { ${AnilistListWrite.entryFields} } }',
      'viewer': _viewer,
    }, variables: {
      'id': GqlVar('Int', id)
    }, auth: true);
    final media = result.require('media');
    final d = AnilistMediaDetail.fromJson(media, viewer: result['viewer']);
    return AnilistEditTarget.of(d);
  }

  /// A page of the characters of title [id], voice actors in [language] (`StaffLanguage`).
  Future<AnilistPeoplePage<AnilistCastEdge>> characters(int id,
      {int page = 1, String language = 'JAPANESE', int perPage = 25}) async {
    final data = await _gql.query('''
      query (\$id: Int, \$page: Int, \$perPage: Int, \$language: StaffLanguage) {
        Media(id: \$id) { characters(page: \$page, perPage: \$perPage, sort: [ROLE, RELEVANCE, ID]) {
          pageInfo { hasNextPage }
          edges { role node { ${AnilistMediaPerson.fields} }
            voiceActors(language: \$language, sort: [RELEVANCE, ID]) { ${AnilistMediaPerson.fields} languageV2 } }
        } }
      }
    ''', variables: {'id': id, 'page': page, 'perPage': perPage, 'language': language});
    final connection = (data['Media'] as Map?)?['characters'];
    return AnilistPeoplePage(
      [
        for (final e in _edges(connection))
          if (AnilistCastEdge.fromJson(e) case final c?) c,
      ],
      hasNext: _hasNext(connection),
    );
  }

  /// A page of the staff of title [id].
  Future<AnilistPeoplePage<AnilistStaffEdge>> staff(int id, {int page = 1, int perPage = 25}) async {
    final data = await _gql.query('''
      query (\$id: Int, \$page: Int, \$perPage: Int) {
        Media(id: \$id) { staff(page: \$page, perPage: \$perPage, sort: [RELEVANCE, ID]) {
          pageInfo { hasNextPage }
          edges { role node { ${AnilistMediaPerson.fields} } }
        } }
      }
    ''', variables: {'id': id, 'page': page, 'perPage': perPage});
    final connection = (data['Media'] as Map?)?['staff'];
    return AnilistPeoplePage(
      [
        for (final e in _edges(connection))
          if (AnilistStaffEdge.fromJson(e) case final s?) s,
      ],
      hasNext: _hasNext(connection),
    );
  }

  /// A page of the recommendations of title [id], the user's votes with the token.
  Future<AnilistPeoplePage<AnilistRecommendation>> recommendations(int id,
      {int page = 1, int perPage = 25}) async {
    final data = await _gql.query('''
      query (\$id: Int, \$page: Int, \$perPage: Int) {
        Media(id: \$id) { recommendations(page: \$page, perPage: \$perPage, sort: [RATING_DESC, ID]) {
          pageInfo { hasNextPage }
          nodes { ${AnilistRecommendation.fields} }
        } }
      }
    ''', variables: {'id': id, 'page': page, 'perPage': perPage}, auth: signedIn);
    final connection = (data['Media'] as Map?)?['recommendations'];
    return AnilistPeoplePage(
      [
        for (final n in _nodes(connection))
          if (AnilistRecommendation.fromJson(n) case final r?) r,
      ],
      hasNext: _hasNext(connection),
    );
  }

  /// Titles of [category] matching [search], for "Recommend a title".
  Future<List<AnilistTitleRef>> searchTitles(String search, {required String category}) async {
    final text = search.trim();
    if (text.isEmpty) return const [];
    final data = await _gql.query('''
      query (\$search: String, \$type: MediaType) {
        Page(perPage: 20) { media(search: \$search, type: \$type, sort: SEARCH_MATCH) { ${AnilistTitleRef.fields} } }
      }
    ''', variables: {'search': text, 'type': category == 'manga' ? 'MANGA' : 'ANIME'}, auth: signedIn);
    return [
      for (final m in _maps((data['Page'] as Map?)?['media']))
        if (AnilistTitleRef.fromJson(m) case final t?) t,
    ];
  }

  static bool _hasNext(Object? connection) {
    final info = connection is Map ? connection['pageInfo'] : null;
    return info is Map && info['hasNextPage'] == true;
  }
}
