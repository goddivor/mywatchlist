import 'package:flutter/foundation.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
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

  const AnilistCategoryStats({
    this.list = const ListStats(),
    this.genres = const [],
    this.formats = const [],
    this.scores = const {},
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

  const AnilistProfile({
    required this.data,
    this.about,
    this.bannerUrl,
    this.anime = const AnilistCategoryStats(),
    this.manga = const AnilistCategoryStats(),
    this.favorites = const AnilistFavorites(),
  });

  String get url => 'https://anilist.co/user/${data.username}';
}

/// Reads profiles from AniList (`Viewer` for the signed-in user, `User(name:)` for others).
class AnilistProfileService {
  AnilistProfileService({AnilistGraphql? client}) : _client = client;

  static AnilistProfileService instance = AnilistProfileService();

  final AnilistGraphql? _client;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

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
      auth: self,
    );
    final user = data[self ? 'Viewer' : 'User'];
    if (user is! Map<String, dynamic>) throw UserProfileUnavailable(username ?? '');
    return parseProfile(user);
  }

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
    );
  }

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
    for (final s in (raw['scores'] as List? ?? const [])) {
      if (s is! Map) continue;
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
