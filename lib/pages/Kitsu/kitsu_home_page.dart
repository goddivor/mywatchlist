import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_browse_screen.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_post_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuCategory, KitsuFeedPost;
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart' show KitsuMedia;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_list.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_row.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_rows.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The Kitsu home tab, in the order of Kitsu's own dashboard and explore page: the Quick update
/// carousel (signed in: the titles being watched with their next episode and a one-tap "✓
/// Episode N"), trending this week, what the people the user follows are watching, trending in
/// two of the user's favourite categories (signed in, hidden when none), then the sections of
/// the user's home layout that Kitsu can fill (news from the Kitsu News Network group, seasonal,
/// upcoming, top rated, favorites, popular, airing, formats, manga and the user's own list), and
/// the site's latest reactions. Suggestions, features and the forum have no Kitsu source.
///
/// Every title is drawn as a Kitsu tile with Kitsu's percentage and opens its Kitsu page.
class KitsuHomePage extends StatefulWidget {
  const KitsuHomePage({super.key});

  @override
  State<KitsuHomePage> createState() => _KitsuHomePageState();
}

class _KitsuHomePageState extends State<KitsuHomePage> {
  /// Bumped by a pull to refresh: every row reloads when it changes.
  int _refresh = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
    });
    UserManager.instance.addListener(_syncAccount);
    _syncAccount();
  }

  @override
  void dispose() {
    UserManager.instance.removeListener(_syncAccount);
    super.dispose();
  }

  bool? _wasSignedIn;

  /// Follows the Kitsu session: the account's title language applies to the rows once read, and
  /// the rows reload when it changes what they show.
  Future<void> _syncAccount() async {
    final signedIn = UserManager.instance.isAuthenticated(AccountType.kitsu);
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    final catalog = KitsuCatalog.instance;
    final before = catalog.account?.titleLang;
    if (!signedIn) {
      catalog.clearAccountPrefs();
    } else {
      await catalog.loadAccountPrefs();
    }
    if (!mounted || catalog.account?.titleLang == before) return;
    HomeSectionCache.clear();
    setState(() => _refresh++);
  }

  Future<void> _onRefresh() async {
    HomeSectionCache.clear();
    setState(() => _refresh++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    // Row titles read S.current: rebuild when the app language changes.
    Localizations.localeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
          builder: (context, state) {
            final tile = getTileSizeValues(state.preferences.tileSize);
            final cardHeight = tile.containerHeight;
            final cardWidth = cardHeight * (2 / 3);
            final sections = [
              for (final s in state.preferences.sections)
                if (s.enabled && kitsuSectionSupported(s)) s,
            ];
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  // Empty list does not suppress the automatic endDrawer button; a placeholder does.
                  actions: const [SizedBox.shrink()],
                  floating: true,
                  snap: true,
                  titleSpacing: 0,
                  toolbarHeight: kToolbarHeight,
                  backgroundColor: Colors.transparent,
                  title: const AppBarHome(transparent: true, showSettings: true),
                ),
                SliverToBoxAdapter(
                  child: ListenableBuilder(
                    listenable: UserManager.instance,
                    builder: (context, _) => UserManager.instance.isAuthenticated(AccountType.kitsu)
                        ? KitsuQuickUpdateRow(refresh: _refresh)
                        : const SizedBox.shrink(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: KitsuMediaRow(
                    cacheKey: 'kitsu:trending:anime',
                    title: S.current.Kitsu_Trending,
                    isAnime: true,
                    load: () => KitsuCatalog.instance.trending(isAnime: true),
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    refresh: _refresh,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ListenableBuilder(
                    listenable: UserManager.instance,
                    builder: (context, _) => !UserManager.instance.isAuthenticated(AccountType.kitsu)
                        ? const SizedBox.shrink()
                        : KitsuMediaRow(
                            cacheKey: 'kitsu:local-trending:anime',
                            title: S.current.Kitsu_Following_Trending,
                            isAnime: true,
                            load: () =>
                                KitsuCatalog.instance.trendingAmongFollowing(isAnime: true),
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            maxAge: const Duration(minutes: 10),
                            refresh: _refresh,
                            hideWhenEmpty: true,
                          ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ListenableBuilder(
                    listenable: UserManager.instance,
                    builder: (context, _) => UserManager.instance.isAuthenticated(AccountType.kitsu)
                        ? _FavouriteCategoryRows(cardWidth: cardWidth, cardHeight: cardHeight, refresh: _refresh)
                        : const SizedBox.shrink(),
                  ),
                ),
                SliverList.builder(
                  itemCount: sections.length,
                  itemBuilder: (context, i) => RepaintBoundary(
                    child: _section(context, sections[i], cardWidth, cardHeight),
                  ),
                ),
                SliverToBoxAdapter(
                  child: KitsuReactionsRow(title: S.current.Kr_Recent_Reactions, refresh: _refresh),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(BuildContext context, HomeSectionPreference s, double w, double h) {
    final title = s.getDisplayTitle();
    if (s.type == SectionType.news) {
      return KitsuNewsRow(
        title: title,
        limit: s.itemCount,
        maxAge: Duration(hours: s.cacheDurationHours),
        refresh: _refresh,
        onOpenPost: (post) => AppRoutes.push<void>(context, KitsuPostPage(postId: post.id)),
        onViewAll: () => AppRoutes.push<void>(context, _KitsuNewsScreen(title: title)),
      );
    }
    if (s.type == SectionType.userList) {
      return _UserListRow(section: s, cardWidth: w, cardHeight: h, refresh: _refresh);
    }
    final query = kitsuQueryForSection(s)!;
    return KitsuMediaRow.query(
      key: ValueKey('${s.type.name}:${query.key}'),
      title: title,
      query: query,
      cardWidth: w,
      cardHeight: h,
      itemCount: s.itemCount.clamp(1, KitsuCatalog.maxPage),
      maxAge: Duration(hours: s.cacheDurationHours),
      refresh: _refresh,
      onViewAll: () =>
          AppRoutes.push<void>(context, KitsuBrowseScreen(title: title, query: query)),
    );
  }
}

/// "Trending in <category>" for two of the categories the user marked as favourite on Kitsu,
/// drawn at random once per load as the site's explore page does. Nothing when there are none.
class _FavouriteCategoryRows extends StatelessWidget {
  final double cardWidth;
  final double cardHeight;
  final int refresh;

  const _FavouriteCategoryRows({required this.cardWidth, required this.cardHeight, required this.refresh});

  @override
  Widget build(BuildContext context) {
    return HomeAsync<List<KitsuCategory>>(
      cacheKey: 'kitsu:favourite-categories',
      maxAge: const Duration(hours: 6),
      refresh: refresh,
      load: () async {
        try {
          final id = await KitsuLibrary.instance.userId();
          final all = [...await KitsuCatalog.instance.favouriteCategories(id)]..shuffle();
          return all.take(2).toList();
        } catch (_) {
          return const <KitsuCategory>[];
        }
      },
      loading: const SizedBox.shrink(),
      builder: (context, categories) => Column(
        children: [
          for (final c in categories)
            KitsuMediaRow(
              key: ValueKey('fav-category:${c.id}'),
              cacheKey: 'kitsu:trending:category:${c.id}:anime',
              title: S.current.Kitsu_Trending_In(c.title),
              isAnime: true,
              load: () => KitsuCatalog.instance.trendingInCategory(c.id, isAnime: true),
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              refresh: refresh,
              hideWhenEmpty: true,
              onViewAll: () => AppRoutes.push<void>(
                context,
                KitsuBrowseScreen(
                  title: c.title,
                  trendingCategoryId: c.id,
                  query: KitsuMediaQuery(isAnime: true, filters: {'categories': c.slug}, sort: 'popularityRank'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The user's own Kitsu library (one category, optionally one status), most recently updated first.
class _UserListRow extends StatelessWidget {
  final HomeSectionPreference section;
  final double cardWidth;
  final double cardHeight;
  final int refresh;

  const _UserListRow({
    required this.section,
    required this.cardWidth,
    required this.cardHeight,
    required this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: section.getDisplayTitle(),
            onTap: () => AppRoutes.push<void>(
              context,
              Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: const KitsuUserPage(),
              ),
            ),
          ),
          ListenableBuilder(
            listenable: UserManager.instance,
            builder: (context, _) {
              if (!UserManager.instance.isAuthenticated(AccountType.kitsu)) {
                return HomeMessage(
                  icon: Icons.person_outline_rounded,
                  text: S.current.Kitsu_Sign_In_List,
                  actionLabel: S.current.Acc_Connect_Tracker,
                  onAction: () => AppRoutes.openManageAccounts(context),
                );
              }
              return _loaded();
            },
          ),
        ],
      ),
    );
  }

  Widget _loaded() {
    final category = section.userCategory;
    final status = ListEntryStatus.fromMal(section.userStatus);
    return HomeAsync<List<KitsuMedia>>(
      cacheKey: 'kitsu:userlist:$category:${status?.name ?? 'all'}:${section.itemCount}',
      maxAge: Duration(hours: section.cacheDurationHours),
      refresh: refresh,
      load: () async {
        final page = await KitsuLibrary.instance.page(
          isAnime: category == 'anime',
          status: status,
          offset: 0,
          limit: section.itemCount,
          sort: '-progressedAt',
        );
        return [for (final e in page.page.entries) kitsuEntryToMedia(e)];
      },
      loading: loadingCardList(
        containerHeight: cardHeight,
        height: cardHeight,
        width: cardWidth,
        itemCount: 8,
        listPadding: const EdgeInsets.all(8),
      ),
      builder: (context, items) {
        if (items.isEmpty) {
          return HomeMessage(icon: Icons.inbox_outlined, text: S.current.Hw_Empty_List);
        }
        return KitsuMediaRow.cards(
          items: items,
          cardWidth: cardWidth,
        );
      },
    );
  }
}

/// The whole Kitsu news feed (group 596) behind the home row's "View all".
class _KitsuNewsScreen extends StatefulWidget {
  final String title;
  const _KitsuNewsScreen({required this.title});

  @override
  State<_KitsuNewsScreen> createState() => _KitsuNewsScreenState();
}

class _KitsuNewsScreenState extends State<_KitsuNewsScreen> {
  late final KitsuFeedController _news = KitsuFeed().news();

  @override
  void dispose() {
    _news.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: KitsuFeedList(
        controller: _news,
        onOpenPost: (KitsuFeedPost post) =>
            AppRoutes.push<void>(context, KitsuPostPage(postId: post.id)),
      ),
    );
  }
}
