import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show loadingGraph;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/content_stats_source.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_statistics.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

/// Score distribution of a title (1 to 10): Jikan `statistics`, else MAL's
/// stats page through the mwl-api ([ContentStatsSource]).
///
/// MAL's official API has no distribution, so when both fail the section
/// shows the score figures MAL does give ([mal]: mean, scored by, rank,
/// popularity, members) with a note and a Retry. No votes at all shows an
/// empty state, never grey bars.
class ScoreStatisticsWidget extends StatefulWidget {
  final int id;
  final String category;
  final double horizPadding;

  /// MAL details of the title, for the fallback figures.
  final MalAnime? mal;

  const ScoreStatisticsWidget({
    super.key,
    required this.id,
    required this.category,
    required this.horizPadding,
    this.mal,
  });

  @override
  State<ScoreStatisticsWidget> createState() => _ScoreStatisticsWidgetState();
}

class _ScoreStatisticsWidgetState extends State<ScoreStatisticsWidget>
    with AutomaticKeepAliveClientMixin {
  late Future<ContentStats> _future = _fetch();

  Future<ContentStats> _fetch() => ContentStatsSource.load(widget.id, widget.category);

  void _retry() => setState(() {
        _future = _fetch();
      });

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<ContentStats>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _MalScoreFallback(
            mal: widget.mal,
            horizPadding: widget.horizPadding,
            onRetry: _retry,
          );
        }
        final data = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done || data == null) {
          return SizedBox(height: 230, child: loadingGraph(context));
        }
        if (data.totalVotes == 0) {
          return SectionMessage(icon: Icons.bar_chart, message: S.current.Res_Score_Empty);
        }
        return ScoreBars(
          scores: data.sortedScores,
          horizPadding: widget.horizPadding,
          fromMyAnimeList: data.source == StatsSource.myAnimeList,
        );
      },
    );
  }
}

/// Ten bars (one per score) sized to the widest one, in the theme accent;
/// percent above, score and vote count below. Fits the width, no scrolling.
class ScoreBars extends StatelessWidget {
  final List<ScoreStatistics> scores;
  final double horizPadding;

  /// The figures come from MAL's stats page (Jikan failed): says so under the bars.
  final bool fromMyAnimeList;

  const ScoreBars({
    super.key,
    required this.scores,
    required this.horizPadding,
    this.fromMyAnimeList = false,
  });

  static const double _maxBarHeight = 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final compact = NumberFormat.compact(locale: locale);
    final percentFormat = NumberFormat.decimalPercentPattern(locale: locale, decimalDigits: 1);
    final maxVotes = scores.fold<int>(1, (m, s) => (s.votes ?? 0) > m ? s.votes! : m);
    final total = scores.fold<int>(0, (sum, s) => sum + (s.votes ?? 0));
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizPadding + 10),
      child: Column(
        children: [
          SizedBox(
            height: _maxBarHeight + 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final s in scores)
                  Expanded(
                    child: _bar(
                      context,
                      s,
                      maxVotes: maxVotes,
                      total: total,
                      compact: compact,
                      percentFormat: percentFormat,
                      small: small,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            S.current.Res_Score_Total_Votes(compact.format(total)),
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (fromMyAnimeList) ...[
            const SizedBox(height: 4),
            Text(S.current.Res_Source_Mal, style: small),
          ],
        ],
      ),
    );
  }

  Widget _bar(
    BuildContext context,
    ScoreStatistics s, {
    required int maxVotes,
    required int total,
    required NumberFormat compact,
    required NumberFormat percentFormat,
    required TextStyle? small,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final votes = s.votes ?? 0;
    final ratio = total == 0 ? 0.0 : votes / total;
    final percent = percentFormat.format(s.percentage != null ? s.percentage! / 100 : ratio);
    final height = (votes / maxVotes * _maxBarHeight).clamp(2.0, _maxBarHeight);
    return Semantics(
      label: S.current.Res_Score_Votes_Semantics('${s.score}', compact.format(votes), percent),
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(percent, style: small, maxLines: 1)),
          const SizedBox(height: 4),
          Container(
            height: height,
            width: 18,
            decoration: BoxDecoration(
              // Stronger accent for the most voted score, softer for the rest.
              color: votes == maxVotes ? scheme.primary : scheme.primary.withValues(alpha: 0.55),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${s.score}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(compact.format(votes), style: small, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

/// What MAL gives about the score when Jikan cannot be reached.
class _MalScoreFallback extends StatelessWidget {
  final MalAnime? mal;
  final double horizPadding;
  final VoidCallback onRetry;

  const _MalScoreFallback({required this.mal, required this.horizPadding, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final m = mal;
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat.decimalPattern(locale);
    final mean = m?.mean;
    final figures = <(String, String)>[
      if (mean != null && mean > 0)
        (S.current.Res_Mean_Score, NumberFormat('0.00', locale).format(mean)),
      if ((m?.numScoringUsers ?? 0) > 0) (S.current.Res_Scored_By, number.format(m!.numScoringUsers)),
      if ((m?.rank ?? 0) > 0) (S.current.Res_Ranked, '#${number.format(m!.rank)}'),
      if ((m?.popularity ?? 0) > 0) (S.current.Res_Popularity, '#${number.format(m!.popularity)}'),
      if ((m?.numListUsers ?? 0) > 0) (S.current.Res_Members, number.format(m!.numListUsers)),
    ];
    if (figures.isEmpty) {
      return SectionMessage.error(message: S.current.Res_Score_Unavailable, onRetry: onRetry);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizPadding + 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, value) in figures)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            S.current.Res_Source_Mal,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SectionMessage.error(
            height: 120,
            message: S.current.Res_Score_Unavailable,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}
