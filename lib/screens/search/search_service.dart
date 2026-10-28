import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:mwl_commons/mwl_commons.dart' show MalSearchPageHtml, MalSearchQuery;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_queries.dart';
import 'package:mywatchlist/screens/search/search_sources.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime.dart' as jikan_model;
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/all_search_result.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/services/api/MAL/models/mal_user_search.dart';
import 'package:mywatchlist/services/api/MAL/models/search_result.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/html_parsers.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// What one search asks for.
@immutable
class SearchRequest {
  final String category;
  final String query;
  final SearchFilters filters;

  const SearchRequest({
    required this.category,
    required this.query,
    this.filters = SearchFilters.empty,
  });
}

/// The results of one search and what is needed to ask for the next page. One object per
/// search; the screen replaces it on every new search.
class SearchPage {
  /// The category that was searched. A special query may change it (`#all@manga` is a manga
  /// search whatever the picker said).
  String category;

  /// Anime, manga, characters and people.
  List<Anime> media = [];
  AllSearchResult? all;
  List<ForumTopicsData> forum = [];
  List<MalUserNode> users = [];
  List<Map<String, dynamic>> clubs = [];
  List<AnimeNewsOrFeaturedItem> articles = [];
  List<Map<String, dynamic>> stacks = [];

  /// MyAnimeList paging of the last anime / manga page.
  SearchResult? paged;

  /// The user name to offer as "User found as …" when MyAnimeList knows a profile of that name
  /// that the user list does not show.
  String? foundUser;

  bool hasMore = false;

  /// Where the anime, manga, character or person rows came from; the next pages ask the same
  /// source.
  MediaSource? source;
  int _jikanPage = 1;
  int _malPage = 1;
  int _userOffset = 0;
  int _forumOffset = 0;
  int _clubPage = 1;
  int _stackPage = 1;
  int _articlePage = 1;

  SearchPage(this.category);

  bool get hasResults {
    switch (category) {
      case SearchCategory.all:
        return all != null && all!.categories.values.any((l) => l.isNotEmpty);
      case SearchCategory.forum:
        return forum.isNotEmpty;
      case SearchCategory.user:
        return users.isNotEmpty || foundUser != null;
      case SearchCategory.club:
        return clubs.isNotEmpty;
      case SearchCategory.interestStack:
        return stacks.isNotEmpty;
      case SearchCategory.news:
      case SearchCategory.featured:
        return articles.isNotEmpty;
      default:
        return media.isNotEmpty;
    }
  }
}

/// Runs searches. Everything here is network and parsing, no widget: the screen only keeps the
/// [SearchPage] it gets back.
///
/// Anime and manga text without filters goes to MyAnimeList's API. Filters (MyAnimeList's API
/// has none), characters and people go to Jikan and, at the same time, to MyAnimeList's own
/// search page (`anime.php`, `manga.php`, `character.php`, `people.php` through the mwl-api
/// `search/content` route): the first source with rows wins, so a network where Jikan is
/// unreachable still gets results. "Jikan" here is Jikan or, when Jikan is down, Tenrai (same
/// schema, chosen by `JikanSource` inside `JikanClient`); it is skipped while `JikanClient`
/// knows both are down. Text
/// of one or two characters can only go to Jikan (MyAnimeList refuses it). Every search is
/// bounded by [searchBudget]; a failure is thrown as is and the screen asks [SearchFailures]
/// whether the network or the source failed.
class SearchService {
  const SearchService();

  /// Longest wait for one search or one next page, every source included.
  static const Duration searchBudget = Duration(seconds: 30);

  /// Rows of MyAnimeList's search page.
  static const int malPageSize = MalSearchQuery.pageSize;

  /// MyAnimeList's search page (replaceable in tests).
  static Future<MalSearchPageHtml?> Function({
    required String category,
    String query,
    Map<String, Object?> filters,
    int page,
  }) malSearchPage = _malSearchPage;

  /// Whether Jikan is tried at all (tests turn it off).
  static bool Function() jikanAllowed = () => !JikanClient.instance.isUnreachable;

  /// GET of a MyAnimeList profile page for the "user found" shortcut (replaceable in tests).
  static Future<http.Response> Function(Uri url) profileGet = http.get;

  /// Longest wait for the profile probe (the user results wait for it).
  static const Duration profileProbeTimeout = Duration(seconds: 8);

  @visibleForTesting
  static void reset() {
    malSearchPage = _malSearchPage;
    profileGet = http.get;
    jikanAllowed = () => !JikanClient.instance.isUnreachable;
  }

  static Future<MalSearchPageHtml?> _malSearchPage({
    required String category,
    String query = '',
    Map<String, Object?> filters = const {},
    int page = 1,
  }) =>
      MwlApi.i.searchContentPage(category: category, query: query, filters: filters, page: page);

  static const int mediaPageSize = 30;
  static const int jikanPageSize = 25;
  static const int _userPageSize = 24;
  static const int _forumPageSize = 30;
  static const int _stackPageSize = 10;

  Future<SearchPage> search(SearchRequest request) => _search(request).timeout(searchBudget);

  Future<void> loadMore(SearchPage page, SearchRequest request) =>
      _loadMore(page, request).timeout(searchBudget);

  Future<SearchPage> _search(SearchRequest request) async {
    final query = request.query.trim();
    if (query.startsWith('#')) {
      final special = SpecialQuery.parse(query.substring(1));
      if (special != null) return _special(special);
    }
    final page = SearchPage(request.category);
    final filters = request.filters.forCategory(request.category);
    switch (request.category) {
      case SearchCategory.all:
        await _all(page, query);
      case SearchCategory.anime:
      case SearchCategory.manga:
        await _media(page, query, filters);
      case SearchCategory.character:
      case SearchCategory.person:
        await _people(page, query);
      case SearchCategory.forum:
        await _forum(page, query, filters);
      case SearchCategory.user:
        await _users(page, query, filters);
      case SearchCategory.club:
        await _clubs(page, query);
      case SearchCategory.featured:
      case SearchCategory.news:
        await _articles(page, query, filters);
      case SearchCategory.interestStack:
        await _stacks(page, query, filters);
    }
    return page;
  }

  Future<void> _loadMore(SearchPage page, SearchRequest request) async {
    final query = request.query.trim();
    final filters = request.filters.forCategory(page.category);
    switch (page.category) {
      case SearchCategory.forum:
        page._forumOffset += _forumPageSize;
        final result = await _forumTopics(query, filters, page._forumOffset);
        page.forum.addAll(result);
        page.hasMore = result.length >= _forumPageSize;
      case SearchCategory.user:
        page._userOffset += _userPageSize;
        final result = await _userPage(query, filters, page._userOffset);
        page.users.addAll(result);
        page.hasMore = result.length >= _userPageSize;
      case SearchCategory.club:
        page._clubPage++;
        final result = await MwlApi.i.searchClubs(query, page: page._clubPage);
        final clubs = (result?['clubs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        page.clubs.addAll(clubs);
        page.hasMore = clubs.isNotEmpty;
      case SearchCategory.interestStack:
        page._stackPage++;
        final stacks = await MwlApi.i.searchInterestStacks(
          query,
          type: filters.text(FilterKey.stackType),
          page: page._stackPage,
        );
        page.stacks.addAll(stacks);
        page.hasMore = stacks.length >= _stackPageSize;
      case SearchCategory.news:
      case SearchCategory.featured:
        page._articlePage++;
        final result = await _articlePage(page.category, query, filters, page._articlePage);
        page.articles.addAll(result?.newsorfeatured ?? []);
        page.hasMore = _hasNext(result);
      default:
        if (page.source == MediaSource.jikan) {
          page._jikanPage++;
          final items = SearchCategory.isMedia(page.category)
              ? await _jikanPageOf(page.category, query, filters, page._jikanPage)
              : await _peoplePage(page.category, query, page._jikanPage);
          page.media.addAll(items);
          page.hasMore = items.length >= jikanPageSize;
        } else if (page.source == MediaSource.malPage) {
          page._malPage++;
          final answer = await _malPageOf(page.category, query, filters, page._malPage);
          final known = {for (final a in page.media) a.id};
          page.media.addAll(answer.items.where((a) => known.add(a.id)));
          page.hasMore = answer.hasMore;
        } else {
          final paging = page.paged?.paging;
          if (paging == null || !(page.paged?.hasNextPage ?? false)) {
            page.hasMore = false;
            return;
          }
          final next = await MalApi.getContentListPage(paging, next: true);
          page.media.addAll(next.data);
          page.paged = next;
          page.hasMore = next.hasNextPage;
        }
    }
  }

  // --- Special queries ---------------------------------------------------------------------

  Future<SearchPage> _special(SpecialQuery special) async {
    final String category;
    final SearchResult result;
    switch (special) {
      case RankingQuery():
        category = special.category;
        result = await MalApi.getContentRankingResult(special.type, limit: mediaPageSize, category: category);
      case MangaRankingQuery():
        category = SearchCategory.manga;
        result = await MalApi.getContentRankingResult(special.type, limit: mediaPageSize, category: category);
      case SeasonQuery():
        category = SearchCategory.anime;
        result = await MalApi.getAnimeSeasonalResult(special.season, special.year, limit: mediaPageSize);
      case SuggestedQuery():
        category = special.category;
        result = await MalApi.getContentSuggestionsResult(limit: mediaPageSize, category: category);
    }
    final page = SearchPage(category);
    page.paged = result;
    page.media = List.of(result.data);
    page.hasMore = result.hasNextPage;
    return page;
  }

  // --- All -----------------------------------------------------------------------------------

  Future<void> _all(SearchPage page, String query) async {
    final idHits = isIdQuery(query)
        ? Future.wait([_idHit(SearchCategory.anime, query), _idHit(SearchCategory.manga, query)])
        : null;
    final probe = _probeUser(query);
    final all = await MalApi.searchAllCategories(query);
    final hits = await idHits;
    if (all != null && hits != null) {
      for (final (index, category) in const [SearchCategory.anime, SearchCategory.manga].indexed) {
        final hit = hits[index];
        if (hit == null) continue;
        final list = all.categories[category] ?? [];
        all.categories[category] = [hit, ...list.where((a) => a.id != hit.id)];
      }
    }
    page.all = all;
    page.foundUser = await probe;
  }

  // --- Anime and manga -------------------------------------------------------------------------

  Future<void> _media(SearchPage page, String query, SearchFilters filters) async {
    final manga = page.category == SearchCategory.manga;
    final idHit = filters.isEmpty && isIdQuery(query) ? _idHit(page.category, query) : null;
    final official = filters.isEmpty && query.length >= MalSearchQuery.minQueryLength;
    SourceAnswer answer;
    if (official) {
      try {
        final text = Uri.encodeComponent(query);
        final result = manga
            ? await MalApi().searchMangaResult(text, limit: mediaPageSize)
            : await MalApi().searchAnimeResult(text, limit: mediaPageSize);
        page.paged = result;
        answer = SourceAnswer(MediaSource.malApi, List.of(result.data), hasMore: result.hasNextPage);
      } catch (e) {
        debugPrint('MAL API search failed, trying the search page: $e');
        answer = await _malPageOf(page.category, query, filters, 1);
      }
    } else {
      answer = await _jikanOrMalPage(
        page.category,
        query,
        jikan: () => _jikanPageOf(page.category, query, filters, 1),
        malPage: () => _malPageOf(page.category, query, filters, 1),
      );
    }
    page.source = answer.source;
    page.media = answer.items;
    page.hasMore = answer.hasMore;
    final hit = await idHit;
    if (hit != null) {
      page.media = [hit, ...page.media.where((a) => a.id != hit.id)];
    }
  }

  /// Jikan as a fast path next to MyAnimeList's search page (see the class comment). A text
  /// too short for MyAnimeList only asks Jikan and fails as [SearchFailureKind.tooShort].
  Future<SourceAnswer> _jikanOrMalPage(
    String category,
    String query, {
    required Future<List<Anime>> Function() jikan,
    required Future<SourceAnswer> Function() malPage,
  }) async {
    Future<SourceAnswer> viaJikan() async {
      final items = await jikan();
      return SourceAnswer(MediaSource.jikan, items, hasMore: items.length >= jikanPageSize);
    }

    if (MalSearchQuery.isTooShort(query)) {
      if (!jikanAllowed()) throw const SearchFailure(SearchFailureKind.tooShort);
      try {
        return await viaJikan();
      } catch (e) {
        throw SearchFailure(SearchFailureKind.tooShort, e);
      }
    }
    return firstUseful([
      if (jikanAllowed()) viaJikan(),
      malPage(),
    ]);
  }

  /// One page of MyAnimeList's own search page; throws when it failed.
  Future<SourceAnswer> _malPageOf(
    String category,
    String query,
    SearchFilters filters,
    int pageNumber,
  ) async {
    final result = await malSearchPage(
      category: category,
      query: query,
      filters: filters.toApiMap(),
      page: pageNumber,
    );
    if (result == null) throw StateError('MyAnimeList search page failed');
    if (result.tooShort) throw const SearchFailure(SearchFailureKind.tooShort);
    final nsfw = Preferences.general.nsfw;
    final items = [
      for (final row in result.items)
        if (nsfw || row.rated != 'Rx') animeFromMalPage(row),
    ];
    return SourceAnswer(MediaSource.malPage, items, hasMore: result.hasNext);
  }

  /// One MyAnimeList entry by id, as a search hit; null when the id does not exist.
  Future<Anime?> _idHit(String category, String query) async {
    final id = int.tryParse(query.trim());
    if (id == null || id <= 0) return null;
    try {
      final result = await MalApi().searchById(id, category: category);
      return result.data.isEmpty ? null : result.data.first;
    } catch (_) {
      return null;
    }
  }

  Future<List<Anime>> _jikanPageOf(
    String category,
    String query,
    SearchFilters filters,
    int pageNumber,
  ) async {
    final jikan = JikanApi();
    final manga = category == SearchCategory.manga;
    final text = query.isEmpty ? null : query;
    final minScore = filters.integer(FilterKey.score)?.toDouble();
    final genres = _ids(filters.genresIn);
    final genresOut = _ids(filters.genresOut);
    final sfw = Preferences.general.nsfw ? null : true;
    final sort = filters.text(FilterKey.sort);
    final items = manga
        ? await jikan.getMangaSearch(
            q: text,
            page: pageNumber,
            limit: jikanPageSize,
            type: filters.text(FilterKey.type),
            status: filters.text(FilterKey.status),
            orderBy: filters.text(FilterKey.orderBy),
            sort: sort,
            minScore: minScore,
            letter: filters.text(FilterKey.letter),
            genres: genres,
            genresExclude: genresOut,
            magazines: filters.integer(FilterKey.magazine)?.toString(),
            startDate: filters.text(FilterKey.startDate),
            endDate: filters.text(FilterKey.endDate),
            sfw: sfw,
          )
        : await jikan.getAnimeSearch(
            q: text,
            page: pageNumber,
            limit: jikanPageSize,
            type: _enumByValue(AnimeSearchQueryType.values, (e) => e.value, filters.text(FilterKey.type)),
            status: _enumByValue(AnimeSearchQueryStatus.values, (e) => e.value, filters.text(FilterKey.status)),
            rating: _enumByValue(AnimeSearchQueryRating.values, (e) => e.value, filters.text(FilterKey.rating)),
            orderBy: _enumByValue(AnimeSearchQueryOrderBy.values, (e) => e.value, filters.text(FilterKey.orderBy)),
            sort: _enumByValue(SearchQuerySort.values, (e) => e.value, sort),
            minScore: minScore,
            letter: filters.text(FilterKey.letter),
            genres: genres,
            genresExclude: genresOut,
            producers: filters.integer(FilterKey.producer)?.toString(),
            startDate: filters.text(FilterKey.startDate),
            endDate: filters.text(FilterKey.endDate),
            sfw: sfw,
          );
    return items.map(jikanToAnime).toList();
  }

  static String? _ids(List<int> ids) => ids.isEmpty ? null : ids.join(',');

  static T? _enumByValue<T>(List<T> values, String Function(T) valueOf, String? value) {
    if (value == null) return null;
    for (final candidate in values) {
      if (valueOf(candidate) == value) return candidate;
    }
    return null;
  }

  @visibleForTesting
  static Anime jikanToAnime(jikan_model.JikanAnime j) {
    return Anime(
      id: j.malId ?? 0,
      title: j.title ?? '',
      imageUrl: j.images?.jpg?.largeImageUrl ?? j.images?.jpg?.imageUrl ?? '',
      score: (j.score ?? 0.0).toDouble(),
      members: (j.members ?? 0).toInt(),
      rank: j.rank,
      popularity: j.popularity,
      synopsis: j.synopsis,
      numEpisodes: j.episodes,
      startDate: j.aired?.from,
      endDate: j.aired?.to,
      mediaType: j.type,
      status: j.status,
      broadcast: j.broadcast != null && j.broadcast!.day != null
          ? Broadcast(
              dayOfTheWeek: j.broadcast!.day!.toLowerCase(),
              startTime: j.broadcast!.time ?? '',
            )
          : null,
      genres: [
        ...(j.genres ?? []).map((g) => g.name ?? ''),
        ...(j.themes ?? []).map((g) => g.name ?? ''),
      ],
    );
  }

  // --- Characters and people ---------------------------------------------------------------

  Future<void> _people(SearchPage page, String query) async {
    final answer = await _jikanOrMalPage(
      page.category,
      query,
      jikan: () => _peoplePage(page.category, query, 1),
      malPage: () => _malPageOf(page.category, query, SearchFilters.empty, 1),
    );
    page.source = answer.source;
    page.media = answer.items;
    page.hasMore = answer.hasMore;
  }

  Future<List<Anime>> _peoplePage(String category, String query, int pageNumber) async {
    final jikan = JikanApi();
    if (category == SearchCategory.character) {
      final chars = await jikan.searchCharacters(q: query, page: pageNumber, limit: jikanPageSize);
      return [
        for (final c in chars)
          Anime(
            id: c.malId ?? 0,
            title: c.name ?? '',
            imageUrl: c.images?.jpg?.imageUrl ?? '',
            score: (c.favorites ?? 0).toDouble(),
            members: c.favorites ?? 0,
          ),
      ];
    }
    final people = await jikan.searchPeople(q: query, page: pageNumber, limit: jikanPageSize);
    return [
      for (final p in people)
        Anime(
          id: p.malId ?? 0,
          title: p.name ?? '',
          imageUrl: p.images?.jpg?.imageUrl ?? '',
          score: (p.favorites ?? 0).toDouble(),
          members: p.favorites ?? 0,
        ),
    ];
  }

  // --- Forum --------------------------------------------------------------------------------

  Future<void> _forum(SearchPage page, String query, SearchFilters filters) async {
    page._forumOffset = 0;
    page.forum = await _forumTopics(query, filters, 0);
    page.hasMore = page.forum.length >= _forumPageSize;
  }

  Future<List<ForumTopicsData>> _forumTopics(String query, SearchFilters filters, int offset) async {
    final result = await MalForumApi().getForumTopics(
      q: query.isEmpty ? null : query,
      boardId: filters.integer(FilterKey.boardId),
      subboardId: filters.integer(FilterKey.subboardId),
      topicUserName: filters.text(FilterKey.topicUser),
      userName: filters.text(FilterKey.user),
      limit: _forumPageSize,
      offset: offset,
    );
    return result?.data ?? [];
  }

  // --- Users ---------------------------------------------------------------------------------

  Future<void> _users(SearchPage page, String query, SearchFilters filters) async {
    page._userOffset = 0;
    final probe = _probeUser(query);
    page.users = await _userPage(query, filters, 0);
    page.hasMore = page.users.length >= _userPageSize;
    final found = await probe;
    final exact = page.users.any((u) => u.username.toLowerCase() == query.trim().toLowerCase());
    page.foundUser = exact ? null : found;
  }

  /// MyAnimeList's user search. Its API has no filters, so with filters on the search page is
  /// read directly (the shared route only takes the text).
  Future<List<MalUserNode>> _userPage(String query, SearchFilters filters, int offset) async {
    if (filters.isEmpty) {
      final result = await MwlApi.i.searchUsers(query, offset: offset);
      return result?.users ?? [];
    }
    final params = <String, String>{
      'cat': 'user',
      if (query.isNotEmpty) 'q': query,
      if (filters.text(FilterKey.location) != null) 'loc': filters.text(FilterKey.location)!,
      if (filters.integer(FilterKey.ageLow) != null) 'agelow': '${filters.integer(FilterKey.ageLow)}',
      if (filters.integer(FilterKey.ageHigh) != null) 'agehigh': '${filters.integer(FilterKey.ageHigh)}',
      if (filters.integer(FilterKey.gender) != null) 'g': '${filters.integer(FilterKey.gender)}',
      'show': '$offset',
    };
    final response = await http.get(Uri.https('myanimelist.net', '/users.php', params));
    if (response.statusCode != 200) throw Exception('User search failed (${response.statusCode})');
    return compute(_parseUsers, response.body);
  }

  /// The profile of [query] when it exists on MyAnimeList, else null: MyAnimeList's own
  /// profile page (`/profile/<name>`, 200 or 404), so the shortcut works without Jikan
  /// (Tenrai has no user endpoints). The name keeps MyAnimeList's casing (`og:url`). Any
  /// failure answers null: the shortcut is a bonus.
  Future<String?> _probeUser(String query) async {
    final name = query.trim();
    if (!looksLikeUsername(name)) return null;
    try {
      final response = await profileGet(
              Uri.https('myanimelist.net', '/profile/${Uri.encodeComponent(name)}'))
          .timeout(profileProbeTimeout);
      if (response.statusCode != 200) return null;
      return canonicalProfileName(response.body, name);
    } catch (_) {
      return null;
    }
  }

  // --- Clubs, articles, stacks ---------------------------------------------------------------

  Future<void> _clubs(SearchPage page, String query) async {
    page._clubPage = 1;
    final result = await MwlApi.i.searchClubs(query, page: 1);
    page.clubs = (result?['clubs'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    page.hasMore = page.clubs.isNotEmpty;
  }

  Future<void> _articles(SearchPage page, String query, SearchFilters filters) async {
    page._articlePage = 1;
    final result = await _articlePage(page.category, query, filters, 1);
    page.articles = result?.newsorfeatured ?? [];
    page.hasMore = _hasNext(result);
  }

  Future<AnimeNewsOrFeaturedResult?> _articlePage(
    String category,
    String query,
    SearchFilters filters,
    int pageNumber,
  ) {
    final tag = filters.text(FilterKey.tag);
    return category == SearchCategory.news
        ? MwlApi.i.searchNews(query, tag: tag, page: pageNumber)
        : MwlApi.i.searchFeatured(query, tag: tag, page: pageNumber);
  }

  static bool _hasNext(AnimeNewsOrFeaturedResult? result) {
    final next = result?.paging.next;
    return next != null && next.isNotEmpty;
  }

  Future<void> _stacks(SearchPage page, String query, SearchFilters filters) async {
    page._stackPage = 1;
    page.stacks = await MwlApi.i.searchInterestStacks(
      query,
      type: filters.text(FilterKey.stackType),
      page: 1,
    );
    page.hasMore = page.stacks.length >= _stackPageSize;
  }

  /// Up to [limit] titles for the autocomplete under the search field. Uses the MyAnimeList
  /// search (one small request) for three letters or more.
  Future<List<Anime>> suggest(String category, String query, {int limit = 6}) async {
    final text = query.trim();
    if (text.length < 3) return const [];
    final encoded = Uri.encodeComponent(text);
    const fields = ['id', 'title', 'main_picture', 'media_type', 'mean', 'num_list_users'];
    final result = category == SearchCategory.manga
        ? await MalApi().searchMangaResult(encoded, limit: limit, fields: fields)
        : await MalApi().searchAnimeResult(encoded, limit: limit, fields: fields);
    return result.data;
  }
}

List<MalUserNode> _parseUsers(String body) =>
    HtmlParsers.parseUserSearch(html_parser.parse(body)).users;

final RegExp _ogProfileUrl = RegExp(
    r"""<meta\s+property=["']og:url["']\s+content=["']https?://myanimelist\.net/profile/([^"'/?#]+)""");

/// The user name of a MyAnimeList profile page as MyAnimeList spells it (from its `og:url`
/// meta tag, in the page head), else [typed].
@visibleForTesting
String canonicalProfileName(String body, String typed) {
  final head = body.length > 40000 ? body.substring(0, 40000) : body;
  final match = _ogProfileUrl.firstMatch(head)?.group(1);
  if (match == null || match.isEmpty) return typed;
  try {
    final name = Uri.decodeComponent(match);
    return name.toLowerCase() == typed.toLowerCase() ? name : typed;
  } catch (_) {
    return typed;
  }
}
