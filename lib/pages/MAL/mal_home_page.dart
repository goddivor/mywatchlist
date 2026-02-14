// ignore_for_file: unreachable_switch_default

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/requests/requests_bloc.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';
import 'package:mywatchlist/widgets/MAL/home/news_widget.dart';
import 'package:mywatchlist/widgets/common/slivers.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:mywatchlist/screens/settings/settings_page.dart';

class MalHomePage extends StatefulWidget {
  const MalHomePage({super.key});
  @override
  _MalHomePageState createState() => _MalHomePageState();
}

class _MalHomePageState extends State<MalHomePage> {
  bool hasOpened = false;
  bool _initialDataLoaded = false;
  final MalApi malApi = MalApi();
  final SeasonType currentSeason = MalApi.getSeasonType();
  String get currentSeasonName => MalApi.getSeasonName(currentSeason);
  int get currentSeasonYear => MalApi.getCurrentSeasonYear();
  late ScrollController scrollController;

  late Map<String, dynamic> topHeaders;

  void _initTopHeaders() {
    topHeaders = {
      'Categories': () {},
      'Genres': () {},
      'Top Anime': () {},
      'Top Manga': () {},
      'Top Airing': () {},
      'Popular Anime': () {},
      'Popular Manga': () {},
    };
  }

  @override
  void initState() {
    super.initState();
    hasOpened = false;
    scrollController = ScrollController();
    _initTopHeaders();

    // Load preferences using BLoC — _loadData will be triggered by BlocListener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
    });

    startOpeningAnimation();
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
          requestsBloc.add(LoadSeasonNowEvent(
              forceUpdate: forceUpdate, cacheDurationHours: cache));
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
      }
    }
  }

  void startOpeningAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        hasOpened = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomePreferencesBloc, HomePreferencesState>(
        listener: (context, homePreferencesState) {
      if (!homePreferencesState.isLoading && !_initialDataLoaded) {
        _initialDataLoaded = true;
        _loadData();
      }
    }, builder: (context, homePreferencesState) {
      final homePreferences = homePreferencesState.preferences;

      return BlocBuilder<ThemeBloc, ThemeState>(builder: (context, themeState) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return AnimatedOpacity(
          opacity: hasOpened ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: NestedScrollView(
              controller: scrollController,
              headerSliverBuilder: (_, __) => [
                SliverLayoutBuilder(
                  builder: (context, constraints) =>
                      _buildAppBar(constraints, theme, isDark),
                )
              ],
              body: RefreshIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: isDark ? theme.cardColor : Colors.white,
                onRefresh: () async {
                  if (mounted) {
                    context
                        .read<HomePreferencesBloc>()
                        .add(LoadHomePreferencesEvent());
                    _loadData(forceUpdate: true);
                    await Future.delayed(const Duration(milliseconds: 800));
                  }
                },
                child: homePreferencesState.isLoading
                    ? loadingError()
                    : CustomScrollWrapper(
                        _buildSections(theme, homePreferences)),
              ),
            ),
          ),
        );
      });
    });
  }

  SliverAppBar _buildAppBar(
      SliverConstraints constraints, ThemeData theme, bool isDark) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      pinned: true,
      floating: true,
      title: AppBarHome(
        transparent: constraints.scrollOffset < 50,
        backgroundColor: constraints.scrollOffset >= 50
            ? theme.appBarTheme.backgroundColor
            : Colors.transparent,
        showAvatar: true,
        showSettings: true,
        onSearchTap: () {},
        onBookmarksTap: () {},
        onCalendarTap: () {},
        onSettingsTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
      ),
      actions: const <Widget>[],
      titleSpacing: 0.0,
      backgroundColor: constraints.scrollOffset > 20
          ? theme.appBarTheme.backgroundColor
          : Colors.transparent,
      toolbarHeight: kToolbarHeight,
      bottom: _buildTopHeader(constraints, theme),
    );
  }

  PreferredSize _buildTopHeader(
      SliverConstraints constraints, ThemeData theme) {
    return PreferredSize(
      preferredSize: const Size(double.infinity, 52),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 7.0),
        child: SizedBox(
          height: 35,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: topHeaders.keys
                .map((key) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ShadowButton(
                        elevation: 0.0,
                        child: Text(
                          key,
                          style: theme.textTheme.bodySmall,
                        ),
                        onPressed: () {
                          final value = topHeaders[key];
                          if (value is Widget) {
                            gotoPage(context: context, newPage: value);
                          } else if (value is Function) {
                            value();
                          }
                        },
                        backgroundColor: theme.cardColor.withValues(alpha: 
                          constraints.scrollOffset > 0 ? 0.1 : 0.4,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(
      ThemeData theme, MalHomePreferences preferences) {
    final tileSize = getTileSizeValues(preferences.tileSize);
    final enabledSections =
        preferences.sections.where((s) => s.enabled).toList();

    return [
      SliverList.builder(
        itemCount: enabledSections.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _buildSection(
                theme, preferences, enabledSections[index], tileSize),
          );
        },
      ),
    ];
  }

  Widget _buildSection(ThemeData theme, MalHomePreferences preferences,
      HomeSectionPreference section, TileSize tileSize) {
    final title =
        section.getDisplayTitle(currentSeasonName, currentSeasonYear);
    switch (section.type) {
      case SectionType.news:
        return _buildNewsSection(theme, section);
      case SectionType.seasonNow:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isSeasonNowLoaded,
          (state) => state.seasonNow, tileSize,
        );
      case SectionType.suggested:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isSuggestedAnimeLoaded,
          (state) => state.suggestedAnime, tileSize,
        );
      case SectionType.upcoming:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isUpcomingAnimeLoaded,
          (state) => state.upcomingAnime, tileSize,
        );
      case SectionType.topScore:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopAnimeByScoreLoaded,
          (state) => state.topAnimeByScore, tileSize,
        );
      case SectionType.topFavorites:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopAnimeFavoriteLoaded,
          (state) => state.topAnimeFavorite, tileSize,
        );
      case SectionType.topPopular:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopAnimeByPopularityLoaded,
          (state) => state.topAnimeByPopularity, tileSize,
        );
      case SectionType.topAnimeAiring:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopAnimeAiringLoaded,
          (state) => state.topAnimeAiring, tileSize,
        );
      case SectionType.topAnimeTV:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopAnimeTVLoaded,
          (state) => state.topAnimeTV, tileSize,
        );
      case SectionType.topAnimeMovie:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopAnimeMovieLoaded,
          (state) => state.topAnimeMovie, tileSize,
        );
      case SectionType.topAnimeSpecial:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopAnimeSpecialLoaded,
          (state) => state.topAnimeSpecial, tileSize,
        );
      case SectionType.topManga:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopMangaLoaded,
          (state) => state.topManga, tileSize,
        );
      case SectionType.topMangaPopular:
        return _buildAnimeSection(
          theme, section, title,
          (state) => state.isTopMangaByPopularityLoaded,
          (state) => state.topMangaByPopularity, tileSize,
        );
      case SectionType.features:
        return _buildFeaturesSection(theme, section);
    }
  }

  Widget _buildNewsSection(ThemeData theme, HomeSectionPreference section) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: section.getDisplayTitle(
                currentSeasonName, currentSeasonYear),
            onTap: () {
              // Navigate to all news
            },
          ),
          BlocBuilder<RequestsBloc, RequestsState>(
            builder: (context, state) {
              if (!state.isNewsLoaded) {
                return loadingCardList(
                  containerHeight: 250.0,
                  height: 250.0,
                  width: 320,
                  itemCount:
                      section.itemCount > 15 ? 15 : section.itemCount,
                  listPadding:
                      const EdgeInsets.only(left: 12, right: 15),
                );
              } else if (state.news.isEmpty) {
                return _buildEmptyState(theme, 'No news available');
              } else {
                final newsItems = state.news.length > section.itemCount
                    ? state.news.sublist(0, section.itemCount)
                    : state.news;

                return HomePageNewsWidget(newsItems);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(ThemeData theme, HomeSectionPreference section) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: section.getDisplayTitle(
                currentSeasonName, currentSeasonYear),
            onTap: () {
              // Navigate to all features
            },
          ),
          BlocBuilder<RequestsBloc, RequestsState>(
            builder: (context, state) {
              if (!state.isFeaturesLoaded) {
                return loadingCardList(
                  containerHeight: 250.0,
                  height: 250.0,
                  width: 320,
                  itemCount:
                      section.itemCount > 15 ? 15 : section.itemCount,
                  listPadding:
                      const EdgeInsets.only(left: 12, right: 15),
                );
              } else if (state.features.isEmpty) {
                return _buildEmptyState(theme, 'No features available');
              } else {
                final featureItems = state.features.length > section.itemCount
                    ? state.features.sublist(0, section.itemCount)
                    : state.features;

                return HomePageNewsWidget(featureItems);
              }
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            onTap: () {
              // Navigate to full section
            },
          ),
          BlocBuilder<RequestsBloc, RequestsState>(
            builder: (context, state) {
              if (!isLoaded(state)) {
                return loadingCardList(
                  containerHeight: cardHeight,
                  height: cardHeight,
                  width: cardWidth,
                  axis: Axis.horizontal,
                  itemCount: section.itemCount,
                  listPadding: const EdgeInsets.all(8.0),
                );
              } else {
                final items = getItems(state);

                if (items.isEmpty) {
                  return _buildEmptyState(theme, 'No items available');
                }

                final limitedItems = items.length > section.itemCount
                    ? items.sublist(0, section.itemCount)
                    : items;

                final isMangaSection = section.type == SectionType.topManga ||
                    section.type == SectionType.topMangaPopular;
                return ContentListWidget(
                  category: isMangaSection ? "manga" : "anime",
                  items: limitedItems,
                  height: cardHeight,
                  showTime: section.type == SectionType.seasonNow ||
                      section.type == SectionType.upcoming,
                  padding: const EdgeInsets.all(8.0),
                  tileWidth: cardWidth,
                  tileHeight: cardHeight,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
