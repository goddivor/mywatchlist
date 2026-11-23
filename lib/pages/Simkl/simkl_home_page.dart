import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart' show SimklSessionExpired;
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart' show SimklEpisode;
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart' hide SimklFormat;
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_title_language.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_sections.dart' show SimklBlockSkeleton;
import 'package:mywatchlist/widgets/Simkl/simkl_catalogue.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_home_rows.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_home_plan.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Home tab for Simkl, progress and schedule first like Simkl's own apps. The TV shows / Anime /
/// Movies switch (shared with Explore) picks the catalogue; the rows come from the shared home
/// preferences (`simklHomePlan`): the user's "Continue watching" and "Up next" (movies: the
/// movies planned), and the catalogue: trending as a fanart carousel and airing today by exact
/// time (movies: today's releases) from Simkl's free CDN files, new premieres and best titles
/// from the API (none for movies). Each catalogue header opens the whole list. Simkl has no
/// manga, news or forum, so those MyAnimeList sections are skipped.
class SimklHomePage extends StatefulWidget {
  /// A fixed catalogue (the Simkl app's catalogue tabs): no switch; null = the shared one.
  final SimklKind? kind;

  /// Inside the Simkl app's catalogue tab, which has its own app bar.
  final bool embedded;

  const SimklHomePage({super.key, this.kind, this.embedded = false});

  @override
  State<SimklHomePage> createState() => _SimklHomePageState();
}

class _SimklHomePageState extends State<SimklHomePage> {
  /// Bumped by a pull to refresh: every section reloads when it changes.
  int _refresh = 0;

  SimklKind get _kind => widget.kind ?? SimklCatalogue.instance.value;

  void _onCatalogue() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SimklCatalogue.instance.removeListener(_onCatalogue);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SimklCatalogue.instance.addListener(_onCatalogue);
    SimklCatalogue.instance.ensureLoaded();
    // The profile's title language (once per run); the rows reload when it is not the default.
    if (simklSignedIn) {
      SimklTitlePreference.ensureLoaded().then((_) {
        if (mounted && SimklTitlePreference.language != SimklTitleLanguage.english) {
          setState(() => _refresh++);
        }
      });
    }
  }

  Future<void> _onRefresh() async {
    HomeSectionCache.clear();
    SimklListService.forEach((s) => s.invalidate());
    SimklDiscoverService.instance.cdn.invalidate();
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
            if (!widget.embedded)
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
            if (widget.kind == null)
              SliverToBoxAdapter(
                child: SimklKindSwitch(value: _kind, onChanged: SimklCatalogue.instance.pick),
              )
            else
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
            BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
              buildWhen: (a, b) => a.isLoading != b.isLoading || a.preferences != b.preferences,
              builder: (context, state) {
                if (state.isLoading) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final kind = _kind;
                final plan = [
                  for (final b in simklHomePlan(state.preferences.sections))
                    if (b.feed == null || SimklFeed.of(kind).contains(b.feed)) b,
                ];
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
                      key: ValueKey('${kind.name}:${block.key}'),
                      child: block.feed == null
                          ? ListenableBuilder(
                              listenable: UserSimklV2.instance,
                              builder: (context, _) => simklSignedIn
                                  ? _ContinueWatching(block: block, kind: kind, cardWidth: cardWidth, refresh: _refresh)
                                  : const SizedBox.shrink(),
                            )
                          : _FeedSection(block: block, kind: kind, cardWidth: cardWidth, refresh: _refresh),
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

/// One catalogue row. Trending is Simkl's fanart carousel, airing today is the day's schedule
/// by exact time (the user's shows first); the others are poster rows. Each header opens the
/// whole list (the airing one, Simkl's calendar).
class _FeedSection extends StatelessWidget {
  final SimklHomeBlock block;
  final SimklKind kind;
  final double cardWidth;
  final int refresh;

  const _FeedSection({required this.block, required this.kind, required this.cardWidth, required this.refresh});

  @override
  Widget build(BuildContext context) {
    final feed = block.feed!;
    final nav = Navigator.of(context);
    final header = SimklRowHeader(
      title: feed.titleOf(kind),
      onSimkl: feed == SimklFeed.trending || feed == SimklFeed.best,
      onTap: () => nav.push(MaterialPageRoute<void>(
        builder: (_) => feed == SimklFeed.airing && kind == SimklKind.anime
            ? const SimklCalendarPage()
            : SimklFeedPage(feed: feed, kind: kind),
      )),
    );
    final Widget body = switch (feed) {
      SimklFeed.airing => HomeAsync<_AiringData>(
          cacheKey: '${feed.cacheKeyOf(kind)}:home',
          maxAge: const Duration(minutes: 30),
          refresh: refresh,
          load: () async {
            final list = simklListById();
            final items = await feed.load(SimklDiscoverService.instance, kind);
            return _AiringData(items, await list);
          },
          loading: const SimklBlockSkeleton(height: 160),
          builder: (context, data) {
            // The CDN answer is already today's episodes by air time: the user's shows first.
            final all = [for (final m in data.items) SimklAiring(m, data.list[m.simklId])];
            final rows = [...all.where((a) => a.entry != null), ...all.where((a) => a.entry == null)];
            if (rows.isEmpty) {
              return HomeMessage(icon: Icons.event_busy_outlined, text: S.of(context).Sk_Feed_Empty);
            }
            final shown = rows.length > block.limit ? rows.sublist(0, block.limit) : rows;
            return Column(children: [
              for (final a in shown) SimklAiringTile(airing: a, onTap: () => openSimklMedia(context, a.media)),
            ]);
          },
        ),
      _ => HomeAsync<List<SimklMedia>>(
          cacheKey: feed.cacheKeyOf(kind),
          maxAge: const Duration(minutes: 30),
          refresh: refresh,
          load: () => feed.load(SimklDiscoverService.instance, kind),
          loading: feed == SimklFeed.trending
              ? SimklBlockSkeleton(height: SimklTrendingCarousel.heightFor(context))
              : SimklRowSkeleton(cardWidth: cardWidth),
          builder: (context, items) {
            if (items.isEmpty) return HomeMessage(icon: Icons.movie_filter_outlined, text: S.of(context).Sk_Feed_Empty);
            final shown = items.length > block.limit ? items.sublist(0, block.limit) : items;
            if (feed == SimklFeed.trending) {
              return SimklTrendingCarousel(items: shown, onTap: (media) => openSimklMedia(context, media));
            }
            return SimklPosterRow(items: shown, cardWidth: cardWidth, onTap: (media) => openSimklMedia(context, media));
          },
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, body]),
    );
  }
}

class _AiringData {
  final List<SimklMedia> items;
  final Map<int, ListEntryView> list;

  const _AiringData(this.items, this.list);
}

/// The user's rows: "Continue watching" (paused sessions from scrobblers, only when there are
/// some) and "Up next" (the next episode of every title being watched, with a one-tap mark, or
/// its countdown when it has not aired yet).
class _ContinueWatching extends StatelessWidget {
  final SimklHomeBlock block;
  final SimklKind kind;
  final double cardWidth;
  final int refresh;

  const _ContinueWatching({required this.block, required this.kind, required this.cardWidth, required this.refresh});

  String get _key => 'simkl_continue_watching_${kind.name}_${block.limit}';

  /// Movies have no next episode: the row lists the movies planned instead.
  bool get _movies => kind == SimklKind.movie;

  @override
  Widget build(BuildContext context) {
    return HomeAsync<_UserRows>(
      cacheKey: _key,
      maxAge: const Duration(minutes: 3),
      refresh: refresh,
      load: () => _load(kind, block.limit),
      loading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SimklRowHeader(title: _movies ? S.of(context).Smp_Plan_To_Watch : S.of(context).Skr_Up_Next),
          SimklRowSkeleton(cardWidth: cardWidth),
        ]),
      ),
      builder: (context, rows) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rows.sessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SimklRowHeader(title: S.of(context).Sk_Continue_Watching),
                _SessionsRow(items: rows.sessions, cardWidth: cardWidth),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SimklRowHeader(title: _movies ? S.of(context).Smp_Plan_To_Watch : S.of(context).Skr_Up_Next),
              if (rows.upNext.isEmpty)
                HomeMessage(
                  icon: Icons.play_circle_outline_rounded,
                  text: _movies ? S.of(context).Skm_No_Planned_Movies : S.of(context).Sk_Continue_Empty,
                )
              else if (_movies)
                SimklPosterRow(
                  items: [
                    for (final e in rows.upNext)
                      SimklMedia(simklId: e.id, kind: kind, title: e.title, posterUrl: e.imageUrl),
                  ],
                  cardWidth: cardWidth,
                  onTap: (media) => openSimklMedia(context, media),
                )
              else
                _UpNextRow(
                  kind: kind,
                  entries: rows.upNext,
                  airing: rows.airing,
                  nextEpisodes: rows.nextEpisodes,
                  cardWidth: cardWidth,
                ),
            ]),
          ),
        ],
      ),
    );
  }

  /// Paused sessions (latest first) and the titles being watched (most recent first), with the
  /// next airing of each from Simkl's calendar. Sessions and calendar are optional: a failure
  /// leaves the rows without them.
  static Future<_UserRows> _load(SimklKind kind, int limit) async {
    final service = SimklListService.of(kind);
    final all = await service.entries();
    if (kind == SimklKind.movie) {
      final planned = [
        for (final e in all)
          if (e.status == ListEntryStatus.planned) e,
      ];
      return _UserRows(const [], planned.take(limit).toList(), const {});
    }
    var sessions = const <SimklPlayback>[];
    try {
      sessions = await service.playback();
    } on SimklSessionExpired {
      rethrow;
    } catch (_) {}
    var calendar = const <SimklMedia>[];
    try {
      calendar = await SimklDiscoverService.instance.calendar(kind: kind);
    } catch (_) {}
    final byId = {for (final e in all) e.id: e};
    final items = <_ContinueItem>[];
    final seen = <int>{};
    for (final p in sessions) {
      if (!seen.add(p.simklId)) continue;
      final known = byId[p.simklId];
      items.add(_ContinueItem(
        SimklMedia(
          simklId: p.simklId,
          kind: kind,
          malId: p.malId ?? known?.malId,
          title: p.title,
          posterUrl: p.posterUrl ?? known?.imageUrl,
          episode: p.episode,
        ),
        p.progress > 0 ? p.progress / 100 : null,
      ));
    }
    final watching = [
      for (final e in all)
        if (e.status == ListEntryStatus.current && (e.total <= 0 || e.progress < e.total)) e,
    ]..sort((a, b) {
        final x = a.updatedAt;
        final y = b.updatedAt;
        if (x == null) return y == null ? 0 : 1;
        return y == null ? -1 : y.compareTo(x);
      });
    final now = DateTime.now().toUtc();
    final airing = <int, SimklMedia>{};
    for (final m in calendar) {
      final at = m.airDate;
      if (at == null || !at.isAfter(now) || !byId.containsKey(m.simklId)) continue;
      airing.putIfAbsent(m.simklId, () => m);
    }
    final shown = watching.take(limit).toList();
    // Shows count episodes per season: each one's episode list (public, cached by Simkl) names
    // the next episode ("S2E9"); a list that fails leaves the plain number.
    final codes = <int, SimklEpisode>{};
    if (kind == SimklKind.tv) {
      await Future.wait([
        for (final e in shown)
          SimklDetailService.instance.episodes(e.id, kind: kind).then((list) {
            final regular = regularEpisodes(list);
            if (e.progress < regular.length) codes[e.id] = regular[e.progress];
          }, onError: (Object _) {}),
      ]);
    }
    return _UserRows(items.take(limit).toList(), shown, airing, codes);
  }
}

class _UserRows {
  final List<_ContinueItem> sessions;
  final List<ListEntryView> upNext;

  /// Next airing (episode and UTC time) of the titles of the list, by Simkl id.
  final Map<int, SimklMedia> airing;

  /// Shows: the next episode of each title, by Simkl id.
  final Map<int, SimklEpisode> nextEpisodes;

  const _UserRows(this.sessions, this.upNext, this.airing, [this.nextEpisodes = const {}]);
}

class _SessionsRow extends StatelessWidget {
  final List<_ContinueItem> items;
  final double cardWidth;

  const _SessionsRow({required this.items, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SimklPosterRow.heightFor(context, cardWidth),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          final card = SimklPosterCard(
            media: item.media,
            width: cardWidth,
            onTap: () => openSimklMedia(context, item.media),
          );
          final resume = item.resume;
          if (resume == null) return card;
          // Where the paused session stopped, along the bottom of the cover.
          return Stack(
            children: [
              card,
              Positioned(
                left: 6,
                right: 6,
                top: cardWidth * SimklPosterCard.aspect - 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(value: resume, minHeight: 3),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The next episode of each watched title: "Ep. N" and a tick that marks it watched, or the
/// countdown to its air time. Marks are kept here so the row follows without a reload.
class _UpNextRow extends StatefulWidget {
  final SimklKind kind;
  final List<ListEntryView> entries;
  final Map<int, SimklMedia> airing;
  final double cardWidth;

  final Map<int, SimklEpisode> nextEpisodes;

  const _UpNextRow({
    required this.kind,
    required this.entries,
    required this.airing,
    this.nextEpisodes = const {},
    required this.cardWidth,
  });

  @override
  State<_UpNextRow> createState() => _UpNextRowState();
}

class _UpNextRowState extends State<_UpNextRow> {
  final Map<int, ListEntryView> _saved = {};
  final Set<int> _busy = {};

  Future<void> _mark(ListEntryView e) async {
    setState(() => _busy.add(e.id));
    try {
      final saved = await SimklListService.of(widget.kind).step(e, 1);
      HomeSectionCache.clearPrefix('simkl_continue_watching_');
      if (mounted) setState(() => _saved[e.id] = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(S.current.Sk_Edit_Failed)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.cardWidth;
    final now = DateTime.now();
    return SizedBox(
      height: SimklPosterRow.heightFor(context, width),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: widget.entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = _saved[widget.entries[i].id] ?? widget.entries[i];
          final next = e.progress + 1;
          final done = e.total > 0 && next > e.total;
          final air = widget.airing[e.id];
          // Shows count episodes per season: Simkl's own "next to watch" names the episode, and
          // only a calendar entry for that very episode makes it upcoming.
          final fromList = widget.kind == SimklKind.tv && !_saved.containsKey(e.id)
              ? SimklListService.of(widget.kind).nextToWatch(e.id)
              : null;
          final ep = widget.kind == SimklKind.tv && !_saved.containsKey(e.id) ? widget.nextEpisodes[e.id] : null;
          final info = fromList?.season != null
              ? fromList
              : ep?.season != null && ep?.number != null
                  ? SimklNextToWatch(season: ep!.season, episode: ep.number!, title: ep.title)
                  : null;
          final upcoming = (air != null &&
                  air.episode != null &&
                  air.airDate!.isAfter(now) &&
                  (widget.kind == SimklKind.tv
                      ? info != null && info.season == air.season && info.episode == air.episode
                      : air.episode! <= next)) ||
              // A show's next episode that has not aired yet cannot be marked.
              (ep?.date?.isAfter(now) ?? false);
          final episodeLabel = info?.season != null
              ? 'S${info!.season}E${info.episode}'
              : S.current.Sk_Episode_Short(next);
          final media = SimklMedia(simklId: e.id, kind: widget.kind, malId: e.malId, title: e.title, posterUrl: e.imageUrl);
          return _UpNextCard(
            media: media,
            width: width,
            line: done
                ? S.current.Smp_Completed
                : upcoming
                    ? '$episodeLabel · ${SimklFormat.countdown((air?.airDate ?? ep?.date)!, now) ?? ''}'
                    : episodeLabel,
            busy: _busy.contains(e.id),
            onMark: done || upcoming ? null : () => _mark(e),
            markLabel: info?.season != null ? S.current.Skm_Mark_Episode_Watched(episodeLabel) : S.current.Skr_Mark_Watched(next),
            onTap: () => openSimklMedia(context, media),
          );
        },
      ),
    );
  }
}

class _UpNextCard extends StatelessWidget {
  final SimklMedia media;
  final double width;
  final String line;
  final bool busy;
  final VoidCallback? onMark;
  final String markLabel;
  final VoidCallback onTap;

  const _UpNextCard({
    required this.media,
    required this.width,
    required this.line,
    required this.busy,
    required this.onMark,
    required this.markLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppImage(
                  url: media.posterUrl,
                  width: width,
                  height: width * SimklPosterCard.aspect,
                  borderRadius: BorderRadius.circular(10),
                  placeholderColor: scheme.surfaceContainerHighest,
                  semanticLabel: media.title,
                ),
                if (onMark != null || busy)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: busy
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                          )
                        : IconButton.filled(
                            tooltip: markLabel,
                            visualDensity: VisualDensity.compact,
                            onPressed: onMark,
                            icon: const Icon(Icons.check_rounded, size: 20),
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One "Continue watching" card: the title and, for a paused session, how far it got (0-1).
class _ContinueItem {
  final SimklMedia media;
  final double? resume;

  const _ContinueItem(this.media, this.resume);
}
