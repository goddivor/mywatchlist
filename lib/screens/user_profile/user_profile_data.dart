import 'package:flutter/foundation.dart';
import 'package:mywatchlist/cache/cached_user_profile.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/user_anime_statistics.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';

/// One favorite shown in the Favorites tab.
class ProfileFavorite {
  final int id;
  final String title;
  final String? imageUrl;

  const ProfileFavorite({required this.id, required this.title, this.imageUrl});

  factory ProfileFavorite.fromJson(Map<String, dynamic> json) => ProfileFavorite(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'imageUrl': imageUrl};
}

/// The four favorite lists of a profile.
class ProfileFavorites {
  final List<ProfileFavorite> anime;
  final List<ProfileFavorite> manga;
  final List<ProfileFavorite> characters;
  final List<ProfileFavorite> people;

  const ProfileFavorites({
    this.anime = const [],
    this.manga = const [],
    this.characters = const [],
    this.people = const [],
  });

  bool get isEmpty => anime.isEmpty && manga.isEmpty && characters.isEmpty && people.isEmpty;

  static List<ProfileFavorite> _list(Object? raw, {required bool named}) {
    if (raw is! List) return const [];
    final out = <ProfileFavorite>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final id = (row['mal_id'] as num?)?.toInt() ?? 0;
      final title =
          ((named ? row['name'] : row['title']) ?? row['title'] ?? row['name']) as String?;
      if (id == 0 || title == null || title.isEmpty) continue;
      final images = row['images'];
      final jpg = images is Map ? images['jpg'] : null;
      final url = jpg is Map ? jpg['image_url'] as String? : null;
      out.add(ProfileFavorite(id: id, title: title, imageUrl: url));
    }
    return out;
  }

  /// From the `favorites` block of a Jikan `users/{name}/full` payload.
  factory ProfileFavorites.fromJikan(Object? raw) {
    if (raw is! Map) return const ProfileFavorites();
    return ProfileFavorites(
      anime: _list(raw['anime'], named: false),
      manga: _list(raw['manga'], named: false),
      characters: _list(raw['characters'], named: true),
      people: _list(raw['people'], named: true),
    );
  }

  factory ProfileFavorites.fromJson(Map<String, dynamic>? json) {
    List<ProfileFavorite> read(String key) => [
          for (final row in (json?[key] as List? ?? const []))
            if (row is Map) ProfileFavorite.fromJson(Map<String, dynamic>.from(row)),
        ];
    return ProfileFavorites(
      anime: read('anime'),
      manga: read('manga'),
      characters: read('characters'),
      people: read('people'),
    );
  }

  Map<String, dynamic> toJson() => {
        'anime': [for (final e in anime) e.toJson()],
        'manga': [for (final e in manga) e.toJson()],
        'characters': [for (final e in characters) e.toJson()],
        'people': [for (final e in people) e.toJson()],
      };
}

/// State of the parts of a profile that only Jikan gives (manga numbers, favorites, and the
/// whole profile of another user): the official MAL data is shown first, Jikan merges later.
enum ProfileExtras {
  /// Jikan answered, or the data comes from the cache.
  ready,

  /// Jikan is still being asked; manga numbers and favorites may be missing or stale.
  loading,

  /// Jikan did not answer and there is nothing cached: manga numbers and favorites are missing.
  unavailable,
}

/// Everything the profile header and the stats tab need about one MyAnimeList user.
class UserProfileData {
  final int id;
  final String username;
  final String? pictureUrl;
  final String? gender;
  final String? location;
  final String? birthday;
  final String? joined;
  final ListStats anime;
  final ListStats manga;

  /// Days spent per anime status (watching, completed, on hold, dropped); own profile only,
  /// because only the official API exposes them.
  final List<double?> animeDays;
  final ProfileFavorites favorites;

  /// Whether the Jikan part is there (never stored: a cached profile is [ProfileExtras.ready]).
  final ProfileExtras extras;

  const UserProfileData({
    required this.id,
    required this.username,
    this.pictureUrl,
    this.gender,
    this.location,
    this.birthday,
    this.joined,
    this.anime = const ListStats(),
    this.manga = const ListStats(),
    this.animeDays = const [],
    this.favorites = const ProfileFavorites(),
    this.extras = ProfileExtras.ready,
  });

  /// A copy with the Jikan part replaced (manga numbers, favorites) and its state.
  UserProfileData withExtras(
    ProfileExtras extras, {
    ListStats? manga,
    ProfileFavorites? favorites,
  }) =>
      UserProfileData(
        id: id,
        username: username,
        pictureUrl: pictureUrl,
        gender: gender,
        location: location,
        birthday: birthday,
        joined: joined,
        anime: anime,
        manga: manga ?? this.manga,
        animeDays: animeDays,
        favorites: favorites ?? this.favorites,
        extras: extras,
      );

  String get profileUrl => 'https://myanimelist.net/profile/$username';

  factory UserProfileData.fromJson(Map<String, dynamic> json) => UserProfileData(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        pictureUrl: json['pictureUrl'] as String?,
        gender: json['gender'] as String?,
        location: json['location'] as String?,
        birthday: json['birthday'] as String?,
        joined: json['joined'] as String?,
        anime: ListStats.fromJson(json['anime'] as Map<String, dynamic>?),
        manga: ListStats.fromJson(json['manga'] as Map<String, dynamic>?),
        animeDays: [
          for (final d in (json['animeDays'] as List? ?? const [])) (d as num?)?.toDouble(),
        ],
        favorites: ProfileFavorites.fromJson(json['favorites'] as Map<String, dynamic>?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'pictureUrl': pictureUrl,
        'gender': gender,
        'location': location,
        'birthday': birthday,
        'joined': joined,
        'anime': anime.toJson(),
        'manga': manga.toJson(),
        'animeDays': animeDays,
        'favorites': favorites.toJson(),
      };
}

/// The profile does not exist, is private, or neither source answered.
class UserProfileUnavailable implements Exception {
  final String username;
  const UserProfileUnavailable(this.username);

  @override
  String toString() => 'UserProfileUnavailable($username)';
}

/// Loads [UserProfileData]: the official API for the signed-in user (fresher numbers, days
/// per status) completed by Jikan (manga numbers, favorites), Jikan alone for everybody else.
/// A fresh disk entry short-circuits the network; a stale one is served when it fails.
class UserProfileRepository {
  UserProfileRepository._();

  static final UserProfileRepository instance = UserProfileRepository._();

  /// Replaced by tests.
  @visibleForTesting
  Future<Map<String, dynamic>> Function(String username) jikanFull =
      (name) => JikanApi().getUserFullProfile(name);

  @visibleForTesting
  Future<MalUserProf> Function() malSelf =
      () => MalUser().getUserInfo(fields: const ['anime_statistics']);

  /// The signed-in user's MAL name, when known without a request.
  static String? get ownUsername {
    final name = UserMalV2.instance.username;
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<UserProfileData> load(
    String? username, {
    bool forceRefresh = false,
  }) async {
    final isSelf = username == null;
    var name = username ?? ownUsername;

    if (name != null && !forceRefresh) {
      final cached = await CachedUserProfile.instance.read(name);
      if (cached != null && cached.age < CachedUserProfile.freshFor) {
        return UserProfileData.fromJson(cached.json);
      }
    }

    MalUserProf? mal;
    if (isSelf) {
      try {
        mal = await malSelf();
        if (mal.name.isNotEmpty) name = mal.name;
      } catch (e) {
        if (kDebugMode) debugPrint('UserProfileRepository: MAL self failed: $e');
        if (name == null) rethrow;
      }
    }
    if (name == null) throw const UserProfileUnavailable('');

    Map<String, dynamic>? full;
    try {
      full = await jikanFull(name);
    } catch (e) {
      if (kDebugMode) debugPrint('UserProfileRepository: Jikan failed for $name: $e');
    }

    if (mal == null && full == null) {
      final stale = await CachedUserProfile.instance.read(name);
      if (stale != null) return UserProfileData.fromJson(stale.json);
      throw UserProfileUnavailable(name);
    }

    final data = merge(name, mal: mal, jikan: full);
    await CachedUserProfile.instance.write(name, data.toJson());
    return data;
  }

  /// Like [load], but never waits for Jikan before showing something: emits the official MAL
  /// data of the signed-in user (or a cached profile) at once with [ProfileExtras.loading],
  /// then the profile merged with Jikan when (if) it answers. Jikan has its own 12 s timeout
  /// and circuit breaker, so the second value comes quickly either way.
  ///
  /// A fresh cached profile is emitted alone, without any request (unless [forceRefresh]).
  /// The stream errors only when nothing at all can be shown.
  Stream<UserProfileData> watch(
    String? username, {
    bool forceRefresh = false,
  }) async* {
    final isSelf = username == null;
    var name = username ?? ownUsername;

    UserProfileData? previous;
    if (name != null) {
      final cached = await CachedUserProfile.instance.read(name);
      if (cached != null) {
        previous = UserProfileData.fromJson(cached.json);
        if (!forceRefresh && cached.age < CachedUserProfile.freshFor) {
          yield previous;
          return;
        }
      }
    }

    MalUserProf? mal;
    if (isSelf) {
      try {
        mal = await malSelf();
        if (mal.name.isNotEmpty) name = mal.name;
      } catch (e) {
        if (kDebugMode) debugPrint('UserProfileRepository: MAL self failed: $e');
        if (name == null) rethrow;
      }
    }
    if (name == null) throw const UserProfileUnavailable('');

    // First value: the official data (with the cached Jikan part, if any) or the cached
    // profile, so the screen never waits for Jikan.
    final samePerson = previous != null && previous.username.toLowerCase() == name.toLowerCase();
    final stale = samePerson ? previous : null;
    final UserProfileData? first;
    if (mal != null) {
      first = merge(name, mal: mal).withExtras(
        ProfileExtras.loading,
        manga: stale?.manga,
        favorites: stale?.favorites,
      );
    } else {
      first = stale?.withExtras(ProfileExtras.loading);
    }
    if (first != null) yield first;

    Map<String, dynamic>? full;
    try {
      full = await jikanFull(name);
    } catch (e) {
      if (kDebugMode) debugPrint('UserProfileRepository: Jikan failed for $name: $e');
    }

    if (full == null) {
      if (first == null) throw UserProfileUnavailable(name);
      // Keep what is shown; the Jikan part is either the cached one or missing.
      yield first.withExtras(stale != null ? ProfileExtras.ready : ProfileExtras.unavailable);
      return;
    }

    final data = merge(name, mal: mal, jikan: full);
    await CachedUserProfile.instance.write(name, data.toJson());
    yield data;
  }

  /// Combines the two sources; the official numbers win where both exist.
  @visibleForTesting
  static UserProfileData merge(
    String name, {
    MalUserProf? mal,
    Map<String, dynamic>? jikan,
  }) {
    final stats = parseJikanStatistics(jikan);
    final malStats = mal?.animeStatistics;
    final hasMalStats = malStats != null && (malStats.numItems ?? 0) > 0;
    final images = jikan?['images'];
    final jpg = images is Map ? images['jpg'] : null;
    final jikanPicture = jpg is Map ? jpg['image_url'] as String? : null;

    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

    return UserProfileData(
      id: mal?.id != null && mal!.id != 0 ? mal.id : (jikan?['mal_id'] as num?)?.toInt() ?? 0,
      username: name,
      pictureUrl: clean(mal?.picture) ?? jikanPicture,
      gender: clean(mal?.gender) ?? clean(jikan?['gender'] as String?),
      location: clean(mal?.location) ?? clean(jikan?['location'] as String?),
      birthday: mal?.birthday?.toIso8601String() ?? clean(jikan?['birthday'] as String?),
      joined: clean(mal?.joinedAt) ?? clean(jikan?['joined'] as String?),
      anime: hasMalStats ? ListStats.fromMalAnime(malStats) : stats.anime,
      manga: stats.manga,
      animeDays: hasMalStats
          ? [
              malStats.numDaysWatching,
              malStats.numDaysCompleted,
              malStats.numDaysOnHold,
              malStats.numDaysDropped,
            ]
          : const [],
      favorites: ProfileFavorites.fromJikan(jikan?['favorites']),
    );
  }
}
