import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart' show ProfileTabScroll;
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuProfileSummary;
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_profile.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_about_extras.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_category_donut.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart' show kitsuStatusLabel;
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_activity_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_favourites_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_list_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_people.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_posts_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_reactions_tab.dart';
import 'package:mywatchlist/widgets/charts/chart_card.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/charts/status_bar_chart.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart' show formatProfileDate;
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A Kitsu profile: a header (cover, avatar, name, followers and following that open their lists)
/// over a pinned bar with lazily built tabs: Stats (list counts by status, time spent, top
/// categories), About (text, counters, social links), Favorites (anime, manga, characters,
/// people), Activity, Reactions, Posts and, on another user's profile, their List.
///
/// [userId] null is the signed-in user. Without a [Scaffold] of its own so it can sit in the
/// home shell as well as in a pushed page ([showBack]).
class KitsuProfileView extends StatefulWidget {
  final String? userId;
  final bool showBack;

  /// Loads the profile; replaced by tests.
  final Future<KitsuProfile> Function(String? userId)? loader;

  const KitsuProfileView({super.key, this.userId, this.showBack = false, this.loader});

  @override
  State<KitsuProfileView> createState() => _KitsuProfileViewState();
}

class _KitsuProfileViewState extends State<KitsuProfileView> {
  late Future<KitsuProfile> _future = _load();

  Future<KitsuProfile> _load() {
    final future = widget.loader != null
        ? widget.loader!(widget.userId)
        : KitsuProfiles.instance.load(userId: widget.userId);
    // The FutureBuilder shows the error; one that lands before it listens is not "unhandled".
    future.ignore();
    return future;
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KitsuProfile>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) return _Loaded(profile: data, isSelf: widget.userId == null, showBack: widget.showBack);
        final body = snapshot.hasError
            ? _ErrorView(error: snapshot.error!, onRetry: _retry)
            : ProfileLoading(label: S.of(context).Kitsu_Prof_Loading);
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.showBack ? AppBar() : null,
          body: SafeArea(child: body),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (error is KitsuSessionExpired) {
      return ProfileMessage(
        icon: Icons.lock_outline,
        title: s.Kitsu_Session_Expired,
        body: s.Kitsu_Session_Expired_Hint,
        actionLabel: s.Prof_Retry,
        onAction: onRetry,
      );
    }
    final missing = error is KitsuHttpError && (error as KitsuHttpError).statusCode == 404;
    return ProfileMessage(
      icon: missing ? Icons.person_off_outlined : Icons.cloud_off_outlined,
      title: s.Prof_Error_Title,
      body: missing ? s.Prof_Not_Found_Body : s.Prof_Error_Body,
      actionLabel: s.Prof_Retry,
      onAction: onRetry,
    );
  }
}

class _Loaded extends StatefulWidget {
  final KitsuProfile profile;
  final bool isSelf;
  final bool showBack;

  const _Loaded({required this.profile, required this.isSelf, required this.showBack});

  @override
  State<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends State<_Loaded> {
  Future<KitsuProfileSummary?>? _summary;

  /// The GraphQL header (social links, pinned post), asked once and only when a tab needs it. A
  /// failure is a missing block, not an error screen.
  Future<KitsuProfileSummary?> _loadSummary() => _summary ??= KitsuSocial.instance
      .summary(widget.profile.handle)
      .then<KitsuProfileSummary?>((v) => v)
      .catchError((Object _) => null);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final profile = widget.profile;
    final slug = profile.handle;
    return DefaultTabController(
      length: widget.isSelf ? 6 : 7,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _Header(profile: profile)),
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                pinned: true,
                automaticallyImplyLeading: widget.showBack,
                title: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    tooltip: s.Kitsu_User_Search_Tooltip,
                    icon: const Icon(Icons.person_search_outlined),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const KitsuUserSearchPage())),
                  ),
                  IconButton(
                    tooltip: s.Kitsu_Open_Profile,
                    icon: const Icon(Icons.open_in_new_rounded),
                    onPressed: () => launchWebView(profile.webUrl, context: context),
                  ),
                ],
                bottom: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: s.Kitsu_Tab_Stats),
                    Tab(text: s.Kitsu_Tab_About),
                    Tab(text: s.Kitsu_Tab_Favorites),
                    Tab(text: s.Kitsu_Tab_Activity),
                    Tab(text: s.Kitsu_Tab_Reactions),
                    Tab(text: s.Kitsu_Tab_Posts),
                    if (!widget.isSelf) Tab(text: s.Kitsu_Tab_List),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _StatsTab(profile: profile),
              _AboutTab(profile: profile, isSelf: widget.isSelf, summary: _loadSummary),
              KitsuFavouritesTab(profile: profile),
              KitsuActivityTab(slug: slug),
              KitsuReactionsTab(slug: slug),
              KitsuPostsTab(
                  slug: slug, pinned: () async => (await _loadSummary())?.pinnedPost),
              if (!widget.isSelf) KitsuListTab(slug: slug),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final KitsuProfile profile;

  const _Header({required this.profile});

  static const double _cover = 150;
  static const double _avatar = 88;

  void _openPeople(BuildContext context, {required bool followers}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => KitsuPeoplePage(slug: profile.handle, followers: followers),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final statusBar = MediaQuery.paddingOf(context).top;
    final joined = formatProfileDate(profile.joined, withDay: false);
    final entries = profile.anime.totalEntries + profile.manga.totalEntries;
    final details = [
      if (joined != null) s.Prof_Joined(joined),
      if (entries > 0) s.Prof_Entry_Count(entries),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: _cover + statusBar,
              width: double.infinity,
              child: profile.coverUrl == null
                  ? ColoredBox(color: scheme.primaryContainer)
                  : AppImage(url: profile.coverUrl, placeholderColor: scheme.primaryContainer),
            ),
            PositionedDirectional(
              start: 16,
              bottom: -_avatar / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 4),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: _avatar,
                    height: _avatar,
                    child: profile.avatarUrl == null
                        ? ColoredBox(
                            color: scheme.secondaryContainer,
                            child: Icon(Icons.person_rounded,
                                size: 44, color: scheme.onSecondaryContainer))
                        : AppImage(
                            url: profile.avatarUrl,
                            placeholderColor: scheme.secondaryContainer,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, _avatar / 2 + 10, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (details.isNotEmpty)
                Text(details,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Counter(
                    label: s.Kitsu_Followers(profile.followers),
                    onTap: () => _openPeople(context, followers: true),
                  ),
                  _Counter(
                    label: s.Kitsu_Following(profile.following),
                    onTap: () => _openPeople(context, followers: false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A follower or following count that opens the matching list.
class _Counter extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Counter({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

/// "12 d 5 h" or "3 h 20 min" in the app language.
String formatKitsuTime(Duration time) {
  final s = S.current;
  if (time.inDays >= 1) return s.Kitsu_Time_Days(time.inDays, time.inHours % 24);
  return s.Kitsu_Time_Hours(time.inHours, time.inMinutes % 60);
}

class _StatsTab extends StatefulWidget {
  final KitsuProfile profile;

  const _StatsTab({required this.profile});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> with AutomaticKeepAliveClientMixin {
  bool _anime = true;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final theme = Theme.of(context);
    final stats = _anime ? widget.profile.anime : widget.profile.manga;
    final colors = themedStatusChartColors(
      AppColors.of(context),
      context.select((PreferencesBloc bloc) => bloc.state.general.statsChartColors),
    );
    final number = NumberFormat.decimalPattern();
    return ProfileTabScroll(
      storageKey: 'kitsu_stats_${widget.profile.id}',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(s.Prof_Anime)),
                ButtonSegment(value: false, label: Text(s.Prof_Manga)),
              ],
              selected: {_anime},
              onSelectionChanged: (v) => setState(() => _anime = v.first),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ChartCard(
            title: _anime ? s.Kitsu_Stats_Anime : s.Kitsu_Stats_Manga,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Figure(label: s.Kitsu_Stat_Entries, value: number.format(stats.totalEntries)),
                _Figure(
                    label: _anime ? s.Kitsu_Stat_Episodes : s.Kitsu_Stat_Chapters,
                    value: number.format(stats.units)),
                _Figure(label: s.Kitsu_Stat_Completed, value: number.format(stats.completed)),
                _Figure(
                    label: _anime ? s.Kitsu_Stat_Time_Watched : s.Kitsu_Stat_Time_Read,
                    value: stats.time == Duration.zero ? '-' : formatKitsuTime(stats.time)),
              ],
            ),
          ),
        ),
        if (stats.timePercentile != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                s.Kitsu_Stat_Percentile(stats.timePercentile!.round().toString()),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        if (stats.totalEntries > 0)
          SliverToBoxAdapter(
            child: ChartCard(
              title: s.Kitsu_Chart_Status,
              child: StatusBarChart(
                key: ValueKey('kitsu_status_$_anime'),
                values: [
                  for (final status in ListEntryStatus.values)
                    (stats.statusCounts[status] ?? 0).toDouble(),
                ],
                labels: [
                  for (final status in ListEntryStatus.values) kitsuStatusLabel(status, isAnime: _anime),
                ],
                colors: colors,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.Kitsu_Stats_Empty,
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ),
          ),
        if (stats.categories.isNotEmpty)
          SliverToBoxAdapter(
            child: ChartCard(
              title: s.Kitsu_Chart_Categories,
              child: KitsuCategoryDonut(items: stats.categories),
            ),
          ),
        SliverToBoxAdapter(child: KitsuRecentActivity(slug: widget.profile.handle)),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;

  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// About
// ---------------------------------------------------------------------------

class _AboutTab extends StatefulWidget {
  final KitsuProfile profile;
  final bool isSelf;
  final Future<KitsuProfileSummary?> Function() summary;

  const _AboutTab({required this.profile, required this.isSelf, required this.summary});

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
    final theme = Theme.of(context);
    final p = widget.profile;
    final birthday = formatProfileDate(p.birthday);
    final joined = formatProfileDate(p.joined);
    final waifu = p.waifuName == null
        ? null
        : '${(p.waifuLabel ?? '').toLowerCase() == 'husbando' ? s.Kitsu_Husbando : s.Kitsu_Waifu}: ${p.waifuName}';
    final rows = <(IconData, String, String)>[
      if (p.location != null) (Icons.place_outlined, s.Prof_Location, p.location!),
      if (p.gender != null) (Icons.person_outline_rounded, s.Prof_Gender, p.gender!),
      if (birthday != null) (Icons.cake_outlined, s.Prof_Birthday, birthday),
      if (joined != null) (Icons.event_outlined, s.Kitsu_Member_Since, joined),
      if (waifu != null) (Icons.favorite_border_rounded, s.Kitsu_Favorite_Character, waifu),
    ];
    return ProfileTabScroll(
      storageKey: 'kitsu_about_${p.id}',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverToBoxAdapter(
            child: p.about == null
                ? Text(
                    widget.isSelf ? s.Prof_About_Empty_Self : s.Prof_About_Empty,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  )
                : SelectableText(p.about!, style: theme.textTheme.bodyMedium),
          ),
        ),
        SliverList.list(
          children: [
            const SizedBox(height: 12),
            for (final row in rows)
              ListTile(
                leading: Icon(row.$1),
                title: Text(row.$3),
                subtitle: Text(row.$2),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: KitsuAboutExtras(profile: p, summary: widget.summary),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: () => launchWebView(p.webUrl, context: context),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(s.Kitsu_Open_Profile),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
