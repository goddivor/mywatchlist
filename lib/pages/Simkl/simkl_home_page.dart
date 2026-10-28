import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_home_plan.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Home tab for Simkl: the rows come from the shared home preferences (`simklHomePlan`): the user's
/// "Continue watching" and the Simkl catalogue lists (airing today, trending, new premieres).
/// Simkl has no manga, news or forum, so those MyAnimeList sections are skipped.
class SimklHomePage extends StatefulWidget {
  const SimklHomePage({super.key});

  @override
  State<SimklHomePage> createState() => _SimklHomePageState();
}

class _SimklHomePageState extends State<SimklHomePage> {
  /// Bumped by a pull to refresh: every section reloads when it changes.
  int _refresh = 0;

  Future<void> _onRefresh() async {
    HomeSectionCache.clear();
    SimklListService.instance.invalidate();
    setState(() => _refresh++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    // Section titles read S.current: rebuild when the app language changes.
    Localizations.localeOf(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              // Empty list does not suppress the automatic endDrawer button; a placeholder does.
              actions: const [SizedBox.shrink()],
              floating: true,
              snap: true,
              titleSpacing: 0,
              toolbarHeight: kToolbarHeight,
              title: const AppBarHome(transparent: true, showSettings: true),
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
                final plan = simklHomePlan(state.preferences.sections);
                final cardWidth = getTileSizeValues(state.preferences.tileSize).containerHeight * (2 / 3);
                if (plan.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text(S.of(context).Hw_Empty_Items)),
                  );
                }
                return SliverList.builder(
                  itemCount: plan.length,
                  itemBuilder: (context, i) {
                    final block = plan[i];
                    return RepaintBoundary(
                      key: ValueKey(block.key),
                      child: block.feed == null
                          ? ListenableBuilder(
                              listenable: UserSimklV2.instance,
                              builder: (context, _) => simklSignedIn
                                  ? _ContinueWatching(block: block, cardWidth: cardWidth, refresh: _refresh)
                                  : const SizedBox.shrink(),
                            )
                          : _FeedSection(block: block, cardWidth: cardWidth, refresh: _refresh),
                    );
                  },
                );
              },
            ),
            SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}

/// One catalogue row; a long "View all" lives in the Explore tab.
class _FeedSection extends StatelessWidget {
  final SimklHomeBlock block;
  final double cardWidth;
  final int refresh;

  const _FeedSection({required this.block, required this.cardWidth, required this.refresh});

  @override
  Widget build(BuildContext context) {
    final feed = block.feed!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: feed.title),
          HomeAsync<List<SimklMedia>>(
            cacheKey: feed.cacheKey,
            maxAge: const Duration(minutes: 30),
            refresh: refresh,
            load: () => feed.load(SimklDiscoverService.instance),
            loading: SimklRowSkeleton(cardWidth: cardWidth),
            builder: (context, items) => items.isEmpty
                ? HomeMessage(icon: Icons.movie_filter_outlined, text: S.of(context).Sk_Feed_Empty)
                : SimklPosterRow(
                    items: items.length > block.limit ? items.sublist(0, block.limit) : items,
                    cardWidth: cardWidth,
                    onTap: (media) => openSimklMedia(context, media),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The titles the user is watching, the most recently watched first.
class _ContinueWatching extends StatelessWidget {
  final SimklHomeBlock block;
  final double cardWidth;
  final int refresh;

  const _ContinueWatching({required this.block, required this.cardWidth, required this.refresh});

  String get _key => 'simkl_continue_watching_${block.limit}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: S.of(context).Sk_Continue_Watching),
          HomeAsync<List<SimklMedia>>(
            cacheKey: _key,
            maxAge: const Duration(minutes: 3),
            refresh: refresh,
            load: () => _load(block.limit),
            loading: SimklRowSkeleton(cardWidth: cardWidth),
            builder: (context, items) => items.isEmpty
                ? HomeMessage(icon: Icons.play_circle_outline_rounded, text: S.of(context).Sk_Continue_Empty)
                : SimklPosterRow(
                    items: items,
                    cardWidth: cardWidth,
                    onTap: (media) => openSimklMedia(context, media),
                  ),
          ),
        ],
      ),
    );
  }

  static Future<List<SimklMedia>> _load(int limit) async {
    final all = await SimklListService.instance.anime(force: false);
    final watching = [
      for (final e in all)
        if (e.status == ListEntryStatus.current) e,
    ]..sort((a, b) {
        final x = a.updatedAt;
        final y = b.updatedAt;
        if (x == null) return y == null ? 0 : 1;
        return y == null ? -1 : y.compareTo(x);
      });
    return [
      for (final e in watching.take(limit))
        SimklMedia(
          simklId: e.id,
          malId: e.malId,
          title: e.title,
          posterUrl: e.imageUrl,
          episode: e.progress + 1 > (e.total > 0 ? e.total : 1 << 30) ? null : e.progress + 1,
        ),
    ];
  }
}
