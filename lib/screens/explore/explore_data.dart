import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:mwl_commons/mwl_commons.dart'
    show
        GenreCategoryList,
        GlobalRecommendationHtml,
        HtmlParsers,
        InterestStack,
        PageParsers,
        RankedPersonHtml,
        ReviewHtml;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/search/data/anime_genres.dart' as anime_genres;
import 'package:mywatchlist/screens/search/data/manga_genres.dart' as manga_genres;
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
class CommunityRecommendation {
  final RecoRef first;
  final RecoRef second;
  final String? username;
  final String? text;

  /// ISO date of the recommendation, as Jikan gives it.
  final String? date;

  const CommunityRecommendation({
    required this.first,
    required this.second,
    this.username,
    this.text,
    this.date,
  });

  /// From one element of Jikan's `recommendations/{anime|manga}` list; null when malformed.
  static CommunityRecommendation? fromJikan(Object? json) {
    if (json is! Map) return null;
    final entry = json['entry'];
    if (entry is! List || entry.length < 2) return null;
    final first = _ref(entry[0]);
    final second = _ref(entry[1]);
    if (first == null || second == null) return null;
    final user = json['user'];
    final text = json['content'];
    return CommunityRecommendation(
      first: first,
      second: second,
      username: user is Map && user['username'] is String ? user['username'] as String : null,
      text: text is String && text.trim().isNotEmpty ? text.trim() : null,
      date: json['date'] is String ? json['date'] as String : null,
    );
  }

  /// From one row of MyAnimeList's recommendation feed (mwl-api or the page read on the
  /// device); null when a side has no id.
  static CommunityRecommendation? fromHtml(GlobalRecommendationHtml row) {
    final first = row.source;
    final second = row.recommended;
    if (first.id == null || second.id == null) return null;
    final text = row.text?.trim();
    return CommunityRecommendation(
      first: RecoRef(id: first.id!, title: first.title ?? '', imageUrl: first.image?.best),
      second: RecoRef(id: second.id!, title: second.title ?? '', imageUrl: second.image?.best),
      username: row.username,
      text: text == null || text.isEmpty ? null : text,
      date: row.timeAdded,
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

/// A group of genres as MAL shows it (Genres, Explicit Genres, Themes, Demographics), from the
/// app's own MyAnimeList genre tables: it never needs the network.
@immutable
class GenreGroup {
  /// MAL's English name of the group (`Explicit Genres`), also the key of its picture.
  final String type;

  /// Genre ids in MAL's order.
  final List<int> ids;

  const GenreGroup(this.type, this.ids);

  static const String explicitType = 'Explicit Genres';

  bool get isExplicit => type == explicitType;
}

/// One source of a [ExploreSources.firstNonEmpty] race: started after [delay] (or as soon as
/// every source started before it ended without rows). [load] gives null or throws on failure.
class ExploreSource<T> {
  final Duration delay;
  final Future<List<T>?> Function() load;

  const ExploreSource(this.load, {this.delay = Duration.zero});
}

/// Several sources for one Explore section; the first that gives rows wins.
abstract final class ExploreSources {
  /// Longest wait of a whole section.
  static Duration budget = const Duration(seconds: 15);

  /// Runs [sources] (each after its delay), completes with the first non-empty list. When
  /// every source ended, or [budget] ran out, it gives an empty list if one source answered
  /// "nothing", else it throws, so the section shows "Try again".
  static Future<List<T>> firstNonEmpty<T>(List<ExploreSource<T>> sources, {Duration? budget}) {
    final completer = Completer<List<T>>();
    final timers = <int, Timer>{};
    final started = <int>{};
    var ended = 0;
    var answeredEmpty = false;
    Object? lastError;
    Timer? budgetTimer;

    void finish() {
      if (completer.isCompleted) return;
      for (final timer in timers.values) {
        timer.cancel();
      }
      budgetTimer?.cancel();
      if (answeredEmpty) {
        completer.complete(<T>[]);
      } else {
        completer.completeError(lastError ?? StateError('No source answered'));
      }
    }

    late void Function(int) start;

    void ended1() {
      ended++;
      if (completer.isCompleted) return;
      if (ended == sources.length) return finish();
      if (ended == started.length) {
        // Everything running has failed: start the next one now, without waiting.
        for (var i = 0; i < sources.length; i++) {
          if (!started.contains(i)) return start(i);
        }
      }
    }

    start = (int i) {
      if (completer.isCompleted || !started.add(i)) return;
      timers.remove(i)?.cancel();
      Future<List<T>?>.sync(sources[i].load).then((rows) {
        if (completer.isCompleted) return;
        if (rows != null && rows.isNotEmpty) {
          for (final timer in timers.values) {
            timer.cancel();
          }
          budgetTimer?.cancel();
          completer.complete(rows);
          return;
        }
        if (rows != null) answeredEmpty = true;
        ended1();
      }, onError: (Object error) {
        lastError = error;
        ended1();
      });
    };

    if (sources.isEmpty) {
      finish();
      return completer.future;
    }
    budgetTimer = Timer(budget ?? ExploreSources.budget, finish);
    for (var i = 0; i < sources.length; i++) {
      final delay = sources[i].delay;
      if (delay <= Duration.zero) {
        start(i);
      } else {
        timers[i] = Timer(delay, () => start(i));
      }
    }
    return completer.future;
  }
}

/// MyAnimeList pages read on the device (the source that needs neither Jikan nor mwl-api).
abstract final class ExploreMalPages {
  static Duration timeout = const Duration(seconds: 10);

  /// GET of one page, body as text; throws on a non-200 status or after [timeout]. Replaceable
  /// in tests.
  static Future<String> Function(Uri url) fetch = _fetch;

  /// Tests parse on the calling isolate.
  @visibleForTesting
  static bool parseInline = false;

  static Future<String> _fetch(Uri url) async {
    final response = await http.get(url, headers: const {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      'Accept-Language': 'en-US,en;q=0.9',
    }).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', url);
    }
    return response.body;
  }

  static Future<R> _parse<A, R>(R Function(A) parser, A input) =>
      parseInline ? Future.value(parser(input)) : compute(parser, input);

  /// MAL's feed of the latest recommendations (`recommendations.php?s=recentrecs`, 100 rows).
  static Future<List<GlobalRecommendationHtml>> recommendations(String category) async {
    final body = await fetch(Uri.parse(
        'https://myanimelist.net/recommendations.php?s=recentrecs&t=$category&show=0'));
    return _parse(parseRecommendations, (body: body, category: category));
  }

  /// One page of MAL's interest stack listing (`/stacks/search?type=`).
  static Future<List<InterestStack>> interestStacks(String category, int page) async {
    final body =
        await fetch(Uri.parse('https://myanimelist.net/stacks/search?type=$category&p=$page'));
    return _parse(parseStacks, body);
  }

  /// A page without MAL's content wrapper (challenge, maintenance) is an error, never "none".
  static void _checkPage(String body) {
    if (!body.contains('contentWrapper')) throw const FormatException('Not a MyAnimeList page');
  }

  @visibleForTesting
  static List<GlobalRecommendationHtml> parseRecommendations(
      ({String body, String category}) input) {
    _checkPage(input.body);
    return PageParsers.parseRecentRecommendations(html.parse(input.body), input.category);
  }

  @visibleForTesting
  static List<InterestStack> parseStacks(String body) {
    _checkPage(body);
    return [
      for (final row in HtmlParsers.parseInterestStackSearch(html.parse(body)))
        InterestStack.fromJson(row),
    ];
  }
}

/// What the Explore page downloads, each call cached by [ExploreCache].
class ExploreData {
  ExploreData._();

  /// Latest recommendations of the whole community, [limit] at most.
  ///
  /// MyAnimeList's own feed, read on the device and through mwl-api at once (neither needs
  /// Jikan, which is unreachable on some networks); Jikan joins after 4 s or as soon as both
  /// failed. The full list is cached once per category, the strip and "View all" share it.
  static Future<List<CommunityRecommendation>> recommendations(String category,
      {int limit = 25}) async {
    final all = await ExploreCache.instance.load('reco:$category', () {
      List<CommunityRecommendation> fromRows(List<GlobalRecommendationHtml> rows) => [
            for (final row in rows)
              if (CommunityRecommendation.fromHtml(row) case final r?) r,
          ];
      return ExploreSources.firstNonEmpty<CommunityRecommendation>([
        ExploreSource(() async => fromRows(await ExploreMalPages.recommendations(category))),
        ExploreSource(() async {
          final rows = await MwlApi.i.getGlobalRecommendations(category: category);
          return rows == null ? null : fromRows(rows);
        }),
        ExploreSource(() => _jikanRecommendations(category), delay: const Duration(seconds: 4)),
      ]);
    });
    return all.take(limit).toList();
  }

  static Future<List<CommunityRecommendation>> _jikanRecommendations(String category) async {
    final url = Uri.parse('${Constants.jikanV4}/recommendations/$category');
    final response = await JikanClient.instance.get(url);
    if (response.statusCode != 200) throw Exception('recommendations ${response.statusCode}');
    final body = await MwlApi.decodeJson(response.body);
    final data = body is Map ? body['data'] : null;
    if (data is! List) return const <CommunityRecommendation>[];
    return [
      for (final item in data)
        if (CommunityRecommendation.fromJikan(item) case final r?) r,
    ];
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

  /// Newest interest stacks of [category], page [page]: MAL's listing read on the device and
  /// through mwl-api at once, the first with rows wins.
  static Future<List<InterestStack>> interestStacks(String category, {int page = 1}) {
    return ExploreCache.instance.load(
      'stacks:$category:$page',
      () => ExploreSources.firstNonEmpty<InterestStack>([
        ExploreSource(() => ExploreMalPages.interestStacks(category, page)),
        ExploreSource(() => MwlApi.i.getInterestStackList(stackType: category, page: page)),
      ]),
    );
  }

  static Future<List<RankedPersonHtml>> topCharacters({int page = 1}) =>
      ExploreCache.instance.load('chars:$page', () => MwlApi.i.getTopCharacters(page: page));

  static Future<List<RankedPersonHtml>> topPeople({int page = 1}) =>
      ExploreCache.instance.load('people:$page', () => MwlApi.i.getTopPeople(page: page));

  /// MAL genre groups of [category], in MAL's order, explicit genres included (the page
  /// decides how to show them with the NSFW preference). Offline: never fails.
  static List<GenreGroup> genreGroups(String category) {
    final manga = category == 'manga';
    final names = manga ? manga_genres.mangaGenreGroupNames : anime_genres.animeGenreGroupNames;
    final ids = manga ? manga_genres.mangaGenreGroupIds : anime_genres.animeGenreGroupIds;
    return [
      for (var i = 0; i < names.length && i < ids.length; i++) GenreGroup(names[i], ids[i]),
    ];
  }

  /// Number of titles of each genre of [category] (mwl-api, cached); empty when unavailable,
  /// the genres still show without counts.
  static Future<Map<int, int>> genreCounts(String category) async {
    try {
      return await ExploreCache.instance.load('genre-counts:$category', () async {
        final result = await MwlApi.i
            .getGenres(category: category)
            .timeout(const Duration(seconds: 12));
        final data = result?['data'];
        if (data is! Map) throw StateError('No genre counts');
        final list = GenreCategoryList.fromJson(Map<String, dynamic>.from(data));
        return <int, int>{
          for (final c in list.categories)
            for (final g in c.genres)
              if ((g.count ?? 0) > 0) g.id: g.count!,
        };
      });
    } catch (_) {
      return const {};
    }
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
