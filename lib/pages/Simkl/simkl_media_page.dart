import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_title_language.dart';
import 'package:mywatchlist/user/base_user.dart' show AuthStatus;
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show launchWebView;
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_header.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_lists.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_progress.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_sections.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_edit_sheet.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:share_plus/share_plus.dart';

/// Native Simkl title page: only Simkl's own data (owner rule for Simkl accounts).
///
/// The record and the episodes come from Simkl's API; the watcher distribution, counters,
/// reviews, comments, memos, tags and links are read from simkl.com (anonymous, desktop
/// markup, parsed off the UI isolate). A section whose source failed or whose markup is no
/// longer recognised is not shown. "Open on MyAnimeList" stays in the menu when the title has
/// a MyAnimeList id. Nothing is ever written to Simkl except on the user's own action (the status
/// bar's list editor, "Mark Ep. N watched"). Block order: Simkl part of
/// `docs/tracker-ui-references.md` (§ 2.3).
class SimklMediaPage extends StatefulWidget {
  final int simklId;
  final String? slug;

  /// Shown while the record loads (the tile that was tapped).
  final String? title;
  final String? posterUrl;
  final SimklDetailService? service;

  /// The signed-in user's list, for the list button (tests pass a fake; null = Simkl's).
  final SimklListService? listService;

  /// Clock of the next-episode card (tests).
  final DateTime Function()? now;

  const SimklMediaPage({
    super.key,
    required this.simklId,
    this.slug,
    this.title,
    this.posterUrl,
    this.service,
    this.listService,
    this.now,
  });

  @override
  State<SimklMediaPage> createState() => _SimklMediaPageState();
}

enum _Phase { loading, ready, failed, notFound }

class _SimklMediaPageState extends State<SimklMediaPage> {
  late final SimklDetailService _service = widget.service ?? SimklDetailService.instance;

  _Phase _phase = _Phase.loading;
  SimklTitle? _title;
  List<SimklEpisode>? _episodes;
  SimklTitlePage? _page;
  bool _pageLoading = true;
  ListEntryView? _entry;
  bool _listKnown = false;
  bool _marking = false;
  bool _checkingIn = false;

  /// The user's list by Simkl id (progress badges on related titles).
  Map<int, ListEntryView> _byId = const {};

  bool get _signedIn => UserSimklV2.instance.getStatus() == AuthStatus.AUTHENTICATED;

  @override
  void initState() {
    super.initState();
    _title = _service.peek<SimklTitle>(SimklDetailService.titleKey(widget.simklId));
    _episodes = _service.peek<List<SimklEpisode>>(SimklDetailService.episodesKey(widget.simklId));
    _page = _service.peek<SimklTitlePage>(SimklDetailService.pageKey(widget.simklId));
    if (_title != null) _phase = _Phase.ready;
    if (_page != null) _pageLoading = false;
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (force) _service.invalidate(widget.simklId);
    // The profile's title language, read once per run (tests inject a service and skip it).
    if (_signedIn && widget.service == null) await SimklTitlePreference.ensureLoaded();
    final id = widget.simklId;
    final record = _service.title(id, force: force);
    unawaited(_service.episodes(id, force: force).then((v) {
      if (mounted) setState(() => _episodes = v);
    }, onError: (_) {
      if (mounted) setState(() => _episodes = const []);
    }));
    unawaited(_loadPage(widget.slug != null ? Future.value(widget.slug) : record.then((t) => t.slug), force));
    unawaited(_loadListEntry(force: force));
    try {
      final t = await record;
      if (mounted) setState(() {
        _title = t;
        _phase = _Phase.ready;
      });
    } on SimklTitleNotFound {
      if (mounted && _title == null) setState(() => _phase = _Phase.notFound);
    } catch (_) {
      if (mounted && _title == null) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _loadPage(Future<String?> slug, bool force) async {
    if (force && mounted && _page == null) setState(() => _pageLoading = true);
    try {
      final s = await slug; // no record, no page: an unknown id is not fetched from simkl.com
      final page = await _service.page(widget.simklId, s, force: force);
      if (mounted) setState(() => _page = page);
    } catch (_) {
      // Cloudflare challenge, network: the scraped sections are simply not shown.
    } finally {
      if (mounted) setState(() => _pageLoading = false);
    }
  }

  Future<void> _loadListEntry({bool force = false}) async {
    if (!_signedIn) return;
    try {
      final list = await (widget.listService ?? SimklListService.instance).anime(force: force);
      final found = list.where((e) => e.id == widget.simklId).firstOrNull;
      if (mounted) setState(() {
        _entry = found;
        _byId = {for (final e in list) e.id: e};
        _listKnown = true;
      });
    } catch (_) {
      // Dead session or network: no list button rather than a wrong one.
    }
  }

  String? get _slug => _title?.slug ?? widget.slug;
  String get _pageUrl => SimklDetailService.pageUrl(widget.simklId, _slug);

  void _openTitle(SimklLinkedTitle item) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SimklMediaPage(
          simklId: item.simklId,
          slug: item.slug,
          title: item.title,
          posterUrl: item.posterUrl,
          service: widget.service,
          listService: widget.listService,
          now: widget.now,
        ),
      ));

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _editList() async {
    final t = _title;
    if (t == null) return;
    final entry = _entry ??
        ListEntryView(
          id: t.simklId,
          malId: t.malId,
          category: 'anime',
          title: t.title,
          imageUrl: t.posterUrl,
          largeImageUrl: t.posterUrl,
          mediaType: t.animeType,
          total: t.totalEpisodes ?? 0,
          genres: t.genres,
        );
    final result = await showSimklEditSheet(context, entry, service: widget.listService);
    if (!mounted) return;
    switch (result) {
      case ListEditUpdated(entry: final saved):
        setState(() => _entry = saved);
      case ListEditRemoved():
        setState(() => _entry = null);
      case ListEditUnchanged():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _title;
    final name = t?.title ?? widget.title ?? '';
    final hasFanart = t?.fanartUrl != null;
    final top = MediaQuery.paddingOf(context).top;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: RefreshIndicator(
        edgeOffset: kToolbarHeight + top,
        onRefresh: () => _load(force: true),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              leading: canPop
                  ? SimklHeroButton(
                      icon: Icons.arrow_back,
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
              expandedHeight: hasFanart ? SimklMediaHero.extent(context, hasFanart: true) - top : null,
              title: _CollapsedTitle(name),
              actions: [
                SimklHeroButton(
                  tooltip: S.current.Smp_Open_On_Simkl,
                  icon: Icons.open_in_browser,
                  onPressed: () => launchWebView(_pageUrl, context: context),
                ),
                _menu(context),
                const SizedBox(width: 4),
              ],
              flexibleSpace: hasFanart
                  ? FlexibleSpaceBar(
                      collapseMode: CollapseMode.parallax,
                      background: SimklMediaHero(fanartUrl: t!.fanartUrl),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: SimklTitleBlock(
                title: t,
                fallbackTitle: name,
                fallbackPoster: widget.posterUrl,
                overlap: hasFanart,
              ),
            ),
            ..._body(context),
            SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final mal = _title?.malId;
    final colors = AppColors.of(context);
    return PopupMenuButton<String>(
      style: IconButton.styleFrom(backgroundColor: colors.imageScrim, foregroundColor: colors.onImageScrim),
      onSelected: (v) {
        switch (v) {
          case 'mal':
            if (mal != null) AppRoutes.openContent(context, id: mal, category: 'anime');
          case 'share':
            Share.share(_pageUrl);
        }
      },
      itemBuilder: (_) => [
        if (mal != null)
          PopupMenuItem(
            value: 'mal',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.launch),
              title: Text(S.current.Smp_Open_On_Mal),
            ),
          ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.share_outlined),
            title: Text(S.current.Smp_Share),
          ),
        ),
      ],
    );
  }

  /// "Watching now": Simkl shows the episode on the dashboard and marks it watched when its
  /// runtime has elapsed. Only on the viewer's tap.
  Future<void> _checkIn(int number) async {
    final t = _title;
    if (t == null || _checkingIn) return;
    setState(() => _checkingIn = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    String message;
    try {
      await (widget.listService ?? SimklListService.instance).checkIn(
        simklId: t.simklId,
        title: t.enTitle ?? t.title,
        episode: number,
        year: t.year,
        malId: t.malId,
        ids: t.externalIds,
      );
      message = S.current.Sdp_Check_In_Done(number);
    } on SimklCheckInTooSoon catch (e) {
      message = S.current.Sdp_Check_In_Wait(e.wait.inSeconds + 1);
    } catch (_) {
      message = S.current.Sdp_Check_In_Failed;
    }
    messenger?.showSnackBar(SnackBar(content: Text(message)));
    if (mounted) setState(() => _checkingIn = false);
  }

  Future<void> _markWatched(int number) async {
    final entry = _entry;
    if (entry == null || _marking) return;
    setState(() => _marking = true);
    try {
      final saved = await (widget.listService ?? SimklListService.instance).setProgress(entry, number);
      if (mounted) setState(() => _entry = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(S.current.Sk_Edit_Failed)));
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  List<Widget> _body(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const [
          SliverToBoxAdapter(child: SimklBlockSkeleton(height: 58)),
          SliverToBoxAdapter(child: SimklBlockSkeleton(height: 180)),
        ];
      case _Phase.notFound:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SectionMessage(icon: Icons.search_off, message: S.current.Smp_Not_Found),
          ),
        ];
      case _Phase.failed:
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SectionMessage(
              icon: Icons.cloud_off_outlined,
              message: S.current.Smp_Load_Error,
              onRetry: () {
                setState(() => _phase = _Phase.loading);
                _load(force: true);
              },
            ),
          ),
        ];
      case _Phase.ready:
        // One lazily built list: sections further down (comments, memos) only load when they
        // come near the screen.
        return [SliverList.list(children: _sections(context, _title!))];
    }
  }

  /// The user's progress on a linked title ("3 / 12"), when it is on the list.
  String? _badge(SimklLinkedTitle item) {
    final e = _byId[item.simklId];
    if (e == null || e.status == null) return null;
    return e.total > 0 ? '${e.progress} / ${e.total}' : '${e.progress}';
  }

  /// Block order of the Simkl reference (docs/tracker-ui-references.md, Simkl § 2.3): ratings,
  /// my status, next episode, synopsis, trailers, episodes, audience, related titles, then the
  /// community and the information table.
  List<Widget> _sections(BuildContext context, SimklTitle t) {
    final page = _page;
    final counters = page?.counters;
    final reviews = page?.reviews;
    final episodes = _episodes;
    final entry = _entry;
    final now = widget.now?.call() ?? DateTime.now();
    final out = <Widget>[SimklRatingStrip(title: t)];

    if (_signedIn && _listKnown) {
      out.add(SimklMyStatusBar(entry: entry, total: t.totalEpisodes ?? 0, onEdit: _editList));
    }
    final next = simklNextUp(
      title: t,
      episodes: episodes,
      entry: entry,
      now: now,
      info: (widget.listService ?? SimklListService.instance).nextToWatch(widget.simklId),
    );
    if (next != null) {
      out.add(SimklNextEpisodeCard(
        next: next,
        now: now,
        marking: _marking,
        checkingIn: _checkingIn,
        onCheckIn: _signedIn && _listKnown && next.episode != null ? () => _checkIn(next.episode!) : null,
        onMark: next.episode == null ? null : () => _markWatched(next.episode!),
        onOpenSequel: next.sequel == null ? null : () => _openTitle(next.sequel!),
      ));
    }

    if (t.overview != null || t.genres.isNotEmpty) {
      out.add(SimklSection(
        title: S.current.Smp_Synopsis,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: simklPagePadding + 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.genres.isNotEmpty) ...[SimklChips(t.genres), const SizedBox(height: 10)],
              if (t.overview != null) SimklExpandableText(t.overview!, maxLines: 4),
            ],
          ),
        ),
      ));
    }

    if (t.trailers.isNotEmpty) {
      out.add(SimklSection(
        title: S.current.Smp_Trailers,
        child: SimklStrip(
          height: SimklTrailerCard.width * 9 / 16,
          itemCount: t.trailers.length,
          itemBuilder: (context, i) => SimklTrailerCard(
            trailer: t.trailers[i],
            onTap: () => launchWebView(t.trailers[i].url, context: context, external: true),
          ),
        ),
      ));
    }

    if (episodes != null && episodes.isNotEmpty) {
      // The user's next episode first in view: the strip starts a little before it.
      out.add(SimklSection(
        title: S.current.Smp_Episodes,
        onViewAll: _openEpisodes,
        child: SimklStrip(
          height: SimklEpisodeCard.heightFor(context),
          itemCount: episodes.length.clamp(0, 30),
          itemBuilder: (context, i) => SimklEpisodeCard(
            episode: episodes[i],
            watched: _isWatched(episodes[i]),
            upcoming: episodes[i].date?.isAfter(now) ?? false,
            onTap: () => _openEpisode(episodes[i]),
          ),
        ),
      ));
    }

    final watchers = page?.watchers;
    if (watchers != null) {
      out.add(SimklSection(title: S.current.Smp_Watchers, child: SimklWatchersView(watchers)));
    } else if (_pageLoading) {
      out.add(const SimklBlockSkeleton(height: 150));
    }

    void linked(String title, List<SimklLinkedTitle> items, String? Function(SimklLinkedTitle) caption) {
      if (items.isEmpty) return;
      out.add(SimklSection(
        title: title,
        child: SimklStrip(
          height: SimklLinkedCard.heightFor(context),
          itemCount: items.length,
          itemBuilder: (context, i) => SimklLinkedCard(
            item: items[i],
            caption: caption(items[i]),
            badge: _badge(items[i]),
            onTap: () => _openTitle(items[i]),
          ),
        ),
      ));
    }

    linked(S.current.Smp_Related, t.relations, (r) => SimklFormat.relation(r.relationType));
    linked(S.current.Smp_Recommendations, t.recommendations, (r) {
      final parts = [
        if (r.usersPercent != null) SimklFormat.percent(r.usersPercent!),
        if (r.usersCount != null) '${SimklFormat.count(r.usersCount!)} ♥',
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    });
    linked(S.current.Smp_Similar, t.similar, (r) => r.year?.toString());

    final countersRow = <SimklCounter>[
      if (counters?.reactions != null && counters!.reactions! > 0)
        SimklCounter(Icons.emoji_emotions_outlined, S.current.Smp_Reactions_Count(counters.reactions!, SimklFormat.count(counters.reactions!)),
            () => launchWebView(_pageUrl, context: context)),
      if (counters?.reviews != null && counters!.reviews! > 0)
        SimklCounter(Icons.rate_review_outlined, S.current.Smp_Reviews_Count(counters.reviews!, SimklFormat.count(counters.reviews!)), _openReviews),
      if (counters?.comments != null && counters!.comments! > 0)
        SimklCounter(Icons.forum_outlined, S.current.Smp_Comments_Count(counters.comments!, SimklFormat.count(counters.comments!)), _openComments),
      if (counters?.memos != null && counters!.memos! > 0)
        SimklCounter(Icons.sticky_note_2_outlined, S.current.Smp_Memos_Count(counters.memos!, SimklFormat.count(counters.memos!)), _openMemos),
    ];
    if (countersRow.isNotEmpty) {
      out.add(SimklSection(title: S.current.Skr_Community, child: SimklCountersRow(countersRow)));
    }

    if (reviews != null && reviews.items.isNotEmpty) {
      out.add(SimklSection(
        title: S.current.Smp_Reviews,
        onViewAll: _openReviews,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reviews.summary != null) SimklReviewSummaryRow(reviews.summary!),
            SimklStrip(
              height: 300,
              itemCount: reviews.items.length,
              itemBuilder: (context, i) => SimklReviewCard(review: reviews.items[i], onOpen: _openReviews),
            ),
          ],
        ),
      ));
    }

    if ((counters?.comments ?? 0) > 0) {
      out.add(_LazyComments(
        load: () => _service.comments(widget.simklId, _slug),
        onViewAll: _openComments,
      ));
    }
    if ((counters?.memos ?? 0) > 0) {
      out.add(_LazyMemos(
        load: () => _service.memos(widget.simklId, _slug),
        onViewAll: _openMemos,
      ));
    }

    out.add(_info(context, t, page));
    return out;
  }

  bool _isWatched(SimklEpisode e) {
    final entry = _entry;
    final n = e.number;
    if (entry == null || entry.status == null || n == null || e.isSpecial) return false;
    return n <= entry.progress;
  }

  Widget _info(BuildContext context, SimklTitle t, SimklTitlePage? page) {
    final studios = page?.studios?.isNotEmpty == true ? page!.studios! : t.studios;
    final rows = <(String, String?)>[
      (S.current.Smp_Type, SimklFormat.type(t.animeType)),
      (S.current.Smp_Episodes, t.totalEpisodes != null && t.totalEpisodes! > 0 ? SimklFormat.count(t.totalEpisodes!) : null),
      (S.current.Smp_Status, SimklFormat.status(t.status)),
      (S.current.Smp_Aired, SimklFormat.aired(t)),
      (S.current.Smp_Season, t.seasonNameYear),
      (S.current.Smp_Airs, SimklFormat.airs(t.airs)),
      (S.current.Smp_Runtime, t.runtime != null && t.runtime! > 0 ? S.current.Smp_Minutes(t.runtime!) : null),
      (S.current.Smp_Network, t.network),
      (S.current.Smp_Studios, studios.isEmpty ? null : studios.join(', ')),
      (S.current.Smp_Producers, page?.producers?.join(', ')),
      (S.current.Smp_Licensors, page?.licensors?.join(', ')),
      (S.current.Smp_Certification, t.certification),
      (S.current.Smp_Alt_Titles, t.altTitles.isEmpty ? null : t.altTitles.join('\n')),
    ];
    final ids = simklExternalLinks(t.externalIds, animeType: t.animeType);
    final tags = page?.tags ?? const <String>[];
    final links = page?.links ?? const <SimklLink>[];
    return SimklSection(
      title: S.current.Smp_Info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in rows)
            if (value != null && value.isNotEmpty) SimklInfoRow(label, value),
          if (ids.isNotEmpty)
            _Labelled(
              S.current.Sdp_Other_Sites,
              SimklChips(
                [for (final l in ids) l.name],
                onTap: (i) => launchWebView(ids[i].url, context: context),
              ),
            ),
          if (tags.isNotEmpty) _TagsBlock(tags),
          if (links.isNotEmpty)
            _Labelled(
              S.current.Smp_Links,
              SimklChips(
                [for (final l in links) l.name],
                onTap: (i) => launchWebView(links[i].url, context: context),
              ),
            ),
        ],
      ),
    );
  }

  void _openEpisode(SimklEpisode e) {
    final n = e.number;
    final url = n != null && !e.isSpecial ? '$_pageUrl/episode-$n/' : _pageUrl;
    launchWebView(url, context: context);
  }

  void _openEpisodes() {
    final episodes = _episodes ?? const <SimklEpisode>[];
    _push(SimklListScreen<SimklEpisode>(
      title: S.current.Smp_Episodes,
      initial: episodes,
      load: ({bool force = false}) => _service.episodes(widget.simklId, force: force),
      itemBuilder: (context, e) => SimklEpisodeRow(
        episode: e,
        watched: _isWatched(e),
        upcoming: e.date?.isAfter(DateTime.now()) ?? false,
        onTap: () => _openEpisode(e),
      ),
    ));
  }

  void _openReviews() {
    final first = _page?.reviews?.items ?? const <SimklReview>[];
    _push(SimklListScreen<SimklReview>(
      title: S.current.Smp_Reviews,
      initial: first,
      load: ({bool force = false}) async =>
          (await _service.reviews(widget.simklId, _slug, force: force))?.items,
      itemBuilder: (context, r) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: simklPagePadding, vertical: 6),
        child: SimklReviewCard(
          review: r,
          compact: false,
          onOpen: r.url == null ? null : () => launchWebView(r.url!, context: context),
        ),
      ),
    ));
  }

  void _openComments() => _push(SimklListScreen<SimklComment>(
        title: S.current.Smp_Comments,
        load: ({bool force = false}) => _service.comments(widget.simklId, _slug, force: force),
        itemBuilder: (context, c) => SimklCommentTile(c),
      ));

  void _openMemos() => _push(SimklListScreen<Object>(
        title: S.current.Smp_Memos,
        load: ({bool force = false}) async {
          final memos = await _service.memos(widget.simklId, _slug, force: force);
          return memos == null ? null : groupMemos(memos);
        },
        itemBuilder: (context, item) =>
            item is SimklMemo ? SimklMemoTile(item) : SimklBucketHeader(item as String),
      ));
}

/// The title in the toolbar, shown once the header has collapsed.
class _CollapsedTitle extends StatelessWidget {
  final String text;

  const _CollapsedTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    var visible = true;
    if (settings != null) {
      final range = settings.maxExtent - settings.minExtent;
      visible = range <= 0 || (settings.currentExtent - settings.minExtent) / range < 0.15;
    }
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _Labelled extends StatelessWidget {
  final String label;
  final Widget child;

  const _Labelled(this.label, this.child);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding + 10, 12, simklPagePadding + 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Tags: the first 20, then all of them on Show more.
class _TagsBlock extends StatefulWidget {
  final List<String> tags;

  const _TagsBlock(this.tags);

  @override
  State<_TagsBlock> createState() => _TagsBlockState();
}

class _TagsBlockState extends State<_TagsBlock> {
  static const _limit = 20;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final more = widget.tags.length > _limit;
    return _Labelled(
      S.current.Smp_Tags,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SimklChips(widget.tags, limit: _all ? null : _limit),
          if (more)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? S.current.Smp_Show_Less : S.current.Smp_Show_More),
            ),
        ],
      ),
    );
  }
}

/// Loads [load] once built (when the section comes near the screen), then shows the first
/// comments; hidden when the page failed or its markup changed.
class _LazyComments extends StatefulWidget {
  final Future<List<SimklComment>?> Function() load;
  final VoidCallback onViewAll;

  const _LazyComments({required this.load, required this.onViewAll});

  @override
  State<_LazyComments> createState() => _LazyCommentsState();
}

class _LazyCommentsState extends State<_LazyComments> {
  static const _shown = 3;
  List<SimklComment>? _items;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.load().then((v) {
      if (!mounted) return;
      setState(() {
        _items = v;
        _done = true;
      });
    }, onError: (_) {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (!_done) return const SimklBlockSkeleton(height: 120);
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return SimklSection(
      title: S.current.Smp_Comments,
      onViewAll: widget.onViewAll,
      child: Column(children: [for (final c in items.take(_shown)) SimklCommentTile(c)]),
    );
  }
}

class _LazyMemos extends StatefulWidget {
  final Future<List<SimklMemo>?> Function() load;
  final VoidCallback onViewAll;

  const _LazyMemos({required this.load, required this.onViewAll});

  @override
  State<_LazyMemos> createState() => _LazyMemosState();
}

class _LazyMemosState extends State<_LazyMemos> {
  static const _shown = 5;
  List<SimklMemo>? _items;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.load().then((v) {
      if (!mounted) return;
      setState(() {
        _items = v;
        _done = true;
      });
    }, onError: (_) {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (!_done) return const SimklBlockSkeleton(height: 120);
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    // The most liked first on the page; the full list keeps Simkl's buckets.
    final top = [...items]..sort((a, b) => b.likes.compareTo(a.likes));
    return SimklSection(
      title: S.current.Smp_Memos,
      onViewAll: widget.onViewAll,
      child: Column(children: [for (final m in top.take(_shown)) SimklMemoTile(m)]),
    );
  }
}
