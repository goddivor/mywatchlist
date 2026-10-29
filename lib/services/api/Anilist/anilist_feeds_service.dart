import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_people_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// A title AniList's daily trends put up: how many users moved it [trending] on the last
/// day, and the episode that drove it (null when the day had no episode).
@immutable
class AnilistTrend {
  final AnilistMedia media;
  final int trending;
  final int? episode;
  const AnilistTrend({required this.media, required this.trending, this.episode});
}

/// A user recommendation: people who liked [from] recommend [to]; [rating] is the sum of
/// the votes. [onMyList] is the signed-in user's status of [to] (only when read signed in).
@immutable
class AnilistRecommendationPair {
  final int id;
  final AnilistMediaRef? from;
  final AnilistMedia to;
  final int rating;
  final String? onMyList;
  const AnilistRecommendationPair({
    required this.id,
    required this.to,
    this.from,
    this.rating = 0,
    this.onMyList,
  });
}

/// A character or staff member born today (or among the most favourited).
@immutable
class AnilistPersonCard {
  final AnilistPersonRef person;

  /// True for a staff member (voice actor, author…), false for a character.
  final bool isStaff;
  const AnilistPersonCard(this.person, {required this.isStaff});
}

/// The answer of one feed request (several rows read in one [AnilistGraphql.batch]), with
/// typed readers per alias. A reader returns null when its alias failed (the row shows its
/// own error) and an empty list when AniList had nothing.
@immutable
class AnilistFeed {
  const AnilistFeed(this.batch, {required this.at, this.titleLang = 'ro', this.adult = false});

  final AnilistBatch batch;
  final DateTime at;
  final String titleLang;

  /// Adult titles allowed (rows that cannot filter on the server are filtered here).
  final bool adult;

  /// The alias failed or was not asked.
  bool failed(String alias) => batch[alias] == null;

  List<Map<String, dynamic>>? _rows(String alias, String field) {
    final page = batch[alias];
    if (page == null) return null;
    final rows = page[field];
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map<String, dynamic>) r,
    ];
  }

  bool _allowed(Map<String, dynamic> media) => adult || media['isAdult'] != true;

  /// `Page.media` rows.
  List<AnilistMedia>? media(String alias) {
    final rows = _rows(alias, 'media');
    if (rows == null) return null;
    return [
      for (final m in rows)
        if (m['id'] is num && _allowed(m)) AnilistMedia.fromJson(m, titleLang: titleLang),
    ];
  }

  /// `Page.airingSchedules` rows as cards carrying the episode (one card per title).
  List<AnilistMedia>? airing(String alias) {
    final rows = _rows(alias, 'airingSchedules');
    if (rows == null) return null;
    final seen = <int>{};
    final out = <AnilistMedia>[];
    for (final r in rows) {
      final m = r['media'];
      final at = r['airingAt'];
      if (m is! Map<String, dynamic> || m['id'] is! num || at is! num || !_allowed(m)) continue;
      if (!seen.add((m['id'] as num).toInt())) continue;
      out.add(AnilistMedia.fromJson(m, titleLang: titleLang).withEpisode(
        (r['episode'] as num?)?.toInt() ?? 0,
        DateTime.fromMillisecondsSinceEpoch(at.toInt() * 1000, isUtc: true),
      ));
    }
    return out;
  }

  /// `Page.mediaTrends` rows, one per title (its strongest day), of [category] only.
  List<AnilistTrend>? trends(String alias, {String category = 'anime'}) {
    final rows = _rows(alias, 'mediaTrends');
    if (rows == null) return null;
    final seen = <int>{};
    final out = <AnilistTrend>[];
    for (final r in rows) {
      final m = r['media'];
      if (m is! Map<String, dynamic> || m['id'] is! num || !_allowed(m)) continue;
      final media = AnilistMedia.fromJson(m, titleLang: titleLang);
      if (media.category != category || !seen.add(media.id)) continue;
      out.add(AnilistTrend(
        media: media,
        trending: (r['trending'] as num?)?.toInt() ?? 0,
        episode: (r['episode'] as num?)?.toInt(),
      ));
    }
    return out;
  }

  /// `Page.recommendations` rows. [notOnList] keeps only titles the user does not have yet
  /// (recommendations from the user's own list), each recommended title once, best voted
  /// first as AniList sorted them.
  List<AnilistRecommendationPair>? recommendations(String alias, {bool notOnList = false}) {
    final rows = _rows(alias, 'recommendations');
    if (rows == null) return null;
    final seen = <int>{};
    final out = <AnilistRecommendationPair>[];
    for (final r in rows) {
      final to = r['mediaRecommendation'];
      if (to is! Map<String, dynamic> || to['id'] is! num || !_allowed(to)) continue;
      final entry = to['mediaListEntry'];
      final status = entry is Map ? entry['status'] as String? : null;
      if (notOnList && status != null) continue;
      final rating = (r['rating'] as num?)?.toInt() ?? 0;
      if (notOnList && rating <= 0) continue;
      final media = AnilistMedia.fromJson(to, titleLang: titleLang);
      if (!seen.add(media.id)) continue;
      out.add(AnilistRecommendationPair(
        id: (r['id'] as num?)?.toInt() ?? 0,
        from: AnilistMediaRef.fromJson(r['media']),
        to: media,
        rating: rating,
        onMyList: status,
      ));
    }
    return out;
  }

  /// `Page.activities` rows.
  List<AnilistActivity>? activities(String alias) {
    final rows = _rows(alias, 'activities');
    if (rows == null) return null;
    return [
      for (final a in rows)
        if (AnilistActivity.fromJson(a) case final activity?) activity,
    ];
  }

  /// `Page.characters` ([isStaff] false) or `Page.staff` rows.
  List<AnilistPersonCard>? people(String alias, {required bool isStaff}) {
    final rows = _rows(alias, isStaff ? 'staff' : 'characters');
    if (rows == null) return null;
    return [
      for (final p in rows)
        if (AnilistPersonRef.fromJson(p) case final person?) AnilistPersonCard(person, isStaff: isStaff),
    ];
  }

  /// `Page.reviews` rows.
  List<AnilistReview>? reviews(String alias) {
    final rows = _rows(alias, 'reviews');
    if (rows == null) return null;
    return [
      for (final r in rows)
        if (AnilistReview.fromJson(r) case final review?) review,
    ];
  }

  /// `Page.threads` rows.
  List<AnilistThread>? threads(String alias) {
    final rows = _rows(alias, 'threads');
    if (rows == null) return null;
    return [
      for (final t in rows)
        if (t['id'] is num) AnilistThread.fromJson(t),
    ];
  }

  /// `Page.pageInfo.hasNextPage` of [alias].
  bool hasNext(String alias) {
    final info = batch[alias]?['pageInfo'];
    return info is Map && info['hasNextPage'] == true;
  }
}

/// One media row of the home: what to ask and how many.
@immutable
class AnilistRowRequest {
  final AnilistMediaQuery query;
  final int count;
  const AnilistRowRequest(this.query, this.count);

  String get key => '${query.key}#$count';
}

/// The tabs of the season page (AniList's and AniChart's season view).
enum AnilistSeasonTab {
  tv(['TV']),
  short(['TV_SHORT']),
  movie(['MOVIE']),
  other(['OVA', 'ONA', 'SPECIAL', 'MUSIC']),

  /// Still airing from earlier seasons.
  leftovers([]);

  const AnilistSeasonTab(this.formats);
  final List<String> formats;
}

/// The aliases of [AnilistFeedsService.explore].
abstract final class AnilistExploreRows {
  static const String trendsToday = 'trendsToday';
  static const String airing = 'airing';
  static const String trending = 'trending';
  static const String season = 'season';
  static const String nextSeason = 'nextSeason';
  static const String publishing = 'publishing';
  static const String top = 'top';
  static const String popular = 'popular';
  static const String manhwa = 'manhwa';
  static const String reviews = 'reviews';
  static const String recommendations = 'recommendations';
  static const String topCharacters = 'topCharacters';
  static const String topStaff = 'topStaff';
}

/// The aliases of the fixed parts of [AnilistFeedsService.home].
abstract final class AnilistHomeParts {
  static const String recommended = 'recommended';
  static const String following = 'following';
  static const String forum = 'forum';
  static const String birthdayCharacters = 'birthdayCharacters';
  static const String birthdayStaff = 'birthdayStaff';

  /// Alias of the media row [i] of the home.
  static String row(int i) => 'row$i';
}

/// The AniList home and Explore feeds: every row of a screen in one request
/// ([AnilistGraphql.batch], one rate-limit token instead of one per row), kept in memory for
/// a while so coming back to the tab asks nothing.
///
/// Arguments are written into the request (GraphQL literals, see [inlineArguments]) because
/// the rows of one batch cannot share variables.
class AnilistFeedsService {
  AnilistFeedsService({
    AnilistGraphql? client,
    AnilistDiscoverService? discover,
    bool Function()? signedIn,
    String Function()? titleLang,
    DateTime Function()? clock,
  })  : _client = client,
        _discover = discover,
        _signedIn = signedIn,
        _titleLang = titleLang ?? (() => Preferences.general.preferredTitle.name),
        _clock = clock ?? DateTime.now;

  /// The service the AniList home and Explore use; tests replace it.
  static AnilistFeedsService instance = AnilistFeedsService();

  final AnilistGraphql? _client;
  final AnilistDiscoverService? _discover;
  final bool Function()? _signedIn;
  final String Function() _titleLang;
  final DateTime Function() _clock;

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;
  AnilistDiscoverService get discover => _discover ?? AnilistDiscoverService.instance;

  /// An AniList session can send `auth: true` reads now.
  bool get signedIn => _signedIn?.call() ?? discover.signedIn;

  final Map<String, ({AnilistFeed feed, DateTime at})> _kept = {};
  final Map<String, Future<AnilistFeed>> _loading = {};

  /// Forgets every kept feed (pull to refresh, account change).
  void clear() => _kept.clear();

  // ------------------------------------------------------------------ parts

  static final RegExp _enumValue = RegExp(r'^[A-Z][A-Z0-9_]*$');

  /// Arguments AniList types as enums (written bare); every other string is quoted.
  static const Set<String> _enumArguments = {
    'type', 'sort', 'season', 'status', 'status_in', 'format_in', 'countryOfOrigin_in', 'source_in',
  };

  /// [variables] written as GraphQL arguments (`type: ANIME, sort: [TRENDING_DESC], …`):
  /// enum values bare (checked to be enum names), strings as JSON strings, lists in brackets.
  @visibleForTesting
  static String inlineArguments(Map<String, dynamic> variables) {
    String literal(String name, Object? value) {
      if (value is List) return '[${value.map((v) => literal(name, v)).join(', ')}]';
      if (value is String) {
        if (_enumArguments.contains(name)) {
          if (!_enumValue.hasMatch(value)) throw ArgumentError.value(value, name, 'Not an enum value');
          return value;
        }
        return jsonEncode(value);
      }
      if (value is bool || value is int) return '$value';
      if (value is num) return value.toInt().toString();
      throw ArgumentError.value(value, name, 'Unsupported argument');
    }

    return [
      for (final e in variables.entries)
        if (e.value != null) '${e.key}: ${literal(e.key, e.value)}',
    ].join(', ');
  }

  static String _page(int perPage, String field, String args, String selection, {bool info = false}) =>
      'Page(perPage: ${perPage.clamp(1, 50)}) { ${info ? 'pageInfo { hasNextPage } ' : ''}'
      '$field${args.isEmpty ? '' : '($args)'} { $selection } }';

  /// The titles of [q] (a media row).
  static String mediaPart(AnilistMediaQuery q, int perPage, {required bool adult, bool info = false}) =>
      _page(perPage, 'media', inlineArguments(q.variables(adultAllowed: adult)), AnilistMedia.fields,
          info: info);

  /// The episodes airing between [from] and [to], soonest first.
  static String airingPart(DateTime from, DateTime to, {int perPage = 50}) => _page(
        perPage,
        'airingSchedules',
        'airingAt_greater: ${from.millisecondsSinceEpoch ~/ 1000}, '
            'airingAt_lesser: ${to.millisecondsSinceEpoch ~/ 1000}, sort: [TIME]',
        'episode airingAt media { ${AnilistMedia.fields} }',
      );

  /// The daily trends of releasing titles since [since], most trending first.
  static String trendsPart(DateTime since, {int perPage = 30}) => _page(
        perPage,
        'mediaTrends',
        'date_greater: ${since.millisecondsSinceEpoch ~/ 1000}, releasing: true, sort: [TRENDING_DESC]',
        'trending episode date media { ${AnilistMedia.fields} }',
      );

  /// Recommendations: [fromMyList] = of the titles on the signed-in user's list, best voted
  /// first (with the user's status of the recommended title); else the latest of everyone.
  static String recommendationsPart({bool fromMyList = false, int perPage = 20}) => _page(
        perPage,
        'recommendations',
        fromMyList ? 'onList: true, sort: [RATING_DESC]' : 'sort: [ID_DESC]',
        'id rating media { ${AnilistMediaRef.fields} } '
            'mediaRecommendation { ${AnilistMedia.fields}${fromMyList ? ' mediaListEntry { status }' : ''} }',
      );

  /// What the people the user follows did lately (list updates and status posts).
  static String followingPart({int perPage = 10}) => _page(
        perPage,
        'activities',
        'isFollowing: true, type_in: [ANIME_LIST, MANGA_LIST, TEXT], sort: [ID_DESC]',
        AnilistActivity.fields(),
      );

  /// Characters ([staff] false) or staff born today ([birthday]) or of all time, the most
  /// favourited first.
  static String peoplePart({required bool staff, bool birthday = false, int perPage = 20}) => _page(
        perPage,
        staff ? 'staff' : 'characters',
        '${birthday ? 'isBirthday: true, ' : ''}sort: [FAVOURITES_DESC]',
        AnilistPersonRef.fields,
      );

  /// The latest reviews of [mediaType] (`ANIME` | `MANGA`).
  static String reviewsPart(String mediaType, {int perPage = 12}) => _page(
        perPage,
        'reviews',
        'mediaType: ${mediaType == 'MANGA' ? 'MANGA' : 'ANIME'}, sort: [ID_DESC]',
        AnilistReview.listFields,
      );

  /// The forum threads replied to last.
  static String threadsPart({int perPage = 8}) => _page(
        perPage,
        'threads',
        'sort: [REPLIED_AT_DESC]',
        'id title replyCount viewCount likeCount isSticky isLocked repliedAt createdAt '
            'user { name avatar { medium } } categories { name }',
      );

  /// AniList's first day of [season] [year] as a FuzzyDateInt (`YYYYMMDD`); winter starts in
  /// December of the year before, as AniList files it.
  @visibleForTesting
  static int seasonStart(String season, int year) => switch (season) {
        'WINTER' => (year - 1) * 10000 + 1201,
        'SPRING' => year * 10000 + 301,
        'SUMMER' => year * 10000 + 601,
        _ => year * 10000 + 901,
      };

  /// The season after [season] [year].
  static (String, int) nextSeason(String season, int year) => switch (season) {
        'WINTER' => ('SPRING', year),
        'SPRING' => ('SUMMER', year),
        'SUMMER' => ('FALL', year),
        _ => ('WINTER', year + 1),
      };

  /// The season before [season] [year].
  static (String, int) previousSeason(String season, int year) => switch (season) {
        'WINTER' => ('FALL', year - 1),
        'SPRING' => ('WINTER', year),
        'SUMMER' => ('SPRING', year),
        _ => ('SUMMER', year),
      };

  /// One tab of the season page. Leftovers = anime still airing that started before the
  /// season (AniList's `status: RELEASING, startDate_lesser`).
  static String seasonPart(AnilistSeasonTab tab, String season, int year,
      {required bool adult, int page = 1, int perPage = 50}) {
    final args = <String, dynamic>{
      'type': 'ANIME',
      if (tab == AnilistSeasonTab.leftovers) ...{
        'status': 'RELEASING',
        'startDate_lesser': seasonStart(season, year),
      } else ...{
        'season': season,
        'seasonYear': year,
        'format_in': tab.formats,
      },
      'sort': ['POPULARITY_DESC'],
      if (!adult) 'isAdult': false,
    };
    return 'Page(page: $page, perPage: ${perPage.clamp(1, 50)}) { pageInfo { hasNextPage } '
        'media(${inlineArguments(args)}) { ${AnilistMedia.fields} } }';
  }

  // ------------------------------------------------------------------ loads

  /// Runs [parts] in one request, kept under [key] for [maxAge] (shared while loading).
  /// [auth] parts are only sent signed in; a dead session drops them and sends the rest
  /// anonymously. Throws only when the whole request fails.
  Future<AnilistFeed> load(
    String key,
    Map<String, String> parts, {
    Map<String, String> authParts = const {},
    Duration maxAge = const Duration(minutes: 10),
    bool force = false,
  }) {
    final kept = _kept[key];
    if (!force && kept != null && _clock().difference(kept.at) < maxAge) return Future.value(kept.feed);
    final running = _loading[key];
    if (running != null) return running;
    final future = _fetch(parts, authParts).then((feed) {
      _kept[key] = (feed: feed, at: _clock());
      return feed;
    }).whenComplete(() => _loading.remove(key));
    return _loading[key] = future;
  }

  Future<AnilistFeed> _fetch(Map<String, String> parts, Map<String, String> authParts) async {
    final adult = await discover.adultAllowed();
    final lang = _titleLang();
    final auth = signedIn && authParts.isNotEmpty;
    AnilistBatch batch;
    try {
      batch = await _gql.batch({...parts, if (auth) ...authParts}, auth: auth);
    } on AnilistSessionExpired {
      if (!auth) rethrow;
      batch = await _gql.batch(parts);
    }
    return AnilistFeed(batch, at: _clock(), titleLang: lang, adult: adult);
  }

  /// The home: [rows] (media rows, alias [AnilistHomeParts.row] by index), plus what is
  /// asked: the recommendations of the user's list, the following feed (both signed in), the
  /// forum and today's birthdays. One request.
  Future<AnilistFeed> home({
    required List<AnilistRowRequest> rows,
    bool recommended = false,
    bool following = true,
    bool forum = false,
    bool birthdays = true,
    Duration maxAge = const Duration(hours: 2),
    bool force = false,
  }) async {
    final adult = await discover.adultAllowed();
    final parts = <String, String>{
      for (var i = 0; i < rows.length; i++)
        AnilistHomeParts.row(i): mediaPart(rows[i].query, rows[i].count, adult: adult),
      if (forum) AnilistHomeParts.forum: threadsPart(),
      if (birthdays) ...{
        AnilistHomeParts.birthdayCharacters: peoplePart(staff: false, birthday: true),
        AnilistHomeParts.birthdayStaff: peoplePart(staff: true, birthday: true, perPage: 12),
      },
    };
    final authParts = <String, String>{
      if (recommended) AnilistHomeParts.recommended: recommendationsPart(fromMyList: true, perPage: 50),
      if (following) AnilistHomeParts.following: followingPart(),
    };
    final key = [
      'home', adult, signedIn, recommended, following, forum, birthdays,
      for (final r in rows) r.key,
    ].join('|');
    return load(key, parts, authParts: authParts, maxAge: maxAge, force: force);
  }

  /// The Explore tab of [category] (`anime` | `manga`): trends with their episode (anime),
  /// what airs in the next 24 hours, trending, this and next season, top, popular, the
  /// latest reviews and recommendations, the most favourited characters and staff. One
  /// request, kept ten minutes.
  Future<AnilistFeed> explore(String category, {bool force = false, int count = 15}) async {
    final adult = await discover.adultAllowed();
    final now = _clock();
    final manga = category == 'manga';
    final (season, year) = AnilistDiscoverService.seasonOf(now);
    final (next, nextYear) = nextSeason(season, year);
    String row(AnilistMediaQuery q) => mediaPart(q, count, adult: adult);
    final parts = <String, String>{
      if (!manga) ...{
        AnilistExploreRows.trendsToday: trendsPart(now.subtract(const Duration(days: 1))),
        AnilistExploreRows.airing: airingPart(now, now.add(const Duration(hours: 24))),
      },
      AnilistExploreRows.trending: row(AnilistMediaQuery(category: category, sort: 'TRENDING_DESC')),
      if (manga) ...{
        AnilistExploreRows.publishing: row(const AnilistMediaQuery(
            category: 'manga', sort: 'POPULARITY_DESC', status: 'RELEASING')),
        AnilistExploreRows.manhwa:
            row(const AnilistMediaQuery(category: 'manga', sort: 'POPULARITY_DESC', country: 'KR')),
      } else ...{
        AnilistExploreRows.season: row(AnilistMediaQuery(
            category: 'anime', sort: 'POPULARITY_DESC', season: season, seasonYear: year)),
        AnilistExploreRows.nextSeason: row(AnilistMediaQuery(
            category: 'anime', sort: 'POPULARITY_DESC', season: next, seasonYear: nextYear)),
      },
      AnilistExploreRows.top: row(AnilistMediaQuery(category: category, sort: 'SCORE_DESC')),
      AnilistExploreRows.popular: row(AnilistMediaQuery(category: category, sort: 'POPULARITY_DESC')),
      AnilistExploreRows.reviews: reviewsPart(manga ? 'MANGA' : 'ANIME'),
      AnilistExploreRows.recommendations: recommendationsPart(),
      AnilistExploreRows.topCharacters: peoplePart(staff: false),
      AnilistExploreRows.topStaff: peoplePart(staff: true),
    };
    return load('explore|$category|$adult|$count|$year$season', parts, force: force);
  }

  /// The first page of every tab of [season] [year] in one request (aliases = tab names).
  Future<AnilistFeed> season(String season, int year, {bool force = false}) async {
    final adult = await discover.adultAllowed();
    return load(
      'season|$season|$year|$adult',
      {
        for (final tab in AnilistSeasonTab.values)
          tab.name: seasonPart(tab, season, year, adult: adult),
      },
      maxAge: const Duration(minutes: 30),
      force: force,
    );
  }

  /// Page [page] (2 and more) of one tab of the season page.
  Future<AnilistMediaPage> seasonPage(AnilistSeasonTab tab, String season, int year, int page) async {
    final adult = await discover.adultAllowed();
    final batch = await _gql.batch({'p': seasonPart(tab, season, year, adult: adult, page: page)});
    final feed = AnilistFeed(batch, at: _clock(), titleLang: _titleLang(), adult: adult);
    return AnilistMediaPage(feed.media('p') ?? (throw batch.errors['p'] ?? const AnilistError(404)),
        hasNext: feed.hasNext('p'));
  }
}
