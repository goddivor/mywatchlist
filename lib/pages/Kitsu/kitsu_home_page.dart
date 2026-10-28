import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_browse_screen.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Anime;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_row.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_rows.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/loading/loadingcard.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The Kitsu home tab: trending anime, then the sections of the user's home layout that Kitsu can
/// fill (seasonal, upcoming, top rated, favorites, popular, airing, formats, manga and the user's
/// own list). News, suggestions, features and the forum have no Kitsu source and are skipped.
///
/// Every title opens the MyAnimeList detail screen of its MyAnimeList id (Kitsu mappings).
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
                if (s.enabled && (kitsuQueryForSection(s) != null || s.type == SectionType.userList))
                  s,
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
                SliverList.builder(
                  itemCount: sections.length,
                  itemBuilder: (context, i) => RepaintBoundary(
                    child: _section(context, sections[i], cardWidth, cardHeight),
                  ),
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
    return HomeAsync<List<Anime>>(
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
        return [
          for (final e in page.page.entries)
            if (kitsuEntryToAnime(e) != null) kitsuEntryToAnime(e)!,
        ];
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
        return ContentListWidget(
          category: category,
          items: items,
          height: cardHeight,
          padding: const EdgeInsets.all(8),
          tileWidth: cardWidth,
          tileHeight: cardHeight,
        );
      },
    );
  }
}
