import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';

/// The activity heatmap: one square per day over the last weeks (columns are weeks, rows
/// Monday to Sunday), darker the busier the day, as anilist.co draws it.
class AnilistHeatmap extends StatelessWidget {
  final List<AnilistActivityDay> days;
  final Color color;

  /// The last day shown; today by default.
  final DateTime? today;

  const AnilistHeatmap({super.key, required this.days, required this.color, this.today});

  static const double _cell = 11;
  static const double _gap = 3;

  static DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final byDay = <DateTime, int>{for (final d in days) _day(d.date): d.level};
    final total = days.fold<int>(0, (a, d) => a + d.amount);
    return Semantics(
      label: S.of(context).Alpp_Heatmap_Summary(total),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final weeks = ((constraints.maxWidth + _gap) ~/ (_cell + _gap)).clamp(8, 53);
            return SizedBox(
              height: 7 * (_cell + _gap) - _gap,
              width: constraints.maxWidth,
              child: CustomPaint(
                painter: _HeatmapPainter(
                  byDay: byDay,
                  weeks: weeks,
                  last: _day(today ?? DateTime.now().toUtc()),
                  color: color,
                  empty: cs.surfaceContainerHighest,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Map<DateTime, int> byDay;
  final int weeks;
  final DateTime last;
  final Color color;
  final Color empty;

  _HeatmapPainter({
    required this.byDay,
    required this.weeks,
    required this.last,
    required this.color,
    required this.empty,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cell = AnilistHeatmap._cell;
    const gap = AnilistHeatmap._gap;
    // The last column ends on the week of [last]; Monday = row 0.
    final lastMonday = last.subtract(Duration(days: last.weekday - 1));
    final paint = Paint();
    for (var w = 0; w < weeks; w++) {
      final monday = lastMonday.subtract(Duration(days: 7 * (weeks - 1 - w)));
      for (var r = 0; r < 7; r++) {
        final day = monday.add(Duration(days: r));
        if (day.isAfter(last)) continue;
        final level = byDay[day] ?? 0;
        paint.color = level <= 0
            ? empty
            : color.withValues(alpha: (0.3 + 0.07 * level).clamp(0.3, 1.0));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * (cell + gap), r * (cell + gap), cell, cell),
            const Radius.circular(2.5),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.byDay != byDay ||
      old.weeks != weeks ||
      old.last != last ||
      old.color != color ||
      old.empty != empty;
}
