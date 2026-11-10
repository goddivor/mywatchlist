import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:mwl_commons/mwl_commons.dart' show InterestStack, RankedPersonHtml, ReviewHtml;
import 'package:mywatchlist/constants/constants.dart' show DisplayType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/explore/explore_images.dart';
import 'package:mywatchlist/screens/explore/explore_list_screen.dart';
import 'package:mywatchlist/screens/explore/explore_sections.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/screens/explore/random_picker.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';

/// The Explore tab: random picks, rankings, genres, the current season, and what the MyAnimeList
/// community is recommending, reviewing, stacking and loving.
///
/// Every data section below the first screen loads only when it scrolls near the viewport
/// ([AsyncSection]) and its answer is cached for ten minutes, so switching between Anime and
/// Manga or coming back to the tab is instant. Searching lives in the search screen, opened from
/// the app bar's search icon (DailyAL has no second search field on this page).
class MalExplorePage extends StatefulWidget {
  const MalExplorePage({super.key});

  @override
  State<MalExplorePage> createState() => _MalExplorePageState();
}

class _MalExplorePageState extends State<MalExplorePage> {
  String _category = 'anime';

  /// True once the page is scrolled: the status bar scrim then takes the colour of the app
  /// bar scrolled under, as the bar does when it floats back over the content.
  final _scrolled = ValueNotifier<bool>(false);

  bool get _isAnime => _category == 'anime';

  @override
  void initState() {
    super.initState();
    ExploreImages.registerLicense();
  }

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) _scrolled.value = n.metrics.extentBefore > 0;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final isAnime = _isAnime;
    // The floating app bar leaves with the content; DailyAL keeps the status bar tinted, so the
    // page never draws its cards under the clock.
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: _page(context, category, isAnime),
        ),
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: _StatusBarScrim(scrolled: _scrolled),
        ),
      ],
    );
  }

  Widget _page(BuildContext context, String category, bool isAnime) {
    return CustomScrollView(
      key: PageStorageKey('explore-$category'),
      slivers: [
        // The same header as the home tab: logo or title, search / bookmarks / calendar /
        // settings, and the account avatar (sidebar).
        SliverAppBar(
          automaticallyImplyLeading: false,
          floating: true,
          snap: true,
          titleSpacing: 0,
          toolbarHeight: kToolbarHeight,
          title: AppBarHome(
            title: S.current.Explore_Title,
            transparent: true,
            showSettings: true,
          ),
          // A non-empty action list stops the AppBar from adding its own end-drawer (☰)
          // button next to the avatar, which already opens the sidebar. Flutter 3.35 has no
          // `automaticallyImplyActions`, and an empty list does not count.
          actions: const [SizedBox.shrink()],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kExplorePadding, 14, kExplorePadding, 14),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                // Text only, like DailyAL's Anime / Manga switch.
                ButtonSegment(value: 'anime', label: Text(S.current.Explore_Anime)),
                ButtonSegment(value: 'manga', label: Text(S.current.Explore_Manga)),
              ],
              selected: {category},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
          ),
        ),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('random'), child: RandomPickerRow(isAnime: isAnime)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Explore_Rankings,
            onViewAll: () => AppRoutes.push<void>(context, RankingsScreen(isAnime: isAnime)),
          ),
        ),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('rankings'), child: RankingsRow(isAnime: isAnime)),
        SliverToBoxAdapter(child: ExploreSectionHeader(title: S.current.Genres)),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('genres'), child: GenresRow(category: category)),
        if (isAnime) ...[
          SliverToBoxAdapter(child: ExploreSectionHeader(title: S.current.Seasonal)),
          SliverToBoxAdapter(child: ExploreStorage.isolated(const SeasonalPicker())),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverToBoxAdapter(child: StudiosEntry()),
        ],
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Recommendations,
            onViewAll: () => AppRoutes.push<void>(
              context,
              ExploreListScreen<CommunityRecommendation>(
                title: S.current.Recommendations,
                paged: false,
                itemExtent: 372,
                loadPage: (_) => ExploreData.recommendations(category, limit: 100),
                itemBuilder: (_, item) => RecommendationCard(
                    item: item, category: category, width: double.infinity),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('recommendations'),
            child: _RecommendationsStrip(category: category)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Reviews,
            onViewAll: () => AppRoutes.push<void>(
              context,
              ExploreListScreen<ReviewHtml>(
                title: S.current.Reviews,
                itemExtent: 272,
                loadPage: (page) => ExploreData.reviews(category, page: page),
                itemBuilder: (_, review) =>
                    ReviewCard(review: review, category: category, width: double.infinity),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('reviews'), child: _ReviewsStrip(category: category)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Interest_Stacks,
            onViewAll: () => AppRoutes.push<void>(
              context,
              ExploreListScreen<InterestStack>(
                title: S.current.Interest_Stacks,
                itemExtent: null,
                loadPage: (page) => ExploreData.interestStacks(category, page: page),
                // The "view all" layout of the detail page's stacks, one card per row.
                itemBuilder: (_, stack) => InterestStackContentList(
                  horizPadding: 0,
                  interestStacks: [stack],
                  type: DisplayType.list_vert,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('stacks'), child: _StacksStrip(category: category)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Characters,
            onViewAll: () => AppRoutes.push<void>(context, _peopleScreen(isPerson: false)),
          ),
        ),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('characters'), child: const _PeopleStrip(isPerson: false)),
        SliverToBoxAdapter(
          child: ExploreSectionHeader(
            title: S.current.Seiyuu,
            onViewAll: () => AppRoutes.push<void>(context, _peopleScreen(isPerson: true)),
          ),
        ),
        SliverToBoxAdapter(
            key: ExploreStorage.strip('seiyuu'), child: const _PeopleStrip(isPerson: true)),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _peopleScreen({required bool isPerson}) => ExploreListScreen<RankedPersonHtml>(
        title: isPerson ? S.current.Seiyuu : S.current.Characters,
        grid: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 124,
          mainAxisExtent: 236,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
        ),
        loadPage: (page) =>
            isPerson ? ExploreData.topPeople(page: page) : ExploreData.topCharacters(page: page),
        itemBuilder: (_, p) => PersonTile(person: p, isPerson: isPerson),
      );
}

/// Keeps the scroll memory of the Explore lists apart.
///
/// [PageStorage] files a scroll position under the [PageStorageKey]s above it. Every horizontal
/// list of the page sat under the page's single `explore-<category>` key, so they all shared one
/// slot, and DailyAL's year row of the seasonal picker (a `ScrollablePositionedList`) stores an
/// `ItemPosition` there, not an offset: each list built after it then failed with
/// `'ItemPosition' is not a subtype of type 'double?'` and drew a grey box.
class ExploreStorage {
  ExploreStorage._();

  /// The key of a horizontal strip, so it keeps its own scroll offset.
  static PageStorageKey<String> strip(String name) => PageStorageKey('explore-strip-$name');

  /// Gives [child] a storage of its own that remembers nothing. The seasonal picker holds two
  /// rows whose saved states have different types (an `ItemPosition` and an offset), and it
  /// scrolls both to the selected season whenever it is built, so it needs no memory.
  static Widget isolated(Widget child) => PageStorage(bucket: _ForgetfulBucket(), child: child);
}

class _ForgetfulBucket extends PageStorageBucket {
  @override
  void writeState(BuildContext context, dynamic data, {Object? identifier}) {}

  @override
  dynamic readState(BuildContext context, {Object? identifier}) => null;
}

/// Paints the status bar area with the app bar's colour, scrolled under or not.
class _StatusBarScrim extends StatelessWidget {
  final ValueListenable<bool> scrolled;

  const _StatusBarScrim({required this.scrolled});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.paddingOf(context).top;
    if (height <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final base = bar.backgroundColor ?? theme.colorScheme.surface;
    final tint = bar.surfaceTintColor;
    final under = tint == null
        ? base
        : ElevationOverlay.applySurfaceTint(base, tint, bar.scrolledUnderElevation ?? 3);
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: scrolled,
        builder: (context, isScrolled, _) => AnimatedContainer(
          duration: kThemeChangeDuration,
          height: height,
          color: isScrolled ? under : base,
        ),
      ),
    );
  }
}

class _RecommendationsStrip extends StatelessWidget {
  final String category;

  const _RecommendationsStrip({required this.category});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<CommunityRecommendation>>(
      reloadKey: category,
      load: () => ExploreData.recommendations(category),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 320, width: 290),
      builder: (context, list) => HorizontalStrip(
        height: 340,
        count: list.length,
        itemBuilder: (context, i) => RecommendationCard(item: list[i], category: category),
      ),
    );
  }
}

class _ReviewsStrip extends StatelessWidget {
  final String category;

  const _ReviewsStrip({required this.category});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<ReviewHtml>>(
      reloadKey: category,
      load: () => ExploreData.reviews(category),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 240, width: 290),
      builder: (context, list) => HorizontalStrip(
        height: 260,
        count: list.length,
        itemBuilder: (context, i) => ReviewCard(review: list[i], category: category),
      ),
    );
  }
}

class _StacksStrip extends StatelessWidget {
  final String category;

  const _StacksStrip({required this.category});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<InterestStack>>(
      reloadKey: category,
      load: () => ExploreData.interestStacks(category),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 230, width: 310),
      // The strip of the detail page's Interest Stacks section, aligned on the Explore margins
      // (each card already has 5 px on its sides).
      builder: (context, list) => InterestStackContentList(
        horizPadding: 0,
        interestStacks: list,
        padding: const EdgeInsets.symmetric(horizontal: kExplorePadding - 5),
      ),
    );
  }
}

class _PeopleStrip extends StatelessWidget {
  final bool isPerson;

  const _PeopleStrip({required this.isPerson});

  @override
  Widget build(BuildContext context) {
    return AsyncSection<List<RankedPersonHtml>>(
      reloadKey: isPerson ? 'people' : 'characters',
      load: () => isPerson ? ExploreData.topPeople() : ExploreData.topCharacters(),
      isEmpty: (list) => list.isEmpty,
      skeleton: horizontalSkeleton(height: 200, width: 110),
      builder: (context, list) {
        final shown = list.take(20).toList();
        return HorizontalStrip(
          height: 236,
          count: shown.length,
          itemBuilder: (context, i) => PersonTile(person: shown[i], isPerson: isPerson),
        );
      },
    );
  }
}
