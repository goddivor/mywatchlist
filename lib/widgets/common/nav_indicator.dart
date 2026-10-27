import 'package:flutter/material.dart';

/// One bottom-bar tab: the active tab sits in a rounded tinted pill; there is no underline
/// bar under the icon (owner's request).
class NavItemContainer extends StatelessWidget {
  final Widget child;
  final bool isSelected;

  /// Accent used for the ripple.
  final Color activeColor;

  /// Pill colour of the active tab (the theme's `secondaryContainer` in the bottom bar).
  final Color? pillColor;
  final VoidCallback onTap;
  final double borderRadius;

  const NavItemContainer({
    super.key,
    required this.child,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
    this.pillColor,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final pill = pillColor ?? Theme.of(context).colorScheme.secondaryContainer;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: activeColor.withValues(alpha: 0.12),
        highlightColor: activeColor.withValues(alpha: 0.06),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: const Cubic(0.23, 1, 0.32, 1),
          decoration: BoxDecoration(
            color: isSelected ? pill : pill.withValues(alpha: 0),
            borderRadius: radius,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Center(heightFactor: 1, child: child),
        ),
      ),
    );
  }
}
