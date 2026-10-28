import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_filters.dart' show SearchCategory;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
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

  /// Asks the shared requests for every enabled section. A row of cards is fetched with the
  /// largest item count among the sections of its kind; the bloc skips what it already holds, so
  /// this runs again after each change of the home settings.
  void _loadData({bool forceUpdate = false}) {
    final requestsBloc = BlocProvider.of<RequestsBloc>(context);
    final preferences = context.read<HomePreferencesBloc>().state.preferences;

    final limits = <SectionType, int>{};
    final cacheHours = <SectionType, int>{};
    for (final section in preferences.sections.where((s) => s.enabled)) {
      final cache = section.cacheDurationHours;
      final type = section.type;
      switch (type) {
        case SectionType.news:
          requestsBloc.add(LoadNewsEvent(forceUpdate: forceUpdate, cacheDurationHours: cache));
        case SectionType.features:
          requestsBloc.add(LoadFeaturesEvent(forceUpdate: forceUpdate, cacheDurationHours: cache));
        case SectionType.userList:
        case SectionType.forum:
          // Loaded by their own widgets (lib/widgets/home/home_sections.dart).
          break;
        case SectionType.seasonNow:
          // Every season row (current or fixed) loads through its own section, sorted by members
          // like DailyAL (lib/widgets/home/home_sections.dart, loadHomeSeasonRow).
          break;
        default:
          if (!type.isContentRow) break;
          final count = section.itemCount.clamp(kHomeRowMinItems, kHomeRowMaxItems);
          if (count > (limits[type] ?? 0)) limits[type] = count;
          final hours = cacheHours[type];
          if (hours == null || cache < hours) cacheHours[type] = cache;
      }
    }
    for (final entry in limits.entries) {
      requestsBloc.add(LoadHomeRowEvent(
        entry.key,
        limit: entry.value,
        forceUpdate: forceUpdate,
        cacheDurationHours: cacheHours[entry.key] ?? 2,
      ));
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
      // Each time the preferences settle (first load, a change in the home settings), load what the
      // sections now need: a new section or a larger item count is fetched at once.
      listener: (context, state) {
        if (!state.isLoading) _loadData();
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
      // Not empty: an empty list lets Flutter add its endDrawer button (☰) to the app bar.
      actions: const [SizedBox.shrink()],
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
    final type = section.type;
    if (type == SectionType.seasonNow) {
      return GeneralSearchScreen.bySeason(section.effectiveSeason, section.effectiveYear);
    }
    if (type == SectionType.suggested) return GeneralSearchScreen.bySuggested();
    final anime = type.animeRanking;
    if (anime != null) return GeneralSearchScreen.byRanking(anime);
    final manga = type.mangaRanking;
    if (manga != null) return GeneralSearchScreen.byMangaRanking(manga);
    return null;
  }

  Widget _buildSection(ThemeData theme, HomeSectionPreference section, TileSize tileSize) {
    final title = section.getDisplayTitle();
    switch (section.type) {
      case SectionType.news:
        return _buildArticles(
          section,
          category: 'news',
          isLoaded: (state) => state.isNewsLoaded,
          isFailed: (state) => state.isNewsFailed,
          items: (state) => state.news,
          emptyText: S.current.Hw_Empty_News,
        );
      case SectionType.features:
        return _buildArticles(
          section,
          category: 'featured',
          isLoaded: (state) => state.isFeaturesLoaded,
          isFailed: (state) => state.isFeaturesFailed,
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
        return _buildSeasonSection(theme, section, title, tileSize);
      default:
        return _buildAnimeSection(theme, section, title, tileSize);
    }
  }

  /// News and featured articles: the filtered search of their category on tap of the title.
  Widget _buildArticles(
    HomeSectionPreference section, {
    required String category,
    required bool Function(RequestsState) isLoaded,
    required bool Function(RequestsState) isFailed,
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
            title: _articlesTitle(section, isNews),
            onTap: () => AppRoutes.openSearch(
              context,
              category: isNews ? SearchCategory.news : SearchCategory.featured,
            ),
          ),
          BlocBuilder<RequestsBloc, RequestsState>(
            buildWhen: (previous, current) =>
                isLoaded(previous) != isLoaded(current) ||
                isFailed(previous) != isFailed(current) ||
                !identical(items(previous), items(current)),
            builder: (context, state) {
              if (!isLoaded(state) && isFailed(state)) {
                return _failed(() => context.read<RequestsBloc>().add(isNews
                    ? LoadNewsEvent(forceUpdate: true, cacheDurationHours: section.cacheDurationHours)
                    : LoadFeaturesEvent(
                        forceUpdate: true, cacheDurationHours: section.cacheDurationHours)));
              }
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

  /// DailyAL's "News" for the news row unless the user renamed it.
  String _articlesTitle(HomeSectionPreference section, bool isNews) {
    final custom = section.customTitle;
    if (isNews && (custom == null || custom.isEmpty)) return S.current.News;
    return section.getDisplayTitle();
  }

  Widget _buildAnimeSection(
    ThemeData theme,
    HomeSectionPreference section,
    String title,
    TileSize tileSize,
  ) {
    // Match DailyAL: width = containerHeight * (2/3)
    final double cardWidth = tileSize.containerHeight * (2 / 3);
    final double cardHeight = tileSize.containerHeight;
    final type = section.type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(section, title),
          BlocBuilder<RequestsBloc, RequestsState>(
            buildWhen: (previous, current) =>
                !identical(previous.rows[type], current.rows[type]) ||
                previous.isRowFailed(type) != current.isRowFailed(type),
            builder: (context, state) {
              if (!state.isRowLoaded(type)) {
                if (state.isRowFailed(type)) {
                  return _failed(() => context.read<RequestsBloc>().add(LoadHomeRowEvent(
                        type,
                        limit: section.itemCount,
                        forceUpdate: true,
                        cacheDurationHours: section.cacheDurationHours,
                      )));
                }
                return _loadingRow(section, cardWidth, cardHeight);
              }
              return _animeRow(
                state.row(type),
                section: section,
                isManga: type.mangaRanking != null,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _failed(VoidCallback onRetry) => HomeMessage(
        icon: Icons.cloud_off_outlined,
        text: S.current.Hw_Section_Failed,
        actionLabel: S.current.Hw_Retry,
        onAction: onRetry,
      );

  /// A seasonal row (the current season or the one picked in the home settings), most members
  /// first like DailyAL.
  Widget _buildSeasonSection(
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
            load: () => loadHomeSeasonRow(
              season: season,
              year: year,
              limit: section.itemCount,
              maxAge: Duration(hours: section.cacheDurationHours),
              // After a pull to refresh, ask MAL again (the disk copy is only the fallback).
              preferCache: _refresh == 0,
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
      padding: const EdgeInsets.all(8.0),
      tileWidth: cardWidth,
      tileHeight: cardHeight,
    );
  }
}
