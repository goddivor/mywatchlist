import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart' show launchWebView;
import 'package:mywatchlist/widgets/charts/chart_card.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/charts/score_stack_chart.dart';
import 'package:mywatchlist/widgets/charts/status_bar_chart.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// What the Simkl profile shows: the account (name, picture, join date…) and the numbers
/// computed from the whole anime list.
class SimklProfileData {
  final UserProfSimkl? account;
  final SimklListStats stats;

  const SimklProfileData(this.account, this.stats);
}

/// Loads the Simkl profile. The account call may fail without hiding the stats (the name and
/// picture stored at sign-in are used then); the list is required.
Future<SimklProfileData> loadSimklProfile({
  SimklUser? user,
  SimklListService? lists,
  bool force = false,
}) async {
  final accountFuture = (user ?? SimklUser()).getUserInfo().then<UserProfSimkl?>((a) => a).catchError(
    (Object e) {
      // A dead session shows on the list call below; any other failure keeps the stored name.
      return null;
    },
  );
  final list = await (lists ?? SimklListService.instance).anime(force: force);
  final account = await accountFuture;
  return SimklProfileData(account, SimklListStats.from(list));
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

class _ProfileBody extends StatelessWidget {
  final SimklProfileData data;
  final bool showBack;

  const _ProfileBody({required this.data, required this.showBack});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final stats = data.stats;
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _Header(data: data, showBack: showBack)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(child: _StatTile(label: s.Prof_Entries_Label, value: number.format(stats.entries))),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(label: s.Prof_Episodes_Label, value: number.format(stats.episodesWatched)),
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
            child: ChartCard(
              title: s.Prof_Chart_Anime_Title,
              child: StatusBarChart(
                values: [for (final status in SimklListStats.statusOrder) (stats.byStatus[status] ?? 0).toDouble()],
                labels: labels,
                colors: colors,
                formatValue: (v) => number.format(v.round()),
              ),
              footer: Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < labels.length; i++) LegendDot(color: colors[i], label: labels[i]),
                ],
              ),
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
          if (stats.recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(s.Sk_Profile_Recent, style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            ),
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
    return Padding(
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
                      Text(name, style: theme.textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
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
        ],
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
      entry.total > 0 ? '${entry.progress} / ${entry.total}' : '${entry.progress}',
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
        final mal = entry.malId;
        if (mal != null) AppRoutes.openContent(context, id: mal, category: 'anime');
      },
    );
  }
}
