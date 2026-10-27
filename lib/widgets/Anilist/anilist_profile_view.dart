import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/screens/user_profile/sections/stats_section.dart'
    show statusLabels;
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart'
    show anilistMediaType;
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_media_card.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/widgets/charts/chart_card.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/charts/ranked_bar_list.dart';
import 'package:mywatchlist/widgets/charts/score_stack_chart.dart';
import 'package:mywatchlist/widgets/charts/status_bar_chart.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart'
    show UserProfileUnavailable;
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/utils/app_routes.dart';

/// An AniList profile: the shared themed header (avatar, name, join date, entries) over
/// three lazily built tabs, Stats, About and Favorites. [username] null = the signed-in user.
/// Without a [Scaffold] of its own, so it sits in the home shell as well as in a pushed page.
class AnilistProfileView extends StatefulWidget {
  final String? username;
  final bool showBack;
  final AnilistProfileService? service;

  const AnilistProfileView({super.key, this.username, this.showBack = false, this.service});

  @override
  State<AnilistProfileView> createState() => _AnilistProfileViewState();
}

class _AnilistProfileViewState extends State<AnilistProfileView> {
  AnilistProfile? _profile;
  Object? _error;
  int _generation = 0;

  AnilistProfileService get _service => widget.service ?? AnilistProfileService.instance;

  @override
  void initState() {
    super.initState();
    // The profile of the last visit shows at once while the fresh one loads.
    _profile = _service.kept(widget.username);
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final generation = ++_generation;
    try {
      final profile = await _service.load(
        username: widget.username,
        force: force,
        maxAge: const Duration(minutes: 5),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      // A refresh that fails keeps the profile already on screen.
      if (_profile == null) setState(() => _error = e);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      final s = S.of(context);
      final error = _error;
      return Column(
        children: [
          AppBar(
            automaticallyImplyLeading: widget.showBack,
            title: Text(widget.username ?? s.Prof_Title_Own),
          ),
          Expanded(
            child: error == null
                ? ProfileLoading(label: s.Prof_Loading)
                : error is AnilistSessionExpired
                    ? ProfileMessage(
                        icon: Icons.lock_outline,
                        title: s.Al_Session_Expired,
                        body: s.Al_Profile_Session_Expired_Body,
                        actionLabel: s.Al_Sign_In_Again,
                        onAction: () async {
                          await AppRoutes.signInAgain(context, AccountType.anilist);
                          if (mounted) _retry();
                        },
                      )
                    : ProfileMessage(
                        icon: error is UserProfileUnavailable
                            ? Icons.person_off_outlined
                            : Icons.cloud_off_outlined,
                        title: s.Prof_Error_Title,
                        body: error is UserProfileUnavailable
                            ? s.Prof_Not_Found_Body
                            : s.Prof_Error_Body,
                        actionLabel: s.Prof_Retry,
                        onAction: _retry,
                      ),
          ),
        ],
      );
    }
    return _Body(
      key: ValueKey(profile.data.username.toLowerCase()),
      profile: profile,
      isSelf: widget.username == null,
      showBack: widget.showBack,
    );
  }
}

class _Body extends StatefulWidget {
  final AnilistProfile profile;
  final bool isSelf;
  final bool showBack;

  const _Body({super.key, required this.profile, required this.isSelf, required this.showBack});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> with SingleTickerProviderStateMixin {
  static const double _tabBarHeight = 48;
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _share() {
    final p = widget.profile;
    final s = S.current;
    String line(String label, int entries, double? mean) =>
        '$label: ${s.Prof_Entry_Count(entries)}${(mean ?? 0) > 0 ? ' · ${profileMean(mean)}' : ''}';
    final summary = [
      if (p.data.anime.totalEntries > 0)
        line(s.Prof_Anime, p.data.anime.totalEntries, p.data.anime.meanScore),
      if (p.data.manga.totalEntries > 0)
        line(s.Prof_Manga, p.data.manga.totalEntries, p.data.manga.meanScore),
    ].join('\n');
    showShareBuilder(
      context,
      subject: p.data.username,
      fields: [
        ShareField(label: s.Prof_Share_Name, value: p.data.username, labelled: false),
        ShareField(label: s.Prof_Share_Link, value: p.url, labelled: false),
        if (summary.isNotEmpty)
          ShareField(label: s.Prof_Share_Stats, value: summary, labelled: false),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final profile = widget.profile;
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverOverlapAbsorber(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          sliver: SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: widget.showBack,
            forceElevated: innerBoxIsScrolled,
            expandedHeight: kToolbarHeight + ProfileHeader.bandHeight + _tabBarHeight,
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            title: _CollapsedTitle(profile.data.username),
            actions: [
              AppBarMenu(
                onShare: _share,
                onOpenInBrowser: () => openLink(context, profile.url),
                items: [
                  if (widget.isSelf)
                    AppBarMenuItem(
                      label: s.Prof_Edit_Profile,
                      icon: Icons.edit_outlined,
                      onTap: () => openLink(context, 'https://anilist.co/settings/profile'),
                    ),
                ],
              ),
            ],
            flexibleSpace: ProfileHeader(
              data: profile.data,
              isSelf: widget.isSelf,
              bottomInset: _tabBarHeight,
            ),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: s.Prof_Tab_Stats),
                Tab(text: s.Prof_Tab_About),
                Tab(text: s.Prof_Tab_Favorites),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          _StatsTab(profile: profile),
          _AboutTab(profile: profile, isSelf: widget.isSelf),
          _FavoritesTab(profile: profile),
        ],
      ),
    );
  }
}

/// The user name in the toolbar, shown once the header has scrolled away (a text colour
/// alpha, not an opacity layer).
class _CollapsedTitle extends StatelessWidget {
  final String username;

  const _CollapsedTitle(this.username);

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final style = DefaultTextStyle.of(context).style;
    var visible = 1.0;
    if (settings != null && settings.maxExtent > settings.minExtent) {
      final expanded = ((settings.currentExtent - settings.minExtent) /
              (settings.maxExtent - settings.minExtent))
          .clamp(0.0, 1.0);
      visible = ((1 - expanded) * 3 - 2).clamp(0.0, 1.0);
    }
    final color = style.color ?? Theme.of(context).colorScheme.onSurface;
    return Text(
      username,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(color: color.withValues(alpha: color.a * visible)),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

class _StatsTab extends StatefulWidget {
  final AnilistProfile profile;
  const _StatsTab({required this.profile});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> with AutomaticKeepAliveClientMixin {
  String _category = 'anime';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final theme = Theme.of(context);
    final manga = _category == 'manga';
    final stats = manga ? widget.profile.manga : widget.profile.anime;
    final list = stats.list;
    final colors = themedStatusChartColors(
      AppColors.of(context),
      context.select((PreferencesBloc bloc) => bloc.state.general.statsChartColors),
    );
    final labels = statusLabels(_category, s);
    final primary = theme.colorScheme.primary;

    return ProfileTabScroll(
      storageKey: 'al_stats_${widget.profile.data.username}',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'anime', label: Text(s.Prof_Anime)),
                ButtonSegment(value: 'manga', label: Text(s.Prof_Manga)),
              ],
              selected: {_category},
              onSelectionChanged: (v) => setState(() => _category = v.first),
            ),
          ),
        ),
        if (list.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                s.Prof_Dist_Empty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _Summary(stats: stats, manga: manga)),
          SliverToBoxAdapter(
            child: ChartCard(
              title: manga ? s.Prof_Chart_Manga_Title : s.Prof_Chart_Anime_Title,
              footer: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 5; i++)
                    LegendDot(
                      color: colors[i],
                      label: '${labels[i]} · ${profileNumber(list.statusCounts[i])}',
                    ),
                ],
              ),
              child: StatusBarChart(
                values: [for (final c in list.statusCounts) c.toDouble()],
                labels: labels,
                colors: colors,
              ),
            ),
          ),
          if (stats.scores.isNotEmpty)
            SliverToBoxAdapter(
              child: ChartCard(
                title: s.Prof_Score_Dist,
                child: ScoreStackChart(
                  scoreByStatus: {
                    for (var score = 1; score <= 10; score++) score: [stats.scores[score] ?? 0],
                  },
                  labels: [s.Prof_Score_Dist],
                  colors: [primary],
                ),
              ),
            ),
          if (stats.genres.isNotEmpty)
            SliverToBoxAdapter(
              child: ChartCard(
                title: s.Prof_Dist_Genres,
                child: RankedBarList(
                  color: primary,
                  items: [
                    for (final g in stats.genres)
                      RankedBarItem(label: g.label, count: g.count, mean: g.mean),
                  ],
                ),
              ),
            ),
          if (stats.formats.isNotEmpty)
            SliverToBoxAdapter(
              child: ChartCard(
                title: s.Prof_Dist_Media,
                child: RankedBarList(
                  color: primary,
                  items: [
                    for (final f in stats.formats)
                      RankedBarItem(
                        label: profileMediaTypeLabel(anilistMediaType(f.label) ?? f.label),
                        count: f.count,
                        mean: f.mean,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// The key numbers on one flat card: value in large, label under it, the mean score in the
/// score colour.
class _Summary extends StatelessWidget {
  final AnilistCategoryStats stats;
  final bool manga;

  const _Summary({required this.stats, required this.manga});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final list = stats.list;
    final hasMean = (list.meanScore ?? 0) > 0;
    final tiles = <(String, String, Color?)>[
      (s.Prof_Mean_Score, profileMean(list.meanScore),
          hasMean ? AppColors.of(context).score.color : null),
      (s.Prof_Entries_Label, profileNumber(list.totalEntries), null),
      if (!manga)
        (
          s.Prof_Days_Label,
          list.days == null ? s.Pp_No_Value : profileNumber(list.days!, digits: 1),
          null
        ),
      (manga ? s.Prof_Chapters_Label : s.Prof_Episodes_Label, profileNumber(list.progress), null),
      if (manga) (s.Prof_Volumes_Label, profileNumber(list.volumes), null),
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final columns = constraints.maxWidth >= 520 ? tiles.length : 3;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 14,
              children: [
                for (final (label, value, color) in tiles)
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color ?? cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

class _AboutTab extends StatefulWidget {
  final AnilistProfile profile;
  final bool isSelf;
  const _AboutTab({required this.profile, required this.isSelf});

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final about = widget.profile.about;
    if (about == null) {
      return ProfileTabScroll(
        storageKey: 'al_about_${widget.profile.data.username}',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ProfileMessage(
              icon: Icons.notes_outlined,
              title: widget.isSelf ? s.Prof_About_Empty_Self : s.Prof_About_Empty,
              actionLabel: widget.isSelf ? s.Al_Edit_On_Anilist : null,
              onAction: widget.isSelf
                  ? () => openLink(context, 'https://anilist.co/settings/profile')
                  : null,
            ),
          ),
        ],
      );
    }
    return ProfileTabScroll(
      storageKey: 'al_about_${widget.profile.data.username}',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: HtmlWidget(
              about,
              textStyle: Theme.of(context).textTheme.bodyMedium,
              onTapUrl: (url) {
                openLink(context, url);
                return true;
              },
              customWidgetBuilder: (element) {
                if (element.localName != 'img') return null;
                final src = element.attributes['src'];
                if (src == null || src.isEmpty) return const SizedBox.shrink();
                final width = MediaQuery.sizeOf(context).width - 32;
                return GestureDetector(
                  onTap: () => zoomInImage(context, src),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: AppImage(
                      url: src,
                      width: width,
                      fit: BoxFit.contain,
                      errorWidget: (_) => const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.isSelf)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                onPressed: () => openLink(context, 'https://anilist.co/settings/profile'),
                icon: const Icon(Icons.edit_outlined),
                label: Text(s.Al_Edit_On_Anilist),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

class _FavoritesTab extends StatefulWidget {
  final AnilistProfile profile;
  const _FavoritesTab({required this.profile});

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _open(AnilistFavorite f, String? category) {
    if (category != null && f.malId != null) {
      openAnilistMedia(
        context,
        AnilistMedia(id: f.id, malId: f.malId, category: category, title: f.title),
      );
    } else {
      openLink(context, f.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final fav = widget.profile.favorites;
    if (fav.isEmpty) {
      return ProfileTabScroll(
        storageKey: 'al_fav_${widget.profile.data.username}',
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ProfileMessage(icon: Icons.favorite_border, title: s.Prof_Fav_Empty),
          ),
        ],
      );
    }
    final groups = <(String, List<AnilistFavorite>, String?)>[
      (s.Prof_Fav_Anime, fav.anime, 'anime'),
      (s.Prof_Fav_Manga, fav.manga, 'manga'),
      (s.Prof_Fav_Characters, fav.characters, null),
      (s.Prof_Fav_People, fav.staff, null),
      (s.Al_Fav_Studios, fav.studios, null),
    ];
    return ProfileTabScroll(
      storageKey: 'al_fav_${widget.profile.data.username}',
      slivers: [
        for (final (title, items, category) in groups)
          if (items.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 120,
                  childAspectRatio: 0.5,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) => _FavoriteTile(
                  favorite: items[i],
                  onTap: () => _open(items[i], category),
                ),
              ),
            ),
          ],
      ],
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final AnilistFavorite favorite;
  final VoidCallback onTap;

  const _FavoriteTile({required this.favorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: favorite.imageUrl == null
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Icon(Icons.business_outlined, color: cs.onSurfaceVariant),
                      ),
                    )
                  : AppImage(
                      url: favorite.imageUrl,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(10),
                      placeholderColor: cs.surfaceContainerHighest,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              favorite.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
