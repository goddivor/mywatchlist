import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_stats_service.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart' show openSimklTitle, openSimklMedia;
import 'package:mywatchlist/services/api/SimKl/simkl_user.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show launchWebView;
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart' show SimklFormat;
import 'package:mywatchlist/widgets/Simkl/simkl_catalogue.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/widgets/charts/chart_card.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/charts/score_stack_chart.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// The numbers of one catalogue (shows, anime or movies) of the profile.
class SimklKindProfile {
  final SimklListStats stats;
  final SimklWatchStats? watch;
  final List<ListEntryView> topRated;
  final Map<ListEntryStatus, int> episodesByStatus;

  const SimklKindProfile(this.stats, {this.watch, this.topRated = const [], this.episodesByStatus = const {}});

  factory SimklKindProfile.of(List<ListEntryView> list, SimklWatchStats? watch) => SimklKindProfile(
        SimklListStats.from(list),
        watch: watch,
        topRated: simklTopRated(list),
        episodesByStatus: simklEpisodesByStatus(list),
      );
}

/// What the Simkl profile shows: the account (name, picture, join date…) and the numbers
/// computed from the whole lists, per catalogue ([byKind]; the anime ones also in [stats]).
class SimklProfileData {
  final UserProfSimkl? account;
  final SimklListStats stats;

  /// Watch time, "now watching" cover and custom lists: each null/empty when Simkl did not
  /// answer (they never hide the rest of the profile).
  final SimklWatchStats? watch;
  final SimklNowWatching? nowWatching;
  final List<SimklCustomList> lists;

  /// The user's 9 and 10 rated titles, best first.
  final List<ListEntryView> topRated;

  /// Episodes watched per list status.
  final Map<ListEntryStatus, int> episodesByStatus;

  /// The catalogues the account has (TV shows, anime, movies); empty = anime only, in the
  /// fields above.
  final Map<SimklKind, SimklKindProfile> byKind;

  const SimklProfileData(
    this.account,
    this.stats, {
    this.watch,
    this.nowWatching,
    this.lists = const [],
    this.topRated = const [],
    this.episodesByStatus = const {},
    this.byKind = const {},
  });

  /// The numbers of [kind] ([byKind], else the anime fields).
  SimklKindProfile of(SimklKind kind) =>
      byKind[kind] ?? SimklKindProfile(stats, watch: watch, topRated: topRated, episodesByStatus: episodesByStatus);
}

/// The titles scored 9 or 10, highest score then latest activity first.
List<ListEntryView> simklTopRated(List<ListEntryView> list, {int limit = 20}) {
  final top = [...list.where((e) => e.score >= 9)]..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0));
    });
  return top.take(limit).toList();
}

/// Episodes watched per list status.
Map<ListEntryStatus, int> simklEpisodesByStatus(List<ListEntryView> list) {
  final out = <ListEntryStatus, int>{};
  for (final e in list) {
    final s = e.status;
    if (s != null) out[s] = (out[s] ?? 0) + e.progress;
  }
  return out;
}

/// `3d 4h`, `5h 20m` or `45m` in the app language.
String simklDuration(int mins) {
  final s = S.current;
  if (mins >= 1440) return s.Skp_Dur_Days_Hours(mins ~/ 1440, (mins % 1440) ~/ 60);
  if (mins >= 60) return s.Skp_Dur_Hours_Mins(mins ~/ 60, mins % 60);
  return s.Skp_Dur_Mins(mins);
}

/// Loads the Simkl profile. The account call may fail without hiding the stats (the name and
/// picture stored at sign-in are used then). The three lists load together; the anime one is
/// required, a failed show or movie list only leaves its catalogue out.
Future<SimklProfileData> loadSimklProfile({
  SimklUser? user,
  SimklListService? lists,
  SimklListService Function(SimklKind kind)? listsOf,
  SimklStatsService? extras,
  bool force = false,
}) async {
  final accountFuture = (user ?? SimklUser()).getUserInfo().then<UserProfSimkl?>((a) => a).catchError(
    (Object e) {
      // A dead session shows on the list call below; any other failure keeps the stored name.
      return null;
    },
  );
  // [lists] alone (tests): the anime list only.
  final SimklListService? Function(SimklKind k) serviceOf =
      listsOf ?? (lists != null ? (SimklKind k) => k == SimklKind.anime ? lists : null : SimklListService.of);
  Future<List<ListEntryView>?> other(SimklKind k) async {
    final service = serviceOf(k);
    if (service == null) return null;
    try {
      return await service.entries(force: force);
    } on SimklSessionExpired {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  final shows = other(SimklKind.tv);
  final movies = other(SimklKind.movie);
  final list = await serviceOf(SimklKind.anime)!.entries(force: force);
  final otherLists = {SimklKind.tv: await shows, SimklKind.movie: await movies};
  final account = await accountFuture;
  final id = account?.accountId ?? 0;
  var watchByKind = const <SimklKind, SimklWatchStats>{};
  SimklWatchStats? watch;
  SimklNowWatching? cover;
  var custom = const <SimklCustomList>[];
  if (id > 0) {
    // Optional extras, one after the other (Simkl rate-limits): a failure only hides its block.
    final service = extras ?? SimklStatsService.instance;
    Future<T?> tryGet<T>(Future<T> Function() call) async {
      try {
        return await call();
      } catch (_) {
        return null;
      }
    }

    watchByKind = await tryGet(() => service.watchStatsByKind(id)) ?? const {};
    watch = watchByKind[SimklKind.anime];
    cover = await tryGet<SimklNowWatching?>(() => service.nowWatching(id));
    if (simklIsPaid(account!.accountType)) custom = await tryGet(() => service.customLists(id)) ?? const [];
  }
  return SimklProfileData(
    account,
    SimklListStats.from(list),
    watch: watch,
    nowWatching: cover,
    lists: custom,
    topRated: simklTopRated(list),
    episodesByStatus: simklEpisodesByStatus(list),
    byKind: otherLists.values.every((l) => l == null)
        ? const {}
        : {
            for (final k in SimklKind.values)
              if (k == SimklKind.anime)
                k: SimklKindProfile.of(list, watch)
              else if (otherLists[k] case final l?)
                k: SimklKindProfile.of(l, watchByKind[k]),
          },
  );
}

/// The signed-in user's Simkl profile: header, key numbers, a bar per list status, the score
/// distribution and the latest activity. Simkl has no manga, friends or clubs to show.
class SimklProfileView extends StatefulWidget {
  /// Shows a back button (when the profile is pushed as a page).
  final bool showBack;

  /// Test hook: replaces the loader.
  final Future<SimklProfileData> Function({bool force})? loader;

  const SimklProfileView({super.key, this.showBack = false, this.loader});

  @override
  State<SimklProfileView> createState() => _SimklProfileViewState();
}

class _SimklProfileViewState extends State<SimklProfileView> {
  late Future<SimklProfileData> _future = _load();

  Future<SimklProfileData> _load({bool force = false}) =>
      (widget.loader ?? ({bool force = false}) => loadSimklProfile(force: force))(force: force);

  Future<void> _refresh() async {
    final next = _load(force: true);
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<SimklProfileData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _ProfileError(error: snapshot.error!, onRetry: _refresh);
        final data = snapshot.data;
        if (data == null) return ProfileLoading(label: S.of(context).Prof_Loading);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: _ProfileBody(data: data, showBack: widget.showBack),
        );
      },
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(bottom: false, child: body),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ProfileError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (error is SimklSessionExpired) {
      return ProfileMessage(
        icon: Icons.lock_outline_rounded,
        title: s.Sk_Session_Expired,
        body: s.Sk_Session_Expired_Hint,
        actionLabel: s.Sk_Sign_In_Again,
        onAction: () => AppRoutes.signInAgain(context, AccountType.simkl),
      );
    }
    return ProfileMessage(
      icon: Icons.cloud_off_outlined,
      title: s.Prof_Error_Title,
      body: s.Prof_Error_Body,
      actionLabel: s.Prof_Retry,
      onAction: onRetry,
    );
  }
}

class _ProfileBody extends StatefulWidget {
  final SimklProfileData data;
  final bool showBack;

  const _ProfileBody({required this.data, required this.showBack});

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  /// The catalogue shown, the one picked on the home and Explore tabs at first.
  late SimklKind _kind =
      widget.data.byKind.containsKey(SimklCatalogue.instance.value) ? SimklCatalogue.instance.value : SimklKind.anime;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final showBack = widget.showBack;
    final s = S.of(context);
    final kind = data.byKind.isEmpty ? SimklKind.anime : _kind;
    final part = data.of(kind);
    final stats = part.stats;
    final movies = kind == SimklKind.movie;
    final colors = themedStatusChartColors(
      AppColors.of(context),
      context.select((PreferencesBloc bloc) => bloc.state.general.statsChartColors),
    );
    final labels = [
      s.Prof_Status_Watching,
      s.Prof_Status_Completed,
      s.Prof_Status_On_Hold,
      s.Prof_Status_Dropped,
      s.Prof_Status_Plan_Watch,
    ];
    final number = NumberFormat.decimalPattern();
    final watch = part.watch;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _Header(data: data, showBack: showBack)),
        if (data.byKind.length > 1)
          SliverToBoxAdapter(
            child: SimklKindSwitch(value: kind, onChanged: (k) => setState(() => _kind = k)),
          ),
        // Simkl's unit is time: watch time, what is left and the last seven days come first.
        if (watch != null && !watch.isEmpty) SliverToBoxAdapter(child: _TimeBlock(watch: watch, movies: movies)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(child: _StatTile(label: s.Prof_Entries_Label, value: number.format(stats.entries))),
                const SizedBox(width: 8),
                // A movie has no episodes: the completed ones are the movies watched.
                Expanded(
                  child: movies
                      ? _StatTile(
                          label: s.Skm_Movies_Watched,
                          value: number.format(stats.byStatus[ListEntryStatus.completed] ?? 0),
                        )
                      : _StatTile(label: s.Prof_Episodes_Label, value: number.format(stats.episodesWatched)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: s.Prof_Mean_Score,
                    value: stats.meanScore == null ? '-' : stats.meanScore!.toStringAsFixed(2),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (stats.entries == 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                s.Sk_Profile_Empty,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: _StatusBreakdown(
              title: data.byKind.isEmpty ? s.Prof_Chart_Anime_Title : simklKindLabel(kind),
              counts: [for (final status in SimklListStats.statusOrder) stats.byStatus[status] ?? 0],
              episodes:
                  movies ? null : [for (final status in SimklListStats.statusOrder) part.episodesByStatus[status] ?? 0],
              labels: labels,
              colors: colors,
            ),
          ),
          if (stats.scoreByStatus.isNotEmpty)
            SliverToBoxAdapter(
              child: ChartCard(
                title: s.Prof_Score_Dist,
                subtitle: s.Sk_Profile_Rated(stats.scored),
                child: ScoreStackChart(scoreByStatus: stats.scoreByStatus, labels: labels, colors: colors),
              ),
            ),
          if (part.topRated.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionTitle(s.Skp_Top_Rated)),
            SliverToBoxAdapter(child: _TopRatedRow(entries: part.topRated)),
          ],
          if (data.lists.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionTitle(s.Skp_Lists)),
            SliverList.builder(
              itemCount: data.lists.length,
              itemBuilder: (context, i) => _CustomListTile(list: data.lists[i]),
            ),
          ],
          if (stats.recent.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionTitle(s.Sk_Profile_Recent)),
            SliverList.builder(
              itemCount: stats.recent.length,
              itemBuilder: (context, i) => _RecentTile(entry: stats.recent[i]),
            ),
          ],
        ],
        SliverToBoxAdapter(
          child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final SimklProfileData data;
  final bool showBack;

  const _Header({required this.data, required this.showBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final user = UserSimklV2.instance;
    final account = data.account;
    final name = (account?.name.isNotEmpty ?? false) ? account!.name : (user.username ?? '');
    final picture = (account?.avatar.isNotEmpty ?? false) ? account!.avatar : user.profileImage;
    final joined = account?.joinedAt == null ? null : DateFormat.yMMM().format(account!.joinedAt!.toLocal());
    final details = [
      if (joined != null) s.Prof_Joined(joined),
      if (account != null && account.location.isNotEmpty) account.location,
    ].join(' · ');
    final accountId = account?.accountId ?? 0;
    final cover = data.nowWatching;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack) const BackButton(),
              const Spacer(),
              if (accountId > 0)
                IconButton(
                  tooltip: s.Sk_Open_On_Simkl,
                  onPressed: () => launchWebView('https://simkl.com/$accountId/', context: context),
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ClipOval(
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: (picture == null || picture.isEmpty)
                        ? SizedBox.square(
                            dimension: 72,
                            child: Icon(Icons.person_rounded, size: 40, color: scheme.onSurfaceVariant),
                          )
                        : AppImage(url: picture, width: 72, height: 72),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: theme.textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          if (account != null && simklIsPaid(account.accountType)) ...[
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                child: Text(
                                  account.accountType.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (details.isNotEmpty)
                        Text(
                          details,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (account != null && account.bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Text(account.bio, style: theme.textTheme.bodyMedium),
            ),
          if (cover != null && cover.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
              child: _NowWatchingCard(cover: cover),
            ),
        ],
      ),
    );
    if (cover == null) return header;
    // The cover of what the user watches now, faded into the page (plain alpha gradient, no blur).
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(child: _Cover(url: cover.coverUrl, fade: theme.scaffoldBackgroundColor)),
        ),
        header,
      ],
    );
  }
}

/// A picture fading to [fade] at the bottom (alpha gradient over the picture).
class _Cover extends StatelessWidget {
  final String url;
  final Color fade;

  const _Cover({required this.url, required this.fade});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppImage(url: url, width: 600, height: 240, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fade.withValues(alpha: 0.55), fade.withValues(alpha: 0.85), fade],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      );
}

class _TopRatedRow extends StatelessWidget {
  final List<ListEntryView> entries;

  const _TopRatedRow({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => openSimklTitle(
                context,
                simklId: e.id,
                kind: SimklKind.ofCategory(e.category),
                title: e.title,
                posterUrl: e.imageUrl,
              ),
              child: SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppImage(
                      url: e.imageUrl,
                      width: 100,
                      height: 142,
                      borderRadius: BorderRadius.circular(8),
                      placeholderColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 4),
                    Text('★ ${e.score}  ${e.title}',
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomListTile extends StatelessWidget {
  final SimklCustomList list;

  const _CustomListTile({required this.list});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.list_alt_rounded),
        title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: list.count > 0 ? Text('${list.count}') : null,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ListItemsSheet(list: list),
        ),
      );
}

class _ListItemsSheet extends StatelessWidget {
  final SimklCustomList list;

  const _ListItemsSheet({required this.list});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: FutureBuilder<List<SimklMedia>>(
        future: SimklStatsService.instance.listItems(list.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <SimklMedia>[];
          if (snapshot.hasError || items.isEmpty) {
            return Center(child: Icon(Icons.inbox_outlined, color: theme.colorScheme.onSurfaceVariant));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(
              leading: AppImage(
                url: items[i].posterUrl,
                width: 40,
                height: 56,
                borderRadius: BorderRadius.circular(6),
                placeholderColor: theme.colorScheme.surfaceContainerHighest,
              ),
              title: Text(items[i].title, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => openSimklMedia(context, items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            Text(value, style: theme.textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final ListEntryView entry;

  const _RecentTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = entry.status;
    final subtitle = [
      if (status != null) status.label(isAnime: true),
      if (entry.category != 'movie') entry.total > 0 ? '${entry.progress} / ${entry.total}' : '${entry.progress}',
      if (entry.score > 0) '★ ${entry.score}',
    ].join(' · ');
    return ListTile(
      leading: AppImage(
        url: entry.imageUrl,
        width: 40,
        height: 56,
        borderRadius: BorderRadius.circular(6),
        placeholderColor: theme.colorScheme.surfaceContainerHighest,
      ),
      title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      onTap: () {
        openSimklTitle(
          context,
          simklId: entry.id,
          kind: SimklKind.ofCategory(entry.category),
          title: entry.title,
          posterUrl: entry.imageUrl,
        );
      },
    );
  }
}

/// "Now watching": the last title the user watched, on the header (tap = its Simkl page).
class _NowWatchingCard extends StatelessWidget {
  final SimklNowWatching cover;

  const _NowWatchingCard({required this.cover});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final id = cover.simklId;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: id == null
            ? null
            : () =>
                openSimklTitle(context, simklId: id, kind: cover.kind, title: cover.title, posterUrl: cover.posterUrl),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              AppImage(
                url: cover.posterUrl,
                width: 36,
                height: 54,
                borderRadius: BorderRadius.circular(6),
                placeholderColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.of(context).Skr_Now_Watching,
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary)),
                    Text(cover.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
              if (id != null) Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Watch time (big), what is left to watch (episodes and time) and the last seven days.
class _TimeBlock extends StatelessWidget {
  final SimklWatchStats watch;

  /// Movies: what is left is the planned movies (no episodes).
  final bool movies;

  const _TimeBlock({required this.watch, this.movies = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    Widget cell(String label, String value, [String? extra]) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              Text(value, style: theme.textTheme.titleMedium),
              if (extra != null)
                Text(extra, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.Skr_Watch_Time, style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
              Text(simklDuration(watch.totalMins), style: theme.textTheme.displaySmall),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cell(
                    s.Skp_Left_To_Watch,
                    simklDuration(watch.leftMins),
                    watch.leftEpisodes > 0 && !movies ? s.Skr_Episodes_Left(watch.leftEpisodes) : null,
                  ),
                  const SizedBox(width: 12),
                  cell(s.Last_Week, simklDuration(watch.lastWeekMins)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entries per list status as one stacked bar, then a row per status: count and episodes.
class _StatusBreakdown extends StatelessWidget {
  final String title;
  final List<int> counts;

  /// Null for movies: no episodes, and only the statuses a movie can have.
  final List<int>? episodes;
  final List<String> labels;
  final List<Color> colors;

  const _StatusBreakdown({
    required this.title,
    required this.counts,
    required this.episodes,
    required this.labels,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = counts.fold<int>(0, (a, b) => a + b);
    return ChartCard(
      title: title,
      child: Column(
        children: [
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(children: [
                  for (var i = 0; i < counts.length; i++)
                    if (counts[i] > 0) Expanded(flex: counts[i], child: ColoredBox(color: colors[i % colors.length])),
                ]),
              ),
            ),
          const SizedBox(height: 10),
          for (var i = 0; i < counts.length; i++)
            if (episodes != null || counts[i] > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: colors[i % colors.length]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(labels[i], style: theme.textTheme.bodyMedium)),
                    if ((episodes?[i] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          S.current.Smp_Episodes_Short(episodes![i]),
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    Text(SimklFormat.count(counts[i]), style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
