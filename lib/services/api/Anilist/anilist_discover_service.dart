import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';

/// An inclusive range of whole numbers; a null bound is open. AniList's `_greater` and
/// `_lesser` arguments are strict, [AnilistMediaQuery.variables] turns the bounds into them.
@immutable
class AnilistRange {
  final int? min;
  final int? max;
  const AnilistRange({this.min, this.max});

  static const AnilistRange any = AnilistRange();

  bool get isOpen => min == null && max == null;

  @override
  bool operator ==(Object other) => other is AnilistRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => '${min ?? ''}-${max ?? ''}';
}

/// AniList's `MediaSort` values, as pairs (ascending, `_DESC`) plus `SEARCH_MATCH`: 36 sorts.
abstract final class AnilistSorts {
  /// The sort keys, in the order the sort sheet lists them.
  static const List<String> keys = [
    'POPULARITY', 'SCORE', 'TRENDING', 'FAVOURITES', 'START_DATE', 'END_DATE',
    'TITLE_ROMAJI', 'TITLE_ENGLISH', 'TITLE_NATIVE', 'EPISODES', 'DURATION', 'CHAPTERS',
    'VOLUMES', 'FORMAT', 'STATUS', 'TYPE', 'UPDATED_AT', 'ID',
  ];

  static const String searchMatch = 'SEARCH_MATCH';

  /// Every `MediaSort` value AniList takes.
  static final List<String> all = [
    for (final k in keys) ...[k, '${k}_DESC'],
    searchMatch,
  ];

  /// The keys that mean something for [category] (no chapters for anime, no episodes for
  /// manga, no type inside one type).
  static List<String> keysFor(String category) => [
        for (final k in keys)
          if (k != 'TYPE' &&
              !(category == 'manga' && (k == 'EPISODES' || k == 'DURATION')) &&
              !(category != 'manga' && (k == 'CHAPTERS' || k == 'VOLUMES')))
            k,
      ];

  /// `SCORE` for `SCORE_DESC`, `SEARCH_MATCH` for itself.
  static String keyOf(String sort) => sort.endsWith('_DESC') ? sort.substring(0, sort.length - 5) : sort;

  static bool isDescending(String sort) => sort.endsWith('_DESC');

  static String of(String key, {required bool descending}) =>
      key == searchMatch ? key : (descending ? '${key}_DESC' : key);
}

/// AniList's own filter values (`MediaFormat`, `MediaStatus`, `MediaSource`, `CountryCode`),
/// checked against the live schema on 2026-10-29.
abstract final class AnilistFilterValues {
  static const List<String> animeFormats = ['TV', 'TV_SHORT', 'MOVIE', 'SPECIAL', 'OVA', 'ONA', 'MUSIC'];
  static const List<String> mangaFormats = ['MANGA', 'NOVEL', 'ONE_SHOT'];
  static const List<String> statuses = ['RELEASING', 'FINISHED', 'NOT_YET_RELEASED', 'HIATUS', 'CANCELLED'];
  static const List<String> sources = [
    'ORIGINAL', 'MANGA', 'LIGHT_NOVEL', 'WEB_NOVEL', 'NOVEL', 'VISUAL_NOVEL', 'VIDEO_GAME',
    'GAME', 'COMIC', 'DOUJINSHI', 'ANIME', 'LIVE_ACTION', 'MULTIMEDIA_PROJECT', 'PICTURE_BOOK',
    'OTHER',
  ];
  static const List<String> countries = ['JP', 'KR', 'CN', 'TW'];
  static const List<String> seasons = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];

  static List<String> formatsFor(String category) => category == 'manga' ? mangaFormats : animeFormats;

  /// Bounds of the range sliders.
  static const int firstYear = 1940;
  static int get lastYear => DateTime.now().year + 2;
  static const int maxEpisodes = 150;
  static const int maxDuration = 170;
  static const int maxChapters = 500;
  static const int maxVolumes = 50;
}

const Object _keep = Object();

/// What a discovery row, a "view all" grid or AniList's search asks for: every argument of
/// `Page.media` MWL offers. Immutable; [key] identifies it for the in-memory caches.
@immutable
class AnilistMediaQuery {
  /// `anime` or `manga`.
  final String category;

  /// AniList `MediaSort` value (`TRENDING_DESC`, `SCORE_DESC`, `POPULARITY_DESC`…), see
  /// [AnilistSorts].
  final String sort;
  final String? search;

  /// `WINTER`, `SPRING`, `SUMMER` or `FALL`, with [seasonYear].
  final String? season;
  final int? seasonYear;

  /// One AniList `MediaStatus` (rows: `RELEASING`, `NOT_YET_RELEASED`…); [statuses] adds more.
  final String? status;
  final List<String> statuses;

  /// AniList `MediaFormat` values.
  final List<String> formats;

  /// AniList `CountryCode` of the origin (`JP`, `KR`, `CN`, `TW`); [countries] adds more.
  final String? country;
  final List<String> countries;

  /// One genre (genre rows and chips); [genres] adds more. All must match.
  final String? genre;
  final List<String> genres;
  final List<String> genresExcluded;

  /// One tag (the tag explorer); [tags] adds more. All must match.
  final String? tag;
  final List<String> tags;
  final List<String> tagsExcluded;
  final List<String> tagCategories;

  /// 0-100: a tag only counts when its relevance on the title is at least this.
  final int? minimumTagRank;

  /// `MediaSource` values (original, manga, light novel…).
  final List<String> sources;

  /// Licensed (true) or doujin (false); null for both.
  final bool? isLicensed;

  /// Ids of AniList's streaming / reading services (`ExternalLinkSourceCollection`).
  final List<int> licensedByIds;

  /// Start year, episodes, minutes per episode, chapters, volumes and the 0-100 score.
  final AnilistRange years;
  final AnilistRange episodes;
  final AnilistRange duration;
  final AnilistRange chapters;
  final AnilistRange volumes;
  final AnilistRange score;

  /// At least this many AniList users have the title in their list.
  final int? popularityMin;

  /// Only titles on (true) or off (false) the signed-in user's list; null for all. Needs a
  /// session: ignored without one.
  final bool? onList;

  /// Only adult titles (true), none (false), or what the account allows (null). Never lets
  /// adult titles through when the account or the app hides them.
  final bool? adult;

  const AnilistMediaQuery({
    required this.category,
    this.sort = 'POPULARITY_DESC',
    this.search,
    this.season,
    this.seasonYear,
    this.status,
    this.statuses = const [],
    this.formats = const [],
    this.country,
    this.countries = const [],
    this.genre,
    this.genres = const [],
    this.genresExcluded = const [],
    this.tag,
    this.tags = const [],
    this.tagsExcluded = const [],
    this.tagCategories = const [],
    this.minimumTagRank,
    this.sources = const [],
    this.isLicensed,
    this.licensedByIds = const [],
    this.years = AnilistRange.any,
    this.episodes = AnilistRange.any,
    this.duration = AnilistRange.any,
    this.chapters = AnilistRange.any,
    this.volumes = AnilistRange.any,
    this.score = AnilistRange.any,
    this.popularityMin,
    this.onList,
    this.adult,
  });

  /// A copy with the given fields; nullable fields take an explicit `null` to clear them.
  AnilistMediaQuery copyWith({
    String? category,
    String? sort,
    Object? search = _keep,
    Object? season = _keep,
    Object? seasonYear = _keep,
    Object? status = _keep,
    List<String>? statuses,
    List<String>? formats,
    Object? country = _keep,
    List<String>? countries,
    Object? genre = _keep,
    List<String>? genres,
    List<String>? genresExcluded,
    Object? tag = _keep,
    List<String>? tags,
    List<String>? tagsExcluded,
    List<String>? tagCategories,
    Object? minimumTagRank = _keep,
    List<String>? sources,
    Object? isLicensed = _keep,
    List<int>? licensedByIds,
    AnilistRange? years,
    AnilistRange? episodes,
    AnilistRange? duration,
    AnilistRange? chapters,
    AnilistRange? volumes,
    AnilistRange? score,
    Object? popularityMin = _keep,
    Object? onList = _keep,
    Object? adult = _keep,
  }) {
    T? pick<T>(Object? v, T? old) => identical(v, _keep) ? old : v as T?;
    return AnilistMediaQuery(
      category: category ?? this.category,
      sort: sort ?? this.sort,
      search: pick(search, this.search),
      season: pick(season, this.season),
      seasonYear: pick(seasonYear, this.seasonYear),
      status: pick(status, this.status),
      statuses: statuses ?? this.statuses,
      formats: formats ?? this.formats,
      country: pick(country, this.country),
      countries: countries ?? this.countries,
      genre: pick(genre, this.genre),
      genres: genres ?? this.genres,
      genresExcluded: genresExcluded ?? this.genresExcluded,
      tag: pick(tag, this.tag),
      tags: tags ?? this.tags,
      tagsExcluded: tagsExcluded ?? this.tagsExcluded,
      tagCategories: tagCategories ?? this.tagCategories,
      minimumTagRank: pick(minimumTagRank, this.minimumTagRank),
      sources: sources ?? this.sources,
      isLicensed: pick(isLicensed, this.isLicensed),
      licensedByIds: licensedByIds ?? this.licensedByIds,
      years: years ?? this.years,
      episodes: episodes ?? this.episodes,
      duration: duration ?? this.duration,
      chapters: chapters ?? this.chapters,
      volumes: volumes ?? this.volumes,
      score: score ?? this.score,
      popularityMin: pick(popularityMin, this.popularityMin),
      onList: pick(onList, this.onList),
      adult: pick(adult, this.adult),
    );
  }

  /// This query with every filter cleared: same category, sort and search.
  AnilistMediaQuery cleared() => AnilistMediaQuery(category: category, sort: sort, search: search);

  /// A copy for [category]: the filters that only exist for the other type (formats,
  /// episodes, duration, chapters, volumes, season, streaming services) are dropped.
  AnilistMediaQuery forCategory(String category) {
    if (category == this.category) return this;
    final sortKey = AnilistSorts.keyOf(sort);
    final keepSort = sortKey == AnilistSorts.searchMatch || AnilistSorts.keysFor(category).contains(sortKey);
    return copyWith(
      category: category,
      sort: keepSort ? sort : 'POPULARITY_DESC',
      formats: const [],
      episodes: AnilistRange.any,
      duration: AnilistRange.any,
      chapters: AnilistRange.any,
      volumes: AnilistRange.any,
      season: null,
      seasonYear: null,
      licensedByIds: const [],
    );
  }

  /// Statuses, countries, genres and tags with the single values folded in.
  List<String> get allStatuses => {if (status != null) status!, ...statuses}.toList();
  List<String> get allCountries => {if (country != null) country!, ...countries}.toList();
  List<String> get allGenres => {if (genre != null) genre!, ...genres}.toList();
  List<String> get allTags => {if (tag != null) tag!, ...tags}.toList();

  /// How many filters are set (the badge of the filter button): sort, text and type excluded,
  /// and the length ranges of the other type (not sent).
  int get filterCount => [
        season != null || seasonYear != null,
        allStatuses.isNotEmpty,
        formats.isNotEmpty,
        allCountries.isNotEmpty,
        allGenres.isNotEmpty,
        genresExcluded.isNotEmpty,
        allTags.isNotEmpty,
        tagsExcluded.isNotEmpty,
        tagCategories.isNotEmpty,
        minimumTagRank != null,
        sources.isNotEmpty,
        isLicensed != null,
        licensedByIds.isNotEmpty,
        !years.isOpen,
        category != 'manga' && !episodes.isOpen,
        category != 'manga' && !duration.isOpen,
        category == 'manga' && !chapters.isOpen,
        category == 'manga' && !volumes.isOpen,
        !score.isOpen,
        popularityMin != null,
        onList != null,
        adult != null,
      ].where((set) => set).length;

  bool get hasFilters => filterCount > 0;

  bool get hasSearch => (search ?? '').trim().isNotEmpty;

  /// The sort actually sent: `SEARCH_MATCH` without a text means nothing to AniList, so the
  /// most popular come first then.
  String get effectiveSort => sort == AnilistSorts.searchMatch && !hasSearch ? 'POPULARITY_DESC' : sort;

  String get key => [
        category, sort, search, season, seasonYear, status, statuses.join('+'), formats.join('+'),
        country, countries.join('+'), genre, genres.join('+'), genresExcluded.join('+'), tag,
        tags.join('+'), tagsExcluded.join('+'), tagCategories.join('+'), minimumTagRank,
        sources.join('+'), isLicensed, licensedByIds.join('+'), years, episodes, duration,
        chapters, volumes, score, popularityMin, onList, adult,
      ].join('|');

  /// The variable declarations and `media(...)` arguments of [variables].
  static const String gqlDeclarations = r'''
$page: Int, $perPage: Int, $type: MediaType, $sort: [MediaSort], $search: String,
$season: MediaSeason, $seasonYear: Int, $status_in: [MediaStatus], $format_in: [MediaFormat],
$countryOfOrigin_in: [CountryCode], $genre_in: [String], $genre_not_in: [String],
$tag_in: [String], $tag_not_in: [String], $tagCategory_in: [String], $minimumTagRank: Int,
$source_in: [MediaSource], $isLicensed: Boolean, $licensedById_in: [Int],
$startDate_greater: FuzzyDateInt, $startDate_lesser: FuzzyDateInt,
$episodes_greater: Int, $episodes_lesser: Int, $duration_greater: Int, $duration_lesser: Int,
$chapters_greater: Int, $chapters_lesser: Int, $volumes_greater: Int, $volumes_lesser: Int,
$weightedScore_greater: Int, $weightedScore_lesser: Int, $popularity_greater: Int,
$onList: Boolean, $isAdult: Boolean''';

  static const String gqlArguments = r'''
type: $type, sort: $sort, search: $search, season: $season, seasonYear: $seasonYear,
status_in: $status_in, format_in: $format_in, countryOfOrigin_in: $countryOfOrigin_in,
genre_in: $genre_in, genre_not_in: $genre_not_in, tag_in: $tag_in, tag_not_in: $tag_not_in,
tagCategory_in: $tagCategory_in, minimumTagRank: $minimumTagRank, source_in: $source_in,
isLicensed: $isLicensed, licensedById_in: $licensedById_in,
startDate_greater: $startDate_greater, startDate_lesser: $startDate_lesser,
episodes_greater: $episodes_greater, episodes_lesser: $episodes_lesser,
duration_greater: $duration_greater, duration_lesser: $duration_lesser,
chapters_greater: $chapters_greater, chapters_lesser: $chapters_lesser,
volumes_greater: $volumes_greater, volumes_lesser: $volumes_lesser,
weightedScore_greater: $weightedScore_greater, weightedScore_lesser: $weightedScore_lesser,
popularity_greater: $popularity_greater, onList: $onList, isAdult: $isAdult''';

  /// The GraphQL variables of this query (absent = no filter). [adultAllowed] is whether the
  /// account (or, signed out, the app) shows adult titles; [signedIn] whether [onList] can be
  /// sent.
  Map<String, dynamic> variables({required bool adultAllowed, bool signedIn = false}) {
    final manga = category == 'manga';
    void range(Map<String, dynamic> into, String name, AnilistRange r) {
      if (r.min != null) into['${name}_greater'] = r.min! - 1;
      if (r.max != null) into['${name}_lesser'] = r.max! + 1;
    }

    final vars = <String, dynamic>{
      'type': manga ? 'MANGA' : 'ANIME',
      'sort': [effectiveSort],
      if (hasSearch) 'search': search!.trim(),
      if (season != null) 'season': season,
      if (seasonYear != null) 'seasonYear': seasonYear,
      if (allStatuses.isNotEmpty) 'status_in': allStatuses,
      if (formats.isNotEmpty) 'format_in': formats,
      if (allCountries.isNotEmpty) 'countryOfOrigin_in': allCountries,
      if (allGenres.isNotEmpty) 'genre_in': allGenres,
      if (genresExcluded.isNotEmpty) 'genre_not_in': genresExcluded,
      if (allTags.isNotEmpty) 'tag_in': allTags,
      if (tagsExcluded.isNotEmpty) 'tag_not_in': tagsExcluded,
      if (tagCategories.isNotEmpty) 'tagCategory_in': tagCategories,
      if (minimumTagRank != null) 'minimumTagRank': minimumTagRank,
      if (sources.isNotEmpty) 'source_in': sources,
      if (isLicensed != null) 'isLicensed': isLicensed,
      if (licensedByIds.isNotEmpty) 'licensedById_in': licensedByIds,
      // FuzzyDateInt is YYYYMMDD: after the last day of the year before, before the next one.
      if (years.min != null) 'startDate_greater': years.min! * 10000 - 1,
      if (years.max != null) 'startDate_lesser': (years.max! + 1) * 10000,
      if (popularityMin != null) 'popularity_greater': popularityMin! - 1,
      if (signedIn && onList != null) 'onList': onList,
    };
    if (!manga) {
      range(vars, 'episodes', episodes);
      range(vars, 'duration', duration);
    } else {
      range(vars, 'chapters', chapters);
      range(vars, 'volumes', volumes);
    }
    range(vars, 'weightedScore', score);
    // `false` hides adult titles; absent lets both through.
    if (!adultAllowed || adult == false) {
      vars['isAdult'] = false;
    } else if (adult == true) {
      vars['isAdult'] = true;
    }
    return vars;
  }

  @override
  bool operator ==(Object other) => other is AnilistMediaQuery && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// The signed-in user's entry of a search result (`mediaListEntry`).
@immutable
class AnilistListEntry {
  final int id;

  /// AniList `MediaListStatus` (`CURRENT`, `PLANNING`, `COMPLETED`, `DROPPED`, `PAUSED`,
  /// `REPEATING`).
  final String status;

  /// The raw entry, as the tracker editor reads it.
  final Map<String, dynamic> json;

  const AnilistListEntry({required this.id, required this.status, required this.json});

  static AnilistListEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final status = json['status'];
    if (status is! String) return null;
    return AnilistListEntry(id: (json['id'] as num?)?.toInt() ?? 0, status: status, json: json);
  }
}

/// A title of a search result: the card fields plus what the result row shows.
@immutable
class AnilistSearchMedia {
  final AnilistMedia media;
  final int? volumes;

  /// Minutes per episode.
  final int? duration;
  final int? favourites;
  final int? startYear;

  /// AniList's score, 0-100 (`weightedScore`, else the deprecated `averageScore`).
  final int? score;

  /// Null when signed out or not on the list.
  final AnilistListEntry? entry;

  const AnilistSearchMedia({
    required this.media,
    this.volumes,
    this.duration,
    this.favourites,
    this.startYear,
    this.score,
    this.entry,
  });

  int get id => media.id;

  /// The same title with [entry] (after an edit); null removes it.
  AnilistSearchMedia withEntry(AnilistListEntry? entry) => AnilistSearchMedia(
        media: media,
        volumes: volumes,
        duration: duration,
        favourites: favourites,
        startYear: startYear,
        score: score,
        entry: entry,
      );

  /// What [AnilistDiscoverService.search] asks on top of [AnilistMedia.fields].
  static const String extraFields = 'volumes duration favourites startDate { year }';

  /// The signed-in user's entry, with the fields the tracker editor reads.
  static const String entryFields = '''
    mediaListEntry {
      id status progress progressVolumes repeat notes
      score(format: POINT_10_DECIMAL)
      startedAt { year month day }
      completedAt { year month day }
    }''';

  factory AnilistSearchMedia.fromJson(Map<String, dynamic> json, {String titleLang = 'ro'}) {
    int? whole(Object? v) => v is num ? v.toInt() : null;
    final start = json['startDate'];
    int? score;
    for (final k in const ['weightedScore', 'averageScore']) {
      final v = json[k];
      if (v is num && v > 0) {
        score = v.round();
        break;
      }
    }
    return AnilistSearchMedia(
      media: AnilistMedia.fromJson(json, titleLang: titleLang),
      volumes: whole(json['volumes']),
      duration: whole(json['duration']),
      favourites: whole(json['favourites']),
      startYear: start is Map ? whole(start['year']) : null,
      score: score,
      entry: AnilistListEntry.fromJson(json['mediaListEntry']),
    );
  }
}

class AnilistSearchPage {
  final List<AnilistSearchMedia> items;
  final bool hasNext;
  const AnilistSearchPage(this.items, {required this.hasNext});
}

/// What AniList's search looks for.
enum AnilistSearchKind {
  anime,
  manga,
  characters,
  staff,
  studios,
  users;

  bool get isMedia => this == anime || this == manga;
}

/// A character, staff member, studio or user of a search result.
@immutable
class AnilistSearchHit {
  final AnilistSearchKind kind;
  final int id;
  final String name;
  final String? nativeName;
  final String? imageUrl;
  final int? favourites;

  /// Staff: their occupations; studio: its best-known title.
  final String? detail;

  const AnilistSearchHit({
    required this.kind,
    required this.id,
    required this.name,
    this.nativeName,
    this.imageUrl,
    this.favourites,
    this.detail,
  });

  /// The page of this hit on anilist.co.
  String get url => switch (kind) {
        AnilistSearchKind.characters => 'https://anilist.co/character/$id',
        AnilistSearchKind.staff => 'https://anilist.co/staff/$id',
        AnilistSearchKind.studios => 'https://anilist.co/studio/$id',
        AnilistSearchKind.users => 'https://anilist.co/user/${Uri.encodeComponent(name)}',
        AnilistSearchKind.anime => 'https://anilist.co/anime/$id',
        AnilistSearchKind.manga => 'https://anilist.co/manga/$id',
      };

  static AnilistSearchHit? fromJson(AnilistSearchKind kind, Map<String, dynamic> json) {
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final id = json['id'];
    if (id is! num) return null;
    final names = json['name'];
    final name = names is Map ? text(names['userPreferred']) ?? text(names['full']) : text(names);
    if (name == null) return null;
    final image = json['image'] ?? json['avatar'];
    String? detail;
    if (kind == AnilistSearchKind.staff) {
      final jobs = json['primaryOccupations'];
      if (jobs is List) detail = text(jobs.whereType<String>().join(', '));
    } else if (kind == AnilistSearchKind.studios) {
      final nodes = (json['media'] as Map?)?['nodes'];
      if (nodes is List && nodes.isNotEmpty && nodes.first is Map) {
        final title = (nodes.first as Map)['title'];
        detail = title is Map ? text(title['userPreferred']) : null;
      }
    }
    return AnilistSearchHit(
      kind: kind,
      id: id.toInt(),
      name: name,
      nativeName: names is Map ? text(names['native']) : null,
      imageUrl: image is Map ? text(image['large']) ?? text(image['medium']) : null,
      favourites: (json['favourites'] as num?)?.toInt(),
      detail: detail,
    );
  }
}

class AnilistHitPage {
  final List<AnilistSearchHit> items;
  final bool hasNext;
  const AnilistHitPage(this.items, {required this.hasNext});
}

/// A thread of the AniList forum.
@immutable
class AnilistThread {
  final int id;
  final String title;
  final String? author;
  final String? avatarUrl;
  final int replyCount;
  final int viewCount;
  final int likeCount;
  final bool sticky;
  final bool locked;
  final DateTime? repliedAt;
  final List<String> categories;

  const AnilistThread({
    required this.id,
    required this.title,
    this.author,
    this.avatarUrl,
    this.replyCount = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.sticky = false,
    this.locked = false,
    this.repliedAt,
    this.categories = const [],
  });

  String get url => 'https://anilist.co/forum/thread/$id';

  factory AnilistThread.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final avatar = user is Map ? user['avatar'] : null;
    final replied = json['repliedAt'] ?? json['createdAt'];
    return AnilistThread(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim() ?? '',
      author: user is Map ? user['name'] as String? : null,
      avatarUrl: avatar is Map ? avatar['medium'] as String? : null,
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      sticky: json['isSticky'] == true,
      locked: json['isLocked'] == true,
      repliedAt: replied is num
          ? DateTime.fromMillisecondsSinceEpoch(replied.toInt() * 1000)
          : null,
      categories: [
        for (final c in (json['categories'] as List? ?? const []))
          if (c is Map && c['name'] is String) c['name'] as String,
      ],
    );
  }
}

class AnilistThreadPage {
  final List<AnilistThread> items;
  final bool hasNext;
  const AnilistThreadPage(this.items, {required this.hasNext});
}

/// One episode about to air.
@immutable
class AnilistAiring {
  final AnilistMedia media;
  final int episode;
  final DateTime at;
  const AnilistAiring({required this.media, required this.episode, required this.at});
}

/// AniList's public reads: the lists behind the home and explore rows, search (titles,
/// characters, staff, studios, users), the airing schedule and the forum.
class AnilistDiscoverService {
  AnilistDiscoverService({
    AnilistGraphql? client,
    String Function()? titleLang,
    bool Function()? signedIn,
    bool Function()? appAdult,
    DateTime Function()? clock,
  })  : _client = client,
        _titleLang = titleLang ?? (() => Preferences.general.preferredTitle.name),
        _signedIn = signedIn ?? _anilistSignedIn,
        _appAdult = appAdult ?? (() => Preferences.general.nsfw),
        _clock = clock ?? DateTime.now;

  static AnilistDiscoverService instance = AnilistDiscoverService();

  final AnilistGraphql? _client;
  final String Function() _titleLang;
  final bool Function() _signedIn;
  final bool Function() _appAdult;
  final DateTime Function() _clock;

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  static bool _anilistSignedIn() {
    final user = UserAnilistV2.instance;
    return user.status == AuthStatus.AUTHENTICATED && !user.needsReLogin;
  }

  /// Whether an AniList session can send `auth: true` reads now.
  bool get signedIn => _signedIn();

  /// Genres AniList knew on 2026-10-29 (`GenreCollection`), without `Hentai`: what the app
  /// shows until [AnilistCatalog] has loaded the live list.
  static const List<String> genres = [
    'Action', 'Adventure', 'Comedy', 'Drama', 'Ecchi', 'Fantasy', 'Horror',
    'Mahou Shoujo', 'Mecha', 'Music', 'Mystery', 'Psychological', 'Romance',
    'Sci-Fi', 'Slice of Life', 'Sports', 'Supernatural', 'Thriller',
  ];

  /// The season (`WINTER`…`FALL`) and year of [date], as AniList cuts them.
  static (String season, int year) seasonOf(DateTime date) {
    final m = date.month;
    final season = m <= 2 || m == 12
        ? 'WINTER'
        : m <= 5
            ? 'SPRING'
            : m <= 8
                ? 'SUMMER'
                : 'FALL';
    // AniList files December in the next year's winter.
    return (season, m == 12 ? date.year + 1 : date.year);
  }

  ({DateTime at, bool value})? _viewerAdult;
  Future<bool>? _viewerAdultLoading;

  /// Whether adult titles may show: signed in to AniList, the account's own
  /// `displayAdultContent` (kept an hour); signed out, or when it cannot be read, the app's
  /// NSFW switch.
  Future<bool> adultAllowed() async {
    if (!_signedIn()) {
      _viewerAdult = null;
      return _appAdult();
    }
    final kept = _viewerAdult;
    if (kept != null && _clock().difference(kept.at) < const Duration(hours: 1)) return kept.value;
    return _viewerAdultLoading ??= () async {
      try {
        final data = await _gql.query('query { Viewer { options { displayAdultContent } } }', auth: true);
        final options = (data['Viewer'] as Map?)?['options'];
        final value = options is Map && options['displayAdultContent'] == true;
        _viewerAdult = (at: _clock(), value: value);
        return value;
      } catch (_) {
        return _appAdult();
      } finally {
        _viewerAdultLoading = null;
      }
    }();
  }

  /// Forgets the account's adult option (account change, settings changed on anilist.co).
  void resetAdult() => _viewerAdult = null;

  /// Titles of [q] as cards (home and explore rows).
  Future<AnilistMediaPage> media(AnilistMediaQuery q, {int page = 1, int perPage = 20}) async {
    final adult = await adultAllowed();
    final data = await _gql.query('''
      query (${AnilistMediaQuery.gqlDeclarations}) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          media(${AnilistMediaQuery.gqlArguments}) { ${AnilistMedia.fields} }
        }
      }
    ''', variables: {'page': page, 'perPage': perPage, ...q.variables(adultAllowed: adult)});
    return parseMediaPage(data, titleLang: _titleLang());
  }

  /// One page of AniList's search for [q]: the result rows, with the signed-in user's entry
  /// of each title. Signed in, the request carries the token (needed for [AnilistMediaQuery.onList]
  /// and the entries); a dead session falls back to a public search when it can.
  Future<AnilistSearchPage> search(AnilistMediaQuery q, {int page = 1, int perPage = 30}) async {
    final adult = await adultAllowed();
    final lang = _titleLang();
    Future<AnilistSearchPage> run({required bool auth}) async {
      final data = await _gql.query('''
        query (${AnilistMediaQuery.gqlDeclarations}) {
          Page(page: \$page, perPage: \$perPage) {
            pageInfo { hasNextPage }
            media(${AnilistMediaQuery.gqlArguments}) {
              ${AnilistMedia.fields} ${AnilistSearchMedia.extraFields}
              ${auth ? AnilistSearchMedia.entryFields : ''}
            }
          }
        }
      ''', variables: {
        'page': page,
        'perPage': perPage,
        ...q.variables(adultAllowed: adult, signedIn: auth),
      }, auth: auth);
      return parseSearchPage(data, titleLang: lang);
    }

    if (!_signedIn()) return run(auth: false);
    try {
      return await run(auth: true);
    } on AnilistSessionExpired {
      if (q.onList != null) rethrow;
      return run(auth: false);
    }
  }

  @visibleForTesting
  static AnilistSearchPage parseSearchPage(Map<String, dynamic> data, {String titleLang = 'ro'}) {
    final page = data['Page'];
    if (page is! Map) return const AnilistSearchPage([], hasNext: false);
    final media = page['media'];
    final info = page['pageInfo'];
    return AnilistSearchPage(
      [
        if (media is List)
          for (final m in media)
            if (m is Map<String, dynamic> && m['id'] is num)
              AnilistSearchMedia.fromJson(m, titleLang: titleLang),
      ],
      hasNext: info is Map && info['hasNextPage'] == true,
    );
  }

  /// Characters, staff, studios or users matching [search] (most favourited, or for users the
  /// most watched, when [search] is empty). [kind] must not be a media kind.
  Future<AnilistHitPage> people(AnilistSearchKind kind, String search,
      {int page = 1, int perPage = 30}) async {
    assert(!kind.isMedia);
    final text = search.trim();
    final (field, sortType, selection) = switch (kind) {
      AnilistSearchKind.characters => (
          'characters',
          'CharacterSort',
          'id name { userPreferred native } image { large } favourites'
        ),
      AnilistSearchKind.staff => (
          'staff',
          'StaffSort',
          'id name { userPreferred native } image { large } favourites primaryOccupations'
        ),
      AnilistSearchKind.studios => (
          'studios',
          'StudioSort',
          'id name favourites media(perPage: 1, sort: [POPULARITY_DESC], isMain: true) '
              '{ nodes { title { userPreferred } } }'
        ),
      _ => ('users', 'UserSort', 'id name avatar { large }'),
    };
    final sort = text.isNotEmpty
        ? 'SEARCH_MATCH'
        : kind == AnilistSearchKind.users
            ? 'WATCHED_TIME_DESC'
            : 'FAVOURITES_DESC';
    final data = await _gql.query('''
      query (\$page: Int, \$perPage: Int, \$search: String, \$sort: [$sortType]) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          $field(search: \$search, sort: \$sort) { $selection }
        }
      }
    ''', variables: {
      'page': page,
      'perPage': perPage,
      if (text.isNotEmpty) 'search': text,
      'sort': [sort],
    });
    return parseHitPage(kind, data);
  }

  @visibleForTesting
  static AnilistHitPage parseHitPage(AnilistSearchKind kind, Map<String, dynamic> data) {
    final page = data['Page'];
    if (page is! Map) return const AnilistHitPage([], hasNext: false);
    final field = switch (kind) {
      AnilistSearchKind.characters => 'characters',
      AnilistSearchKind.staff => 'staff',
      AnilistSearchKind.studios => 'studios',
      _ => 'users',
    };
    final rows = page[field];
    final info = page['pageInfo'];
    return AnilistHitPage(
      [
        if (rows is List)
          for (final r in rows)
            if (r is Map<String, dynamic>)
              if (AnilistSearchHit.fromJson(kind, r) case final hit?) hit,
      ],
      hasNext: info is Map && info['hasNextPage'] == true,
    );
  }

  final Map<String, ({DateTime at, List<AnilistMedia> items})> _rows = {};

  /// The first [count] titles of [q], kept for [maxAge] (explore rows: coming back to the tab
  /// or switching Anime / Manga does not ask again).
  Future<List<AnilistMedia>> row(AnilistMediaQuery q,
      {int count = 15, Duration maxAge = const Duration(minutes: 10)}) async {
    final key = '${q.key}#$count';
    final kept = _rows[key];
    if (kept != null && DateTime.now().difference(kept.at) < maxAge) return kept.items;
    final items = (await media(q, perPage: count)).items;
    _rows[key] = (at: DateTime.now(), items: items);
    return items;
  }

  /// The episodes airing in the next [hours] hours as cards (the episode on the card).
  Future<List<AnilistMedia>> airingSoon({int hours = 24}) async {
    final key = 'airing#$hours';
    final kept = _rows[key];
    if (kept != null && DateTime.now().difference(kept.at) < const Duration(minutes: 10)) {
      return kept.items;
    }
    final now = DateTime.now();
    final rows = await airing(now, now.add(Duration(hours: hours)));
    final seen = <int>{};
    final items = [
      for (final r in rows)
        if (seen.add(r.media.id)) r.media.withEpisode(r.episode, r.at),
    ];
    _rows[key] = (at: DateTime.now(), items: items);
    return items;
  }

  @visibleForTesting
  static AnilistMediaPage parseMediaPage(Map<String, dynamic> data, {String titleLang = 'ro'}) {
    final page = data['Page'];
    if (page is! Map) return const AnilistMediaPage([], hasNext: false);
    final media = page['media'];
    final info = page['pageInfo'];
    return AnilistMediaPage(
      [
        if (media is List)
          for (final m in media)
            if (m is Map<String, dynamic> && m['id'] is num)
              AnilistMedia.fromJson(m, titleLang: titleLang),
      ],
      hasNext: info is Map && info['hasNextPage'] == true,
    );
  }

  /// Episodes airing between [from] and [to], soonest first.
  Future<List<AnilistAiring>> airing(DateTime from, DateTime to,
      {int page = 1, int perPage = 50}) async {
    final data = await _gql.query('''
      query (\$page: Int, \$perPage: Int, \$from: Int, \$to: Int) {
        Page(page: \$page, perPage: \$perPage) {
          airingSchedules(airingAt_greater: \$from, airingAt_lesser: \$to, sort: TIME) {
            episode airingAt
            media { ${AnilistMedia.fields} }
          }
        }
      }
    ''', variables: {
      'page': page,
      'perPage': perPage,
      'from': from.millisecondsSinceEpoch ~/ 1000,
      'to': to.millisecondsSinceEpoch ~/ 1000,
    });
    final lang = _titleLang();
    final rows = (data['Page'] as Map?)?['airingSchedules'];
    final adult = await adultAllowed();
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map && r['media'] is Map<String, dynamic> && r['airingAt'] is num)
            if (adult || (r['media'] as Map)['isAdult'] != true)
              AnilistAiring(
                media: AnilistMedia.fromJson(r['media'] as Map<String, dynamic>, titleLang: lang),
                episode: (r['episode'] as num?)?.toInt() ?? 0,
                at: DateTime.fromMillisecondsSinceEpoch((r['airingAt'] as num).toInt() * 1000,
                    isUtc: true),
              ),
    ];
  }

  /// Forum threads; [sort] is a `ThreadSort` value.
  Future<AnilistThreadPage> threads({
    String sort = 'REPLIED_AT_DESC',
    int page = 1,
    int perPage = 25,
  }) async {
    final data = await _gql.query('''
      query (\$page: Int, \$perPage: Int, \$sort: [ThreadSort]) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          threads(sort: \$sort) {
            id title replyCount viewCount likeCount isSticky isLocked repliedAt createdAt
            user { name avatar { medium } }
            categories { name }
          }
        }
      }
    ''', variables: {'page': page, 'perPage': perPage, 'sort': [sort]});
    final pageData = data['Page'];
    if (pageData is! Map) return const AnilistThreadPage([], hasNext: false);
    final rows = pageData['threads'];
    final info = pageData['pageInfo'];
    return AnilistThreadPage(
      [
        if (rows is List)
          for (final t in rows)
            if (t is Map<String, dynamic> && t['id'] is num) AnilistThread.fromJson(t),
      ],
      hasNext: info is Map && info['hasNextPage'] == true,
    );
  }
}
