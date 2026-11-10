import 'package:flutter/foundation.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart'
    show AnilistFavouriteKind;
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart' show ListStats;

/// One bar of a distribution (a genre, a format, a score…).
@immutable
class AnilistStatCount {
  final String label;
  final int count;

  /// Mean score (0-10) of the entries in this bucket, 0 when unknown.
  final double mean;
  const AnilistStatCount(this.label, this.count, {this.mean = 0});
}

/// The numbers of one category of a profile.
@immutable
class AnilistCategoryStats {
  final ListStats list;
  final List<AnilistStatCount> genres;
  final List<AnilistStatCount> formats;

  /// Entries per score 1-10 (AniList's 0-100 scale folded to tens).
  final Map<int, int> scores;

  /// Entries per AniList score value (0-100 scale as AniList stores it), 0 left out.
  final Map<int, int> rawScores;

  const AnilistCategoryStats({
    this.list = const ListStats(),
    this.genres = const [],
    this.formats = const [],
    this.scores = const {},
    this.rawScores = const {},
  });
}

/// A favorite title, character, person or studio.
@immutable
class AnilistFavorite {
  final int id;
  final int? malId;
  final String title;
  final String? imageUrl;

  /// anilist.co page.
  final String url;
  const AnilistFavorite({
    required this.id,
    this.malId,
    required this.title,
    this.imageUrl,
    required this.url,
  });
}

@immutable
class AnilistFavorites {
  final List<AnilistFavorite> anime;
  final List<AnilistFavorite> manga;
  final List<AnilistFavorite> characters;
  final List<AnilistFavorite> staff;
  final List<AnilistFavorite> studios;

  const AnilistFavorites({
    this.anime = const [],
    this.manga = const [],
    this.characters = const [],
    this.staff = const [],
    this.studios = const [],
  });

  bool get isEmpty =>
      anime.isEmpty && manga.isEmpty && characters.isEmpty && staff.isEmpty && studios.isEmpty;
}

/// A user's AniList profile: the header data the shared profile header draws, the about
/// text and the per-category numbers.
@immutable
class AnilistProfile {
  final UserProfileData data;
  final String? about;
  final String? bannerUrl;
  final AnilistCategoryStats anime;
  final AnilistCategoryStats manga;
  final AnilistFavorites favorites;

  /// `options.profileColor`: one of AniList's colour names (`blue`, `purple`, `pink`, `orange`,
  /// `red`, `green`, `gray`) or a `#rrggbb` hex; null = AniList's default blue.
  final String? profileColor;

  /// The supporter badge text ("Donator", a custom one) and tier; null for no badge.
  final String? donatorBadge;
  final int donatorTier;
  final List<String> moderatorRoles;
  final List<String> previousNames;

  /// The signed-in user follows this user / this user follows the signed-in user.
  final bool isFollowing;
  final bool isFollower;
  final bool isBlocked;

  /// The user's own score format (`POINT_100`, `POINT_10_DECIMAL`, `POINT_10`, `POINT_5`,
  /// `POINT_3`).
  final String scoreFormat;

  const AnilistProfile({
    required this.data,
    this.about,
    this.bannerUrl,
    this.anime = const AnilistCategoryStats(),
    this.manga = const AnilistCategoryStats(),
    this.favorites = const AnilistFavorites(),
    this.profileColor,
    this.donatorBadge,
    this.donatorTier = 0,
    this.moderatorRoles = const [],
    this.previousNames = const [],
    this.isFollowing = false,
    this.isFollower = false,
    this.isBlocked = false,
    this.scoreFormat = 'POINT_10',
  });

  String get url => 'https://anilist.co/user/${data.username}';
}

/// Which part of a profile's statistics is read (each is its own request, so one failing part
/// leaves the others).
enum AnilistStatsPart { overview, genres, tags, voiceActors, staff, studios }

/// One row of a ranked statistic (a genre, tag, voice actor, staff member or studio).
@immutable
class AnilistRankedStat {
  /// The tag / person / studio id, null for a genre.
  final int? id;
  final String name;
  final String? imageUrl;
  final int count;

  /// Mean score 0-10, 0 when unknown.
  final double mean;

  /// Minutes watched (anime) of the entries counted here.
  final int minutes;

  /// Chapters read (manga) of the entries counted here.
  final int chapters;

  /// AniList ids of the titles counted here.
  final List<int> mediaIds;

  const AnilistRankedStat({
    this.id,
    required this.name,
    this.imageUrl,
    required this.count,
    this.mean = 0,
    this.minutes = 0,
    this.chapters = 0,
    this.mediaIds = const [],
  });
}

/// The distributions of the Stats tab Overview.
@immutable
class AnilistStatsOverview {
  final double standardDeviation;
  final int episodesOrChapters;
  final int minutes;

  /// Minutes (anime) or chapters (manga) of the Planning list.
  final int plannedAmount;
  final List<AnilistStatCount> lengths;
  final List<AnilistStatCount> releaseYears;
  final List<AnilistStatCount> startYears;
  final List<AnilistStatCount> countries;

  const AnilistStatsOverview({
    this.standardDeviation = 0,
    this.episodesOrChapters = 0,
    this.minutes = 0,
    this.plannedAmount = 0,
    this.lengths = const [],
    this.releaseYears = const [],
    this.startYears = const [],
    this.countries = const [],
  });
}

/// One day of the activity heatmap.
@immutable
class AnilistActivityDay {
  final DateTime date;
  final int amount;

  /// 0-10, AniList's own intensity.
  final int level;
  const AnilistActivityDay(this.date, this.amount, this.level);
}

/// One page of a user's favourites of one kind.
@immutable
class AnilistFavouritePage {
  final List<AnilistFavorite> items;
  final bool hasNext;
  const AnilistFavouritePage(this.items, {required this.hasNext});
}

/// The score buckets of a profile in the user's own score format: the 1-based bucket and the
/// number of entries. `POINT_5` = stars 1-5, `POINT_3` = frown / neutral / smile, every other
/// format = tens 1-10.
List<({int bucket, int count})> foldScores(Map<int, int> raw, String format) {
  final out = <int, int>{};
  for (final e in raw.entries) {
    if (e.key <= 0) continue;
    final bucket = switch (format) {
      'POINT_5' => (e.key / 20).round().clamp(1, 5).toInt(),
      'POINT_3' => e.key <= 35 ? 1 : (e.key <= 60 ? 2 : 3),
      _ => (e.key / 10).round().clamp(1, 10).toInt(),
    };
    out[bucket] = (out[bucket] ?? 0) + e.value;
  }
  final size = switch (format) { 'POINT_5' => 5, 'POINT_3' => 3, _ => 10 };
  return [for (var b = 1; b <= size; b++) (bucket: b, count: out[b] ?? 0)];
}

/// `en` | `ja` | `ro` (a `TitleLang` name) for an AniList title language.
String titleLangOf(AnilistTitleLanguage language) => switch (language) {
      AnilistTitleLanguage.english || AnilistTitleLanguage.englishStylised => 'en',
      AnilistTitleLanguage.native || AnilistTitleLanguage.nativeStylised => 'ja',
      _ => 'ro',
    };

/// Reads profiles from AniList (`Viewer` for the signed-in user, `User(name:)` for others).
class AnilistProfileService {
  AnilistProfileService({AnilistGraphql? client, bool? signedIn})
      : _client = client,
        _signedIn = signedIn;

  static AnilistProfileService instance = AnilistProfileService();

  final AnilistGraphql? _client;
  final bool? _signedIn;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  /// Reads that can use the account do (titles follow its title language, the follow flags
  /// exist only then).
  bool get signedIn =>
      _signedIn ?? UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  static const String _stats = '''
    count meanScore
    statuses { status count }
    scores(sort: MEAN_DESC) { score count }
    formats { format count meanScore }
    genres(limit: 15, sort: COUNT_DESC) { genre count meanScore }
  ''';

  static const String _fields = '''
    id name about(asHtml: true) bannerImage createdAt
    avatar { large }
    options { profileColor }
    mediaListOptions { scoreFormat }
    donatorBadge donatorTier moderatorRoles previousNames
    isFollowing isFollower isBlocked
    statistics {
      anime { $_stats minutesWatched episodesWatched }
      manga { $_stats chaptersRead volumesRead }
    }
    favourites {
      anime(perPage: 12) { nodes { id idMal title { userPreferred } coverImage { large } } }
      manga(perPage: 12) { nodes { id idMal title { userPreferred } coverImage { large } } }
      characters(perPage: 12) { nodes { id name { userPreferred } image { large } } }
      staff(perPage: 12) { nodes { id name { userPreferred } image { large } } }
      studios(perPage: 12) { nodes { id name } }
    }
  ''';

  final Map<String, ({DateTime at, AnilistProfile profile})> _kept = {};

  /// [username] null = the signed-in user (needs the session, throws
  /// [AnilistSessionExpired] without it). A profile read in the last [maxAge] comes from
  /// memory (coming back to the tab is instant); [force] asks AniList again.
  Future<AnilistProfile> load({
    String? username,
    bool force = false,
    Duration maxAge = const Duration(minutes: 5),
  }) async {
    final key = (username ?? '').toLowerCase();
    final kept = _kept[key];
    if (!force && kept != null && DateTime.now().difference(kept.at) < maxAge) {
      return kept.profile;
    }
    final profile = await _fetch(username);
    _kept[key] = (at: DateTime.now(), profile: profile);
    return profile;
  }

  /// The profile kept in memory, if any.
  AnilistProfile? kept(String? username) => _kept[(username ?? '').toLowerCase()]?.profile;

  /// Forgets the kept profiles (sign out).
  void clear() => _kept.clear();

  Future<AnilistProfile> _fetch(String? username) async {
    final self = username == null;
    final data = await _gql.query(
      self
          ? 'query { Viewer { $_fields } }'
          : 'query (\$name: String) { User(name: \$name) { $_fields } }',
      variables: self ? const {} : {'name': username},
      auth: self || signedIn,
    );
    final user = data[self ? 'Viewer' : 'User'];
    if (user is! Map<String, dynamic>) throw UserProfileUnavailable(username ?? '');
    return parseProfile(user);
  }

  // Statistics ------------------------------------------------------------------------

  static const String _rankedFields = 'count meanScore minutesWatched chaptersRead mediaIds';

  static String _statsSelection(AnilistStatsPart part, {required bool manga}) {
    final amount = manga ? 'chaptersRead' : 'minutesWatched';
    return switch (part) {
      AnilistStatsPart.overview => '''
        standardDeviation ${manga ? 'chaptersRead' : 'episodesWatched minutesWatched'}
        statuses { status count $amount }
        lengths { length count meanScore }
        releaseYears { releaseYear count meanScore }
        startYears { startYear count meanScore }
        countries { country count meanScore }
      ''',
      AnilistStatsPart.genres =>
        'genres(limit: 100, sort: COUNT_DESC) { genre $_rankedFields }',
      AnilistStatsPart.tags =>
        'tags(limit: 100, sort: COUNT_DESC) { tag { id name } $_rankedFields }',
      AnilistStatsPart.voiceActors =>
        'voiceActors(limit: 60, sort: COUNT_DESC) { voiceActor { id name { userPreferred } '
            'image { large } } $_rankedFields }',
      AnilistStatsPart.staff =>
        'staff(limit: 60, sort: COUNT_DESC) { staff { id name { userPreferred } '
            'image { large } } $_rankedFields }',
      AnilistStatsPart.studios =>
        'studios(limit: 60, sort: COUNT_DESC) { studio { id name } $_rankedFields }',
    };
  }

  Future<Map<dynamic, dynamic>> _statsRaw(
      String username, String category, AnilistStatsPart part) async {
    final manga = category == 'manga';
    final data = await _gql.query(
      'query (\$name: String) { User(name: \$name) { statistics { $category { '
      '${_statsSelection(part, manga: manga)} } } } }',
      variables: {'name': username},
      auth: signedIn,
    );
    final stats = (data['User'] as Map?)?['statistics'];
    final block = stats is Map ? stats[category] : null;
    if (block is! Map) throw UserProfileUnavailable(username);
    return block;
  }

  /// The Overview distributions of [username]'s [category] (`anime` | `manga`).
  Future<AnilistStatsOverview> loadStatsOverview(String username, String category) async =>
      parseStatsOverview(await _statsRaw(username, category, AnilistStatsPart.overview),
          manga: category == 'manga');

  /// A ranked statistic ([part] other than `overview`) of [username]'s [category].
  Future<List<AnilistRankedStat>> loadRanked(
      String username, String category, AnilistStatsPart part) async {
    assert(part != AnilistStatsPart.overview);
    return parseRanked(await _statsRaw(username, category, part), part);
  }

  @visibleForTesting
  static AnilistStatsOverview parseStatsOverview(Map<dynamic, dynamic> raw,
      {required bool manga}) {
    int count(Object? v) => (v as num?)?.toInt() ?? 0;
    List<AnilistStatCount> buckets(String key, String label) => [
          for (final e in (raw[key] as List? ?? const []))
            if (e is Map && e[label] != null)
              AnilistStatCount('${e[label]}', count(e['count']),
                  mean: ((e['meanScore'] as num?)?.toDouble() ?? 0) / 10),
        ];
    var planned = 0;
    for (final st in (raw['statuses'] as List? ?? const [])) {
      if (st is Map && st['status'] == 'PLANNING') {
        planned += count(st[manga ? 'chaptersRead' : 'minutesWatched']);
      }
    }
    final years = buckets('releaseYears', 'releaseYear')
      ..sort((a, b) => a.label.compareTo(b.label));
    final starts = buckets('startYears', 'startYear')..sort((a, b) => a.label.compareTo(b.label));
    return AnilistStatsOverview(
      standardDeviation: ((raw['standardDeviation'] as num?)?.toDouble() ?? 0) / 10,
      episodesOrChapters: count(manga ? raw['chaptersRead'] : raw['episodesWatched']),
      minutes: manga ? 0 : count(raw['minutesWatched']),
      plannedAmount: planned,
      lengths: buckets('lengths', 'length'),
      releaseYears: years,
      startYears: starts,
      countries: buckets('countries', 'country'),
    );
  }

  @visibleForTesting
  static List<AnilistRankedStat> parseRanked(Map<dynamic, dynamic> raw, AnilistStatsPart part) {
    final key = switch (part) {
      AnilistStatsPart.genres => 'genres',
      AnilistStatsPart.tags => 'tags',
      AnilistStatsPart.voiceActors => 'voiceActors',
      AnilistStatsPart.staff => 'staff',
      _ => 'studios',
    };
    int count(Object? v) => (v as num?)?.toInt() ?? 0;
    final out = <AnilistRankedStat>[];
    for (final e in (raw[key] as List? ?? const [])) {
      if (e is! Map) continue;
      final String? name;
      int? id;
      String? image;
      switch (part) {
        case AnilistStatsPart.genres:
          name = e['genre'] as String?;
        case AnilistStatsPart.tags:
          final t = e['tag'];
          name = t is Map ? t['name'] as String? : null;
          id = t is Map ? count(t['id']) : null;
        case AnilistStatsPart.studios:
          final t = e['studio'];
          name = t is Map ? t['name'] as String? : null;
          id = t is Map ? count(t['id']) : null;
        default:
          final t = e[part == AnilistStatsPart.staff ? 'staff' : 'voiceActor'];
          name = t is Map ? ((t['name'] as Map?)?['userPreferred'] as String?) : null;
          id = t is Map ? count(t['id']) : null;
          image = t is Map ? ((t['image'] as Map?)?['large'] as String?) : null;
      }
      if (name == null || name.isEmpty) continue;
      out.add(AnilistRankedStat(
        id: id == 0 ? null : id,
        name: name,
        imageUrl: image,
        count: count(e['count']),
        mean: ((e['meanScore'] as num?)?.toDouble() ?? 0) / 10,
        minutes: count(e['minutesWatched']),
        chapters: count(e['chaptersRead']),
        mediaIds: [
          for (final m in (e['mediaIds'] as List? ?? const []))
            if (m is num) m.toInt(),
        ],
      ));
    }
    return out;
  }

  /// The activity heatmap of user [userId]: AniList's `activityHistory` (a deprecated block
  /// that still answers), one entry per active day.
  Future<List<AnilistActivityDay>> loadActivityHistory(int userId) async {
    final data = await _gql.query(
      'query (\$id: Int) { User(id: \$id) { stats { activityHistory { date amount level } } } }',
      variables: {'id': userId},
      auth: signedIn,
    );
    return parseActivityHistory(((data['User'] as Map?)?['stats'] as Map?)?['activityHistory']);
  }

  @visibleForTesting
  static List<AnilistActivityDay> parseActivityHistory(Object? raw) => [
        if (raw is List)
          for (final e in raw)
            if (e is Map && e['date'] is num)
              AnilistActivityDay(
                DateTime.fromMillisecondsSinceEpoch((e['date'] as num).toInt() * 1000,
                    isUtc: true),
                (e['amount'] as num?)?.toInt() ?? 0,
                (e['level'] as num?)?.toInt() ?? 0,
              ),
      ];

  /// The titles with [ids] (the ones a statistic counted), most popular first.
  Future<List<AnilistFavorite>> titlesById(List<int> ids, {int limit = 50}) async {
    if (ids.isEmpty) return const [];
    final data = await _gql.query('''
      query (\$ids: [Int], \$perPage: Int) {
        Page(perPage: \$perPage) {
          media(id_in: \$ids, sort: POPULARITY_DESC) {
            id idMal type title { userPreferred } coverImage { large }
          }
        }
      }
    ''', variables: {'ids': ids.take(500).toList(), 'perPage': limit}, auth: signedIn);
    return _nodes((data['Page'] as Map?)?['media'], 'media');
  }

  // Favourites ------------------------------------------------------------------------

  static String _favouriteSelection(AnilistFavouriteKind kind) => switch (kind) {
        AnilistFavouriteKind.anime || AnilistFavouriteKind.manga =>
          'nodes { id idMal title { userPreferred } coverImage { large } }',
        AnilistFavouriteKind.character || AnilistFavouriteKind.staff =>
          'nodes { id name { userPreferred } image { large } }',
        AnilistFavouriteKind.studio => 'nodes { id name }',
      };

  static String _favouriteKey(AnilistFavouriteKind kind) => switch (kind) {
        AnilistFavouriteKind.anime => 'anime',
        AnilistFavouriteKind.manga => 'manga',
        AnilistFavouriteKind.character => 'characters',
        AnilistFavouriteKind.staff => 'staff',
        AnilistFavouriteKind.studio => 'studios',
      };

  /// One page of [username]'s favourites of [kind], in their favourite order.
  Future<AnilistFavouritePage> loadFavourites(
    String username,
    AnilistFavouriteKind kind, {
    int page = 1,
    int perPage = 50,
  }) async {
    final key = _favouriteKey(kind);
    final data = await _gql.query('''
      query (\$name: String, \$page: Int, \$perPage: Int) {
        User(name: \$name) {
          favourites { $key(page: \$page, perPage: \$perPage) {
            pageInfo { hasNextPage } ${_favouriteSelection(kind)} } }
        }
      }
    ''', variables: {'name': username, 'page': page, 'perPage': perPage}, auth: signedIn);
    final block = ((data['User'] as Map?)?['favourites'] as Map?)?[key];
    if (block is! Map) return const AnilistFavouritePage([], hasNext: false);
    final info = block['pageInfo'];
    return AnilistFavouritePage(
      _nodes(block['nodes'], kind.name),
      hasNext: info is Map && info['hasNextPage'] == true,
    );
  }

  static List<AnilistFavorite> _nodes(Object? nodes, String kind) {
    if (nodes is! List) return const [];
    final media = kind == 'anime' || kind == 'manga' || kind == 'media';
    final studio = kind == 'studio';
    final out = <AnilistFavorite>[];
    for (final n in nodes) {
      if (n is! Map || n['id'] is! num) continue;
      final id = (n['id'] as num).toInt();
      final path = media
          ? (n['type'] == 'MANGA' || kind == 'manga' ? 'manga' : 'anime')
          : studio
              ? 'studio'
              : kind == 'character'
                  ? 'character'
                  : 'staff';
      out.add(AnilistFavorite(
        id: id,
        malId: media ? (n['idMal'] as num?)?.toInt() : null,
        title: studio
            ? (n['name'] as String? ?? '')
            : media
                ? ((n['title'] as Map?)?['userPreferred'] as String? ?? '')
                : ((n['name'] as Map?)?['userPreferred'] as String? ?? ''),
        imageUrl: ((media ? n['coverImage'] : n['image']) as Map?)?['large'] as String?,
        url: 'https://anilist.co/$path/$id',
      ));
    }
    return out;
  }

  /// Saves the favourite order of [kind] to [ids] (every favourite of that kind, first to
  /// last): AniList numbers them 1..n. A write, run only from the viewer's own reorder.
  Future<void> saveFavouriteOrder(AnilistFavouriteKind kind, List<int> ids) async {
    final prefix = kind.name;
    await _gql.mutate(
      'mutation (\$ids: [Int], \$order: [Int]) { '
      'UpdateFavouriteOrder(${prefix}Ids: \$ids, ${prefix}Order: \$order) { __typename } }',
      variables: {
        'ids': ids,
        'order': [for (var i = 1; i <= ids.length; i++) i],
      },
    );
  }

  // Account title language ---------------------------------------------------------------

  static String? _accountTitleLang;

  /// The title language of the signed-in AniList account (`en` | `ja` | `ro`, a `TitleLang`
  /// name), read once from its settings; the app's own title preference when signed out or
  /// when the settings cannot be read.
  Future<String> accountTitleLang() async {
    final kept = _accountTitleLang;
    if (kept != null) return kept;
    final fallback = Preferences.general.preferredTitle.name;
    if (!signedIn) return fallback;
    try {
      final settings = await AnilistSettingsService.instance.load();
      return _accountTitleLang = titleLangOf(settings.titleLanguage);
    } catch (_) {
      return fallback;
    }
  }

  /// Forgets the kept title language (the settings page changed it, or sign out).
  static void forgetTitleLang() => _accountTitleLang = null;

  @visibleForTesting
  static AnilistProfile parseProfile(Map<String, dynamic> user) {
    final stats = user['statistics'];
    final anime = _category(stats is Map ? stats['anime'] : null, manga: false);
    final manga = _category(stats is Map ? stats['manga'] : null, manga: true);
    final created = user['createdAt'];
    final avatar = user['avatar'];
    final about = user['about'];
    final banner = user['bannerImage'];
    return AnilistProfile(
      data: UserProfileData(
        id: (user['id'] as num?)?.toInt() ?? 0,
        username: user['name'] as String? ?? '',
        pictureUrl: avatar is Map ? avatar['large'] as String? : null,
        joined: created is num && created > 0
            ? DateTime.fromMillisecondsSinceEpoch(created.toInt() * 1000, isUtc: true)
                .toIso8601String()
            : null,
        anime: anime.list,
        manga: manga.list,
      ),
      about: about is String && about.trim().isNotEmpty ? about : null,
      bannerUrl: banner is String && banner.isNotEmpty ? banner : null,
      anime: anime,
      manga: manga,
      favorites: _favorites(user['favourites']),
      profileColor: _text((user['options'] as Map?)?['profileColor']),
      donatorBadge: _text(user['donatorBadge']),
      donatorTier: (user['donatorTier'] as num?)?.toInt() ?? 0,
      moderatorRoles: _strings(user['moderatorRoles']),
      previousNames: _strings(user['previousNames']),
      isFollowing: user['isFollowing'] == true,
      isFollower: user['isFollower'] == true,
      isBlocked: user['isBlocked'] == true,
      scoreFormat: _text((user['mediaListOptions'] as Map?)?['scoreFormat']) ?? 'POINT_10',
    );
  }

  static String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

  static List<String> _strings(Object? v) =>
      v is List ? [for (final e in v) if (e is String && e.trim().isNotEmpty) e.trim()] : const [];

  static AnilistCategoryStats _category(Object? raw, {required bool manga}) {
    if (raw is! Map) return const AnilistCategoryStats();
    int count(Object? v) => (v as num?)?.toInt() ?? 0;
    var current = 0, completed = 0, onHold = 0, dropped = 0, planned = 0;
    for (final s in (raw['statuses'] as List? ?? const [])) {
      if (s is! Map) continue;
      final n = count(s['count']);
      switch (s['status']) {
        case 'CURRENT' || 'REPEATING':
          current += n;
        case 'COMPLETED':
          completed += n;
        case 'PAUSED':
          onHold += n;
        case 'DROPPED':
          dropped += n;
        case 'PLANNING':
          planned += n;
      }
    }
    final mean = (raw['meanScore'] as num?)?.toDouble() ?? 0;
    final minutes = count(raw['minutesWatched']);
    final scores = <int, int>{};
    final rawScores = <int, int>{};
    for (final s in (raw['scores'] as List? ?? const [])) {
      if (s is! Map) continue;
      if (count(s['score']) > 0) {
        rawScores[count(s['score'])] = (rawScores[count(s['score'])] ?? 0) + count(s['count']);
      }
      // AniList buckets 0-100 scores by tens (10, 20…100); 0 = unscored.
      final bucket = (count(s['score']) / 10).round().clamp(0, 10).toInt();
      if (bucket == 0) continue;
      scores[bucket] = (scores[bucket] ?? 0) + count(s['count']);
    }
    return AnilistCategoryStats(
      list: ListStats(
        meanScore: mean > 0 ? mean / 10 : null,
        totalEntries: count(raw['count']),
        days: manga ? null : minutes / 1440,
        progress: count(manga ? raw['chaptersRead'] : raw['episodesWatched']),
        volumes: manga ? count(raw['volumesRead']) : 0,
        current: current,
        completed: completed,
        onHold: onHold,
        dropped: dropped,
        planned: planned,
      ),
      genres: [
        for (final g in (raw['genres'] as List? ?? const []))
          if (g is Map && g['genre'] is String)
            AnilistStatCount(g['genre'] as String, count(g['count']),
                mean: ((g['meanScore'] as num?)?.toDouble() ?? 0) / 10),
      ],
      formats: [
        for (final f in (raw['formats'] as List? ?? const []))
          if (f is Map && f['format'] is String)
            AnilistStatCount(f['format'] as String, count(f['count']),
                mean: ((f['meanScore'] as num?)?.toDouble() ?? 0) / 10),
      ],
      scores: scores,
      rawScores: rawScores,
    );
  }

  static AnilistFavorites _favorites(Object? raw) {
    if (raw is! Map) return const AnilistFavorites();
    List<AnilistFavorite> read(String key, String path,
        {bool media = false, bool studio = false}) {
      final block = raw[key];
      final nodes = block is Map ? block['nodes'] : null;
      if (nodes is! List) return const [];
      return [
        for (final n in nodes)
          if (n is Map && n['id'] is num)
            AnilistFavorite(
              id: (n['id'] as num).toInt(),
              malId: media ? ((n['idMal'] as num?)?.toInt()) : null,
              title: studio
                  ? (n['name'] as String? ?? '')
                  : media
                      ? ((n['title'] as Map?)?['userPreferred'] as String? ?? '')
                      : ((n['name'] as Map?)?['userPreferred'] as String? ?? ''),
              imageUrl: ((media ? n['coverImage'] : n['image']) as Map?)?['large'] as String?,
              url: 'https://anilist.co/$path/${(n['id'] as num).toInt()}',
            ),
      ];
    }

    return AnilistFavorites(
      anime: read('anime', 'anime', media: true),
      manga: read('manga', 'manga', media: true),
      characters: read('characters', 'character'),
      staff: read('staff', 'staff'),
      studios: read('studios', 'studio', studio: true),
    );
  }
}
