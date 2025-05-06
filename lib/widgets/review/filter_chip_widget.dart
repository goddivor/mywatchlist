// lib/widgets/review/filter_chip_widget.dart

import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/review/review_filter_state.dart';
import 'package:mywatchlist/widgets/review/review_filters.dart';

class FilterChipWidget extends StatelessWidget {
  final ReviewFilterType filter;
  final FilterState state;
  final VoidCallback onTap;
  
  const FilterChipWidget({
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
    Color textColor;
    IconData? icon;
    
    switch (state) {
      case FilterState.include:
        backgroundColor = theme.colorScheme.primary;
        textColor = theme.colorScheme.onPrimary;
        icon = Icons.add;
        break;
      case FilterState.exclude:
        backgroundColor = theme.colorScheme.error;
        textColor = theme.colorScheme.onError;
        icon = Icons.remove;
        break;
      case FilterState.inactive:
      default:
        backgroundColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
        icon = null;
        break;
    }
    
    return ActionChip(
      avatar: icon != null 
          ? CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Icon(icon, color: textColor, size: 16),
            )
          : null,
      backgroundColor: backgroundColor,
      labelStyle: TextStyle(color: textColor),
      label: Text(filter.displayName),
      onPressed: onTap,
    );
  }
}