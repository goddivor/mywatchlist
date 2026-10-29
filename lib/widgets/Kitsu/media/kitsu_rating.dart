import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart' show KitsuCatalog, KitsuRatingSystem;
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// The user's own Kitsu rating (`ratingTwenty`, 2 to 20) in the rating system of the account,
/// as Kitsu shows it everywhere: Simple = four faces (awful, meh, good, great), Regular = stars
/// from 0.5 to 5 in half steps, Advanced = 1 to 10 in half points. The community score is never
/// shown this way: it stays Kitsu's percentage.
abstract final class KitsuRating {
  /// The account's system, Advanced while the account settings are unknown (the finest one, so
  /// nothing is rounded away).
  static KitsuRatingSystem get current => KitsuCatalog.instance.account?.ratingSystem ?? KitsuRatingSystem.advanced;

  /// Simple faces, worst first, with the `ratingTwenty` Kitsu stores for each.
  static const List<int> simpleSteps = [2, 8, 14, 20];

  /// Index of the face (0 awful … 3 great) that [twenty] falls in.
  static int simpleIndex(int twenty) {
    if (twenty <= 5) return 0;
    if (twenty <= 11) return 1;
    if (twenty <= 16) return 2;
    return 3;
  }

  static String simpleLabel(int index) => switch (index) {
        0 => S.current.Kr_Rating_Awful,
        1 => S.current.Kr_Rating_Meh,
        2 => S.current.Kr_Rating_Good,
        _ => S.current.Kr_Rating_Great,
      };

  static IconData simpleIcon(int index) => switch (index) {
        0 => Icons.sentiment_very_dissatisfied_rounded,
        1 => Icons.sentiment_neutral_rounded,
        2 => Icons.sentiment_satisfied_rounded,
        _ => Icons.sentiment_very_satisfied_rounded,
      };

  /// The value of [twenty] in [system] without its unit: `3.5` (stars), `7.5` (points) or the
  /// face's word.
  static String text(int twenty, KitsuRatingSystem system) {
    final t = twenty.clamp(2, 20);
    String half(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return switch (system) {
      KitsuRatingSystem.simple => simpleLabel(simpleIndex(t)),
      KitsuRatingSystem.regular => half(t / 4),
      KitsuRatingSystem.advanced => half(t / 2),
    };
  }

  /// What a screen reader says: "3.5 stars", "7.5 out of 10", "Good".
  static String spoken(int twenty, KitsuRatingSystem system) => switch (system) {
        KitsuRatingSystem.simple => text(twenty, system),
        KitsuRatingSystem.regular => S.current.Kr_Rating_Stars(text(twenty, system)),
        KitsuRatingSystem.advanced => S.current.Kr_Rating_Points(text(twenty, system)),
      };

  /// The steps a picker offers in [system], as `ratingTwenty` values, lowest first.
  static List<int> steps(KitsuRatingSystem system) => switch (system) {
        KitsuRatingSystem.simple => simpleSteps,
        KitsuRatingSystem.regular => [for (var t = 2; t <= 20; t += 2) t],
        KitsuRatingSystem.advanced => [for (var t = 2; t <= 20; t++) t],
      };

  /// [twenty] moved to the nearest step of [system] (a Regular user sees 7/20 as 2 stars).
  static int snap(int twenty, KitsuRatingSystem system) {
    final options = steps(system);
    if (system == KitsuRatingSystem.simple) return options[simpleIndex(twenty)];
    var best = options.first;
    for (final o in options) {
      if ((o - twenty).abs() < (best - twenty).abs()) best = o;
    }
    return best;
  }
}

/// The user's rating drawn in their Kitsu system: a face, a star with its value, or the points.
/// Null or 0 draws [empty] (nothing by default).
class KitsuRatingBadge extends StatelessWidget {
  final int? twenty;
  final KitsuRatingSystem? system;
  final double size;
  final Widget? empty;

  const KitsuRatingBadge({super.key, required this.twenty, this.system, this.size = 16, this.empty});

  @override
  Widget build(BuildContext context) {
    final value = twenty;
    if (value == null || value <= 0) return empty ?? const SizedBox.shrink();
    final sys = system ?? KitsuRating.current;
    final theme = Theme.of(context);
    final color = AppColors.of(context).score.color;
    final style = theme.textTheme.labelLarge?.copyWith(fontSize: size - 2, fontWeight: FontWeight.w600);
    final Widget child = switch (sys) {
      KitsuRatingSystem.simple => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(KitsuRating.simpleIcon(KitsuRating.simpleIndex(value)), size: size + 2, color: color),
          const SizedBox(width: 4),
          Text(KitsuRating.text(value, sys), style: style),
        ]),
      KitsuRatingSystem.regular => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star_rounded, size: size + 2, color: color),
          const SizedBox(width: 2),
          Text(KitsuRating.text(value, sys), style: style),
        ]),
      KitsuRatingSystem.advanced => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star_rounded, size: size + 2, color: color),
          const SizedBox(width: 2),
          Text(KitsuRating.text(value, sys), style: style),
        ]),
    };
    return Semantics(label: KitsuRating.spoken(value, sys), excludeSemantics: true, child: child);
  }
}

/// Asks for a rating in the account's system. Pops the chosen `ratingTwenty`, 0 to remove the
/// rating, or null when dismissed.
Future<int?> showKitsuRatingSheet(BuildContext context, {int? current, KitsuRatingSystem? system, String? title}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => KitsuRatingPicker(current: current, system: system ?? KitsuRating.current, title: title),
  );
}

/// The body of [showKitsuRatingSheet]: four faces, or a slider of stars or points.
class KitsuRatingPicker extends StatefulWidget {
  final int? current;
  final KitsuRatingSystem system;
  final String? title;

  const KitsuRatingPicker({super.key, this.current, required this.system, this.title});

  @override
  State<KitsuRatingPicker> createState() => _KitsuRatingPickerState();
}

class _KitsuRatingPickerState extends State<KitsuRatingPicker> {
  late int _value = widget.current != null && widget.current! > 0
      ? KitsuRating.snap(widget.current!, widget.system)
      : KitsuRating.steps(widget.system)[KitsuRating.steps(widget.system).length ~/ 2];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.current;
    final steps = KitsuRating.steps(widget.system);
    final rated = widget.current != null && widget.current! > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title ?? s.Kr_Rate_Title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (widget.system == KitsuRatingSystem.simple)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < steps.length; i++)
                  _Face(
                    index: i,
                    selected: KitsuRating.simpleIndex(_value) == i,
                    onTap: () => Navigator.of(context).pop(steps[i]),
                  ),
              ],
            )
          else ...[
            Center(child: KitsuRatingBadge(twenty: _value, system: widget.system, size: 28)),
            Slider(
              value: steps.indexOf(_value).clamp(0, steps.length - 1).toDouble(),
              min: 0,
              max: (steps.length - 1).toDouble(),
              divisions: steps.length - 1,
              label: KitsuRating.text(_value, widget.system),
              onChanged: (v) => setState(() => _value = steps[v.round()]),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_value),
              child: Text(s.Kr_Rate_Save),
            ),
          ],
          if (rated) ...[
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              onPressed: () => Navigator.of(context).pop(0),
              child: Text(s.Kr_Rate_Remove),
            ),
          ],
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _Face({required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(KitsuRating.simpleIcon(index), size: 34, color: fg),
              const SizedBox(height: 4),
              Text(KitsuRating.simpleLabel(index), style: theme.textTheme.labelMedium?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
