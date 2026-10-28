import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';

/// Filters of a review list: sort, score and tags.
@immutable
class ReviewFilters {
  final ReviewSort sort;
  final int? score;
  final Set<String> tags;

  const ReviewFilters({this.sort = ReviewSort.newest, this.score, this.tags = const {}});

  bool get narrowed => score != null || tags.isNotEmpty;

  ReviewFilters copyWith({ReviewSort? sort, int? Function()? score, Set<String>? tags}) => ReviewFilters(
        sort: sort ?? this.sort,
        score: score != null ? score() : this.score,
        tags: tags ?? this.tags,
      );

  /// The same sort without score or tags.
  ReviewFilters cleared() => ReviewFilters(sort: sort);
}

/// DailyAL's filter row above reviews: score distribution, sort, score and
/// one button per tag, in one horizontal strip.
class ReviewFilterBar extends StatelessWidget {
  final ReviewFilters filters;
  final Map<int, int> distribution;
  final List<String> tags;
  final ValueChanged<ReviewFilters> onChanged;
  final EdgeInsetsGeometry padding;

  const ReviewFilterBar({
    super.key,
    required this.filters,
    required this.distribution,
    required this.tags,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  });

  void _showDistribution(BuildContext context) {
    if (distribution.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => ReviewDistributionDialog(distribution: distribution),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = distribution.keys.toList()..sort();
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (distribution.isNotEmpty)
              IconButton(
                tooltip: S.current.Social_Reviews_Score_Distribution,
                onPressed: () => _showDistribution(context),
                icon: Icon(Icons.bar_chart, size: 20, color: theme.colorScheme.primary),
                visualDensity: VisualDensity.compact,
              ),
            if (scores.isNotEmpty) ...[
              _buildScoreSelect(theme, scores),
              const SizedBox(width: 8),
            ],
            _buildSortSelect(theme),
            for (final tag in tags) _buildTagButton(theme, tag),
          ],
        ),
      ),
    );
  }

  Widget _buildSortSelect(ThemeData theme) {
    final sort = filters.sort;
    return PopupMenuButton<ReviewSort>(
      tooltip: S.current.Social_Reviews_Sort,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => onChanged(filters.copyWith(sort: value)),
      itemBuilder: (_) => [
        for (final option in ReviewSort.values)
          PopupMenuItem<ReviewSort>(
            value: option,
            height: 40,
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 16,
                  color: option == sort ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: option == sort ? FontWeight.w600 : FontWeight.normal,
                    color: option == sort ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: _Pill(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sort.icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(sort.label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSelect(ThemeData theme, List<int> scores) {
    final selected = filters.score;
    final foreground = selected != null ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant;
    return PopupMenuButton<int>(
      tooltip: S.current.Social_Reviews_Filter_Score,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => onChanged(filters.copyWith(score: () => value)),
      itemBuilder: (_) => [
        for (final score in scores.reversed)
          PopupMenuItem<int>(
            value: score,
            height: 40,
            child: Row(
              children: [
                Image.asset('assets/images/star.png', height: 16),
                const SizedBox(width: 8),
                Text(
                  '$score',
                  style: TextStyle(
                    fontWeight: score == selected ? FontWeight.w600 : FontWeight.normal,
                    color: score == selected ? theme.colorScheme.primary : null,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 16),
                Text(
                  '${distribution[score] ?? 0}',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
      child: _Pill(
        color: selected != null ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/star.png', height: 14),
            const SizedBox(width: 6),
            if (selected != null) ...[
              Text('$selected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
              const SizedBox(width: 6),
              // Clearing sits on its own tap target so it never opens the menu.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(filters.copyWith(score: () => null)),
                child: Tooltip(
                  message: S.current.Social_Reviews_Clear_Filter,
                  child: Icon(Icons.close, size: 16, color: foreground),
                ),
              ),
            ] else
              Icon(Icons.arrow_drop_down, size: 20, color: foreground),
          ],
        ),
      ),
    );
  }

  Widget _buildTagButton(ThemeData theme, String tag) {
    final selected = filters.tags.contains(tag);
    final foreground = selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: _Pill(
        color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
        onTap: () {
          final next = {...filters.tags};
          selected ? next.remove(tag) : next.add(tag);
          onChanged(filters.copyWith(tags: next));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.close, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded filter button; wraps [child] with the tap area of a Material pill.
class _Pill extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  const _Pill({required this.color, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Bars of the number of reviews per score (1 to 10).
class ReviewDistributionDialog extends StatelessWidget {
  final Map<int, int> distribution;

  const ReviewDistributionDialog({super.key, required this.distribution});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = NumberFormat.compact(locale: Localizations.localeOf(context).toString());
    final maxCount = distribution.values.reduce((a, b) => a > b ? a : b);
    final total = distribution.values.fold(0, (a, b) => a + b);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.bar_chart, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(S.current.Social_Reviews_Score_Distribution, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 260,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var score = 1; score <= 10; score++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if ((distribution[score] ?? 0) > 0)
                              Text(format.format(distribution[score]), style: const TextStyle(fontSize: 9)),
                            const SizedBox(height: 4),
                            Container(
                              height: maxCount > 0 ? (distribution[score] ?? 0) / maxCount * 180 : 0,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.current.Social_Reviews_Count(total),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.current.Social_Close)),
      ],
    );
  }
}
