import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/screens/user_profile/sections/stats_section.dart' show statusLabels;
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart'
    show anilistMediaType;
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/profile/profile_ranked.dart';
import 'package:mywatchlist/widgets/charts/chart_card.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';
import 'package:mywatchlist/widgets/charts/ranked_bar_list.dart';
import 'package:mywatchlist/widgets/charts/score_stack_chart.dart';
import 'package:mywatchlist/widgets/charts/status_bar_chart.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/profile/profile_format.dart';

/// Stats tab: an Anime / Manga switch, then the sub-pages of anilist.co's statistics
/// (Overview, Genres, Tags, Voice actors, Staff, Studios). Each sub-page asks AniList the
/// first time it is shown.
class AnilistStatsTab extends StatefulWidget {
  final AnilistProfile profile;
  final AnilistProfileService? service;

  const AnilistStatsTab({super.key, required this.profile, this.service});

  @override
  State<AnilistStatsTab> createState() => _AnilistStatsTabState();
}

class _AnilistStatsTabState extends State<AnilistStatsTab> with AutomaticKeepAliveClientMixin {
  String _category = 'anime';
  AnilistStatsPart _part = AnilistStatsPart.overview;

  @override
  bool get wantKeepAlive => true;

  AnilistProfileService get _service => widget.service ?? AnilistProfileService.instance;

  String _partLabel(S s, AnilistStatsPart p) => switch (p) {
        AnilistStatsPart.overview => s.Alpp_Stats_Overview,
        AnilistStatsPart.genres => s.Prof_Dist_Genres,
        AnilistStatsPart.tags => s.Alpp_Stats_Tags,
        AnilistStatsPart.voiceActors => s.Alpp_Stats_Voice_Actors,
        AnilistStatsPart.staff => s.Alpp_Stats_Staff,
        AnilistStatsPart.studios => s.Prof_Dist_Studios,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final manga = _category == 'manga';
    final profile = widget.profile;
    final stats = manga ? profile.manga : profile.anime;
    return ProfileTabScroll(
      storageKey: 'al_stats_${profile.data.username}',
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
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final p in AnilistStatsPart.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(_partLabel(s, p)),
                      selected: _part == p,
                      onSelected: (_) => setState(() => _part = p),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (stats.list.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(s.Prof_Dist_Empty,
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            ),
          )
        else if (_part == AnilistStatsPart.overview) ...[
          SliverToBoxAdapter(child: _SummaryCard(stats: stats, manga: manga)),
          ..._overview(context, stats, manga),
        ] else
          SliverToBoxAdapter(
            child: AnilistRankedStats(
              key: ValueKey('${profile.data.username}/$_category/${_part.name}'),
              username: profile.data.username,
              category: _category,
              part: _part,
              service: widget.service,
            ),
          ),
      ],
    );
  }

  List<Widget> _overview(BuildContext context, AnilistCategoryStats stats, bool manga) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final list = stats.list;
    final colors = themedStatusChartColors(
      AppColors.of(context),
      context.select((PreferencesBloc bloc) => bloc.state.general.statsChartColors),
    );
    final labels = statusLabels(_category, s);
    final folded = foldScores(stats.rawScores, widget.profile.scoreFormat);
    final tens = !{'POINT_5', 'POINT_3'}.contains(widget.profile.scoreFormat);
    String scoreLabel(int bucket) => switch (widget.profile.scoreFormat) {
          'POINT_5' => '$bucket',
          'POINT_3' => switch (bucket) {
              1 => s.Alpp_Score_Bad,
              2 => s.Alpp_Score_Neutral,
              _ => s.Alpp_Score_Good,
            },
          _ => '$bucket',
        };
    return [
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
                    label: '${labels[i]} · ${profileNumber(list.statusCounts[i])}'),
            ],
          ),
          child: StatusBarChart(
            values: [for (final c in list.statusCounts) c.toDouble()],
            labels: labels,
            colors: colors,
          ),
        ),
      ),
      if (folded.any((b) => b.count > 0))
        SliverToBoxAdapter(
          child: ChartCard(
            title: s.Prof_Score_Dist,
            child: tens
                ? ScoreStackChart(
                    scoreByStatus: {for (final b in folded) b.bucket: [b.count]},
                    labels: [s.Prof_Score_Dist],
                    colors: [primary],
                  )
                : BarStrip(
                    color: primary,
                    items: [
                      for (final b in folded) AnilistStatCount(scoreLabel(b.bucket), b.count),
                    ],
                  ),
          ),
        ),
      SliverToBoxAdapter(
        child: _Lazy<AnilistStatsOverview>(
          key: ValueKey('${widget.profile.data.username}/$_category/overview'),
          load: () => _service.loadStatsOverview(widget.profile.data.username, _category),
          builder: (context, o) => Column(
            children: [
              if (o.lengths.isNotEmpty)
                ChartCard(
                  title: manga ? s.Alpp_Stats_Chapter_Count : s.Alpp_Stats_Episode_Count,
                  child: BarStrip(color: primary, items: o.lengths),
                ),
              if (o.releaseYears.isNotEmpty)
                ChartCard(
                    title: s.Alpp_Stats_Release_Year,
                    child: BarStrip(color: primary, items: o.releaseYears)),
              if (o.startYears.isNotEmpty)
                ChartCard(
                    title: s.Alpp_Stats_Start_Year,
                    child: BarStrip(color: primary, items: o.startYears)),
              if (o.countries.isNotEmpty)
                ChartCard(
                  title: s.Alpp_Stats_Countries,
                  child: RankedBarList(color: primary, items: [
                    for (final c in o.countries)
                      RankedBarItem(label: c.label, count: c.count, mean: c.mean),
                  ]),
                ),
            ],
          ),
        ),
      ),
      if (stats.formats.isNotEmpty)
        SliverToBoxAdapter(
          child: ChartCard(
            title: s.Prof_Dist_Media,
            child: RankedBarList(color: primary, items: [
              for (final f in stats.formats)
                RankedBarItem(
                  label: profileMediaTypeLabel(anilistMediaType(f.label) ?? f.label),
                  count: f.count,
                  mean: f.mean,
                ),
            ]),
          ),
        ),
    ];
  }
}

/// The key numbers on one flat card; the standard deviation and the planned time come with
/// the Overview request and appear when it answers.
class _SummaryCard extends StatefulWidget {
  final AnilistCategoryStats stats;
  final bool manga;

  const _SummaryCard({required this.stats, required this.manga});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final list = widget.stats.list;
    final manga = widget.manga;
    final hasMean = (list.meanScore ?? 0) > 0;
    final tiles = <(String, String, Color?)>[
      (s.Prof_Mean_Score, profileMean(list.meanScore),
          hasMean ? AppColors.of(context).score.color : null),
      (s.Prof_Entries_Label, profileNumber(list.totalEntries), null),
      if (!manga)
        (s.Prof_Days_Label,
            list.days == null ? s.Pp_No_Value : profileNumber(list.days!, digits: 1), null),
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
                        Text(value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700, color: color ?? cs.onSurface)),
                        const SizedBox(height: 2),
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
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

/// Loads one value when first built (quietly: nothing while loading, a Retry line on a
/// failure) and builds it.
class _Lazy<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T value) builder;

  const _Lazy({super.key, required this.load, required this.builder});

  @override
  State<_Lazy<T>> createState() => _LazyState<T>();
}

class _LazyState<T> extends State<_Lazy<T>> {
  late Future<T> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return widget.builder(context, snapshot.data as T);
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _future = widget.load()),
                icon: const Icon(Icons.refresh),
                label: Text(S.of(context).Prof_Retry),
              ),
            ),
          );
        }
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
        );
      },
    );
  }
}

/// A small bar chart of labelled buckets (years, lengths, 5-star scores), scrolling sideways
/// when there are many; the count is printed over each bar.
class BarStrip extends StatelessWidget {
  final List<AnilistStatCount> items;
  final Color color;
  final double height;

  const BarStrip({super.key, required this.items, required this.color, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = items.fold<int>(1, (a, b) => b.count > a ? b.count : a);
    final labelStyle =
        theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return SizedBox(
      height: height + 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return SizedBox(
            width: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(item.count == 0 ? '' : profileNumber(item.count), style: labelStyle),
                const SizedBox(height: 2),
                Container(
                  width: 22,
                  height: (height * item.count / max).clamp(item.count == 0 ? 0 : 3, height).toDouble(),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(item.label, maxLines: 1, style: labelStyle),
              ],
            ),
          );
        },
      ),
    );
  }
}
