// lib/widgets/review/filter_chip_widget.dart

import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/MAL/review/review_filter_state.dart';
import 'package:mywatchlist/widgets/MAL/review/review_filters.dart';

class IconFilterChip extends StatelessWidget {
  final ReviewFilterType filter;
  final FilterState state;
  final VoidCallback onTap;

  const IconFilterChip({
    super.key,
    required this.filter,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Define colors based on state
    Color backgroundColor;
    Color iconColor;

    switch (state) {
      case FilterState.include:
        backgroundColor = theme.colorScheme.primary;
        iconColor = theme.colorScheme.onPrimary;
        break;
      case FilterState.exclude:
        backgroundColor = theme.colorScheme.error;
        iconColor = theme.colorScheme.onError;
        break;
      case FilterState.inactive:
      default:
        backgroundColor = theme.colorScheme.surfaceVariant;
        iconColor = theme.colorScheme.onSurfaceVariant;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Tooltip(
        message:
            '${state == FilterState.include ? 'Inclure' : (state == FilterState.exclude ? 'Exclure' : 'Filtrer')} ${filter.displayName}',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: _getIconForFilter(filter, iconColor),
        ),
      ),
    );
  }

  Widget _getIconForFilter(ReviewFilterType filter, Color color) {
    switch (filter) {
      case ReviewFilterType.nice:
        return Icon(Icons.thumb_up, color: color, size: 20);
      case ReviewFilterType.loveIt:
        return Icon(Icons.favorite, color: color, size: 20);
      case ReviewFilterType.funny:
        return Icon(Icons.mood, color: color, size: 20);
      case ReviewFilterType.confusing:
        return Icon(Icons.question_mark, color: color, size: 20);
      case ReviewFilterType.informative:
        return Icon(Icons.info, color: color, size: 20);
      case ReviewFilterType.wellWritten:
        return Icon(Icons.edit, color: color, size: 20);
      case ReviewFilterType.creative:
        return Icon(Icons.auto_awesome, color: color, size: 20);
      case ReviewFilterType.preliminary:
        return Icon(Icons.hourglass_empty, color: color, size: 20);
      case ReviewFilterType.spoiler:
        return Icon(Icons.warning, color: color, size: 20);
      default:
        return Icon(Icons.filter_list, color: color, size: 20);
    }
  }
}
