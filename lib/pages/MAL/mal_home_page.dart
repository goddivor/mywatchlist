// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:mywatchlist/enums.dart';
// import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
// import 'package:mywatchlist/services/api/MAL/mal_api.dart';
// import 'package:mywatchlist/user/requests/requests_bloc.dart';
// import 'package:mywatchlist/widgets/contentlistwidget.dart';
// import 'package:mywatchlist/widgets/custombutton.dart';
// import 'package:mywatchlist/widgets/homeappbar.dart';
// import 'package:mywatchlist/widgets/loadingcard.dart';
// import 'package:mywatchlist/widgets/news_widget.dart';
// import 'package:mywatchlist/widgets/slivers.dart';

// class MalHomePage extends StatefulWidget {
//   const MalHomePage({super.key});
//   @override
//   _MalHomePageState createState() => _MalHomePageState();
// }

// class _MalHomePageState extends State<MalHomePage> {
//   bool hasOpened = false;
//   final MalApi malApi = MalApi();
//   final SeasonType currentSeason = MalApi.getSeasonType();
//   String get currentSeasonName => MalApi.getSeasonName(currentSeason);
//   int get currentSeasonYear => MalApi.getCurrentSeasonYear();
//   ScrollController scrollController = ScrollController();
//   ScrollController bodyHeaderController = ScrollController();
//   // late AccountType _currentAccountType;

//   final Map<String, dynamic> topHeaders = {
//     'Header1': () => print('Header1 Clicked'),
//     'Header2': () => print('Header2 Clicked'),
//     // Ajoutez d'autres headers ici
//   };

//   @override
//   void initState() {
//     super.initState();
//     hasOpened = false;
//     // _currentAccountType = AccountManager.instance.getSelectedAccountType();
//     startOpeningAnimation();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadData();
//     });
//   }

//   void _loadData() {
//     final requestsBloc = BlocProvider.of<RequestsBloc>(context);
//     requestsBloc.add(LoadNewsEvent());
//     requestsBloc.add(LoadSeasonNowEvent());
//     requestsBloc.add(LoadUpcomingAnimeEvent());
//     requestsBloc.add(LoadTopAnimeFavoriteEvent());
//     requestsBloc.add(LoadTopAnimeByPopularityEvent());
//     requestsBloc.add(LoadTopAnimeByScoreEvent());
//     requestsBloc.add(LoadSuggestedAnimeEvent());
//   }

//   startOpeningAnimation() async {
//     setState(() {
//       hasOpened = true;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.only(left: 0, right: 0, top: 0),
//       child: AnimatedOpacity(
//         opacity: hasOpened ? 1 : 0,
//         duration: const Duration(milliseconds: 500),
//         child: DefaultTabController(
//           length: topHeaders.length,
//           child: NestedScrollView(
//             controller: scrollController,
//             headerSliverBuilder: (_, __) => [
//               SliverLayoutBuilder(
//                 builder: (context, constraints) => _buildAppBar(constraints),
//               )
//             ],
//             body: RefreshIndicator(
//               onRefresh: () async {
//                 if (mounted) {
//                   // Envoyer l'événement de force update à RequestsBloc
//                   context.read<RequestsBloc>().add(LoadNewsEvent());
//                   context.read<RequestsBloc>().add(LoadSeasonNowEvent());
//                   context.read<RequestsBloc>().add(LoadUpcomingAnimeEvent());
//                   context.read<RequestsBloc>().add(LoadTopAnimeFavoriteEvent());
//                   context
//                       .read<RequestsBloc>()
//                       .add(LoadTopAnimeByPopularityEvent());
//                   context.read<RequestsBloc>().add(LoadTopAnimeByScoreEvent());
//                   context.read<RequestsBloc>().add(LoadSuggestedAnimeEvent());

//                   // Optionnel : Attendre un court délai pour s'assurer que les données sont chargées
//                   await Future.delayed(const Duration(milliseconds: 500));
//                 }
//               },
//               child: CustomScrollWrapper(newSlivers()),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   List<Widget> newSlivers() {
//     return [
//       SliverList(
//         delegate: SliverChildListDelegate(
//           [
//             // Section: News
//             _buildSection(
//               title: 'News',
//               content: BlocBuilder<RequestsBloc, RequestsState>(
//                 builder: (context, state) {
//                   if (!state.isNewsLoaded) {
//                     return loadingCardList(
//                       containerHeight: 250.0,
//                       height: 250.0,
//                       width: 320,
//                       itemCount: 15,
//                       listPadding: const EdgeInsets.only(left: 12, right: 15),
//                     );
//                   } else if (state.news.isEmpty) {
//                     return const Center(child: Text('No news available'));
//                   } else {
//                     return HomePageNewsWidget(state.news);
//                   }
//                 },
//               ),
//             ),
//             // Section: Current Season Anime
//             _buildSection(
//               title: '$currentSeasonName $currentSeasonYear Anime',
//               content: BlocBuilder<RequestsBloc, RequestsState>(
//                 builder: (context, state) {
//                   if (!state.isSeasonNowLoaded) {
//                     return loadingCardList(
//                       containerHeight: 270.0,
//                       height: 270.0,
//                       width: 170.0,
//                       axis: Axis.horizontal,
//                       itemCount: 15,
//                       listPadding: const EdgeInsets.all(8.0),
//                     );
//                   } else if (state.seasonNow.isEmpty) {
//                     return const Center(
//                         child: Text('No current season anime available'));
//                   } else {
//                     return _buildAnimeList(state.seasonNow);
//                   }
//                 },
//               ),
//             ),
//             // Section: Suggested Anime
//             _buildSection(
//               title: 'Suggested Anime',
//               content: BlocBuilder<RequestsBloc, RequestsState>(
//                 builder: (context, state) {
//                   if (!state.isSuggestedAnimeLoaded) {
//                     return loadingCardList(
//                       containerHeight: 270.0,
//                       height: 270.0,
//                       width: 170.0,
//                       axis: Axis.horizontal,
//                       itemCount: 15,
//                       listPadding: const EdgeInsets.all(8.0),
//                     );
//                   } else if (state.suggestedAnime.isEmpty) {
//                     return const Center(
//                         child: Text('No suggested anime available'));
//                   } else {
//                     return _buildAnimeList(state.suggestedAnime);
//                   }
//                 },
//               ),
//             ),
//             // Section: Top Upcoming Anime
//             _buildSection(
//               title: 'Top Upcoming Anime',
//               content: BlocBuilder<RequestsBloc, RequestsState>(
//                 builder: (context, state) {
//                   if (!state.isUpcomingAnimeLoaded) {
//                     return loadingCardList(
//                       containerHeight: 270.0,
//                       height: 270.0,
//                       width: 170.0,
//                       axis: Axis.horizontal,
//                       itemCount: 15,
//                       listPadding: const EdgeInsets.all(8.0),
//                     );
//                   } else if (state.upcomingAnime.isEmpty) {
//                     return const Center(
//                         child: Text('No upcoming anime available'));
//                   } else {
//                     return _buildAnimeList(state.upcomingAnime);
//                   }
//                 },
//               ),
//             ),
//             // Section: Top Anime by Score
//             _buildSection(
//               title: 'Top Anime by Score',
//               content: BlocBuilder<RequestsBloc, RequestsState>(
//                 builder: (context, state) {
//                   if (!state.isTopAnimeByScoreLoaded) {
//                     return loadingCardList(
//                       containerHeight: 270.0,
//                       height: 270.0,
//                       width: 170.0,
//                       axis: Axis.horizontal,
//                       itemCount: 15,
//                       listPadding: const EdgeInsets.all(8.0),
//                     );
//                   } else if (state.topAnimeByScore.isEmpty) {
//                     return const Center(
//                         child: Text('No top scored anime available'));
//                   } else {
//                     return _buildAnimeList(state.topAnimeByScore);
//                   }
//                 },
//               ),
//             ),
//             // Section: All-time Anime Favorites
//             _buildSection(
//               title: 'All-time Anime Favorites',
//               content: BlocBuilder<RequestsBloc, RequestsState>(
//                 builder: (context, state) {
//                   if (!state.isTopAnimeFavoriteLoaded) {
//                     return loadingCardList(
//                       containerHeight: 270.0,
//                       height: 270.0,
//                       width: 170.0,
//                       axis: Axis.horizontal,
//                       itemCount: 15,
//                       listPadding: const EdgeInsets.all(8.0),
//                     );
//                   } else if (state.topAnimeFavorite.isEmpty) {
//                     return const Center(
//                         child: Text('No favorite anime available'));
//                   } else {
//                     return _buildAnimeList(state.topAnimeFavorite);
//                   }
//                 },
//               ),
//             ),
//             // Section: Most Popular Anime
//             _buildSection(
//               title: 'Most Popular Anime',
//               content: BlocBuilder<RequestsBloc, RequestsState>(
//                 builder: (context, state) {
//                   if (!state.isTopAnimeByPopularityLoaded) {
//                     return loadingCardList(
//                       containerHeight: 270.0,
//                       height: 270.0,
//                       width: 170.0,
//                       axis: Axis.horizontal,
//                       itemCount: 15,
//                       listPadding: const EdgeInsets.all(8.0),
//                     );
//                   } else if (state.topAnimeByPopularity.isEmpty) {
//                     return const Center(
//                         child: Text('No popular anime available'));
//                   } else {
//                     return _buildAnimeList(state.topAnimeByPopularity);
//                   }
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     ];
//   }

//   SliverAppBar _buildAppBar(SliverConstraints constraints) {
//     return SliverAppBar(
//       automaticallyImplyLeading: false,
//       pinned: true,
//       floating: true,
//       title: AppBarHome(),
//       actions: const <Widget>[],
//       titleSpacing: 0.0,
//       backgroundColor:constraints.scrollOffset > 0 ? null : Colors.transparent,
//       toolbarHeight: kToolbarHeight,
//       bottom: _buildTopHeader(constraints),
//     );
//   }

//   PreferredSize _buildTopHeader(SliverConstraints constraints) {
//     return PreferredSize(
//       preferredSize: const Size(double.infinity, 52),
//       child: Padding(
//         padding: const EdgeInsets.only(bottom: 10, top: 7.0),
//         child: SizedBox(
//           height: 35,
//           child: ListView(
//             scrollDirection: Axis.horizontal,
//             padding: const EdgeInsets.symmetric(horizontal: 8),
//             children: topHeaders.keys.map((key) {
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 3),
//                 child: ShadowButton(
//                   elevation: 0.0,
//                   onPressed: () {
//                     var value = topHeaders[key]!;
//                     if (value is Widget) {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (context) => value),
//                       );
//                     } else if (value is Function) {
//                       value();
//                     }
//                   },
//                   backgroundColor: Color(
//                     constraints.scrollOffset > 0
//                         ? Theme.of(context).cardColor.value
//                         : Theme.of(context).cardColor.value,
//                   ).withOpacity(constraints.scrollOffset > 0 ? 0.1 : 0.4),
//                   padding: const EdgeInsets.symmetric(horizontal: 15),
//                   child: Text(
//                     key,
//                     style: Theme.of(context).textTheme.bodySmall,
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//         ),
//       ),
//     );
//   }

//   // Méthode pour créer une section avec un titre et du contenu
//   Widget _buildSection({required String title, required Widget content}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 10.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SectionTitle(title: title, onTap: () {}),
//           content,
//         ],
//       ),
//     );
//   }

//   // Méthode pour afficher une liste horizontale d'animes
//   Widget _buildAnimeList(List<Anime> animes) {
//     return ContentListWidget(
//       //using horizontalwidget
//       category: "anime",
//       items: animes,
//       height: 270.0, // Hauteur de la liste
//       showTime: false,
//     );
//   }
// }

// class SectionTitle extends StatelessWidget {
//   final String title;
//   final VoidCallback onTap;

//   const SectionTitle({super.key, required this.title, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(8.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(title,
//               style:
//                   const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           IconButton(
//             icon: const Icon(Icons.arrow_forward),
//             onPressed: onTap,
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
// import 'package:mywatchlist/screens/settings/settings_page.dart';
import 'package:mywatchlist/user/requests/requests_bloc.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/utils/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/contentlistwidget.dart';
// import 'package:mywatchlist/widgets/custombutton.dart';
import 'package:mywatchlist/widgets/home/section_header.dart';
import 'package:mywatchlist/widgets/homeappbar.dart';
import 'package:mywatchlist/widgets/loadingcard.dart';
import 'package:mywatchlist/widgets/news_widget.dart';
import 'package:mywatchlist/widgets/slivers.dart';

class MalHomePage extends StatefulWidget {
  const MalHomePage({super.key});
  @override
  _MalHomePageState createState() => _MalHomePageState();
}

class _MalHomePageState extends State<MalHomePage>
    with SingleTickerProviderStateMixin {
  bool hasOpened = false;
  // late MalHomePreferences _preferences;
  final MalApi malApi = MalApi();
  final SeasonType currentSeason = MalApi.getSeasonType();
  String get currentSeasonName => MalApi.getSeasonName(currentSeason);
  int get currentSeasonYear => MalApi.getCurrentSeasonYear();
  late ScrollController scrollController;
  late AnimationController _animationController;

  final Map<String, dynamic> topFilters = {
    'Trending': () => print('Trending Selected'),
    'Popular': () => print('Popular Selected'),
    'New': () => print('New Selected'),
    'All': () => print('All Selected'),
  };

  @override
  void initState() {
    super.initState();
    hasOpened = false;
    scrollController = ScrollController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Load preferences using BLoC
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
    });

    // Load user preferences
    // _loadPreferences();

    // Start animation and load data
    startOpeningAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Future<void> _loadPreferences() async {
  //   try {
  //     // Load preferences from storage
  //     final loadedPreferences = await MalHomePreferences.load();

  //     if (mounted) {
  //       setState(() {
  //         _preferences = loadedPreferences;
  //       });

  //       // Load data based on preferences
  //       WidgetsBinding.instance.addPostFrameCallback((_) {
  //         _loadData();
  //       });
  //     }
  //   } catch (e) {
  //     debugPrint('Error loading preferences: $e');
  //     // Just load data with default preferences if there was an error
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       _loadData();
  //     });
  //   }
  // }

  // Future<void> _savePreferences() async {
  //   await _preferences.save();
  //   if (mounted) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: const Text('Preferences saved'),
  //         backgroundColor: Theme.of(context).colorScheme.primary,
  //         behavior: SnackBarBehavior.floating,
  //         duration: const Duration(seconds: 2),
  //       ),
  //     );
  //   }
  // }

  void _loadData() {
    final requestsBloc = BlocProvider.of<RequestsBloc>(context);
    final preferences = context.read<HomePreferencesBloc>().state.preferences;

    // Load all data based on enabled sections
    if (preferences.sections.any(
        (section) => section.type == SectionType.news && section.enabled)) {
      requestsBloc.add(LoadNewsEvent());
    }

    if (preferences.sections.any((section) =>
        section.type == SectionType.seasonNow && section.enabled)) {
      requestsBloc.add(LoadSeasonNowEvent());
    }

    if (preferences.sections.any(
        (section) => section.type == SectionType.upcoming && section.enabled)) {
      requestsBloc.add(LoadUpcomingAnimeEvent());
    }

    if (preferences.sections.any((section) =>
        section.type == SectionType.topFavorites && section.enabled)) {
      requestsBloc.add(LoadTopAnimeFavoriteEvent());
    }

    if (preferences.sections.any((section) =>
        section.type == SectionType.topPopular && section.enabled)) {
      requestsBloc.add(LoadTopAnimeByPopularityEvent());
    }

    if (preferences.sections.any(
        (section) => section.type == SectionType.topScore && section.enabled)) {
      requestsBloc.add(LoadTopAnimeByScoreEvent());
    }

    if (preferences.sections.any((section) =>
        section.type == SectionType.suggested && section.enabled)) {
      requestsBloc.add(LoadSuggestedAnimeEvent());
    }
  }

  void startOpeningAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {
        hasOpened = true;
      });
      _animationController.forward();
    }
  }

  // No longer need edit mode functions since editing is moved to settings

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
        builder: (context, homePreferencesState) {
      final homePreferences = homePreferencesState.preferences;

      return BlocBuilder<ThemeBloc, ThemeState>(builder: (context, themeState) {
        final theme = Theme.of(context);
        final isDark = themeState.isDarkMode;

        return Padding(
          padding: const EdgeInsets.only(left: 0, right: 0, top: 0),
          child: AnimatedOpacity(
            opacity: hasOpened ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              // floatingActionButton: _buildFloatingActionButton(theme),
              body: DefaultTabController(
                length: topFilters.length,
                child: NestedScrollView(
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
                        // Reload preferences using BLoC
                        context
                            .read<HomePreferencesBloc>()
                            .add(LoadHomePreferencesEvent());
                        // Reload all data when refreshing
                        _loadData();
                        // Wait for data to load
                        await Future.delayed(const Duration(milliseconds: 800));
                      }
                    },
                    child: homePreferencesState.isLoading
                        ? Center(child: CircularProgressIndicator())
                        : CustomScrollWrapper(
                            _buildSections(theme, homePreferences)),
                  ),
                ),
              ),
            ),
          ),
        );
      });
    });
  }

  // Widget _buildFloatingActionButton(ThemeData theme) {
  //   return FloatingActionButton(
  //     onPressed: () {
  //       // Navigate to settings page
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => const SettingsPage(),
  //         ),
  //       ).then((_) {
  //         // Reload preferences when returning from settings
  //         _loadPreferences();
  //       });
  //     },
  //     backgroundColor: theme.colorScheme.primary,
  //     foregroundColor: theme.colorScheme.onPrimary,
  //     elevation: 4,
  //     tooltip: 'Settings',
  //     child: const Icon(Icons.settings),
  //   );
  // }

  SliverAppBar _buildAppBar(
      SliverConstraints constraints, ThemeData theme, bool isDark) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      pinned: true,
      floating: true,
      title: AppBarHome(
        title: 'MyAnimeList',
        transparent: constraints.scrollOffset < 50,
        backgroundColor: constraints.scrollOffset >= 50
            ? theme.appBarTheme.backgroundColor
            : Colors.transparent,
        showAvatar: true,
        onSearchTap: () {
          // Handle search
        },
        onBookmarksTap: () {
          // Handle bookmarks
        },
        onCalendarTap: () {
          // Handle calendar
        },
      ),
      actions: const <Widget>[],
      titleSpacing: 0.0,
      backgroundColor: constraints.scrollOffset > 20
          ? theme.appBarTheme.backgroundColor
          : Colors.transparent,
      toolbarHeight: kToolbarHeight,
      bottom: _buildFiltersTab(constraints, theme, isDark),
    );
  }

  PreferredSize _buildFiltersTab(
      SliverConstraints constraints, ThemeData theme, bool isDark) {
    return PreferredSize(
      preferredSize: const Size(double.infinity, 52),
      child: Container(
        color: constraints.scrollOffset > 20
            ? theme.appBarTheme.backgroundColor
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 0, top: 4.0),
          child: TabBar(
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.secondary,
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
            dividerColor: Colors.transparent,
            tabs: topFilters.keys.map((key) {
              return Tab(text: key);
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Edit mode content has been moved to settings

  List<Widget> _buildSections(ThemeData theme, MalHomePreferences preferences) {
    final tileSize = getTileSizeValues(preferences.tileSize);

    return [
      SliverList(
        delegate: SliverChildListDelegate(
          preferences.sections
              .where((section) => section.enabled)
              .map((section) {
            switch (section.type) {
              case SectionType.news:
                return _buildNewsSection(theme, section);
              case SectionType.seasonNow:
                return _buildAnimeSection(
                  theme,
                  preferences,
                  section,
                  '$currentSeasonName $currentSeasonYear Anime',
                  (state) => state.isSeasonNowLoaded,
                  (state) => state.seasonNow,
                  tileSize,
                );
              case SectionType.suggested:
                return _buildAnimeSection(
                  theme,
                  preferences,
                  section,
                  'Suggested For You',
                  (state) => state.isSuggestedAnimeLoaded,
                  (state) => state.suggestedAnime,
                  tileSize,
                );
              case SectionType.upcoming:
                return _buildAnimeSection(
                  theme,
                  preferences,
                  section,
                  'Top Upcoming Anime',
                  (state) => state.isUpcomingAnimeLoaded,
                  (state) => state.upcomingAnime,
                  tileSize,
                );
              case SectionType.topScore:
                return _buildAnimeSection(
                  theme,
                  preferences,
                  section,
                  'Top Anime by Score',
                  (state) => state.isTopAnimeByScoreLoaded,
                  (state) => state.topAnimeByScore,
                  tileSize,
                );
              case SectionType.topFavorites:
                return _buildAnimeSection(
                  theme,
                  preferences,
                  section,
                  'All-time Anime Favorites',
                  (state) => state.isTopAnimeFavoriteLoaded,
                  (state) => state.topAnimeFavorite,
                  tileSize,
                );
              case SectionType.topPopular:
                return _buildAnimeSection(
                  theme,
                  preferences,
                  section,
                  'Most Popular Anime',
                  (state) => state.isTopAnimeByPopularityLoaded,
                  (state) => state.topAnimeByPopularity,
                  tileSize,
                );
              default:
                return const SizedBox.shrink();
            }
          }).toList(),
        ),
      ),
    ];
  }

  Widget _buildNewsSection(ThemeData theme, HomeSectionPreference section) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(0.1, 1.0, curve: Curves.easeOut),
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Anime News & Features',
              onTap: () {
                // Navigate to all news
              },
              color: theme.colorScheme.primary,
            ),
            BlocBuilder<RequestsBloc, RequestsState>(
              builder: (context, state) {
                if (!state.isNewsLoaded) {
                  return loadingCardList(
                    containerHeight: 250.0,
                    height: 250.0,
                    width: 320,
                    itemCount: section.itemCount > 15 ? 15 : section.itemCount,
                    listPadding: const EdgeInsets.only(left: 12, right: 15),
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
      ),
    );
  }

  Widget _buildAnimeSection(
    ThemeData theme,
    MalHomePreferences preferences,
    HomeSectionPreference section,
    String title,
    bool Function(RequestsState) isLoaded,
    List<Anime> Function(RequestsState) getItems,
    TileSize tileSize,
  ) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay =
            preferences.sections.indexWhere((s) => s.type == section.type) *
                0.1;
        final start = 0.1 + delay;
        final end = 1.0;

        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(start, end, curve: Curves.easeOut),
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: title,
              onTap: () {
                // Navigate to full section
              },
              color: theme.colorScheme.primary,
            ),
            BlocBuilder<RequestsBloc, RequestsState>(
              builder: (context, state) {
                if (!isLoaded(state)) {
                  return loadingCardList(
                    containerHeight: tileSize.containerHeight,
                    height: tileSize.contentHeight,
                    width: tileSize.contentWidth,
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

                  return ContentListWidget(
                    category: "anime",
                    items: limitedItems,
                    height: tileSize.containerHeight,
                    showTime: section.type == SectionType.seasonNow ||
                        section.type == SectionType.upcoming,
                    padding: const EdgeInsets.all(8.0),
                    tileWidth: tileSize.contentWidth,
                    tileHeight: tileSize.contentHeight,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
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

class TileSize {
  final double contentHeight;
  final double contentWidth;
  final double containerHeight;
  final double loadingContainerHeight;

  const TileSize({
    required this.contentHeight,
    required this.contentWidth,
    required this.containerHeight,
    required this.loadingContainerHeight,
  });
}

TileSize getTileSizeValues(HomePageTileSize size) {
  switch (size) {
    case HomePageTileSize.xs:
      return const TileSize(
        contentHeight: 104,
        contentWidth: 80,
        containerHeight: 187.6,
        loadingContainerHeight: 130,
      );
    case HomePageTileSize.s:
      return const TileSize(
        contentHeight: 130,
        contentWidth: 100,
        containerHeight: 215,
        loadingContainerHeight: 162.5,
      );
    case HomePageTileSize.m:
      return const TileSize(
        contentHeight: 160,
        contentWidth: 120,
        containerHeight: 237,
        loadingContainerHeight: 200,
      );
    case HomePageTileSize.l:
      return const TileSize(
        contentHeight: 200,
        contentWidth: 150,
        containerHeight: 280,
        loadingContainerHeight: 250,
      );
    case HomePageTileSize.xl:
      return const TileSize(
        contentHeight: 230,
        contentWidth: 172.93,
        containerHeight: 322,
        loadingContainerHeight: 287.5,
      );
  }
}
