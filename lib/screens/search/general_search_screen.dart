import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType, gotoPage;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart';
import 'package:mywatchlist/screens/search/search_filter_panel.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/screens/search/search_history.dart';
import 'package:mywatchlist/screens/search/search_home_view.dart';
import 'package:mywatchlist/screens/search/search_options.dart';
import 'package:mywatchlist/screens/search/search_queries.dart';
import 'package:mywatchlist/screens/search/search_service.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/common/select/select.dart' show SelectOption, labelOf;
import 'package:mywatchlist/widgets/MAL/search/filtermodal.dart';

part 'search_active_filters.dart';
part 'search_bar_part.dart';
part 'search_logic.dart';
part 'search_results_part.dart';


/// Where the search is: before a search (history, autocomplete), running, with results, with none,
/// or failed.
enum SearchStage { notStarted, started, loaded, empty, error }

/// Search over anime, manga, characters, people, users, forum topics, articles, clubs and interest
/// stacks, with filters, special `#` queries, search by MyAnimeList id and autocomplete.
///
/// Other screens open it with the constructor or, more simply, with one of the entry points:
/// [byQuery], [byGenre], [byStudio], [byMagazine], [byTag], [bySeason], [byRanking],
/// [byMangaRanking], [bySuggested], [byUser]. `AppRoutes.openSearch` pushes it too.
class GeneralSearchScreen extends StatefulWidget {
  final String? searchQuery;
  final bool autoFocus;
  final bool showBackButton;
  final String category;

  /// Initial filters in the shape older callers use (genres by name, a producer or magazine,
  /// a news / featured tag). Read once, when the screen opens.
  final Map<String, FilterOption>? filterOutputs;

  /// Initial filters, typed. Wins over [filterOutputs] when both are given.
  final SearchFilters? filters;

  const GeneralSearchScreen({
    super.key,
    this.searchQuery,
    this.category = SearchCategory.all,
    this.showBackButton = false,
    this.autoFocus = false,
    this.filterOutputs,
    this.filters,
  });

  // --- Entry points ---------------------------------------------------------------------------

  /// Searches [query] in [category] (all categories by default).
  static GeneralSearchScreen byQuery(
    String query, {
    String category = SearchCategory.all,
    bool showBackButton = true,
  }) =>
      GeneralSearchScreen(searchQuery: query, category: category, showBackButton: showBackButton);

  /// Anime or manga with the given genres. Names are matched in any spelling (`Slice_of_Life`,
  /// `Slice of Life`), [ids] are MyAnimeList genre ids, [excluded] are names to leave out.
  static GeneralSearchScreen byGenre({
    List<String> names = const [],
    List<int> ids = const [],
    List<String> excluded = const [],
    String category = SearchCategory.anime,
  }) {
    final manga = category == SearchCategory.manga;
    final include = <int>[
      ...SearchCatalog.genreIds(names, manga: manga),
      for (final id in ids)
        if (SearchCatalog.genresEng(manga: manga).containsKey(id)) id,
    ].toSet().toList();
    final exclude = SearchCatalog.genreIds(excluded, manga: manga).where((id) => !include.contains(id)).toList();
    return GeneralSearchScreen(
      category: manga ? SearchCategory.manga : SearchCategory.anime,
      showBackButton: true,
      filters: SearchFilters.empty.set(FilterKey.genresIn, include).set(FilterKey.genresOut, exclude),
    );
  }

  /// Anime of one studio (producer). [name] is shown when the id is not in the catalog.
  static GeneralSearchScreen byStudio({required int id, String? name}) => GeneralSearchScreen(
        category: SearchCategory.anime,
        showBackButton: true,
        filters: SearchFilters.empty
            .set(FilterKey.producer, id)
            .set(FilterKey.producerLabel, SearchCatalog.producerName(id) == null ? name : null),
      );

  /// Manga of one magazine. [name] is shown when the id is not in the catalog.
  static GeneralSearchScreen byMagazine({required int id, String? name}) => GeneralSearchScreen(
        category: SearchCategory.manga,
        showBackButton: true,
        filters: SearchFilters.empty
            .set(FilterKey.magazine, id)
            .set(FilterKey.magazineLabel, SearchCatalog.magazineName(id) == null ? name : null),
      );

  /// News or featured articles with one tag (the tag key, e.g. `Interview` or `New Anime`).
  static GeneralSearchScreen byTag(String tag, {bool news = false}) => GeneralSearchScreen(
        category: news ? SearchCategory.news : SearchCategory.featured,
        showBackButton: true,
        filters: SearchFilters.empty.set(FilterKey.tag, tag),
      );

  /// Anime of a season.
  static GeneralSearchScreen bySeason(SeasonType season, int year) =>
      GeneralSearchScreen(searchQuery: SpecialQuery.season(season, year), showBackButton: true);

  /// An anime ranking (top airing, most popular…).
  static GeneralSearchScreen byRanking(RankingType type) =>
      GeneralSearchScreen(searchQuery: SpecialQuery.animeRanking(type), showBackButton: true);

  /// A manga ranking.
  static GeneralSearchScreen byMangaRanking(MangaRanking type) =>
      GeneralSearchScreen(searchQuery: SpecialQuery.mangaRanking(type), showBackButton: true);

  /// The signed-in user's suggestions (`anime` or `manga`).
  static GeneralSearchScreen bySuggested({String category = SearchCategory.anime}) =>
      GeneralSearchScreen(searchQuery: SpecialQuery.suggested(category), showBackButton: true);

  /// MyAnimeList users matching [username].
  static GeneralSearchScreen byUser(String username) => GeneralSearchScreen(
        searchQuery: username,
        category: SearchCategory.user,
        showBackButton: true,
      );

  @override
  State<GeneralSearchScreen> createState() => _GeneralSearchScreenState();
}

class _GeneralSearchScreenState extends State<GeneralSearchScreen> with TickerProviderStateMixin {
  static const SearchService _service = SearchService();
  static const Duration _suggestDelay = Duration(milliseconds: 400);

  final FocusNode _focusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SearchHistory _history = SearchHistory.instance;
  final ValueNotifier<SuggestionState> _suggestions = ValueNotifier(SuggestionState.idle);

  late String _category;
  late SearchFilters _filters;
  SearchDisplay _display = SearchDisplay.defaults;

  SearchStage _stage = SearchStage.notStarted;
  SearchStage _loadMoreStage = SearchStage.notStarted;
  SearchPage? _page;
  SearchRequest? _request;
  bool _showPanel = false;
  bool _specialQuery = false;

  /// Bumped by every search / reset; an answer that comes back with an older value is dropped.
  int _searchToken = 0;
  int _suggestToken = 0;
  Timer? _suggestTimer;

  /// Tabs of the "all" view: one per category that has results.
  List<String> _allTabs = const [];
  TabController? _tabController;

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _filters = widget.filters?.forCategory(_category) ??
        SearchFilters.fromOutputs(widget.filterOutputs, category: _category);
    _loadDisplay();

    _searchController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
    final initial = widget.searchQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      _searchController.text = initial;
      _specialQuery = initial.startsWith('#');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch(initial);
      });
    } else if (_filters.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch('');
      });
    }
  }

  Future<void> _loadDisplay() async {
    await _history.load();
    _set(() {
      _display = SearchDisplay(
        type: _history.displayType,
        subType: _history.displaySubType,
        gridColumns: _history.gridAxisCount,
        gridHeight: _history.gridHeight,
      );
    });
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _searchController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _tabController?.dispose();
    _suggestions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showPanel,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showPanel) _set(() => _showPanel = false);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Column(
          children: [
            _buildSearchBar(context),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildBody(context)),
                  if (_showPanel)
                    Positioned.fill(
                      child: SearchFilterPanel(
                        category: _category,
                        filters: _filters,
                        display: _display,
                        onApply: _applyPanel,
                        onClose: () => _set(() => _showPanel = false),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
