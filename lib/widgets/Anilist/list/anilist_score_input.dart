import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/edit/number_bar.dart';

/// The score control of the user's AniList format, on AniList's raw 0-100 value:
/// a 0-100 slider, a 0-10 slider in tenths, the 0-10 number bar, five stars or three faces.
/// [onChanged] gets the new raw value (0 = not scored).
class AnilistScoreInput extends StatelessWidget {
  final AnilistScoreFormat format;
  final int raw;
  final bool busy;
  final ValueChanged<int> onChanged;

  const AnilistScoreInput({
    super.key,
    required this.format,
    required this.raw,
    required this.onChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      AnilistScoreFormat.point100 || AnilistScoreFormat.point10Decimal =>
        AnilistScoreSlider(format: format, raw: raw, busy: busy, onChanged: onChanged),
      AnilistScoreFormat.point10 => NumberBar(
          first: 0,
          count: 11,
          selected: format.fromRaw(raw).round(),
          busy: busy,
          semanticLabel: (v) => v == 0 ? S.current.Edit_No_Score : '$v',
          labelBuilder: (context, v) => v == 0 ? const Icon(Icons.block, size: 18) : Text('$v'),
          onSelected: (v) => onChanged(format.toRaw(v.toDouble())),
        ),
      AnilistScoreFormat.point5 => _Symbols(
          count: 5,
          selected: format.fromRaw(raw).round(),
          busy: busy,
          icon: (i, on) => on ? Icons.star_rounded : Icons.star_outline_rounded,
          color: (context, i) => AppColors.of(context).score.color,
          label: (i) => '$i/5',
          onSelected: (v) => onChanged(format.toRaw(v.toDouble())),
        ),
      AnilistScoreFormat.point3 => _Symbols(
          count: 3,
          selected: format.fromRaw(raw).round(),
          busy: busy,
          // Faces are distinct shapes: only the picked one is coloured.
          exclusive: true,
          icon: (i, on) => switch (i) {
            1 => Icons.sentiment_dissatisfied_rounded,
            2 => Icons.sentiment_neutral_rounded,
            _ => Icons.sentiment_satisfied_rounded,
          },
          color: (context, i) => Theme.of(context).colorScheme.primary,
          label: (i) => '$i/3',
          onSelected: (v) => onChanged(format.toRaw(v.toDouble())),
        ),
    };
  }
}

/// Slider of the 0-100 and 0-10 decimal formats, with the value on its right.
class AnilistScoreSlider extends StatelessWidget {
  final AnilistScoreFormat format;
  final int raw;
  final bool busy;
  final ValueChanged<int> onChanged;

  const AnilistScoreSlider({
    super.key,
    required this.format,
    required this.raw,
    required this.onChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = format.max;
    final value = format.fromRaw(raw).clamp(0, max).toDouble();
    final divisions = (max / format.step).round();
    final text = raw > 0 ? format.format(raw) : '–';
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            max: max,
            divisions: divisions,
            label: raw > 0 ? text : null,
            onChanged: busy ? null : (v) => onChanged(format.toRaw(v)),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            text,
            textAlign: TextAlign.end,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

/// A row of tappable symbols (stars, faces). Tapping the picked one again clears the score.
class _Symbols extends StatelessWidget {
  final int count;
  final int selected;
  final bool busy;
  final bool exclusive;
  final IconData Function(int index, bool on) icon;
  final Color Function(BuildContext context, int index) color;
  final String Function(int index) label;
  final ValueChanged<int> onSelected;

  const _Symbols({
    required this.count,
    required this.selected,
    required this.busy,
    required this.icon,
    required this.color,
    required this.label,
    required this.onSelected,
    this.exclusive = false,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= count; i++)
          IconButton(
            iconSize: 34,
            tooltip: label(i),
            isSelected: exclusive ? selected == i : selected >= i,
            onPressed: busy ? null : () => onSelected(selected == i ? 0 : i),
            icon: Icon(
              icon(i, exclusive ? selected == i : selected >= i),
              color: (exclusive ? selected == i : selected >= i) ? color(context, i) : muted,
            ),
          ),
      ],
    );
  }
}
