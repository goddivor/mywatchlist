import 'package:flutter/material.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';

class TrackerItem extends StatelessWidget {
  final Tracker tracker;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final bool isSelected;

  const TrackerItem(
      {super.key,
      required this.tracker,
      required this.onTap,
      required this.onDoubleTap,
      required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.1)
                : isDark
                    ? theme.cardColor
                    : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Logo with circle background
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surface
                        : theme.colorScheme.surface.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(
                    tracker.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(width: 16),

                // Tracker name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tracker.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tracker.isActive ? 'Connected' : 'Not connected',
                        style: TextStyle(
                          fontSize: 14,
                          color: tracker.isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Status indicator
                Container(
                  width: 60,
                  alignment: Alignment.centerRight,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: tracker.isActive
                        ? Container(
                            key: const ValueKey('active'),
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: theme.colorScheme.primary,
                              size: 28,
                            ),
                          )
                        : Container(
                            key: const ValueKey('inactive'),
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.add_circle_outline,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                              size: 24,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
