import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart' show SearchCategory;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/requests/requests_bloc.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/MAL/home/news_widget.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/common/slivers.dart';
import 'package:mywatchlist/widgets/home/home_chips.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/home/home_showcase.dart';
import 'package:mywatchlist/widgets/home/maintenance_notice.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';

/// The MyAnimeList home tab: the app bar with the shortcut chips, then the sections the user
/// picked in the home settings (news, seasonal and ranking rows, suggestions, the user's list and
/// the forum).
class MalHomePage extends StatefulWidget {
  const MalHomePage({super.key});
  @override
  State<MalHomePage> createState() => _MalHomePageState();
}

class _MalHomePageState extends State<MalHomePage> {
  bool _initialDataLoaded = false;
  late final ScrollController scrollController;

  /// Bumped by a pull to refresh: the sections that load on their own reload when it changes.
  int _refresh = 0;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();

    // Load preferences using BLoC; _loadData is triggered by the BlocConsumer listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
      checkMalMaintenance(context);
      showHomeShowcaseOnce(context);
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _loadData({bool forceUpdate = false}) {
    final requestsBloc = BlocProvider.of<RequestsBloc>(context);
    final preferences = context.read<HomePreferencesBloc>().state.preferences;

    for (final section in preferences.sections.where((s) => s.enabled)) {
      final cache = section.cacheDurationHours;
      switch (section.type) {
        case SectionType.news:
          requestsBloc.add(LoadNewsEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.seasonNow:
          // A fixed season is loaded by its own section, not by the shared current-season request.
          if (section.season == null && section.year == null) {
            requestsBloc.add(LoadSeasonNowEvent(
                forceUpdate: forceUpdate, cacheDurationHours: cache));
          }
          break;
        case SectionType.upcoming:
          requestsBloc.add(LoadUpcomingAnimeEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topFavorites:
          requestsBloc.add(LoadTopAnimeFavoriteEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topPopular:
          requestsBloc.add(LoadTopAnimeByPopularityEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topScore:
          requestsBloc.add(LoadTopAnimeByScoreEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.suggested:
          requestsBloc.add(LoadSuggestedAnimeEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topAnimeAiring:
          requestsBloc.add(LoadTopAnimeAiringEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topAnimeTV:
          requestsBloc.add(LoadTopAnimeTVEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topAnimeMovie:
          requestsBloc.add(LoadTopAnimeMovieEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topAnimeSpecial:
          requestsBloc.add(LoadTopAnimeSpecialEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topManga:
          requestsBloc.add(LoadTopMangaEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.topMangaPopular:
          requestsBloc.add(LoadTopMangaByPopularityEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.features:
          requestsBloc.add(LoadFeaturesEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
          break;
        case SectionType.userList:
        case SectionType.forum:
          // Loaded by their own widgets (lib/widgets/home/home_sections.dart).
          break;
      }
    }
  }

  Future<void> _onRefresh() async {
    if (!mounted) return;
    HomeSectionCache.clear();
    context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
    setState(() => _refresh++);
    _loadData(forceUpdate: true);
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    // Section titles and chips read S.current: rebuild when the app language changes.
    Localizations.localeOf(context);
    return BlocConsumer<HomePreferencesBloc, HomePreferencesState>(
      listener: (context, state) {
        if (!state.isLoading && !_initialDataLoaded) {
          _initialDataLoaded = true;
          _loadData();
        }
      },
      builder: (context, homePreferencesState) {
        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: NestedScrollView(
            controller: scrollController,
            headerSliverBuilder: (_, __) => [
              SliverLayoutBuilder(
                builder: (context, constraints) => _buildAppBar(constraints, theme),
              )
            ],
            body: RefreshIndicator(
              onRefresh: _onRefresh,
              child: homePreferencesState.isLoading
                  ? loadingError()
                  : CustomScrollWrapper(
                      _buildSections(theme, homePreferencesState.preferences)),
            ),
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(SliverConstraints constraints, ThemeData theme) {
    final scrolled = constraints.scrollOffset >= 50;
    return SliverAppBar(
      automaticallyImplyLeading: false,
      pinned: true,
      floating: true,
      title: AppBarHome(
        transparent: !scrolled,
        backgroundColor: scrolled ? theme.appBarTheme.backgroundColor : Colors.transparent,
        showAvatar: true,
        showSettings: true,
      ),
      actions: const <Widget>[],
      titleSpacing: 0.0,
      backgroundColor:
          constraints.scrollOffset > 20 ? theme.appBarTheme.backgroundColor : Colors.transparent,
      toolbarHeight: kToolbarHeight,
      bottom: PreferredSize(
        preferredSize: const Size(double.infinity, 52),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 7.0),
          child: HomeChipsBar(elevated: constraints.scrollOffset > 0),
        ),
      ),
    );
  }

  List<Widget> _buildSections(ThemeData theme, MalHomePreferences preferences) {
    final tileSize = getTileSizeValues(preferences.tileSize);
    final enabledSections = preferences.sections.where((s) => s.enabled).toList();

    return [
      SliverList.builder(
        itemCount: enabledSections.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _buildSection(theme, enabledSections[index], tileSize),
          );
        },
      ),
    ];
  }

  /// Where a ranking-backed section lands when its title is tapped, null for the others.
  Widget? _screenFor(HomeSectionPreference section) {
    switch (section.type) {
      case SectionType.seasonNow:
        return GeneralSearchScreen.bySeason(section.effectiveSeason, section.effectiveYear);
      case SectionType.suggested:
        return GeneralSearchScreen.bySuggested();
      case SectionType.upcoming:
        return GeneralSearchScreen.byRanking(RankingType.UPCOMING);
      case SectionType.topScore:
        return GeneralSearchScreen.byRanking(RankingType.ALL);
      case SectionType.topFavorites:
        return GeneralSearchScreen.byRanking(RankingType.FAVOURITE);
      case SectionType.topPopular:
        return GeneralSearchScreen.byRanking(RankingType.BYPOPULARITY);
      case SectionType.topAnimeAiring:
        return GeneralSearchScreen.byRanking(RankingType.AIRING);
      case SectionType.topAnimeTV:
        return GeneralSearchScreen.byRanking(RankingType.TV);
      case SectionType.topAnimeMovie:
        return GeneralSearchScreen.byRanking(RankingType.MOVIE);
      case SectionType.topAnimeSpecial:
        return GeneralSearchScreen.byRanking(RankingType.SPECIAL);
      case SectionType.topManga:
        return GeneralSearchScreen.byMangaRanking(MangaRanking.all);
      case SectionType.topMangaPopular:
        return GeneralSearchScreen.byMangaRanking(MangaRanking.bypopularity);
      case SectionType.news:
      case SectionType.features:
      case SectionType.userList:
      case SectionType.forum:
        return null;
    }
  }

  Widget _buildSection(ThemeData theme, HomeSectionPreference section, TileSize tileSize) {
    final title = section.getDisplayTitle();
    switch (section.type) {
      case SectionType.news:
        return _buildArticles(
          section,
          category: 'news',
          isLoaded: (state) => state.isNewsLoaded,
          items: (state) => state.news,
          emptyText: S.current.Hw_Empty_News,
        );
      case SectionType.features:
        return _buildArticles(
          section,
          category: 'featured',
          isLoaded: (state) => state.isFeaturesLoaded,
          items: (state) => state.features,
          emptyText: S.current.Hw_Empty_Features,
        );
      case SectionType.userList:
        return HomeUserListSection(
          section: section,
          cardWidth: tileSize.containerHeight * (2 / 3),
          cardHeight: tileSize.containerHeight,
          refresh: _refresh,
        );
      case SectionType.forum:
        return HomeForumSection(section: section, refresh: _refresh);
      case SectionType.seasonNow:
        if (section.season != null || section.year != null) {
          return _buildFixedSeasonSection(theme, section, title, tileSize);
        }
        return _buildAnimeSection(theme, section, title, (s) => s.isSeasonNowLoaded,
            (s) => s.seasonNow, tileSize);
      case SectionType.suggested:
        return _buildAnimeSection(theme, section, title, (s) => s.isSuggestedAnimeLoaded,
            (s) => s.suggestedAnime, tileSize);
      case SectionType.upcoming:
        return _buildAnimeSection(theme, section, title, (s) => s.isUpcomingAnimeLoaded,
            (s) => s.upcomingAnime, tileSize);
      case SectionType.topScore:
        return _buildAnimeSection(theme, section, title, (s) => s.isTopAnimeByScoreLoaded,
            (s) => s.topAnimeByScore, tileSize);
      case SectionType.topFavorites:
        return _buildAnimeSection(theme, section, title, (s) => s.isTopAnimeFavoriteLoaded,
            (s) => s.topAnimeFavorite, tileSize);
      case SectionType.topPopular:
        return _buildAnimeSection(theme, section, title,
            (s) => s.isTopAnimeByPopularityLoaded, (s) => s.topAnimeByPopularity, tileSize);
      case SectionType.topAnimeAiring:
        return _buildAnimeSection(theme, section, title, (s) => s.isTopAnimeAiringLoaded,
            (s) => s.topAnimeAiring, tileSize);
      case SectionType.topAnimeTV:
        return _buildAnimeSection(theme, section, title, (s) => s.isTopAnimeTVLoaded,
            (s) => s.topAnimeTV, tileSize);
      case SectionType.topAnimeMovie:
        return _buildAnimeSection(theme, section, title, (s) => s.isTopAnimeMovieLoaded,
            (s) => s.topAnimeMovie, tileSize);
      case SectionType.topAnimeSpecial:
        return _buildAnimeSection(theme, section, title, (s) => s.isTopAnimeSpecialLoaded,
            (s) => s.topAnimeSpecial, tileSize);
      case SectionType.topManga:
        return _buildAnimeSection(theme, section, title, (s) => s.isTopMangaLoaded,
            (s) => s.topManga, tileSize);
      case SectionType.topMangaPopular:
        return _buildAnimeSection(theme, section, title,
            (s) => s.isTopMangaByPopularityLoaded, (s) => s.topMangaByPopularity, tileSize);
    }
  }

  /// News and featured articles: the filtered search of their category on tap of the title.
  Widget _buildArticles(
    HomeSectionPreference section, {
    required String category,
    required bool Function(RequestsState) isLoaded,
    required List<Map<String, String>> Function(RequestsState) items,
    required String emptyText,
  }) {
    final isNews = category == 'news';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: section.getDisplayTitle(),
            onTap: () => AppRoutes.openSearch(
              context,
              category: isNews ? SearchCategory.news : SearchCategory.featured,
            ),
          ),
          BlocBuilder<RequestsBloc, RequestsState>(
            buildWhen: (previous, current) =>
                isLoaded(previous) != isLoaded(current) ||
                !identical(items(previous), items(current)),
            builder: (context, state) {
              if (!isLoaded(state)) {
                return loadingCardList(
                  containerHeight: 250.0,
                  height: 250.0,
                  width: 320,
                  itemCount: section.itemCount > 15 ? 15 : section.itemCount,
                  listPadding: const EdgeInsets.only(left: 12, right: 15),
                );
              }
              final list = items(state);
              if (list.isEmpty) {
                return HomeMessage(icon: Icons.inbox_outlined, text: emptyText);
              }
              final shown = list.length > section.itemCount
                  ? list.sublist(0, section.itemCount)
                  : list;
              return HomePageNewsWidget(shown, category: category);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimeSection(
    ThemeData theme,
    HomeSectionPreference section,
    String title,
    bool Function(RequestsState) isLoaded,
    List<Anime> Function(RequestsState) getItems,
    TileSize tileSize,
  ) {
    // Match DailyAL: width = containerHeight * (2/3)
    final double cardWidth = tileSize.containerHeight * (2 / 3);
    final double cardHeight = tileSize.containerHeight;
    final isManga =
        section.type == SectionType.topManga || section.type == SectionType.topMangaPopular;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(section, title),
          BlocBuilder<RequestsBloc, RequestsState>(
            buildWhen: (previous, current) =>
                isLoaded(previous) != isLoaded(current) ||
                !identical(getItems(previous), getItems(current)),
            builder: (context, state) {
              if (!isLoaded(state)) {
                return _loadingRow(section, cardWidth, cardHeight);
              }
              return _animeRow(
                getItems(state),
                section: section,
                isManga: isManga,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
              );
            },
          ),
        ],
      ),
    );
  }

  /// A seasonal row for a season picked in the home settings (the shared request only knows the
  /// current season).
  Widget _buildFixedSeasonSection(
    ThemeData theme,
    HomeSectionPreference section,
    String title,
    TileSize tileSize,
  ) {
    final double cardWidth = tileSize.containerHeight * (2 / 3);
    final double cardHeight = tileSize.containerHeight;
    final season = section.effectiveSeason;
    final year = section.effectiveYear;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(section, title),
          HomeAsync<List<Anime>>(
            cacheKey: 'season:${season.name}:$year:${section.itemCount}',
            maxAge: Duration(hours: section.cacheDurationHours),
            refresh: _refresh,
            load: () => MalApi.getAnimeSeasonal(
              season,
              year,
              sortType: SortType.AnimeNumListUsers,
              limit: section.itemCount,
            ),
            loading: _loadingRow(section, cardWidth, cardHeight),
            builder: (context, items) => _animeRow(
              items,
              section: section,
              isManga: false,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(HomeSectionPreference section, String title) {
    final screen = _screenFor(section);
    return SectionHeader(
      title: title,
      onTap: screen == null ? null : () => AppRoutes.push<void>(context, screen),
    );
  }

  Widget _loadingRow(HomeSectionPreference section, double cardWidth, double cardHeight) {
    return loadingCardList(
      containerHeight: cardHeight,
      height: cardHeight,
      width: cardWidth,
      axis: Axis.horizontal,
      itemCount: section.itemCount,
      listPadding: const EdgeInsets.all(8.0),
    );
  }

  Widget _animeRow(
    List<Anime> items, {
    required HomeSectionPreference section,
    required bool isManga,
    required double cardWidth,
    required double cardHeight,
  }) {
    if (items.isEmpty) {
      return HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_Items);
    }
    final limited = items.length > section.itemCount ? items.sublist(0, section.itemCount) : items;
    return ContentListWidget(
      category: isManga ? "manga" : "anime",
      items: limited,
      height: cardHeight,
      showTime: section.type == SectionType.seasonNow || section.type == SectionType.upcoming,
      padding: const EdgeInsets.all(8.0),
      tileWidth: cardWidth,
      tileHeight: cardHeight,
    );
  }
}
