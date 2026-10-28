import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_home_sections.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeSectionCache;

/// The AniList home tab: the app bar with the shortcut chips, then the sections the user
/// picked in the home settings (shared with MyAnimeList's home): seasonal, trending and
/// ranking rows, the user's own list and the AniList forum. News and features are MyAnimeList's
/// and are skipped.
class AnilistHomePage extends StatefulWidget {
  const AnilistHomePage({super.key});

  @override
  State<AnilistHomePage> createState() => _AnilistHomePageState();
}

class _AnilistHomePageState extends State<AnilistHomePage> {
  /// Bumped by a pull to refresh: every section reloads from the network when it changes.
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
    context.read<HomePreferencesBloc>().add(LoadHomePreferencesEvent());
    setState(() => _refresh++);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    // Section titles and chips read S.current: rebuild when the app language changes.
    Localizations.localeOf(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        edgeOffset: kToolbarHeight + 60,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              floating: true,
              titleSpacing: 0,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: kToolbarHeight,
              title: AppBarHome(
                backgroundColor: Colors.transparent,
                showAvatar: true,
                showSettings: true,
                onSearchTap: () => openAnilistSearch(context),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(52),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 10, top: 7),
                  child: AnilistChipsBar(),
                ),
              ),
            ),
            BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
              buildWhen: (a, b) => a.isLoading != b.isLoading || a.preferences != b.preferences,
              builder: (context, state) {
                if (state.isLoading) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final tile = getTileSizeValues(state.preferences.tileSize);
                final sections = [
                  for (final s in state.preferences.sections)
                    if (s.enabled && anilistShowsSection(s)) s,
                ];
                if (sections.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(S.current.Hw_Empty_Items)),
                  );
                }
                return SliverList.builder(
                  itemCount: sections.length,
                  itemBuilder: (context, i) => RepaintBoundary(
                    child: AnilistHomeSection(
                      key: ValueKey('${sections[i].type.name}$i'),
                      section: sections[i],
                      cardWidth: tile.containerHeight * (2 / 3),
                      cardHeight: tile.containerHeight,
                      refresh: _refresh,
                    ),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
