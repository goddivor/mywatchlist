import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// What Kitsu's `stats` resource says about one kind of media.
@immutable
class KitsuMediaStats {
  /// Titles on the list, episodes or chapters consumed, and titles completed.
  final int media;
  final int units;
  final int completed;

  /// Time spent watching (anime) or reading (manga).
  final Duration time;

  /// Share of Kitsu users this one is ahead of (0-100) on time spent, `null` when Kitsu gave none.
  final double? timePercentile;

  /// Titles per category, most frequent first.
  final List<MapEntry<String, int>> categories;

  /// Entries per list status (from the library, not from `stats`).
  final Map<ListEntryStatus, int> statusCounts;

  const KitsuMediaStats({
    this.media = 0,
    this.units = 0,
    this.completed = 0,
    this.time = Duration.zero,
    this.timePercentile,
    this.categories = const [],
    this.statusCounts = const {},
  });

  int get totalEntries => statusCounts.values.fold(0, (a, b) => a + b);

  KitsuMediaStats withCounts(Map<ListEntryStatus, int> counts) => KitsuMediaStats(
        media: media,
        units: units,
        completed: completed,
        time: time,
        timePercentile: timePercentile,
        categories: categories,
        statusCounts: counts,
      );
}

/// A Kitsu user as the profile screen shows it.
@immutable
class KitsuProfile {
  final String id;
  final String name;
  final String? slug;
  final String? about;
  final String? location;
  final String? gender;
  final String? birthday;
  final String? joined;
  final String? avatarUrl;
  final String? coverUrl;
  final int followers;
  final int following;
  final int ratingsCount;
  final int reviewsCount;
  final int favoritesCount;
  final int commentsCount;
  final int postsCount;
  final int reactionsCount;
  final int likesReceivedCount;
  final String? waifuName;
  final String? waifuLabel;
  final KitsuMediaStats anime;
  final KitsuMediaStats manga;

  const KitsuProfile({
    required this.id,
    required this.name,
    this.slug,
    this.about,
    this.location,
    this.gender,
    this.birthday,
    this.joined,
    this.avatarUrl,
    this.coverUrl,
    this.followers = 0,
    this.following = 0,
    this.ratingsCount = 0,
    this.reviewsCount = 0,
    this.favoritesCount = 0,
    this.commentsCount = 0,
    this.postsCount = 0,
    this.reactionsCount = 0,
    this.likesReceivedCount = 0,
    this.waifuName,
    this.waifuLabel,
    this.anime = const KitsuMediaStats(),
    this.manga = const KitsuMediaStats(),
  });

  /// What GraphQL looks a profile up by: the slug, else the numeric id (a user may have no slug).
  String get handle => slug ?? id;

  String get webUrl => 'https://kitsu.app/users/${slug ?? id}';

  KitsuProfile withStats(KitsuMediaStats anime, KitsuMediaStats manga) => KitsuProfile(
        id: id,
        name: name,
        slug: slug,
        about: about,
        location: location,
        gender: gender,
        birthday: birthday,
        joined: joined,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
        followers: followers,
        following: following,
        ratingsCount: ratingsCount,
        reviewsCount: reviewsCount,
        favoritesCount: favoritesCount,
        commentsCount: commentsCount,
        postsCount: postsCount,
        reactionsCount: reactionsCount,
        likesReceivedCount: likesReceivedCount,
        waifuName: waifuName,
        waifuLabel: waifuLabel,
        anime: anime,
        manga: manga,
      );
}

/// Loads a Kitsu profile, its statistics and its favorites.
class KitsuProfiles {
  KitsuProfiles({KitsuHttp? http, KitsuLibrary? library, KitsuCatalog? catalog})
      : _http = http,
        _library = library,
        _catalog = catalog;

  static KitsuProfiles instance = KitsuProfiles();

  final KitsuHttp? _http;
  final KitsuLibrary? _library;
  final KitsuCatalog? _catalog;
  KitsuHttp get http => _http ?? KitsuHttp.instance;
  KitsuLibrary get library => _library ?? KitsuLibrary.instance;
  KitsuCatalog get catalog => _catalog ?? KitsuCatalog.instance;

  static const String _userFields =
      'name,slug,about,location,gender,birthday,createdAt,avatar,coverImage,followersCount,'
      'followingCount,ratingsCount,reviewsCount,favoritesCount,commentsCount,postsCount,'
      'mediaReactionsCount,likesReceivedCount,waifuOrHusbando,stats,waifu';

  /// The profile of Kitsu user [userId], or of the signed-in user when null. The first answer is
  /// the profile with its Kitsu statistics; [loadCounts] adds the list counts per status of the
  /// signed-in user (other users' libraries may be private).
  Future<KitsuProfile> load({String? userId, bool withCounts = true}) async {
    final self = userId == null;
    final json = await http.getJson(
      self ? '/users' : '/users/$userId',
      query: {
        if (self) 'filter[self]': 'true',
        'include': 'stats,waifu',
        'fields[users]': _userFields,
        'fields[stats]': 'kind,statsData',
        'fields[characters]': 'canonicalName',
      },
      auth: self,
    );
    final doc = KitsuDocument.from(json);
    if (doc.data.isEmpty) throw const KitsuHttpError(404);
    var profile = parse(doc.data.first, doc);
    if (withCounts) {
      try {
        final counts = await Future.wait([
          library.statusCounts(isAnime: true, userId: profile.id, auth: self),
          library.statusCounts(isAnime: false, userId: profile.id, auth: self),
        ]);
        profile = profile.withStats(
            profile.anime.withCounts(counts[0]), profile.manga.withCounts(counts[1]));
      } on KitsuSessionExpired {
        rethrow;
      } catch (e) {
        if (kDebugMode) debugPrint('KitsuProfiles: counts failed: $e');
      }
    }
    return profile;
  }

  /// The favorite anime or manga of user [userId], in the user's order.
  Future<List<KitsuMedia>> favorites(String userId, {required bool isAnime}) async {
    final json = await http.getJson('/favorites', query: {
      'filter[userId]': userId,
      'filter[itemType]': isAnime ? 'Anime' : 'Manga',
      'sort': 'favRank',
      'fields[favorites]': 'favRank,item',
      'page[limit]': '${KitsuCatalog.maxPage}',
    });
    final ids = <String>[];
    for (final f in KitsuDocument.from(json).data) {
      final item = ((f['relationships'] as Map?)?['item'] as Map?)?['data'];
      if (item is Map && item['id'] != null) ids.add('${item['id']}');
    }
    return catalog.byIds(ids, isAnime: isAnime);
  }

  @visibleForTesting
  static KitsuProfile parse(Map<String, dynamic> user, KitsuDocument doc) {
    final a = kitsuAttrs(user);
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    int count(String k) => (a[k] as num?)?.toInt() ?? 0;
    String? image(Object? v, List<String> keys) {
      if (v is! Map) return null;
      for (final k in keys) {
        final u = text(v[k]);
        if (u != null) return u;
      }
      return null;
    }

    KitsuMediaStats stats(String prefix) {
      var media = 0, units = 0, completed = 0;
      var time = Duration.zero;
      double? percentile;
      var categories = <MapEntry<String, int>>[];
      for (final s in doc.relatedAll(user, 'stats')) {
        final sa = kitsuAttrs(s);
        final kind = sa['kind'];
        final data = sa['statsData'];
        if (data is! Map || kind is! String || !kind.startsWith(prefix)) continue;
        if (kind.endsWith('amount-consumed')) {
          media = (data['media'] as num?)?.toInt() ?? 0;
          units = (data['units'] as num?)?.toInt() ?? 0;
          completed = (data['completed'] as num?)?.toInt() ?? 0;
          time = Duration(seconds: (data['time'] as num?)?.toInt() ?? 0);
          final p = data['percentiles'];
          percentile = p is Map && p['time'] is num ? (p['time'] as num).toDouble() : null;
        } else if (kind.endsWith('category-breakdown')) {
          final cats = data['categories'];
          if (cats is Map) {
            categories = [
              for (final e in cats.entries)
                if (e.value is num) MapEntry('${e.key}', (e.value as num).toInt()),
            ]..sort((x, y) => y.value.compareTo(x.value));
          }
        }
      }
      return KitsuMediaStats(
          media: media,
          units: units,
          completed: completed,
          time: time,
          timePercentile: percentile,
          categories: categories);
    }

    final waifu = doc.related(user, 'waifu');
    return KitsuProfile(
      id: '${user['id']}',
      name: text(a['name']) ?? '',
      slug: text(a['slug']),
      about: text(a['about']),
      location: text(a['location']),
      gender: text(a['gender']),
      birthday: text(a['birthday']),
      joined: text(a['createdAt']),
      avatarUrl: image(a['avatar'], const ['large', 'medium', 'original', 'small']),
      coverUrl: image(a['coverImage'], const ['large', 'original', 'small']),
      followers: count('followersCount'),
      following: count('followingCount'),
      ratingsCount: count('ratingsCount'),
      reviewsCount: count('reviewsCount'),
      favoritesCount: count('favoritesCount'),
      commentsCount: count('commentsCount'),
      postsCount: count('postsCount'),
      reactionsCount: count('mediaReactionsCount'),
      likesReceivedCount: count('likesReceivedCount'),
      waifuName: waifu == null ? null : text(kitsuAttrs(waifu)['canonicalName']),
      waifuLabel: text(a['waifuOrHusbando']),
      anime: stats('anime'),
      manga: stats('manga'),
    );
  }
}
