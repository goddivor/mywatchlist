import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/widgets/charts/chart_palette.dart';

/// One bar per list status. The tooltip (touch or long press) gives the share of the total.
///
/// [values], [labels] and [colors] have the same length. Stateless: fl_chart draws the
/// tooltip itself, so a touch never rebuilds the page.
class StatusBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final double height;

  /// Formats the number under each label and in the tooltip.
  final String Function(double value)? formatValue;

  const StatusBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.colors,
    this.height = 190,
    this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = NumberFormat.compact();
    String format(double v) => formatValue?.call(v) ?? compact.format(v);
    final total = values.fold<double>(0, (a, b) => a + b);
    final maxY = values.fold<double>(0, (a, b) => a > b ? a : b);
    final labelStyle = theme.textTheme.labelSmall;
    final background = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.05,
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              fitInsideHorizontally: true,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final share = total == 0
                    ? ''
                    : ' · ${NumberFormat.percentPattern().format(values[groupIndex] / total)}';
                return BarTooltipItem(
                  '${labels[groupIndex]}\n${format(values[groupIndex])}$share',
                  (theme.textTheme.labelMedium ?? const TextStyle())
                      .copyWith(color: theme.colorScheme.onInverseSurface),
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
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= values.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: Text(
                      format(values[i]),
                      style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: 26,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [colors[i], lighten(colors[i])],
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY == 0 ? 1 : maxY * 1.05,
                      color: background,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
