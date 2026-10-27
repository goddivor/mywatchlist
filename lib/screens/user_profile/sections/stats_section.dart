import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/character_screen.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/screens/user_profile/user_insights.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/services/api/MAL/user_anime_statistics.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/charts/chart_card.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/charts/ranked_bar_list.dart';
import 'package:mywatchlist/widgets/charts/score_stack_chart.dart';
import 'package:mywatchlist/widgets/charts/status_bar_chart.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';
import 'package:mywatchlist/widgets/user/profile/profile_header.dart';

/// The Stats tab: key numbers, the list status chart, and (loaded in the background) the
/// charts computed from the whole list. Anime and manga switch without leaving the tab.
class StatsSection extends StatefulWidget {
  final UserProfileData data;
  final bool isSelf;

  /// Asks Jikan again when the manga numbers could not be loaded.
  final VoidCallback? onRetryExtras;

  const StatsSection({super.key, required this.data, required this.isSelf, this.onRetryExtras});

  @override
  State<StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<StatsSection> with AutomaticKeepAliveClientMixin {
  String _category = 'anime';
  final Map<String, Future<UserInsights>> _insights = {};

  @override
  bool get wantKeepAlive => true;

  Future<UserInsights> _insightsFor(String category) => _insights.putIfAbsent(
        category,
        () => UserInsightsLoader.load(widget.data.username, category),
      );

  void _retryInsights() => setState(() => _insights.remove(_category));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final manga = _category == 'manga';
    final stats = manga ? widget.data.manga : widget.data.anime;
    final colors = themedStatusChartColors(
      AppColors.of(context),
      context.select((PreferencesBloc bloc) => bloc.state.general.statsChartColors),
    );
    // Manga numbers come from Jikan only: say they are coming (or failed) instead of "empty".
    final extras = widget.data.extras;
    final waitingForJikan = manga && stats.isEmpty && extras != ProfileExtras.ready;

    return ProfileTabScroll(
      storageKey: 'stats_${widget.data.username}',
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
              onSelectionChanged: (value) => setState(() => _category = value.first),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _SummaryCard(data: widget.data, stats: stats, manga: manga)),
        if (waitingForJikan)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: extras == ProfileExtras.loading
                  ? ProfileLoading(label: s.Pp_Extras_Loading)
                  : ProfileMessage(
                      icon: Icons.cloud_off_outlined,
                      title: s.Pp_Extras_Unavailable,
                      actionLabel: widget.onRetryExtras == null ? null : s.Prof_Retry,
                      onAction: widget.onRetryExtras,
                    ),
            ),
          )
        else if (stats.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                s.Prof_Dist_Empty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: _StatusCard(
              stats: stats,
              manga: manga,
              colors: colors,
              animeDays: widget.data.animeDays,
              // The per-status days exist for the signed-in user only.
              key: ValueKey('status_$_category'),
            ),
          ),
        FutureBuilder<UserInsights>(
          key: ValueKey('insights_$_category'),
          future: _insightsFor(_category),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SliverToBoxAdapter(
                child: ChartCard(
                  title: s.Prof_Score_Dist,
                  child: SizedBox(
                    height: 160,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 12),
                          Text(s.Prof_Insights_Loading),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              final expired = snapshot.error is MalSessionExpired;
              return SliverToBoxAdapter(
                child: ChartCard(
                  title: s.Prof_Score_Dist,
                  child: Column(
                    children: [
                      Text(
                        expired ? s.Prof_Session_Expired_Body : s.Prof_Insights_Error,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed:
                            expired ? () => AppRoutes.signInAgain(context, _mal) : _retryInsights,
                        child: Text(expired ? s.Prof_Sign_In : s.Prof_Retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return _InsightsSlivers(
              insights: snapshot.data!,
              category: _category,
              colors: colors,
            );
          },
        ),
      ],
    );
  }

  static const _mal = AccountType.myanimelist;
}

String _number(num value, {int digits = 0}) => profileNumber(value, digits: digits);

List<String> statusLabels(String category, S s) => [
      category == 'manga' ? s.Prof_Status_Reading : s.Prof_Status_Watching,
      s.Prof_Status_Completed,
      s.Prof_Status_On_Hold,
      s.Prof_Status_Dropped,
      category == 'manga' ? s.Prof_Status_Plan_Read : s.Prof_Status_Plan_Watch,
    ];

/// The key numbers on one flat card (no tile inside the card): value in large, label under
/// it, the mean score with the score colour; then the user's details.
class _SummaryCard extends StatelessWidget {
  final UserProfileData data;
  final ListStats stats;
  final bool manga;

  const _SummaryCard({required this.data, required this.stats, required this.manga});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tokens = AppColors.of(context);
    final hasMean = (stats.meanScore ?? 0) > 0;
    final tiles = <(String, String, Color?)>[
      (s.Prof_Mean_Score, profileMean(stats.meanScore), hasMean ? tokens.score.color : null),
      (s.Prof_Entries_Label, _number(stats.totalEntries), null),
      (
        s.Prof_Days_Label,
        stats.days == null ? s.Pp_No_Value : _number(stats.days!, digits: 1),
        null,
      ),
      (manga ? s.Prof_Chapters_Label : s.Prof_Episodes_Label, _number(stats.progress), null),
      if (manga) (s.Prof_Volumes_Label, _number(stats.volumes), null),
    ];
    final birthday = formatProfileDate(data.birthday);
    final info = <(IconData, String, String)>[
      if (data.gender != null)
        (Icons.person_outline, s.Prof_Gender, profileGenderLabel(data.gender!)),
      if (data.location != null) (Icons.place_outlined, s.Prof_Location, data.location!),
      if (birthday != null) (Icons.cake_outlined, s.Prof_Birthday, birthday),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
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
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            if (info.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: cs.outlineVariant),
              ),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final (icon, label, value) in info)
                    Semantics(
                      label: label,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Flexible(child: Text(value, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatefulWidget {
  final ListStats stats;
  final bool manga;
  final List<Color> colors;
  final List<double?> animeDays;

  const _StatusCard({
    super.key,
    required this.stats,
    required this.manga,
    required this.colors,
    required this.animeDays,
  });

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  bool _byDays = false;

  bool get _hasDays => !widget.manga && widget.animeDays.any((d) => (d ?? 0) > 0);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final labels = statusLabels(widget.manga ? 'manga' : 'anime', s);
    final byDays = _byDays && _hasDays;
    // Days exist for the four statuses that have watching time, not for "plan to watch".
    final slots = byDays ? 4 : 5;
    final values = byDays
        ? [for (var i = 0; i < 4; i++) widget.animeDays.elementAtOrNull(i) ?? 0.0]
        : [for (final c in widget.stats.statusCounts) c.toDouble()];

    return ChartCard(
      title: widget.manga ? s.Prof_Chart_Manga_Title : s.Prof_Chart_Anime_Title,
      actions: [
        if (_hasDays)
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(value: false, label: Text(s.Prof_Chart_By_Entries)),
              ButtonSegment(value: true, label: Text(s.Prof_Chart_By_Days)),
            ],
            selected: {byDays},
            onSelectionChanged: (v) => setState(() => _byDays = v.first),
          ),
      ],
      footer: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (var i = 0; i < slots; i++)
            LegendDot(
              color: widget.colors[i],
              label:
                  '${labels[i]} · ${byDays ? s.Prof_Days_Count(_number(values[i], digits: 1)) : _number(values[i])}',
            ),
        ],
      ),
      child: StatusBarChart(
        values: values,
        labels: labels.take(slots).toList(),
        colors: widget.colors.take(slots).toList(),
        formatValue: byDays ? (v) => _number(v, digits: 1) : null,
      ),
    );
  }
}

class _InsightsSlivers extends StatelessWidget {
  final UserInsights insights;
  final String category;
  final List<Color> colors;

  const _InsightsSlivers({
    required this.insights,
    required this.category,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final manga = category == 'manga';
    final labels = statusLabels(category, s);
    final statusKeys = insights.statuses;
    final hasScores = insights.scoreByStatus.values.any((c) => c.any((n) => n > 0));
    final primary = Theme.of(context).colorScheme.primary;

    Widget distribution(InsightKind kind, String title, {void Function(DistributionItem)? onTap}) {
      return _DistributionCard(
        insights: insights,
        kind: kind,
        title: title,
        statusKeys: statusKeys,
        statusLabels: labels,
        color: primary,
        onItemTap: onTap,
      );
    }

    final children = <Widget>[
      if (hasScores)
        ChartCard(
          title: s.Prof_Score_Dist,
          subtitle: insights.unrated > 0 ? s.Prof_Unrated_Count(insights.unrated) : null,
          footer: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (var i = 0; i < labels.length; i++) LegendDot(color: colors[i], label: labels[i]),
            ],
          ),
          child: ScoreStackChart(
            scoreByStatus: insights.scoreByStatus,
            labels: labels,
            colors: colors,
          ),
        ),
      if (insights.aboveMean.isNotEmpty)
        _AboveMeanShelf(entries: insights.aboveMean, category: category),
      if (hasScores) ...[
        distribution(InsightKind.genre, s.Prof_Dist_Genres),
        distribution(InsightKind.mediaType, s.Prof_Dist_Media),
        if (!manga) distribution(InsightKind.source, s.Prof_Dist_Sources),
        if (manga)
          distribution(
            InsightKind.author,
            s.Prof_Dist_Authors,
            onTap: (item) {
              if (item.id != 0) {
                gotoPage(
                  context: context,
                  newPage: CharacterScreen(id: item.id, category: 'person'),
                );
              }
            },
          )
        else
          distribution(InsightKind.studio, s.Prof_Dist_Studios),
      ] else
        ChartCard(
          title: s.Prof_Score_Dist,
          child: Text(s.Prof_Dist_Empty),
        ),
    ];

    return SliverList.builder(
      itemCount: children.length,
      itemBuilder: (context, i) => children[i],
    );
  }
}

class _DistributionCard extends StatefulWidget {
  final UserInsights insights;
  final InsightKind kind;
  final String title;
  final List<String> statusKeys;
  final List<String> statusLabels;
  final Color color;
  final void Function(DistributionItem item)? onItemTap;

  const _DistributionCard({
    required this.insights,
    required this.kind,
    required this.title,
    required this.statusKeys,
    required this.statusLabels,
    required this.color,
    this.onItemTap,
  });

  @override
  State<_DistributionCard> createState() => _DistributionCardState();
}

class _DistributionCardState extends State<_DistributionCard> {
  String? _status;
  bool _byMean = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final items = widget.insights.items(widget.kind, status: _status, byMean: _byMean);
    final onTap = widget.onItemTap;

    return ChartCard(
      title: widget.title,
      subtitle: s.Prof_Dist_Scored_Only,
      actions: [
        PopupMenuButton<bool>(
          tooltip: _byMean ? s.Prof_Dist_Sort_Mean : s.Prof_Dist_Sort_Count,
          icon: const Icon(Icons.sort),
          initialValue: _byMean,
          onSelected: (value) => setState(() => _byMean = value),
          itemBuilder: (_) => [
            PopupMenuItem(value: false, child: Text(s.Prof_Dist_Sort_Count)),
            PopupMenuItem(value: true, child: Text(s.Prof_Dist_Sort_Mean)),
          ],
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(s.Prof_Dist_All, null),
                for (var i = 0; i < widget.statusKeys.length; i++)
                  _chip(widget.statusLabels[i], widget.statusKeys[i]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(s.Prof_Dist_Empty),
            )
          else
            RankedBarList(
              key: ValueKey('${widget.kind.name}_${_status}_$_byMean'),
              color: widget.color,
              items: [
                for (final item in items)
                  RankedBarItem(
                    label: _label(item.name),
                    count: item.count,
                    mean: item.mean,
                    onTap: onTap == null ? null : () => onTap(item),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? status) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _status == status,
        onSelected: (_) => setState(() => _status = status),
      ),
    );
  }

  /// MAL media types and sources are API values ("light_novel"): show them translated.
  String _label(String name) => switch (widget.kind) {
        InsightKind.mediaType => profileMediaTypeLabel(name),
        InsightKind.source => profileSourceLabel(name),
        _ => name,
      };
}

class _AboveMeanShelf extends StatelessWidget {
  final List<AboveMeanEntry> entries;
  final String category;

  static const double _cardWidth = 104;
  static const double _imageHeight = 148;

  const _AboveMeanShelf({required this.entries, required this.category});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(s.Prof_Above_Mean, style: theme.textTheme.titleMedium),
        ),
        SizedBox(
          height: _imageHeight + 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              return SizedBox(
                width: _cardWidth + 8,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => AppRoutes.openContent(context, id: entry.id, category: category),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppImage(
                          url: entry.pictureUrl,
                          width: _cardWidth,
                          height: _imageHeight,
                          borderRadius: BorderRadius.circular(10),
                          placeholderColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                        Text(
                          s.Prof_Score_Compare(
                            '${entry.score}',
                            _number(entry.mean, digits: 2),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
