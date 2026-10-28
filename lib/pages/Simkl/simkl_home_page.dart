import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/MAL/home/section_header.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Home tab for Simkl: "Continue watching" from the user's list, then the Simkl catalogue rows
/// (airing today, trending, new premieres). Simkl has no manga, news or forum, so none of those
/// MyAnimeList sections exist here; the home preferences page edits the MyAnimeList home only.
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
              floating: true,
              snap: true,
              titleSpacing: 0,
              toolbarHeight: kToolbarHeight,
              title: const AppBarHome(transparent: true, showSettings: true),
            ),
            SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: UserSimklV2.instance,
                builder: (context, _) => simklSignedIn
                    ? _ContinueWatching(refresh: _refresh)
                    : const SizedBox.shrink(),
              ),
            ),
            SliverList.list(
              children: [
                for (final feed in SimklFeed.values)
                  RepaintBoundary(child: _FeedSection(feed: feed, refresh: _refresh)),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One catalogue row; a long "View all" lives in the Explore tab.
class _FeedSection extends StatelessWidget {
  final SimklFeed feed;
  final int refresh;

  const _FeedSection({required this.feed, required this.refresh});

  @override
  Widget build(BuildContext context) {
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
            loading: const SimklRowSkeleton(),
            builder: (context, items) => items.isEmpty
                ? HomeMessage(icon: Icons.movie_filter_outlined, text: S.of(context).Sk_Feed_Empty)
                : SimklPosterRow(
                    items: items,
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
  final int refresh;

  const _ContinueWatching({required this.refresh});

  static const _key = 'simkl_continue_watching';

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
            load: _load,
            loading: const SimklRowSkeleton(),
            builder: (context, items) => items.isEmpty
                ? HomeMessage(icon: Icons.play_circle_outline_rounded, text: S.of(context).Sk_Continue_Empty)
                : SimklPosterRow(items: items, onTap: (media) => openSimklMedia(context, media)),
          ),
        ],
      ),
    );
  }

  static Future<List<SimklMedia>> _load() async {
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
      for (final e in watching.take(20))
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
