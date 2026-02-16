// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/screens/search/search_history.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime.dart' as jikan_model;
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/screens/forum/club_screen.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/services/api/MAL/models/all_search_result.dart';
import 'package:mywatchlist/services/api/MAL/models/mal_user_search.dart';
import 'package:mywatchlist/services/api/MAL/models/search_result.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_news_featured.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/MAL/search/filtermodal.dart';
import 'package:mywatchlist/widgets/MAL/search/headerwidget.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

enum SearchStage { notStarted, started, loaded, empty }

class GeneralSearchScreen extends StatefulWidget {
  final String? searchQuery;
  final bool autoFocus;
  final bool showBackButton;
  final String category;
  final Map<String, FilterOption>? filterOutputs;

  const GeneralSearchScreen({
    super.key,
    this.searchQuery,
    this.category = 'all',
    this.showBackButton = false,
    this.autoFocus = false,
    this.filterOutputs,
  });

  @override
  State<GeneralSearchScreen> createState() => _GeneralSearchScreenState();
}

class _GeneralSearchScreenState extends State<GeneralSearchScreen>
    with TickerProviderStateMixin {
  SearchStage _stage = SearchStage.notStarted;
  SearchStage _loadMoreStage = SearchStage.notStarted;

  SearchResult? _searchResult;
  AllSearchResult? _allSearchResult;
  List<Anime> _results = [];
  bool _isSpecialQuery = false;
  bool _showFilter = false;

  // Category-specific results
  List<ForumTopicsData> _forumResults = [];
  List<MalUserNode> _userResults = [];
  List<Map<String, dynamic>> _clubResults = [];
  List<AnimeNewsOrFeaturedItem> _newsOrFeaturedResults = [];
  int _newsOrFeaturedPage = 1;
  int _clubPage = 1;
  int _userOffset = 0;
  int _forumOffset = 0;
  bool _hasMoreResults = false;

  final FocusNode _focusNode = FocusNode(canRequestFocus: true);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SearchHistory _history = SearchHistory.instance;

  late String _category;
  String _prevQuery = '';
  Map<String, FilterOption> _filterOutputs = {};

  // Display settings (loaded from SearchHistory persistence)
  late DisplayType _displayType;
  late DisplaySubType _displaySubType;
  late int _gridAxisCount;
  late double _gridHeight;

  late TabController _tabController;

  List<String> _allSectionSearch = [
    'anime',
    'manga',
    'character',
    'person',
  ];

  // Character and person searches use Jikan API

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _filterOutputs = widget.filterOutputs ?? {};
    _tabController = TabController(
      length: _allSectionSearch.length,
      vsync: this,
    );

    _history.load();

    // Restore persisted display settings
    _displayType = _history.displayType;
    _displaySubType = _history.displaySubType;
    _gridAxisCount = _history.gridAxisCount;
    _gridHeight = _history.gridHeight;

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      _searchController.text = widget.searchQuery!;
      if (widget.searchQuery!.startsWith('#')) {
        _isSpecialQuery = true;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startSearch(_searchController.text);
      });
    } else if (_filterOutputs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startSearch('');
      });
    }

    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchTextChanged() {
    final text = _searchController.text;

    if (text.startsWith('#')) {
      if (!_isSpecialQuery) setState(() => _isSpecialQuery = true);
    } else {
      if (_isSpecialQuery) setState(() => _isSpecialQuery = false);
    }

    if (text.isEmpty && _stage != SearchStage.notStarted) {
      setState(() {
        _stage = SearchStage.notStarted;
        _results = [];
        _allSearchResult = null;
        _searchResult = null;
      });
    }
  }

  // --- Search Logic ---

  Future<void> _startSearch(String query) async {
    if (_stage == SearchStage.started) return;
    query = query.trim();
    if (query.isEmpty && _filterOutputs.isEmpty) return;

    _prevQuery = query;
    if (query.isNotEmpty) _history.addQuery(query);

    setState(() {
      _stage = SearchStage.started;
      _loadMoreStage = SearchStage.notStarted;
    });

    try {
      if (query.startsWith('#')) {
        await _startSpecialSearch(query.substring(1));
      } else {
        await _dispatchSearch(query);
      }

      if (_hasResults) {
        setState(() => _stage = SearchStage.loaded);
      } else {
        setState(() => _stage = SearchStage.empty);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _stage = SearchStage.empty);
    }
  }

  bool get _hasResults {
    if (_category == 'all') return _allSearchResult != null;
    if (_category == 'forum') return _forumResults.isNotEmpty;
    if (_category == 'user') return _userResults.isNotEmpty;
    if (_category == 'club') return _clubResults.isNotEmpty;
    if (_category == 'interest_stack') return _interestStackResults.isNotEmpty;
    if (_category == 'news' || _category == 'featured') {
      return _newsOrFeaturedResults.isNotEmpty;
    }
    return _results.isNotEmpty;
  }

  Future<void> _dispatchSearch(String query) async {
    switch (_category) {
      case 'all':
        _allSearchResult = await MalApi.searchAllCategories(query);
        if (_allSearchResult != null) _updateAllSectionSearch();
        break;

      case 'anime':
      case 'manga':
        if (_filterOutputs.isNotEmpty) {
          await _searchWithFilters(query);
        } else {
          final result = _category == 'manga'
              ? await MalApi().searchMangaResult(query, limit: 30)
              : await MalApi().searchAnimeResult(query, limit: 30);
          _searchResult = result;
          _results = result.data;
        }
        break;

      case 'character':
      case 'person':
        await _searchJikan(query);
        break;

      case 'forum':
        await _searchForum(query);
        break;

      case 'user':
        await _searchUsers(query);
        break;

      case 'club':
        await _searchClubs(query);
        break;

      case 'featured':
      case 'news':
        await _searchFeaturedOrNews(query);
        break;

      case 'interest_stack':
        await _searchInterestStacks(query);
        break;
    }
  }

  Future<void> _searchForum(String query) async {
    final forum = MalForumApi();
    int? boardId;
    int? subboardId;
    String? topicUserName;
    String? userName;

    if (_filterOutputs.containsKey('board_id')) {
      boardId = _filterOutputs['board_id']!.apiValues != null
          ? _filterOutputs['board_id']!.apiValues![
              _filterOutputs['board_id']!.values!
                  .indexOf(_filterOutputs['board_id']!.value!)]
          : int.tryParse(_filterOutputs['board_id']!.value ?? '');
    }
    if (_filterOutputs.containsKey('subboard_id')) {
      subboardId = _filterOutputs['subboard_id']!.apiValues != null
          ? _filterOutputs['subboard_id']!.apiValues![
              _filterOutputs['subboard_id']!.values!
                  .indexOf(_filterOutputs['subboard_id']!.value!)]
          : int.tryParse(_filterOutputs['subboard_id']!.value ?? '');
    }
    if (_filterOutputs.containsKey('topic_user_name')) {
      topicUserName = _filterOutputs['topic_user_name']!.value;
    }
    if (_filterOutputs.containsKey('user_name')) {
      userName = _filterOutputs['user_name']!.value;
    }

    _forumOffset = 0;
    final result = await forum.getForumTopics(
      q: query.isNotEmpty ? query : null,
      boardId: boardId,
      subboardId: subboardId,
      topicUserName: topicUserName,
      userName: userName,
      limit: 30,
      offset: 0,
    );
    _forumResults = result?.data ?? [];
    _hasMoreResults = _forumResults.length >= 30;
  }

  Future<void> _searchUsers(String query) async {
    _userOffset = 0;
    final result = await MwlApi.i.searchUsers(query, offset: 0);
    _userResults = result?.users ?? [];
    _hasMoreResults = _userResults.length >= 24;
  }

  Future<void> _searchClubs(String query) async {
    _clubPage = 1;
    final result = await MwlApi.i.searchClubs(query, page: 1);
    _clubResults = (result?['clubs'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    _hasMoreResults = _clubResults.isNotEmpty;
  }

  Future<void> _searchFeaturedOrNews(String query) async {
    _newsOrFeaturedPage = 1;
    // Extract tag filter if present
    String? tag;
    if (_filterOutputs.containsKey('tags') &&
        _filterOutputs['tags']!.value != null &&
        _filterOutputs['tags']!.value != 'All') {
      tag = _filterOutputs['tags']!.value;
    }
    final result = _category == 'news'
        ? await MwlApi.i.searchNews(query, tag: tag, page: 1)
        : await MwlApi.i.searchFeatured(query, tag: tag, page: 1);
    _newsOrFeaturedResults = result?.newsorfeatured ?? [];
    _hasMoreResults = result?.paging.next != null &&
        result!.paging.next!.isNotEmpty;
  }

  // Interest stack specific state
  List<Map<String, dynamic>> _interestStackResults = [];
  int _interestStackPage = 1;

  Future<void> _searchInterestStacks(String query) async {
    _interestStackPage = 1;
    String? type;
    if (_filterOutputs.containsKey('type') &&
        _filterOutputs['type']!.value != null) {
      final idx =
          _filterOutputs['type']!.values?.indexOf(_filterOutputs['type']!.value!);
      if (idx != null && idx >= 0 && _filterOutputs['type']!.apiValues != null) {
        type = _filterOutputs['type']!.apiValues![idx]?.toString();
      }
    }

    _interestStackResults = await MwlApi.i.searchInterestStacks(
      query,
      type: type,
      page: 1,
    );
    _hasMoreResults = _interestStackResults.length >= 10;
  }

  Future<void> _searchWithFilters(String query) async {
    final jikan = JikanApi();

    // Build Jikan filter parameters from _filterOutputs
    String? type = _filterOutputs['type']?.value?.toLowerCase();
    String? status = _filterOutputs['status']?.value?.toLowerCase();
    String? rating = _filterOutputs['rating']?.value;
    String? orderBy = _filterOutputs['order_by']?.value?.toLowerCase();
    String? sort = _filterOutputs['sort']?.value?.toLowerCase();
    String? score = _filterOutputs['score']?.value;
    String? letter = _filterOutputs['letter']?.value;
    String? startDate = _filterOutputs['start_date']?.value;
    String? endDate = _filterOutputs['end_date']?.value;
    String? producer = _filterOutputs['producer']?.value;

    // Genres
    List<String>? includedGenres = _filterOutputs['genres']?.includedOptions;
    List<String>? excludedGenres = _filterOutputs['genres']?.excludedOptions;

    String? genres;
    String? genresExclude;

    if (includedGenres != null && includedGenres.isNotEmpty) {
      final genreMap = _category == 'manga' ? Mal.mangaGenresEng : Mal.animeGenresEng;
      genres = includedGenres
          .map((g) {
            final entry = genreMap.entries.where((e) => e.value == g);
            return entry.isNotEmpty ? entry.first.key.toString() : null;
          })
          .where((e) => e != null)
          .join(',');
    }
    if (excludedGenres != null && excludedGenres.isNotEmpty) {
      final genreMap = _category == 'manga' ? Mal.mangaGenresEng : Mal.animeGenresEng;
      genresExclude = excludedGenres
          .map((g) {
            final entry = genreMap.entries.where((e) => e.value == g);
            return entry.isNotEmpty ? entry.first.key.toString() : null;
          })
          .where((e) => e != null)
          .join(',');
    }

    // Rating: map display value to API value
    String? ratingApi;
    if (rating != null) {
      final ratedEntries = ratedMap.entries.where((e) => e.value == rating);
      if (ratedEntries.isNotEmpty) {
        ratingApi = ratedEntries.first.key.name;
      }
    }

    // Producer: map display value to API id
    String? producerApi;
    if (producer != null) {
      final studioEntry = Mal.animeStudios.entries.where(
        (e) => e.value == producer,
      );
      if (studioEntry.isNotEmpty) {
        producerApi = studioEntry.first.key.toString();
      }
    }

    double? minScore;
    if (score != null) {
      minScore = double.tryParse(score.replaceAll('+', ''));
    }

    if (_category == 'manga') {
      // Magazine: map display value to API id
      String? magazineApi;
      if (_filterOutputs['magazines']?.value != null) {
        final magEntry = Mal.mangaMagazines.entries.where(
          (e) => e.value == _filterOutputs['magazines']!.value,
        );
        if (magEntry.isNotEmpty) {
          magazineApi = magEntry.first.key.toString();
        }
      }

      final items = await jikan.getMangaSearch(
        q: query.isNotEmpty ? query : null,
        limit: 25,
        type: type,
        status: status,
        orderBy: orderBy,
        sort: sort == 'ascending' ? 'asc' : sort == 'descending' ? 'desc' : null,
        minScore: minScore,
        letter: letter,
        genres: genres,
        genresExclude: genresExclude,
        magazines: magazineApi,
        startDate: startDate,
        endDate: endDate,
      );
      _results = items.map(_jikanToAnime).toList();
      _searchResult = SearchResult(data: _results);
    } else {
      // Anime
      AnimeSearchQueryType? queryType;
      if (type != null) {
        queryType = AnimeSearchQueryType.values.where(
          (e) => e.value == type,
        ).firstOrNull;
      }

      AnimeSearchQueryStatus? queryStatus;
      if (status != null) {
        queryStatus = AnimeSearchQueryStatus.values.where(
          (e) => e.value == status,
        ).firstOrNull;
      }

      AnimeSearchQueryRating? queryRating;
      if (ratingApi != null) {
        queryRating = AnimeSearchQueryRating.values.where(
          (e) => e.value == ratingApi,
        ).firstOrNull;
      }

      AnimeSearchQueryOrderBy? queryOrderBy;
      if (orderBy != null) {
        queryOrderBy = AnimeSearchQueryOrderBy.values.where(
          (e) => e.value == orderBy,
        ).firstOrNull;
      }

      SearchQuerySort? querySort;
      if (sort != null) {
        querySort = sort == 'ascending' ? SearchQuerySort.asc : SearchQuerySort.desc;
      }

      final items = await jikan.getAnimeSearch(
        q: query.isNotEmpty ? query : null,
        limit: 25,
        type: queryType,
        status: queryStatus,
        rating: queryRating,
        orderBy: queryOrderBy,
        sort: querySort,
        minScore: minScore,
        letter: letter,
        genres: genres,
        genresExclude: genresExclude,
        producers: producerApi,
        startDate: startDate,
        endDate: endDate,
      );
      _results = items.map(_jikanToAnime).toList();
      _searchResult = SearchResult(data: _results);
    }
  }

  static Anime _jikanToAnime(jikan_model.JikanAnime j) {
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

  Future<bool> _startSpecialSearch(String query) async {
    if (rankingMap.values.contains(query)) {
      _category = 'anime';
      final rankingType = rankingMap.keys.elementAt(
        rankingMap.values.toList().indexOf(query),
      );
      final result = await MalApi.getContentRankingResult(
        rankingType,
        limit: 30,
        category: 'anime',
      );
      _searchResult = result;
      _results = result.data;
      return true;
    }

    if (query.contains('@')) {
      final parts = query.split('@');
      if (parts.length == 2) {
        final season = parts[0].toLowerCase();
        final year = int.tryParse(parts[1]);
        if (year != null && seasonMapInverse.containsKey(season)) {
          _category = 'anime';
          final seasonType = seasonMapInverse[season]!;
          final result = await MalApi.getAnimeSeasonalResult(
            seasonType,
            year,
            limit: 30,
          );
          _searchResult = result;
          _results = result.data;
          return true;
        }

        // Handle suggested@anime / suggested@manga
        if (parts[0] == 'suggested') {
          final cat = parts[1] == 'manga' ? 'manga' : 'anime';
          _category = cat;
          final result = await MalApi.getContentSuggestionsResult(
            limit: 30,
            category: cat,
          );
          _searchResult = result;
          _results = result.data;
          return true;
        }

        if (parts[1] == 'manga' && mangaRankingMap.values.contains(parts[0])) {
          _category = 'manga';
          final rankingType = mangaRankingMap.keys.elementAt(
            mangaRankingMap.values.toList().indexOf(parts[0]),
          );
          final result = await MalApi.getContentRankingResult(
            rankingType,
            limit: 30,
            category: 'manga',
          );
          _searchResult = result;
          _results = result.data;
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _searchJikan(String query) async {
    final jikan = JikanApi();
    if (_category == 'character') {
      final chars = await jikan.searchCharacters(q: query, limit: 25);
      _results = chars
          .map((c) => Anime(
                id: c.malId ?? 0,
                title: c.name ?? '',
                imageUrl: c.images?.jpg?.imageUrl ?? '',
                score: (c.favorites ?? 0).toDouble(),
                members: c.favorites ?? 0,
              ))
          .toList();
      _searchResult = SearchResult(data: _results);
    } else if (_category == 'person') {
      final people = await jikan.searchPeople(q: query, limit: 25);
      _results = people
          .map((p) => Anime(
                id: p.malId ?? 0,
                title: p.name ?? '',
                imageUrl: p.images?.jpg?.imageUrl ?? '',
                score: (p.favorites ?? 0).toDouble(),
                members: p.favorites ?? 0,
              ))
          .toList();
      _searchResult = SearchResult(data: _results);
    }
  }

  void _updateAllSectionSearch() {
    if (_allSearchResult == null) return;
    final keys = _allSearchResult!.categories.keys
        .where((k) => (_allSearchResult!.categories[k] ?? []).isNotEmpty)
        .toList();
    if (keys.isNotEmpty) {
      _allSectionSearch = keys;
      _tabController.dispose();
      _tabController = TabController(
        length: _allSectionSearch.length,
        vsync: this,
      );
    }
  }

  Future<void> _loadMore() async {
    if (_loadMoreStage == SearchStage.started) return;
    if (!_hasMoreResults && (_searchResult == null || !_searchResult!.hasNextPage)) return;

    setState(() => _loadMoreStage = SearchStage.started);

    try {
      switch (_category) {
        case 'forum':
          _forumOffset += 30;
          final forum = MalForumApi();
          final result = await forum.getForumTopics(
            q: _prevQuery.isNotEmpty ? _prevQuery : null,
            limit: 30,
            offset: _forumOffset,
          );
          final data = result?.data ?? [];
          _forumResults.addAll(data);
          _hasMoreResults = data.length >= 30;
          break;

        case 'user':
          _userOffset += 24;
          final result =
              await MwlApi.i.searchUsers(_prevQuery, offset: _userOffset);
          final users = result?.users ?? [];
          _userResults.addAll(users);
          _hasMoreResults = users.length >= 24;
          break;

        case 'club':
          _clubPage++;
          final result =
              await MwlApi.i.searchClubs(_prevQuery, page: _clubPage);
          final clubs = (result?['clubs'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
          _clubResults.addAll(clubs);
          _hasMoreResults = clubs.isNotEmpty;
          break;

        case 'interest_stack':
          _interestStackPage++;
          String? type;
          if (_filterOutputs.containsKey('type') &&
              _filterOutputs['type']!.value != null) {
            final idx = _filterOutputs['type']!
                .values
                ?.indexOf(_filterOutputs['type']!.value!);
            if (idx != null &&
                idx >= 0 &&
                _filterOutputs['type']!.apiValues != null) {
              type = _filterOutputs['type']!.apiValues![idx]?.toString();
            }
          }
          final stacks = await MwlApi.i.searchInterestStacks(
            _prevQuery,
            type: type,
            page: _interestStackPage,
          );
          _interestStackResults.addAll(stacks);
          _hasMoreResults = stacks.length >= 10;
          break;

        case 'news':
        case 'featured':
          _newsOrFeaturedPage++;
          String? tag;
          if (_filterOutputs.containsKey('tags') &&
              _filterOutputs['tags']!.value != null &&
              _filterOutputs['tags']!.value != 'All') {
            tag = _filterOutputs['tags']!.value;
          }
          final nfResult = _category == 'news'
              ? await MwlApi.i.searchNews(_prevQuery,
                  tag: tag, page: _newsOrFeaturedPage)
              : await MwlApi.i.searchFeatured(_prevQuery,
                  tag: tag, page: _newsOrFeaturedPage);
          final nfItems = nfResult?.newsorfeatured ?? [];
          _newsOrFeaturedResults.addAll(nfItems);
          _hasMoreResults = nfResult?.paging.next != null &&
              nfResult!.paging.next!.isNotEmpty;
          break;

        default:
          if (_searchResult == null || !_searchResult!.hasNextPage) {
            setState(() => _loadMoreStage = SearchStage.empty);
            return;
          }
          final next = await MalApi.getContentListPage(
              _searchResult!.paging!,
              next: true);
          if (next.data.isEmpty) {
            setState(() => _loadMoreStage = SearchStage.empty);
            return;
          }
          _results.addAll(next.data);
          _searchResult = next;
          break;
      }
      setState(() => _loadMoreStage = SearchStage.loaded);
    } catch (e) {
      debugPrint('Load more error: $e');
      setState(() => _loadMoreStage = SearchStage.empty);
    }
  }

  void _reset() {
    setState(() {
      _stage = SearchStage.notStarted;
      _loadMoreStage = SearchStage.notStarted;
      _searchResult = null;
      _allSearchResult = null;
      _results = [];
      _forumResults = [];
      _userResults = [];
      _clubResults = [];
      _interestStackResults = [];
      _newsOrFeaturedResults = [];
      _clubPage = 1;
      _userOffset = 0;
      _forumOffset = 0;
      _interestStackPage = 1;
      _newsOrFeaturedPage = 1;
      _hasMoreResults = false;
    });
  }

  void _onCategorySelect(String value) {
    setState(() {
      _category = value;
      _filterOutputs.clear();
    });
  }

  void _saveDisplaySettings() {
    _history.displayType = _displayType;
    _history.displaySubType = _displaySubType;
    _history.gridAxisCount = _gridAxisCount;
    _history.gridHeight = _gridHeight;
    _history.saveDisplaySettings();
  }

  void _onFilterApply(Map<String, FilterOption> newFilters) {
    _showFilter = false;
    _filterOutputs = Map.from(newFilters);
    _reset();
    if (_searchController.text.isNotEmpty || _filterOutputs.isNotEmpty) {
      _startSearch(_searchController.text);
    }
    if (mounted) setState(() {});
  }

  void _navigateToContent(Anime anime, String category) {
    gotoPage(
      context: context,
      newPage: ContentDetailedScreen(
        node: anime,
        category: category,
      ),
    );
  }

  List<FilterOption> _getFilterOptions() {
    switch (_category) {
      case 'anime':
        return _animeFilters;
      case 'manga':
        return _mangaFilters;
      case 'forum':
        return _forumFilters;
      case 'user':
        return _userFilters;
      case 'featured':
        return _featuredFilters;
      case 'news':
        return _newsFilters;
      case 'interest_stack':
        return _interestStackFilters;
      default:
        return [];
    }
  }

  bool get _hasDisplay =>
      _category == 'anime' || _category == 'manga';

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildBody(),
          _buildSearchBar(),
          if (_showFilter)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFilterSection(),
            ),
        ],
      ),
    );
  }

  // --- Search Bar ---

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topPadding + 4, bottom: 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _buildLeadingButton(),
                      if (_isSpecialQuery) _buildSpecialTag(),
                      Expanded(child: _buildSearchField()),
                      _buildFilterButton(),
                    ],
                  ),
                ),
                if (_category == 'all' && _stage == SearchStage.loaded)
                  _buildAllSectionsTabBar()
                else if (!_showFilter)
                  const Divider(height: 1, thickness: 0.5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadingButton() {
    final hasText = _searchController.text.isNotEmpty;
    return IconButton(
      onPressed: () {
        if (hasText) {
          _searchController.clear();
          if (_isSpecialQuery) setState(() => _isSpecialQuery = false);
          _filterOutputs.clear();
          _reset();
        } else {
          if (_showFilter) {
            setState(() => _showFilter = false);
          } else if (widget.showBackButton) {
            Navigator.pop(context);
          }
        }
      },
      icon: Icon(hasText ? Icons.clear : Icons.arrow_back),
    );
  }

  Widget _buildSpecialTag() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'special',
        style: theme.textTheme.bodySmall?.copyWith(
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextFormField(
      focusNode: _focusNode,
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onFieldSubmitted: (value) {
        if (value.trim().isNotEmpty || _filterOutputs.isNotEmpty) {
          _showFilter = false;
          _reset();
          _startSearch(value);
        }
      },
      style: TextStyle(
        fontWeight: _isSpecialQuery ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.zero,
        hintText: 'Search ${_category == "all" ? "" : _category}',
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasFilters = _filterOutputs.isNotEmpty;
    return SizedBox(
      height: 38,
      width: 50,
      child: ShadowButton(
        onPressed: () {
          setState(() => _showFilter = !_showFilter);
        },
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Icon(
          hasFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildAllSectionsTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: _allSectionSearch
          .map((e) => Tab(child: Text(_capitalizeFirst(e))))
          .toList(),
    );
  }

  // --- Filter Section (slide-down panel) ---

  Widget _buildFilterSection() {
    final theme = Theme.of(context);
    final filterOptions = _getFilterOptions();
    final categories = [
      'all',
      'anime',
      'manga',
      'character',
      'person',
      'user',
      'forum',
      'featured',
      'news',
      'club',
      'interest_stack',
    ];

    final hasFilters = filterOptions.isNotEmpty;
    final hasDisplay = _hasDisplay;
    // all/club/character/person: Category only
    // anime/manga: Category + Filter + Display
    // forum/user/featured/news/interest_stack: Category + Filter
    int tabCount = 1; // Category always present
    if (hasFilters) tabCount++;
    if (hasDisplay) tabCount++;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      child: DefaultTabController(
          length: tabCount,
          child: Builder(
            builder: (controllerContext) {
              return Column(
                children: [
                  if (tabCount > 1)
                    TabBar(
                      tabs: [
                        const Tab(text: 'Category'),
                        if (hasFilters) const Tab(text: 'Filter'),
                        if (hasDisplay) const Tab(text: 'Display'),
                      ],
                    ),
                  Expanded(
                    child: tabCount > 1
                      ? TabBarView(
                    children: [
                      // Category tab
                      _buildCategoryTab(categories),
                      // Filter tab
                      if (hasFilters)
                        FilterModal(
                          filterOptions: filterOptions,
                          filterOutputs: _filterOutputs,
                          showBottombar: false,
                          onChange: (filters) {
                            setState(() {
                              _filterOutputs = filters;
                            });
                          },
                        ),
                      // Display tab
                      if (hasDisplay) _buildDisplayTab(),
                    ],
                  )
                      : _buildCategoryTab(categories),
                  ),
                  // Bottom bar
                  _buildFilterBottomBar(controllerContext),
                ],
              );
            },
          ),
        ),
    );
  }

  Widget _buildCategoryTab(List<String> categories) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: categories.map((cat) {
        return RadioListTile<String>(
          value: cat,
          groupValue: _category,
          title: Text(_categoryDisplayName(cat)),
          dense: true,
          selected: cat == _category,
          onChanged: (value) {
            if (value != null && value != _category) {
              _onCategorySelect(value);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildDisplayTab() {
    final isGrid = _displayType == DisplayType.grid;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      children: [
        // Display Type
        const ListTile(title: Text('Display Type')),
        RadioListTile<DisplayType>(
          value: DisplayType.grid,
          groupValue: _displayType,
          title: const Text('Grid'),
          dense: true,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _displayType = value;
                _displaySubType = DisplaySubType.comfortable;
              });
            }
          },
        ),
        RadioListTile<DisplayType>(
          value: DisplayType.list_vert,
          groupValue: _displayType,
          title: const Text('List'),
          dense: true,
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _displayType = value;
                _displaySubType = DisplaySubType.comfortable;
              });
            }
          },
        ),

        // Display Sub Type
        const ListTile(title: Text('Display Sub Type')),
        for (final sub in [
          DisplaySubType.comfortable,
          DisplaySubType.compact,
          if (isGrid) DisplaySubType.cover_only_grid,
          DisplaySubType.spacious,
        ])
          RadioListTile<DisplaySubType>(
            value: sub,
            groupValue: _displaySubType,
            title: Text(_capitalizeFirst(sub.name.replaceAll('_', ' '))),
            dense: true,
            onChanged: (value) {
              if (value != null) setState(() => _displaySubType = value);
            },
          ),

        // Grid sliders (only for grid display type)
        if (isGrid) ...[
          SB.h10,
          _buildGridAxisSlider(),
          SB.h10,
          _buildGridHeightSlider(),
        ],
      ],
    );
  }

  Widget _buildGridAxisSlider() {
    const min = 2;
    const max = 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            'Grid Axis Size ($_gridAxisCount)',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        SB.h10,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              SB.w10,
              const Text('$min'),
              SB.w10,
              Expanded(
                child: Slider(
                  value: _gridAxisCount.toDouble(),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  label: '$_gridAxisCount',
                  onChanged: (value) {
                    setState(() => _gridAxisCount = value.toInt());
                  },
                ),
              ),
              SB.w10,
              const Text('$max'),
              SB.w10,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGridHeightSlider() {
    const double min = 160;
    const double max = 360;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Text(
            'Grid Height (${_gridHeight.toInt()})',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        SB.h10,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            children: [
              SB.w10,
              const Text('$min'),
              SB.w10,
              Expanded(
                child: Slider(
                  value: _gridHeight,
                  min: min,
                  max: max,
                  divisions: 100,
                  label: '${_gridHeight.toInt()}',
                  onChanged: (value) {
                    setState(() => _gridHeight = value);
                  },
                ),
              ),
              SB.w10,
              const Text('$max'),
              SB.w10,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBottomBar(BuildContext controllerContext) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Column(
        children: [
          const Divider(height: 1),
          SB.h5,
          Row(
            children: [
              SB.w10,
              PlainButton(
                child: const Text('Reset'),
                onPressed: () {
                  final tabIndex =
                      DefaultTabController.of(controllerContext).index;
                  final hasFilters = _getFilterOptions().isNotEmpty;
                  final hasDisplay = _hasDisplay;
                  setState(() {
                    if (tabIndex == 0) {
                      // Reset category
                      _category = 'all';
                      _reset();
                    } else if (hasFilters && tabIndex == 1) {
                      // Reset filters
                      _filterOutputs.clear();
                    } else if (hasDisplay &&
                        tabIndex == (hasFilters ? 2 : 1)) {
                      // Reset display
                      _displayType = DisplayType.grid;
                      _displaySubType = DisplaySubType.compact;
                      _gridAxisCount = 3;
                      _gridHeight = 200;
                      _saveDisplaySettings();
                    }
                  });
                },
              ),
              const Spacer(),
              ShadowButton(
                child: const Text('Save'),
                onPressed: () {
                  _saveDisplaySettings();
                  _onFilterApply(Map.from(_filterOutputs));
                },
              ),
              const Spacer(),
              PlainButton(
                child: const Text('Close'),
                onPressed: () {
                  setState(() => _showFilter = false);
                },
              ),
              SB.w10,
            ],
          ),
        ],
      ),
    );
  }

  String _categoryDisplayName(String cat) {
    switch (cat) {
      case 'interest_stack':
        return 'Interest Stack';
      default:
        return _capitalizeFirst(cat);
    }
  }

  // --- Body ---

  Widget _buildBody() {
    final topOffset = _category == 'all' && _stage == SearchStage.loaded
        ? 140.0
        : 100.0;

    return Padding(
      padding: EdgeInsets.only(top: topOffset),
      child: switch (_stage) {
        SearchStage.notStarted => _buildHistoryView(),
        SearchStage.started => _buildLoadingView(),
        SearchStage.loaded => _buildResultsView(),
        SearchStage.empty => _buildEmptyView(),
      },
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyView() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  // --- Results ---

  Widget _buildResultsView() {
    if (_category == 'all' && _allSearchResult != null) {
      return _buildAllCategoryResults();
    }
    return _buildSingleCategoryResults();
  }

  Widget _buildAllCategoryResults() {
    return TabBarView(
      controller: _tabController,
      children: _allSectionSearch.map((cat) {
        final items = _allSearchResult!.categories[cat] ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'No $cat results',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 8),
            _buildAllCategorySection(cat, items),
            const SizedBox(height: 16),
            _buildSearchInCategoryButton(cat),
            const SizedBox(height: 80),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAllCategorySection(String cat, List<Anime> items) {
    switch (cat) {
      case 'anime':
      case 'manga':
        return _buildAllAnimeMangaResults(items, cat);
      case 'character':
      case 'person':
        return _buildCharacterOrPersonItems(items, cat == 'character');
      case 'forum':
        return _buildForumItems(items);
      case 'news':
      case 'featured':
        return _buildNewsOrFeaturedItems(items, cat == 'news');
      case 'club':
        return _buildClubItems(items);
      default:
        return _buildGenericListResults(items, cat);
    }
  }

  Widget _buildSearchInCategoryButton(String cat) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PlainButton(
        onPressed: () {
          gotoPage(
            context: context,
            newPage: GeneralSearchScreen(
              autoFocus: false,
              category: cat,
              searchQuery: _prevQuery,
              showBackButton: true,
            ),
          );
        },
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            "Search '$_prevQuery' in ${_capitalizeFirst(cat)}",
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleCategoryResults() {
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 8),
        _buildCategoryResultContent(),
        const SizedBox(height: 8),
        if (_canLoadMore) _buildLoadMoreButton(),
        const SizedBox(height: 80),
      ],
    );
  }

  bool get _canLoadMore {
    if (['forum', 'user', 'club', 'interest_stack', 'news', 'featured']
        .contains(_category)) {
      return _hasMoreResults;
    }
    return _searchResult?.hasNextPage == true;
  }

  Widget _buildCategoryResultContent() {
    switch (_category) {
      case 'forum':
        return _buildForumResults();
      case 'user':
        return _buildUserResults();
      case 'club':
        return _buildClubResults();
      case 'interest_stack':
        return _buildInterestStackResults();
      case 'news':
      case 'featured':
        return _buildNewsOrFeaturedResults();
      case 'character':
      case 'person':
        return _buildCharacterOrPersonResults();
      default:
        if (_displayType == DisplayType.list_vert) {
          return _buildListResults(_results, _category);
        }
        return _buildGridResults(_results, _category);
    }
  }

  /// Build a grid of AnimeGridCard results (same card as homepage)
  Widget _buildGridResults(List<Anime> items, String category) {
    final double cardHeight = _gridHeight;
    final double cardWidth = cardHeight * (2 / 3);
    final int crossAxisCount = _gridAxisCount;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: cardWidth / (cardHeight + 36),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final anime = items[index];
        return AnimeGridCard(
          node: anime,
          category: category,
          width: cardWidth,
          height: cardHeight,
          gridHeight: cardHeight + 36,
          showMemberCount: _displaySubType != DisplaySubType.cover_only_grid,
          showText: _displaySubType != DisplaySubType.cover_only_grid,
          displaySubType: _displaySubType,
          onTap: () => _navigateToContent(anime, category),
        );
      },
    );
  }

  /// Build a vertical list of anime/manga results (for DisplayType.list_vert).
  /// Dispatches to compact, comfortable, or spacious sub-type.
  Widget _buildListResults(List<Anime> items, String category) {
    switch (_displaySubType) {
      case DisplaySubType.compact:
        return _buildCompactListResults(items, category);
      case DisplaySubType.spacious:
        return _buildSpaciousListResults(items, category);
      default:
        return _buildComfortableListResults(items, category);
    }
  }

  /// Compact list: small avatar (40×40), title, score on the right.
  Widget _buildCompactListResults(List<Anime> items, String category) {
    final theme = Theme.of(context);
    return Column(
      children: items.map((item) {
        return ListTile(
          dense: true,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl.isNotEmpty
                ? Image.network(
                    item.imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40,
                      height: 40,
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: Icon(Icons.image_not_supported,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: Icon(Icons.image_not_supported,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
          ),
          title: Text(
            item.title,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: item.mediaType != null
              ? Text(
                  item.mediaType!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          trailing: item.score > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      item.score.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : null,
          onTap: () => _navigateToContent(item, category),
        );
      }).toList(),
    );
  }

  /// Comfortable list: medium image (80×112), title, type/episodes, score/members.
  Widget _buildComfortableListResults(List<Anime> items, String category) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: items.map((item) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToContent(item, category),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 80,
                            height: 112,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 112,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(Icons.image_not_supported,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 112,
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Icon(Icons.image_not_supported,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                  ),
                  SB.w10,
                  Expanded(
                    child: SizedBox(
                      height: 112,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SB.h5,
                          if (item.mediaType != null ||
                              (item.numEpisodes != null &&
                                  item.numEpisodes! > 0))
                            Text(
                              [
                                if (item.mediaType != null) item.mediaType!,
                                if (item.numEpisodes != null &&
                                    item.numEpisodes! > 0)
                                  '${item.numEpisodes} eps',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const Spacer(),
                          Row(
                            children: [
                              if (item.score > 0) ...[
                                const Icon(Icons.star,
                                    size: 16, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  item.score.toStringAsFixed(2),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (item.score > 0 && item.members > 0)
                                Text(' · ',
                                    style: theme.textTheme.bodySmall),
                              if (item.members > 0)
                                Text(
                                  _formatMemberCount(item.members),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Spacious list: large image (100×140), title, synopsis, genres, score/members.
  Widget _buildSpaciousListResults(List<Anime> items, String category) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: items.map((item) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToContent(item, category),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 100,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 140,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(Icons.image_not_supported,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 100,
                            height: 140,
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Icon(Icons.image_not_supported,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                  ),
                  SB.w10,
                  Expanded(
                    child: SizedBox(
                      height: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Score + members
                          Row(
                            children: [
                              if (item.score > 0) ...[
                                const Icon(Icons.star,
                                    size: 16, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  item.score.toStringAsFixed(2),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (item.score > 0 && item.members > 0)
                                Text(' · ',
                                    style: theme.textTheme.bodySmall),
                              if (item.members > 0)
                                Text(
                                  _formatMemberCount(item.members),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          SB.h5,
                          // Title
                          Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SB.h5,
                          // Type · Status
                          if (item.mediaType != null || item.status != null)
                            Text(
                              [
                                if (item.mediaType != null) item.mediaType!,
                                if (item.status != null) item.status!,
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          const Spacer(),
                          // Synopsis
                          if (item.synopsis != null &&
                              item.synopsis!.isNotEmpty)
                            Text(
                              item.synopsis!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Responsive anime/manga layout for the "all" category view.
  /// Mobile (<600dp): comfortable list tiles. Tablet (>=600dp): compact grid.
  Widget _buildAllAnimeMangaResults(List<Anime> items, String category) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    if (isTablet) {
      final crossAxisCount = screenWidth >= 840 ? 5 : 4;
      const double cardHeight = 200;
      const double cardWidth = cardHeight * (2 / 3);

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: cardWidth / (cardHeight + 36),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final anime = items[index];
          return AnimeGridCard(
            node: anime,
            category: category,
            width: cardWidth,
            height: cardHeight,
            gridHeight: cardHeight + 36,
            showMemberCount: true,
            showText: true,
            displaySubType: DisplaySubType.compact,
            onTap: () => _navigateToContent(anime, category),
          );
        },
      );
    }

    // Mobile: comfortable list tiles
    return _buildAllAnimeMangaList(items, category);
  }

  Widget _buildAllAnimeMangaList(List<Anime> items, String category) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: items.map((item) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _navigateToContent(item, category),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 80,
                            height: 112,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 112,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(Icons.image_not_supported,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 112,
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Icon(Icons.image_not_supported,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                  ),
                  SB.w10,
                  Expanded(
                    child: SizedBox(
                      height: 112,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SB.h5,
                          if (item.mediaType != null ||
                              (item.numEpisodes != null &&
                                  item.numEpisodes! > 0))
                            Text(
                              [
                                if (item.mediaType != null) item.mediaType!,
                                if (item.numEpisodes != null &&
                                    item.numEpisodes! > 0)
                                  '${item.numEpisodes} eps',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          const Spacer(),
                          Row(
                            children: [
                              if (item.score > 0) ...[
                                const Icon(Icons.star,
                                    size: 16, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  item.score.toStringAsFixed(2),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (item.score > 0 && item.members > 0)
                                Text(' · ',
                                    style: theme.textTheme.bodySmall),
                              if (item.members > 0)
                                Text(
                                  _formatMemberCount(item.members),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatMemberCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M members';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K members';
    }
    return '$count members';
  }

  // Generic list for non-anime/manga items (character, person, forum, club, news, featured in "all" view)
  Widget _buildGenericListResults(List<Anime> items, String category) {
    final theme = Theme.of(context);
    return Column(
      children: items.map((item) {
        return Column(
          children: [
            ListTile(
              leading: item.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Icon(Icons.image_not_supported,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconForCategory(category),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              title: Text(
                item.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: item.synopsis != null && item.synopsis!.isNotEmpty
                  ? Text(
                      item.synopsis!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              onTap: () {
                if (category == 'anime' || category == 'manga') {
                  _navigateToContent(item, category);
                }
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      }).toList(),
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'character':
        return Icons.face;
      case 'person':
        return Icons.person;
      case 'forum':
        return Icons.forum;
      case 'club':
        return Icons.group;
      case 'news':
        return Icons.newspaper;
      case 'featured':
        return Icons.article;
      default:
        return Icons.search;
    }
  }

  // --- Category-specific result builders ---

  Widget _buildForumResults() {
    final theme = Theme.of(context);
    return Column(
      children: _forumResults.map((topic) {
        final title = topic.title ?? '';
        final createdBy = topic.createdBy?.name ?? '';
        final posts = topic.numberOfPosts ?? 0;

        String formattedDate = '';
        if (topic.lastPostCreatedAt != null) {
          final dt = topic.lastPostCreatedAt!;
          formattedDate = '${dt.day}/${dt.month}/${dt.year}';
        }

        return Column(
          children: [
            ListTile(
              title: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$createdBy  ·  $formattedDate',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$posts posts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              onTap: topic.id != null
                  ? () {
                      gotoPage(
                        context: context,
                        newPage: ForumPostsScreen(topic: topic),
                      );
                    }
                  : null,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildUserResults() {
    final theme = Theme.of(context);
    return Column(
      children: _userResults.map((user) {
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: user.imageUrl != null && user.imageUrl!.isNotEmpty
                ? NetworkImage(user.imageUrl!)
                : null,
            child: user.imageUrl == null || user.imageUrl!.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(
            user.username,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: user.lastOnline != null
              ? Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      user.lastOnline!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                )
              : null,
          onTap: () {
            // TODO: Navigate to user profile
          },
        );
      }).toList(),
    );
  }

  Widget _buildClubResults() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: _clubResults.map((club) {
          final name = club['name'] as String? ?? '';
          final desc = club['desc'] as String? ?? '';
          final members = club['members'] as String? ?? '';
          final imgUrl = club['imgUrl'] as String?;
          final lastPostBy = club['lastPostBy'] as String?;
          final lastPostTime = club['lastPostTime'] as String?;

          final clubId = club['id'] as int?;
          return InkWell(
            onTap: () {
              if (clubId != null) {
                gotoPage(
                  context: context,
                  newPage: ClubScreen(
                    clubHtml: ClubHtml(
                      id: clubId,
                      name: name,
                      imgUrl: imgUrl,
                      desc: desc,
                      members: members,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Club image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: imgUrl != null && imgUrl.isNotEmpty
                        ? Image.network(
                            imgUrl,
                            width: 70,
                            height: 98,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 70,
                              height: 98,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(Icons.group,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 98,
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Icon(Icons.group,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                  ),
                  SB.w10,
                  // Club info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (desc.isNotEmpty) ...[
                          SB.h5,
                          Text(
                            desc,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        SB.h5,
                        Row(
                          children: [
                            if (lastPostBy != null && lastPostTime != null)
                              Expanded(
                                child: Text(
                                  '$lastPostBy · $lastPostTime',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.primary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (lastPostBy == null || lastPostTime == null)
                              const Spacer(),
                            if (members.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.people,
                                        size: 14,
                                        color: theme
                                            .colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      members,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNewsOrFeaturedResults() {
    final theme = Theme.of(context);
    final isNews = _category == 'news';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: _newsOrFeaturedResults.map((item) {
          final tagList = item.tags.isNotEmpty
              ? item.tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
              : <String>[];
          return InkWell(
            onTap: () {
              // TODO: Navigate to news/featured detail
            },
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 220,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      child: item.imageUrl.isNotEmpty
                          ? Image.network(
                              item.imageUrl,
                              width: 110,
                              height: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 110,
                                height: 220,
                                color: theme.colorScheme.surfaceContainerHigh,
                                child: Icon(
                                  isNews ? Icons.newspaper : Icons.article,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : Container(
                              width: 110,
                              height: 220,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(
                                isNews ? Icons.newspaper : Icons.article,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              item.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SB.h5,
                            // Summary text
                            if (item.text.isNotEmpty)
                              Expanded(
                                child: Text(
                                  item.text,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.fade,
                                ),
                              )
                            else
                              const Spacer(),
                            SB.h5,
                            // Tags
                            if (tagList.isNotEmpty)
                              SizedBox(
                                height: 28,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: tagList.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 4),
                                  itemBuilder: (context, index) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme.surfaceContainerHigh,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        tagList[index],
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// News/Featured items in the "all" category view (limited data from searchAllCategories)
  /// News/Featured items in the "all" category view
  Widget _buildNewsOrFeaturedItems(List<Anime> items, bool isNews) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: items.map((item) {
          final owner = item.status; // parsed from "by Author"
          final date = item.startDate;
          return InkWell(
            onTap: () {
              // TODO: Navigate to news/featured detail
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 100,
                            height: 130,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 130,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(
                                isNews ? Icons.newspaper : Icons.article,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            width: 100,
                            height: 130,
                            color: theme.colorScheme.surfaceContainerHigh,
                            child: Icon(
                              isNews ? Icons.newspaper : Icons.article,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  SB.w10,
                  Expanded(
                    child: SizedBox(
                      height: 130,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          if (owner != null || date != null)
                            Text(
                              [
                                if (owner != null) 'by $owner',
                                if (date != null) date,
                              ].join('  ·  '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCharacterOrPersonResults() {
    return _buildCharacterOrPersonItems(_results, _category == 'character');
  }

  Widget _buildCharacterOrPersonItems(List<Anime> items, bool isCharacter) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: items.map((item) {
          return InkWell(
            onTap: () {
              // TODO: Navigate to character/person detail
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 70,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 70,
                              height: 96,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(
                                isCharacter ? Icons.face : Icons.person,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 96,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCharacter ? Icons.face : Icons.person,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  SB.w10,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.members > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.favorite,
                                  size: 14,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${item.members} favorites',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Forum items in the "all" category view (same card style as news/featured)
  Widget _buildForumItems(List<Anime> items) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: items.map((item) {
          final owner = item.status;
          final date = item.startDate;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              gotoPage(
                context: context,
                newPage: ForumPostsScreen(
                  topic: ForumTopicsData(
                    id: item.id,
                    title: item.title,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 100,
                            height: 130,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 130,
                              color: theme.colorScheme.primaryContainer,
                              child: Icon(Icons.forum,
                                  color:
                                      theme.colorScheme.onPrimaryContainer),
                            ),
                          )
                        : Container(
                            width: 100,
                            height: 130,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.forum,
                                color:
                                    theme.colorScheme.onPrimaryContainer),
                          ),
                  ),
                  SB.w10,
                  Expanded(
                    child: SizedBox(
                      height: 130,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          if (owner != null || date != null)
                            Text(
                              [
                                if (owner != null) 'by $owner',
                                if (date != null) date,
                              ].join('  ·  '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Club items in the "all" category view (same card style as news/featured)
  Widget _buildClubItems(List<Anime> items) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: items.map((item) {
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              gotoPage(
                context: context,
                newPage: ClubScreen(
                  clubHtml: ClubHtml(
                    id: item.id,
                    name: item.title,
                    imgUrl: item.imageUrl.isNotEmpty ? item.imageUrl : null,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl.isNotEmpty
                        ? Image.network(
                            item.imageUrl,
                            width: 100,
                            height: 130,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 130,
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(Icons.group,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            width: 100,
                            height: 130,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.group,
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                  ),
                  SB.w10,
                  Expanded(
                    child: SizedBox(
                      height: 130,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          if (item.members > 0)
                            Row(
                              children: [
                                Icon(Icons.people,
                                    size: 14,
                                    color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  _formatMemberCount(item.members),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInterestStackResults() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: _interestStackResults.map((stack) {
          final title = stack['title'] as String? ?? '';
          final username = stack['username'] as String?;
          final description = stack['description'] as String?;
          final entries = stack['entries'] as int?;
          final reStacks = stack['reStacks'] as int?;
          final imageUrls =
              (stack['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];

          return InkWell(
            onTap: () {
              // TODO: Navigate to interest stack detail
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stacked images
                  GestureDetector(
                    onTap: imageUrls.isNotEmpty
                        ? () => zoomInImageList(context, imageUrls)
                        : null,
                    child: SizedBox(
                      width: 80,
                      height: 100,
                      child: imageUrls.isNotEmpty
                          ? Stack(
                              children: [
                                for (int i = (imageUrls.length > 3
                                        ? 2
                                        : imageUrls.length - 1);
                                    i >= 0;
                                    i--)
                                  Positioned(
                                    left: i * 12.0,
                                    top: i * 6.0,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        boxShadow: [
                                          BoxShadow(blurRadius: 6.0),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: Image.network(
                                          imageUrls[i],
                                          width: 50,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 50,
                                            height: 70,
                                            color: theme.colorScheme
                                                .surfaceContainerHigh,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Container(
                              width: 50,
                              height: 70,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.layers,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                    ),
                  ),
                  SB.w10,
                  // Stack info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (username != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'by $username',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                        SB.h5,
                        Row(
                          children: [
                            if (entries != null)
                              Text(
                                '$entries Entries',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (entries != null && reStacks != null)
                              Text(
                                '  ·  ',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (reStacks != null)
                              Text(
                                '$reStacks Restacks',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        if (description != null &&
                            description.isNotEmpty) ...[
                          SB.h5,
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    final theme = Theme.of(context);
    if (_loadMoreStage == SearchStage.started) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadMoreStage == SearchStage.empty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No more results',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PlainButton(
        onPressed: _loadMore,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('Load More', style: theme.textTheme.bodyMedium),
        ),
      ),
    );
  }

  // --- History View ---

  Widget _buildHistoryView() {
    return StreamBuilder<List<String>>(
      stream: _history.queryHistoryStream,
      initialData: _history.queries,
      builder: (context, querySnapshot) {
        return StreamBuilder<List<Anime>>(
          stream: _history.recentAnimeStream,
          initialData: _history.recentAnime,
          builder: (context, animeSnapshot) {
            return StreamBuilder<List<Anime>>(
              stream: _history.recentMangaStream,
              initialData: _history.recentManga,
              builder: (context, mangaSnapshot) {
                final queries = querySnapshot.data ?? [];
                final recentAnime = animeSnapshot.data ?? [];
                final recentManga = mangaSnapshot.data ?? [];
                return _buildHistoryContent(queries, recentAnime, recentManga);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryContent(
    List<String> queries,
    List<Anime> recentAnime,
    List<Anime> recentManga,
  ) {
    final theme = Theme.of(context);
    final hasContent =
        queries.isNotEmpty || recentAnime.isNotEmpty || recentManga.isNotEmpty;

    return CustomScrollView(
      slivers: [
        if (!hasContent)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.search_rounded,
                      size: 64,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'Search anime, manga, characters...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use # for special searches\ne.g. #best, #popular, #winter@2025',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Query history
        if (queries.isNotEmpty) ...[
          _buildSectionHeader('History', onClear: _history.clearQueries),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final query = queries[index];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.history,
                      size: 20,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4)),
                  title: Text(query, style: theme.textTheme.bodyMedium),
                  trailing: IconButton(
                    icon: Icon(Icons.close,
                        size: 18,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4)),
                    onPressed: () => _history.removeQuery(query),
                  ),
                  onTap: () {
                    _focusNode.unfocus();
                    _searchController.text = query;
                    _startSearch(query);
                  },
                );
              },
              childCount: queries.length,
            ),
          ),
        ],

        // Recent anime
        if (recentAnime.isNotEmpty) ...[
          _buildSectionHeader('Recent Anime',
              onClear: _history.clearRecentAnime),
          SliverToBoxAdapter(
            child: _buildRecentHorizontalList(recentAnime, 'anime'),
          ),
        ],

        // Recent manga
        if (recentManga.isNotEmpty) ...[
          _buildSectionHeader('Recent Manga',
              onClear: _history.clearRecentManga),
          SliverToBoxAdapter(
            child: _buildRecentHorizontalList(recentManga, 'manga'),
          ),
        ],

        // Season search
        SliverToBoxAdapter(child: const SizedBox(height: 24)),
        _buildSectionHeader('Search by Season'),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),
        SliverToBoxAdapter(child: _SeasonalSection()),

        // Anime Rankings
        SliverToBoxAdapter(child: const SizedBox(height: 24)),
        _buildSectionHeader('Anime Categories'),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),
        SliverToBoxAdapter(child: _buildRankingButtons('anime')),

        // Manga Rankings
        SliverToBoxAdapter(child: const SizedBox(height: 16)),
        _buildSectionHeader('Manga Categories'),
        SliverToBoxAdapter(child: const SizedBox(height: 8)),
        SliverToBoxAdapter(child: _buildRankingButtons('manga')),

        SliverToBoxAdapter(child: const SizedBox(height: 80)),
      ],
    );
  }

  /// Horizontal list of recent anime/manga using AnimeGridCard
  /// Horizontal list of recent anime/manga using the same card as the homepage.
  Widget _buildRecentHorizontalList(List<Anime> items, String category) {
    return BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
      builder: (context, homePreferencesState) {
        final preferences = homePreferencesState.preferences;
        final tileSize = getTileSizeValues(preferences.tileSize);
        final double cardHeight = tileSize.containerHeight;
        final double cardWidth = cardHeight * (2 / 3);

        return SizedBox(
          height: cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: SizedBox(
                  width: cardWidth,
                  child: AnimeGridCard(
                    node: item,
                    category: category,
                    width: cardWidth,
                    height: cardHeight,
                    gridHeight: cardHeight,
                    showText: false,
                    showMemberCount: true,
                    displaySubType: DisplaySubType.compact,
                    onTap: () => _navigateToContent(item, category),
                    onClose: () {
                      if (category == 'manga') {
                        _history.removeRecentManga(item.id);
                      } else {
                        _history.removeRecentAnime(item.id);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  SliverToBoxAdapter _buildSectionHeader(String title,
      {VoidCallback? onClear}) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onClear != null)
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingButtons(String category) {
    final rankings = category == 'manga'
        ? desiredMangaRankingMap
        : desiredTopAnimeOrder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: rankings.entries.map((entry) {
          final query = category == 'manga'
              ? '#${mangaRankingMap[entry.key]}@manga'
              : '#${rankingMap[entry.key]}';
          return ActionChip(
            label: Text(entry.value, style: const TextStyle(fontSize: 12)),
            onPressed: () {
              _searchController.text = query;
              _isSpecialQuery = true;
              _startSearch(query);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  // --- Utilities ---

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // --- Filter Definitions ---

  static List<FilterOption> get _animeFilters {
    return [
      FilterOption(
        fieldName: 'Anime Type',
        type: FilterType.select,
        apiFieldName: 'type',
        desc: 'Filter by type of anime',
        values: AnimeType.values.map((e) => e.name).toList(),
      ),
      FilterOption(
        fieldName: 'Anime Status',
        type: FilterType.select,
        apiFieldName: 'status',
        desc: 'Filter by airing status',
        values: jikanAnimeStatusMap.values.toList(),
      ),
      FilterOption(
        fieldName: 'Rated',
        type: FilterType.select,
        apiFieldName: 'rating',
        desc: 'Filter by age rating',
        values: ratedMap.values.toList(),
      ),
      FilterOption(
        fieldName: 'Genre Include/Exclude',
        type: FilterType.multiple,
        apiFieldName: 'genres',
        desc: 'Include or exclude genres',
        values: Mal.animeGenresEng.values.toList(),
      ),
      FilterOption(
        fieldName: 'Order By',
        type: FilterType.select,
        apiFieldName: 'order_by',
        desc: 'Order results by property',
        values: animeOrderType.entries
            .where((e) => e.key != OrderType.rating)
            .map((e) => e.value)
            .toList(),
      ),
      FilterOption(
        fieldName: 'Sort By',
        type: FilterType.select,
        apiFieldName: 'sort',
        dependent: 'order_by',
        desc: 'Sort order',
        values: sortTypeMap.values.toList(),
      ),
      FilterOption(
        fieldName: 'Score',
        type: FilterType.select,
        apiFieldName: 'score',
        desc: 'Minimum score',
        values: List.generate(9, (i) => '${9 - i}+'),
        apiValues: List.generate(9, (i) => (9 - i).toString()),
      ),
      FilterOption(
        fieldName: 'Start Date',
        type: FilterType.date,
        apiFieldName: 'start_date',
        desc: 'Filter by start date',
      ),
      FilterOption(
        fieldName: 'End Date',
        type: FilterType.date,
        apiFieldName: 'end_date',
        desc: 'Filter by end date',
      ),
      FilterOption(
        fieldName: 'Producer',
        type: FilterType.select,
        apiFieldName: 'producer',
        desc: 'Filter by studio/producer',
        values: Mal.animeStudios.values.toList(),
      ),
      FilterOption(
        fieldName: 'Starting With',
        type: FilterType.select,
        apiFieldName: 'letter',
        desc: 'Filter by starting letter',
        values: List.generate(26, (i) => String.fromCharCode(i + 65)),
      ),
    ];
  }

  static List<FilterOption> get _mangaFilters {
    return [
      FilterOption(
        fieldName: 'Manga Type',
        type: FilterType.select,
        apiFieldName: 'type',
        desc: 'Filter by type of manga',
        values: mangaTypeMap.values.toList(),
      ),
      FilterOption(
        fieldName: 'Manga Status',
        type: FilterType.select,
        apiFieldName: 'status',
        desc: 'Filter by publishing status',
        values: mangaStatusMap.values.toList(),
      ),
      FilterOption(
        fieldName: 'Genre Include/Exclude',
        type: FilterType.multiple,
        apiFieldName: 'genres',
        desc: 'Include or exclude genres',
        values: Mal.mangaGenresEng.values.toList(),
      ),
      FilterOption(
        fieldName: 'Order By',
        type: FilterType.select,
        apiFieldName: 'order_by',
        desc: 'Order results by property',
        values: mangaOrderType.values.toList(),
      ),
      FilterOption(
        fieldName: 'Sort By',
        type: FilterType.select,
        apiFieldName: 'sort',
        dependent: 'order_by',
        desc: 'Sort order',
        values: sortTypeMap.values.toList(),
      ),
      FilterOption(
        fieldName: 'Score',
        type: FilterType.select,
        apiFieldName: 'score',
        desc: 'Minimum score',
        values: List.generate(9, (i) => '${9 - i}+'),
        apiValues: List.generate(9, (i) => (9 - i).toString()),
      ),
      FilterOption(
        fieldName: 'Start Date',
        type: FilterType.date,
        apiFieldName: 'start_date',
        desc: 'Filter by start date',
      ),
      FilterOption(
        fieldName: 'End Date',
        type: FilterType.date,
        apiFieldName: 'end_date',
        desc: 'Filter by end date',
      ),
      FilterOption(
        fieldName: 'Magazines',
        type: FilterType.select,
        apiFieldName: 'magazines',
        desc: 'Filter by magazine',
        values: Mal.mangaMagazines.values.toList(),
      ),
      FilterOption(
        fieldName: 'Starting With',
        type: FilterType.select,
        apiFieldName: 'letter',
        desc: 'Filter by starting letter',
        values: List.generate(26, (i) => String.fromCharCode(i + 65)),
      ),
    ];
  }

  static List<FilterOption> get _forumFilters {
    return [
      FilterOption(
        fieldName: 'Board',
        type: FilterType.select,
        apiFieldName: 'board_id',
        mutualExclusive: 'subboard_id',
        desc: 'Select either Board or Sub Board',
        apiValues: ForumConstants.boards.keys.toList(),
        values: ForumConstants.boards.values.toList(),
      ),
      FilterOption(
        fieldName: 'SubBoard',
        type: FilterType.select,
        apiFieldName: 'subboard_id',
        mutualExclusive: 'board_id',
        desc: 'Select either Board or Sub Board',
        apiValues: ForumConstants.subBoards.keys.toList(),
        values: ForumConstants.subBoards.values.toList(),
      ),
      FilterOption(
        fieldName: 'Topic Username',
        type: FilterType.equal,
        apiFieldName: 'topic_user_name',
        desc: 'Filter by topic creator username',
      ),
      FilterOption(
        fieldName: 'Username',
        type: FilterType.equal,
        apiFieldName: 'user_name',
        desc: 'Any username',
      ),
    ];
  }

  static List<FilterOption> get _userFilters {
    return [
      FilterOption(
        fieldName: 'Location',
        type: FilterType.equal,
        apiFieldName: 'loc',
        desc: 'Ex: California',
      ),
      FilterOption(
        fieldName: 'Age Low',
        type: FilterType.equal,
        apiFieldName: 'agelow',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        desc: 'Ex: 18',
      ),
      FilterOption(
        fieldName: 'Age High',
        type: FilterType.equal,
        apiFieldName: 'agehigh',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        desc: 'Ex: 24',
      ),
      FilterOption(
        fieldName: 'Gender',
        type: FilterType.select,
        apiFieldName: 'g',
        desc: 'Filter by gender',
        apiValues: [0, 1, 2, 3],
        values: ["Don't care", 'Male', 'Female', 'Non-Binary'],
      ),
    ];
  }

  static List<FilterOption> get _featuredFilters {
    return [
      FilterOption(
        fieldName: 'Tags',
        type: FilterType.select,
        apiFieldName: 'tags',
        desc: 'Filter featured articles by tag',
        apiValues: ForumConstants.tags.keys.toList(),
        values: ForumConstants.tags.values.toList(),
      ),
    ];
  }

  static List<FilterOption> get _newsFilters {
    return [
      FilterOption(
        fieldName: 'Tags',
        type: FilterType.single_list,
        apiFieldName: 'tags',
        singleList: ForumConstants.newsTags,
        desc: 'Filter news by tag',
      ),
    ];
  }

  static List<FilterOption> get _interestStackFilters {
    return [
      FilterOption(
        fieldName: 'Type',
        type: FilterType.select,
        apiFieldName: 'type',
        desc: 'Filter by interest stack type',
        apiValues: [null, 'anime', 'manga', 'myanimelist'],
        values: ['All', 'Anime', 'Manga', 'MyAnimeList'],
      ),
    ];
  }
}

// --- Seasonal Widget ---

class _SeasonalSection extends StatefulWidget {
  @override
  State<_SeasonalSection> createState() => _SeasonalSectionState();
}

class _SeasonalSectionState extends State<_SeasonalSection> {
  static const int _maxYear = 2027;
  static const int _minYear = 1960;
  static final int _totalYears = _maxYear - _minYear + 1;

  final List<String> _seasonList = seasonMapCaps.values.toList();
  late final List<String> _yearList;

  late int _selectedYearIndex;
  late int _selectedSeasonIndex;

  @override
  void initState() {
    super.initState();
    _yearList =
        List.generate(_totalYears, (i) => (_maxYear - i).toString());

    final currentYear = DateTime.now().year;
    _selectedYearIndex = (_maxYear - currentYear).abs();
    _selectedSeasonIndex = MalApi.getSeasonType().index;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Year scrollable row
        HeaderWidget(
          header: _yearList,
          selectedIndex: _selectedYearIndex,
          shouldAnimate: false,
          fontSize: 19,
          listPadding: const EdgeInsets.symmetric(horizontal: 20),
          onPressed: (index) {
            if (mounted) setState(() => _selectedYearIndex = index);
          },
        ),
        SB.h15,
        // Season scrollable row
        HeaderWidget(
          header: _seasonList,
          selectedIndex: _selectedSeasonIndex,
          fontSize: 13,
          shouldAnimate: false,
          itemPadding: const EdgeInsets.symmetric(horizontal: 20),
          listPadding: const EdgeInsets.symmetric(horizontal: 20),
          onPressed: (index) {
            if (mounted) setState(() => _selectedSeasonIndex = index);
          },
        ),
        SB.h15,
        // Action button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ShadowButton(
              onPressed: () {
                final season = seasonMap.keys.elementAt(_selectedSeasonIndex);
                final year =
                    int.parse(_yearList.elementAt(_selectedYearIndex));
                gotoPage(
                  context: context,
                  newPage: GeneralSearchScreen(
                    searchQuery:
                        '#${seasonMap[season]}@$year',
                    autoFocus: false,
                    showBackButton: true,
                  ),
                );
              },
              child: const Text('Search'),
            ),
          ),
        ),
      ],
    );
  }
}
