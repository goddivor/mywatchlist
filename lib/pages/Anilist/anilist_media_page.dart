import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_actions.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media_detail.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show openLink;
import 'package:mywatchlist/widgets/Anilist/list/anilist_entry_editor.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_cards.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_entry.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_header.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_overview.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_media_tabs.dart';
import 'package:mywatchlist/widgets/Anilist/media/anilist_recommend_sheet.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart' show runAnilistWrite, requireAnilistSignIn;
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the AniList title page of AniList id [id]; [title] and [coverUrl] show while it
/// loads (the card that was tapped).
Future<void> openAnilistMediaPage(
  BuildContext context, {
  required int id,
  String? title,
  String? coverUrl,
}) =>
    AppRoutes.push<void>(context, AnilistMediaPage(id: id, title: title, coverUrl: coverUrl));

/// The native AniList title page, AniList's own layout (AniHyou, Otraku, anilist.co; see the
/// AniList part of `docs/tracker-ui-references.md`), never the MyAnimeList one: banner, cover
/// and title, label rail, % scores, rankings, the user's entry with +1, "Continue watching",
/// synopsis and genres, then the tabs Overview, Characters, Staff, Relations, Stats, Social
/// and Reviews under a pinned bar.
///
/// One request reads the page (`AnilistMediaDetailService`); the Characters, Staff and
/// recommendation lists page on when their tab is shown. Writes (list entry, favourite,
/// recommendation vote or new recommendation) only happen on the viewer's tap.
class AnilistMediaPage extends StatefulWidget {
  const AnilistMediaPage({
    super.key,
    required this.id,
    this.title,
    this.coverUrl,
    this.service,
    this.actions,
    this.social,
    this.write,
    this.lists,
    this.editor,
    this.clock,
  });

  final int id;
  final String? title;
  final String? coverUrl;

  /// Test hooks; the shared instances otherwise.
  final AnilistMediaDetailService? service;
  final AnilistActions? actions;
  final AnilistSocialService? social;
  final AnilistListWrite? write;
  final AnilistListService? lists;
  final Future<AnilistEditResult?> Function(BuildContext context, AnilistEditTarget target)? editor;
  final DateTime Function()? clock;

  @override
  State<AnilistMediaPage> createState() => AnilistMediaPageState();
}

enum _Phase { loading, ready, failed, notFound }

@visibleForTesting
class AnilistMediaPageState extends State<AnilistMediaPage> with SingleTickerProviderStateMixin {
  late final AnilistMediaDetailService _service = widget.service ?? AnilistMediaDetailService.instance;
  AnilistActions get _actions => widget.actions ?? AnilistActions.instance;
  AnilistSocialService get _social => widget.social ?? AnilistSocialService(signedIn: _service.signedIn);
  AnilistListWrite get _write => widget.write ?? AnilistListWrite.instance;

  late final TabController _tabs = TabController(length: AnilistMediaTab.values.length, vsync: this);
  AnilistMediaTab _tab = AnilistMediaTab.overview;

  _Phase _phase = _Phase.loading;
  AnilistMediaDetail? _detail;
  bool _stepping = false;

  String _language = 'JAPANESE';
  AnilistPager<AnilistCastEdge>? _characters;
  AnilistPager<AnilistStaffEdge>? _staff;
  AnilistPager<AnilistRecommendation>? _recommendations;

  AnilistMediaDetail? get detail => _detail;

  @override
  void initState() {
    super.initState();
    _detail = _service.peek(widget.id);
    if (_detail != null) _phase = _Phase.ready;
    _tabs.addListener(_onTab);
    _load();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    _characters?.dispose();
    _staff?.dispose();
    _recommendations?.dispose();
    super.dispose();
  }

  void _onTab() {
    final tab = AnilistMediaTab.values[_tabs.index];
    if (tab != _tab) setState(() => _tab = tab);
    _pagerOf(tab)?.loadMore();
  }

  void _show(AnilistMediaTab tab) => _tabs.animateTo(tab.index);

  AnilistPager<Object?>? _pagerOf(AnilistMediaTab tab) {
    final id = widget.id;
    switch (tab) {
      case AnilistMediaTab.characters:
        return _characters ??=
            AnilistPager((page) => _service.characters(id, page: page, language: _language));
      case AnilistMediaTab.staff:
        return _staff ??= AnilistPager((page) => _service.staff(id, page: page));
      case AnilistMediaTab.relations:
        return _recommendations ??= AnilistPager((page) => _service.recommendations(id, page: page));
      default:
        return null;
    }
  }

  Future<void> _load({bool force = false}) async {
    try {
      final found = await _service.detail(widget.id, force: force);
      if (!mounted) return;
      if (found == null) {
        if (_detail == null) setState(() => _phase = _Phase.notFound);
        return;
      }
      setState(() {
        _detail = found;
        _phase = _Phase.ready;
      });
    } catch (_) {
      if (mounted && _detail == null) setState(() => _phase = _Phase.failed);
    }
  }

  void _update(AnilistMediaDetail next) {
    _service.keep(next);
    setState(() => _detail = next);
  }

  void _snack(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  // ------------------------------------------------------------------ writes (on tap only)

  Future<void> _toggleFavourite() async {
    final d = _detail;
    if (d == null) return;
    final done = await runAnilistWrite<bool>(context, () async {
      await _actions.toggleFavourite(d.isAnime ? AnilistFavouriteKind.anime : AnilistFavouriteKind.manga, d.id);
      return true;
    }, service: _social);
    if (done != true || !mounted) return;
    final now = _detail!;
    _update(now.copyWith(
      isFavourite: !now.isFavourite,
      favourites: (now.favourites + (now.isFavourite ? -1 : 1)).clamp(0, 1 << 31).toInt(),
    ));
  }

  Future<void> _edit() async {
    final d = _detail;
    if (d == null || !requireAnilistSignIn(context, service: _social)) return;
    final result = await editAnilistTitleEntry(
      context,
      AnilistEditTarget.of(d),
      write: _write,
      lists: widget.lists,
      editor: widget.editor,
    );
    if (!mounted || result == null) return;
    switch (result) {
      case AnilistEditSaved(detail: final saved):
        _update(_detail!.copyWith(entry: saved));
      case AnilistEditRemoved():
        _update(_detail!.copyWith(clearEntry: true));
    }
  }

  Future<void> _plusOne() async {
    final d = _detail;
    final entry = d?.entry;
    if (d == null || entry == null || _stepping) return;
    setState(() => _stepping = true);
    final input = anilistPlusOne(entry, total: d.total, today: (widget.clock ?? DateTime.now)());
    final saved = await runAnilistWrite(context, () => _write.save(input), service: _social);
    if (!mounted) return;
    setState(() => _stepping = false);
    if (saved == null) return;
    (widget.lists ?? AnilistListService.instance).invalidate(d.category);
    _update(_detail!.copyWith(entry: entry.merge(saved)));
  }

  Future<void> _vote(AnilistRecommendation r, AnilistRecommendationVote vote) async {
    final d = _detail;
    if (d == null) return;
    final done = await runAnilistWrite<bool>(context, () async {
      await _social.rateRecommendation(d.id, r.media.id, vote);
      return true;
    }, service: _social);
    if (done != true || !mounted) return;
    final voted = r.voted(vote);
    _update(_detail!.copyWith(recommendations: [
      for (final x in _detail!.recommendations) x.media.id == r.media.id ? voted : x,
    ]));
    final pager = _recommendations;
    if (pager != null) {
      for (final x in [...pager.items]) {
        if (x.media.id == r.media.id) pager.replace(x, x.voted(vote));
      }
    }
  }

  Future<void> _recommend() async {
    final d = _detail;
    if (d == null || !requireAnilistSignIn(context, service: _social)) return;
    final picked = await pickAnilistRecommendation(context, category: d.category, excludeId: d.id, service: _service);
    if (picked == null || !mounted) return;
    final done = await runAnilistWrite<bool>(context, () async {
      await _social.rateRecommendation(d.id, picked.id, AnilistRecommendationVote.up);
      return true;
    }, service: _social);
    if (done != true || !mounted) return;
    _snack(S.current.Amp_Recommend_Done);
    setState(() {
      _recommendations?.dispose();
      _recommendations = null;
    });
    _pagerOf(AnilistMediaTab.relations)?.loadMore();
  }

  void _setLanguage(String language) {
    setState(() {
      _language = language;
      _characters?.dispose();
      _characters = null;
    });
    _pagerOf(AnilistMediaTab.characters)?.loadMore();
  }

  // ------------------------------------------------------------------ menu

  Future<void> _menu(String action) async {
    final d = _detail;
    final url = d?.siteUrl ?? 'https://anilist.co/anime/${widget.id}';
    switch (action) {
      case 'share':
        await Share.share(url);
      case 'anilist':
        await openLink(context, url, confirm: false);
      case 'mal':
        if (d?.malId != null) await AppRoutes.openContent(context, id: d!.malId!, category: d.category);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: d?.title ?? widget.title ?? ''));
        _snack(S.current.Amp_Copied);
    }
  }

  // ------------------------------------------------------------------ build

  bool _nearEnd(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) _pagerOf(_tab)?.loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = _detail;
    final scheme = Theme.of(context).colorScheme;
    final name = d?.title ?? widget.title ?? '';
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: scheme.surface.withValues(alpha: 0.72),
      foregroundColor: scheme.onSurface,
    );
    final appBar = SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      leading: IconButton(
        style: buttonStyle,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const BackButtonIcon(),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: _CollapsedTitle(name),
      actions: [
        if (d != null)
          IconButton(
            style: buttonStyle,
            tooltip: d.isFavourite ? s.Alp_Remove_Favourite : s.Alp_Add_Favourite,
            icon: Icon(d.isFavourite ? Icons.favorite : Icons.favorite_border,
                color: d.isFavourite ? scheme.error : null),
            onPressed: _toggleFavourite,
          ),
        PopupMenuButton<String>(
          style: buttonStyle,
          onSelected: _menu,
          itemBuilder: (_) => [
            PopupMenuItem(value: 'share', child: Text(s.Share)),
            PopupMenuItem(value: 'anilist', child: Text(s.Amp_Open_Anilist)),
            if (d?.malId != null) PopupMenuItem(value: 'mal', child: Text(s.Amp_Open_Mal)),
            PopupMenuItem(value: 'copy', child: Text(s.Amp_Copy_Title)),
          ],
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: AnilistMediaBanner(bannerUrl: d?.bannerUrl, coverColor: d?.coverColor),
      ),
    );
    return Scaffold(
      floatingActionButton: d == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              icon: Icon(d.entry == null ? Icons.add : Icons.edit_outlined),
              label: Text(d.entry?.status == null
                  ? s.Amp_Add_To_List
                  : AnilistLabels.listStatus(d.entry!.status!, anime: d.isAnime)),
            ),
      body: RefreshIndicator(
        edgeOffset: 120,
        onRefresh: () => _load(force: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: _nearEnd,
          child: CustomScrollView(
            slivers: [
              appBar,
              ...switch (_phase) {
                _Phase.ready => _body(context, d!),
                _Phase.loading => [
                    SliverToBoxAdapter(child: _Placeholder(title: name, coverUrl: widget.coverUrl)),
                    const SliverToBoxAdapter(
                        child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))),
                  ],
                _Phase.failed => [
                    SliverToBoxAdapter(
                      child: AnilistTabMessage(
                        text: s.Amp_Load_Failed,
                        onRetry: () {
                          setState(() => _phase = _Phase.loading);
                          _load(force: true);
                        },
                      ),
                    ),
                  ],
                _Phase.notFound => [SliverToBoxAdapter(child: AnilistTabMessage(text: s.Amp_Not_Found))],
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, AnilistMediaDetail d) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final continueEpisode = d.continueEpisode;
    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnilistMediaHeader(detail: d),
            if (d.entry != null)
              AnilistMyEntryCard(detail: d, onEdit: _edit, onPlusOne: _plusOne, busy: _stepping),
            if (continueEpisode != null) AnilistContinueCard(episode: continueEpisode),
            if (d.description != null) AnilistSynopsis(html: d.description!),
            if (d.genres.isNotEmpty) AnilistGenreChips(detail: d),
            const SizedBox(height: 8),
          ],
        ),
      ),
      SliverPersistentHeader(
        pinned: true,
        delegate: _TabBarDelegate(
          color: scheme.surface,
          tabBar: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final t in AnilistMediaTab.values) Tab(text: _tabLabel(s, t)),
            ],
          ),
        ),
      ),
      ..._tabSlivers(context, d),
    ];
  }

  static String _tabLabel(S s, AnilistMediaTab t) => switch (t) {
        AnilistMediaTab.overview => s.Amp_Tab_Overview,
        AnilistMediaTab.characters => s.Characters,
        AnilistMediaTab.staff => s.Staff,
        AnilistMediaTab.relations => s.Amp_Tab_Relations,
        AnilistMediaTab.stats => s.Stats,
        AnilistMediaTab.social => s.Amp_Tab_Social,
        AnilistMediaTab.reviews => s.Reviews,
      };

  List<Widget> _tabSlivers(BuildContext context, AnilistMediaDetail d) {
    final s = S.of(context);
    switch (_tab) {
      case AnilistMediaTab.overview:
        return [AnilistOverview(detail: d, onVote: _vote, onShowTab: _show)];
      case AnilistMediaTab.characters:
        final pager = _pagerOf(AnilistMediaTab.characters) as AnilistPager<AnilistCastEdge>;
        return [
          if (d.isAnime) SliverToBoxAdapter(child: AnilistLanguageBar(language: _language, onChanged: _setLanguage)),
          AnilistPagerSliver<AnilistCastEdge>(
            key: ValueKey('characters-$_language'),
            pager: pager,
            empty: s.Amp_No_Characters,
            itemBuilder: (_, e) => AnilistCastCard(edge: e),
          ),
        ];
      case AnilistMediaTab.staff:
        return [
          AnilistPagerSliver<AnilistStaffEdge>(
            pager: _pagerOf(AnilistMediaTab.staff) as AnilistPager<AnilistStaffEdge>,
            empty: s.Amp_No_Staff,
            itemBuilder: (_, e) => AnilistStaffCard(edge: e),
          ),
        ];
      case AnilistMediaTab.relations:
        return anilistRelationsSlivers(
          context,
          detail: d,
          recommendations: _pagerOf(AnilistMediaTab.relations) as AnilistPager<AnilistRecommendation>,
          onVote: _vote,
          onRecommend: _recommend,
        );
      case AnilistMediaTab.stats:
        return [SliverToBoxAdapter(child: AnilistStatsTab(detail: d))];
      case AnilistMediaTab.social:
        return [SliverToBoxAdapter(child: AnilistSocialTab(detail: d, signedIn: _service.signedIn))];
      case AnilistMediaTab.reviews:
        return [SliverToBoxAdapter(child: AnilistReviewsTab(detail: d))];
    }
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.title, this.coverUrl});

  final String title;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: coverUrl,
            width: AnilistMediaHeader.coverWidth,
            height: AnilistMediaHeader.coverHeight,
            borderRadius: BorderRadius.circular(10),
            placeholderColor: scheme.surfaceContainerHighest,
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate({required this.tabBar, required this.color});

  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar || old.color != color;
}

/// The title in the app bar once the banner is folded away.
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle(this.text);

  final String text;

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
