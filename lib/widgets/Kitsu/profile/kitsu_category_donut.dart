import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// The category breakdown of a Kitsu profile as a donut with the biggest category's share in the
/// middle, and a legend. Shows the [maxSlices] biggest categories and groups the rest as "Other".
class KitsuCategoryDonut extends StatelessWidget {
  final List<MapEntry<String, int>> items;
  final int maxSlices;

  const KitsuCategoryDonut({super.key, required this.items, this.maxSlices = 6});

  /// The slices drawn: the biggest [maxSlices] and, if any is left, the sum of the others.
  static List<MapEntry<String, int>> slices(List<MapEntry<String, int>> items, int maxSlices,
      String other) {
    final sorted = [...items]..sort((a, b) => b.value.compareTo(a.value));
    final head = sorted.take(maxSlices).toList();
    final rest = sorted.skip(maxSlices).fold<int>(0, (a, b) => a + b.value);
    return [...head, if (rest > 0) MapEntry(other, rest)];
  }

  /// Distinct slice colours derived from the theme's primary colour.
  static Color colorAt(ColorScheme scheme, int index) {
    final hsl = HSLColor.fromColor(scheme.primary);
    return hsl.withHue((hsl.hue + index * 47) % 360).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parts = slices(items, maxSlices, S.of(context).Kitsu_Categories_Other);
    final total = parts.fold<int>(0, (a, b) => a + b.value);
    if (total == 0) return const SizedBox.shrink();
    final colors = [for (var i = 0; i < parts.length; i++) colorAt(scheme, i)];
    final number = NumberFormat.decimalPattern();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(
              values: [for (final p in parts) p.value.toDouble()],
              colors: colors,
              track: scheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Text('${(parts.first.value * 100 / total).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < parts.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(parts[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium),
                      ),
                      Text(number.format(parts[i].value), style: theme.textTheme.labelLarge),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color track;

  _DonutPainter({required this.values, required this.colors, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    final total = values.fold<double>(0, (a, b) => a + b);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      paint.color = colors[i];
      canvas.drawArc(rect, start, math.max(sweep - 0.03, 0.01), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors || old.track != track;
}
