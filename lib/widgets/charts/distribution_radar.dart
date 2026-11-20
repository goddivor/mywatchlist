import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One shape of a [DistributionRadar]: a colour and one value per axis.
class RadarSeries {
  final Color color;
  final List<double> values;
  const RadarSeries(this.color, this.values);
}

/// A radar chart of a breakdown (genres, media types, sources, studios), DailyAL's view:
/// one axis per item, one shape per series (a list status, or a single one). Needs at least
/// 3 axes; every series has one value per axis.
class DistributionRadar extends StatelessWidget {
  /// Most axes drawn: past this the labels overlap on a phone.
  static const int maxAxes = 8;

  /// Fewest axes a radar can draw.
  static const int minAxes = 3;

  final List<String> axes;
  final List<RadarSeries> series;

  const DistributionRadar({super.key, required this.axes, required this.series})
      : assert(axes.length >= minAxes);

  static String _short(String label) =>
      label.length <= 14 ? label : '${label.substring(0, 13).trimRight()}…';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grid = BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6));
    return Semantics(
      label: axes.join(', '),
      child: AspectRatio(
        aspectRatio: 1.1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              // Zero at the centre: a small status stays small instead of sitting on a ring.
              isMinValueAtCenter: true,
              radarBorderData: grid,
              gridBorderData: grid,
              tickBorderData: grid,
              tickCount: 3,
              ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
              titlePositionPercentageOffset: 0.12,
              titleTextStyle: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurface),
              getTitle: (index, angle) => RadarChartTitle(text: _short(axes[index])),
              radarTouchData: RadarTouchData(enabled: false),
              dataSets: [
                for (final s in series)
                  RadarDataSet(
                    fillColor: s.color.withValues(alpha: 0.18),
                    borderColor: s.color,
                    borderWidth: 2,
                    entryRadius: 2.5,
                    dataEntries: [for (final v in s.values) RadarEntry(value: v)],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
