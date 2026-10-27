import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Number of entries per score (1 to 10), each bar stacked by list status.
///
/// [scoreByStatus] maps a score to the counts of every status, in the order of [labels] and
/// [colors].
class ScoreStackChart extends StatelessWidget {
  final Map<int, List<int>> scoreByStatus;
  final List<String> labels;
  final List<Color> colors;
  final double height;

  const ScoreStackChart({
    super.key,
    required this.scoreByStatus,
    required this.labels,
    required this.colors,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = scoreByStatus.keys.toList()..sort();
    final totals = [for (final s in scores) scoreByStatus[s]!.fold<int>(0, (a, b) => a + b)];
    final maxY = totals.fold<int>(0, (a, b) => a > b ? a : b);
    final grandTotal = totals.fold<int>(0, (a, b) => a + b);
    final percent = NumberFormat.decimalPercentPattern(decimalDigits: 1);
    final number = NumberFormat.decimalPattern();

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.08,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final counts = scoreByStatus[scores[groupIndex]]!;
                final lines = <String>[
                  for (var i = 0; i < counts.length; i++)
                    if (counts[i] > 0) '${labels[i]}: ${number.format(counts[i])}',
                  if (grandTotal > 0 && totals[groupIndex] > 0)
                    percent.format(totals[groupIndex] / grandTotal),
                ];
                return BarTooltipItem(
                  lines.isEmpty ? '${scores[groupIndex]}' : lines.join('\n'),
                  (theme.textTheme.labelMedium ?? const TextStyle())
                      .copyWith(color: theme.colorScheme.onInverseSurface),
                  textAlign: TextAlign.start,
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= scores.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      '${scores[i]}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < scores.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: totals[i].toDouble(),
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    rodStackItems: _stack(scoreByStatus[scores[i]]!),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<BarChartRodStackItem> _stack(List<int> counts) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final to = from + counts[i];
      items.add(BarChartRodStackItem(from, to, colors[i]));
      from = to;
    }
    return items;
  }
}
