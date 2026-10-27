import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mwl_commons/mwl_commons.dart' show GenreCategoryList, InterestStack, RankedPersonHtml, ReviewHtml;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';

/// Keeps the answer of a loader for [ttl], so switching Anime/Manga or coming back to the tab
/// does not download a section again. A failed load is forgotten, so "Try again" really retries.
class ExploreCache {
  ExploreCache._();

  static final ExploreCache instance = ExploreCache._();

  final Map<String, ({DateTime at, Future<Object?> future})> _entries = {};

  Future<T> load<T>(String key, Future<T> Function() fetch,
      {Duration ttl = const Duration(minutes: 10)}) {
    final hit = _entries[key];
    if (hit != null && DateTime.now().difference(hit.at) < ttl) {
      return hit.future.then((v) => v as T);
    }
    final future = fetch();
    _entries[key] = (at: DateTime.now(), future: future);
    future.then<void>((_) {}, onError: (Object _) {
      if (_entries[key]?.future == future) _entries.remove(key);
    });
    return future;
  }

  void forget(String key) => _entries.remove(key);

  @visibleForTesting
  void clear() => _entries.clear();
}

/// An anime or manga named inside a recommendation.
@immutable
class RecoRef {
  final int id;
  final String title;
  final String? imageUrl;

  const RecoRef({required this.id, required this.title, this.imageUrl});
}

/// "If you liked [first], you might like [second]", written by [username].
@immutable
class Recommendation {
  final RecoRef first;
  final RecoRef second;
  final String? username;
  final String? text;

  /// ISO date of the recommendation, as Jikan gives it.
  final String? date;

  const Recommendation({
    required this.first,
    required this.second,
    this.username,
    this.text,
    this.date,
  });

  /// From one element of Jikan's `recommendations/{anime|manga}` list; null when malformed.
  static Recommendation? fromJikan(Object? json) {
    if (json is! Map) return null;
    final entry = json['entry'];
    if (entry is! List || entry.length < 2) return null;
    final first = _ref(entry[0]);
    final second = _ref(entry[1]);
    if (first == null || second == null) return null;
    final user = json['user'];
    final text = json['content'];
    return Recommendation(
      first: first,
      second: second,
      username: user is Map && user['username'] is String ? user['username'] as String : null,
      text: text is String && text.trim().isNotEmpty ? text.trim() : null,
      date: json['date'] is String ? json['date'] as String : null,
    );
  }

  static RecoRef? _ref(Object? json) {
    if (json is! Map || json['mal_id'] is! int) return null;
    final images = json['images'];
    final jpg = images is Map ? images['jpg'] : null;
    String? image;
    if (jpg is Map) {
      image = (jpg['image_url'] ?? jpg['large_image_url']) as String?;
    }
    return RecoRef(
      id: json['mal_id'] as int,
      title: (json['title'] as String?) ?? '',
      imageUrl: image,
    );
  }
}

/// A group of genres as MAL shows it (Genres, Themes, Demographics, Explicit Genres).
@immutable
class GenreGroup {
  final String type;
  final List<({int id, String name, int count})> genres;

  const GenreGroup(this.type, this.genres);

  bool get isExplicit => type == 'Explicit Genres';
}

/// What the Explore page downloads, each call cached by [ExploreCache].
class ExploreData {
  ExploreData._();

  /// Latest recommendations of the whole community (Jikan), 25 at most.
  static Future<List<Recommendation>> recommendations(String category, {int limit = 25}) {
    return ExploreCache.instance.load('reco:$category:$limit', () async {
      final url = Uri.parse('${Constants.jikanV4}/recommendations/$category');
      final response = await JikanClient.instance.get(url);
      if (response.statusCode != 200) throw Exception('recommendations ${response.statusCode}');
      final body = await MwlApi.decodeJson(response.body);
      final data = body is Map ? body['data'] : null;
      if (data is! List) return const <Recommendation>[];
      return [
        for (final item in data)
          if (Recommendation.fromJikan(item) case final r?) r,
      ].take(limit).toList();
    });
  }

  /// Latest reviews of [category], MAL page [page].
  static Future<List<ReviewHtml>> reviews(String category, {int page = 1}) {
    return ExploreCache.instance.load(
      'reviews:$category:$page',
      () async {
        final list = await MwlApi.i.getReviewList(category: category, page: page);
        return list.where((r) => (r.reviewText ?? '').trim().isNotEmpty).toList();
      },
    );
  }

  /// Newest interest stacks of [category], page [page].
  static Future<List<InterestStack>> interestStacks(String category, {int page = 1}) {
    return ExploreCache.instance.load('stacks:$category:$page', () async {
      final result = await MwlApi.i.getInterestStacks(stackType: category, page: page);
      final data = result?['data'];
      if (data is! List) return const <InterestStack>[];
      return [
        for (final e in data)
          if (e is Map) InterestStack.fromJson(Map<String, dynamic>.from(e)),
      ];
    });
  }

  static Future<List<RankedPersonHtml>> topCharacters({int page = 1}) =>
      ExploreCache.instance.load('chars:$page', () => MwlApi.i.getTopCharacters(page: page));

  static Future<List<RankedPersonHtml>> topPeople({int page = 1}) =>
      ExploreCache.instance.load('people:$page', () => MwlApi.i.getTopPeople(page: page));

  /// MAL genre groups of [category]; the explicit group only when the NSFW preference is on.
  static Future<List<GenreGroup>> genreGroups(String category) async {
    final groups = await ExploreCache.instance.load('genres:$category', () async {
      final result = await MwlApi.i.getGenres(category: category);
      final data = result?['data'];
      if (data is! Map) return const <GenreGroup>[];
      final list = GenreCategoryList.fromJson(Map<String, dynamic>.from(data));
      final merged = <String, List<({int id, String name, int count})>>{};
      for (final c in list.categories) {
        merged.putIfAbsent(c.type, () => []).addAll([
          for (final g in c.genres) (id: g.id, name: g.name, count: g.count ?? 0),
        ]);
      }
      return [for (final e in merged.entries) GenreGroup(e.key, e.value)];
    });
    final nsfw = Preferences.general.nsfw;
    return [
      for (final g in groups)
        if (nsfw || !g.isExplicit) g,
    ];
  }

  /// The id of a random anime or manga (Jikan, never cached). Honours the NSFW preference.
  static Future<int?> randomId(String category) async {
    final sfw = !Preferences.general.nsfw;
    final url = Uri.parse('${Constants.jikanV4}/random/$category?sfw=$sfw');
    final response = await JikanClient.instance.get(url, useCache: false);
    if (response.statusCode != 200) return null;
    final body = await MwlApi.decodeJson(response.body);
    final data = body is Map ? body['data'] : null;
    final id = data is Map ? data['mal_id'] : null;
    return id is int ? id : null;
  }

  /// A random id of the signed-in MyAnimeList user's list [status] (a MAL status word).
  /// Null when the list is empty; throws [NotSignedInException] without a MAL session.
  static Future<int?> randomFromList(String category, String status, {Random? random}) async {
    if (!UserManager.instance.isAuthenticated(AccountType.myanimelist)) {
      throw const NotSignedInException();
    }
    final url = '${MalApi.userBaseEndPoint}/@me/${category}list'
        '?fields=id&limit=1000&status=$status';
    final response = await MalApi.authorizedGet(url);
    if (response.statusCode != 200) throw Exception('list ${response.statusCode}');
    final body = await MwlApi.decodeJson(response.body);
    final data = body is Map ? body['data'] : null;
    final ids = <int>[
      if (data is List)
        for (final item in data)
          if (item is Map && item['node'] is Map && (item['node'] as Map)['id'] is int)
            (item['node'] as Map)['id'] as int,
    ];
    if (ids.isEmpty) return null;
    return ids[(random ?? Random()).nextInt(ids.length)];
  }
}

/// Thrown when an action needs a MyAnimeList session and there is none.
class NotSignedInException implements Exception {
  const NotSignedInException();
}
