import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// What a discovery row or "view all" grid asks AniList for. Immutable; [key] identifies it
/// for the in-memory caches.
@immutable
class AnilistMediaQuery {
  /// `anime` or `manga`.
  final String category;

  /// AniList `MediaSort` value (`TRENDING_DESC`, `SCORE_DESC`, `POPULARITY_DESC`…).
  final String sort;

  /// `WINTER`, `SPRING`, `SUMMER` or `FALL`, with [seasonYear].
  final String? season;
  final int? seasonYear;

  /// AniList `MediaStatus` (`RELEASING`, `NOT_YET_RELEASED`…).
  final String? status;

  /// AniList `MediaFormat` values.
  final List<String> formats;

  /// AniList `CountryCode` of the origin (`JP`, `KR`, `CN`), null for any.
  final String? country;
  final String? genre;
  final String? search;

  const AnilistMediaQuery({
    required this.category,
    this.sort = 'POPULARITY_DESC',
    this.season,
    this.seasonYear,
    this.status,
    this.formats = const [],
    this.country,
    this.genre,
    this.search,
  });

  AnilistMediaQuery copyWith({String? category, String? genre, String? search, String? sort}) =>
      AnilistMediaQuery(
        category: category ?? this.category,
        sort: sort ?? this.sort,
        season: season,
        seasonYear: seasonYear,
        status: status,
        formats: formats,
        country: country,
        genre: genre ?? this.genre,
        search: search ?? this.search,
      );

  String get key => [category, sort, season, seasonYear, status, formats.join('+'), country, genre, search]
      .join('|');

  @override
  bool operator ==(Object other) => other is AnilistMediaQuery && other.key == key;

  @override
  int get hashCode => key.hashCode;
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

/// AniList's public reads: the lists behind the home and explore rows, search, the airing
/// schedule and the forum.
class AnilistDiscoverService {
  AnilistDiscoverService({AnilistGraphql? client, String Function()? titleLang})
      : _client = client,
        _titleLang = titleLang ?? (() => Preferences.general.preferredTitle.name);

  static AnilistDiscoverService instance = AnilistDiscoverService();

  final AnilistGraphql? _client;
  final String Function() _titleLang;

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  /// Genres AniList knows (`GenreCollection`), as of the last check.
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

  Future<AnilistMediaPage> media(AnilistMediaQuery q, {int page = 1, int perPage = 20}) async {
    final adult = Preferences.general.nsfw;
    final data = await _gql.query('''
      query (\$page: Int, \$perPage: Int, \$type: MediaType, \$sort: [MediaSort],
          \$season: MediaSeason, \$seasonYear: Int, \$status: MediaStatus,
          \$formats: [MediaFormat], \$country: CountryCode, \$genre: String, \$search: String, \$adult: Boolean) {
        Page(page: \$page, perPage: \$perPage) {
          pageInfo { hasNextPage }
          media(type: \$type, sort: \$sort, season: \$season, seasonYear: \$seasonYear,
              status: \$status, format_in: \$formats, countryOfOrigin: \$country, genre: \$genre, search: \$search,
              isAdult: \$adult) { ${AnilistMedia.fields} }
        }
      }
    ''', variables: {
      'page': page,
      'perPage': perPage,
      'type': q.category == 'manga' ? 'MANGA' : 'ANIME',
      'sort': [q.sort],
      if (q.season != null) 'season': q.season,
      if (q.seasonYear != null) 'seasonYear': q.seasonYear,
      if (q.status != null) 'status': q.status,
      if (q.formats.isNotEmpty) 'formats': q.formats,
      if (q.country != null) 'country': q.country,
      if (q.genre != null) 'genre': q.genre,
      if (q.search != null && q.search!.trim().isNotEmpty) 'search': q.search!.trim(),
      // `false` hides adult titles; null lets them through (the NSFW preference).
      if (!adult) 'adult': false,
    });
    return parseMediaPage(data, titleLang: _titleLang());
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
    final adult = Preferences.general.nsfw;
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
