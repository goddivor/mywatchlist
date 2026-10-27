import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// One row of a [RankedBarList].
class RankedBarItem {
  final String label;
  final int count;
  final double mean;

  /// Null = the row is not tappable (no chevron, no ripple).
  final VoidCallback? onTap;

  const RankedBarItem({
    required this.label,
    required this.count,
    required this.mean,
    this.onTap,
  });
}

/// A horizontal bar per item, longest first: the entry count as the bar, the mean score as a
/// badge. Shows [collapsedCount] rows and a "show all" button for the rest. Plain widgets
/// (no chart canvas), so a long list stays cheap.
class RankedBarList extends StatefulWidget {
  final List<RankedBarItem> items;
  final Color color;
  final int collapsedCount;

  const RankedBarList({
    super.key,
    required this.items,
    required this.color,
    this.collapsedCount = 8,
  });

  @override
  State<RankedBarList> createState() => _RankedBarListState();
}

class _RankedBarListState extends State<RankedBarList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.items;
    final shown = _expanded ? items : items.take(widget.collapsedCount).toList();
    final maxCount = items.fold<int>(1, (a, b) => b.count > a ? b.count : a);
    final canExpand = items.length > widget.collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in shown)
          _Row(item: item, maxCount: maxCount, color: widget.color),
        if (canExpand)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? S.current.Prof_Dist_Show_Less : S.current.Prof_Dist_Show_All(items.length),
                style: theme.textTheme.labelLarge,
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final RankedBarItem item;
  final int maxCount;
  final Color color;

  const _Row({required this.item, required this.maxCount, required this.color});

  /// Two decimals with the locale's separator (8,90 in French).
  static NumberFormat get _mean => NumberFormat.decimalPattern()
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxCount == 0 ? 0.0 : item.count / maxCount;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                S.current.Prof_Dist_Mean(_mean.format(item.mean)),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(NumberFormat.decimalPattern().format(item.count), style: theme.textTheme.labelLarge),
              if (item.onTap != null)
                Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
    if (item.onTap == null) return row;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}
