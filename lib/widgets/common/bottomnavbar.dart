import 'package:flutter/material.dart';
import 'package:line_icons/line_icon.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/nav_indicator.dart';

/// The home shell's bottom bar: five tabs, the active one in a rounded accent-tinted pill with the
/// accent icon (no underline bar). Line icons, as DailyAL.
class BottomNavBar extends StatefulWidget {
  final int? startIndex;
  final ValueChanged<int>? onChanged;
  final bool forceBackground;

  const BottomNavBar({
    super.key,
    this.onChanged,
    this.startIndex = 0,
    this.forceBackground = false,
  });

  /// Tab icons, in `HomeTab` order (home, forum, list, profile, explore).
  static const List<Widget> icons = [
    LineIcon.home(size: iconSize),
    LineIcon.comments(size: iconSize),
    LineIcon.list(size: iconSize),
    LineIcon.user(size: iconSize),
    LineIcon.globe(size: iconSize),
  ];

  static const double iconSize = 24.0;

  /// The active tab's pill: the accent at 12 % over the bar, so the accent icon on it keeps
  /// 3:1 even for vivid accents (a `secondaryContainer` pill did not for red or pink).
  static Color pillColor(ColorScheme cs) =>
      Color.alphaBlend(cs.primary.withValues(alpha: 0.12), cs.surfaceContainer);

  /// Accessible names of the tabs, in the same order.
  static List<String> labels() => [
        S.current.Hw_Tab_Home,
        S.current.Hw_Tab_Forum,
        S.current.Hw_Tab_List,
        S.current.Hw_Tab_Profile,
        S.current.Hw_Tab_Explore,
      ];

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int pageIndex = widget.startIndex ?? 0;

  /// The shell can change tab from code (Back to home, a notification, the startup page):
  /// follow [BottomNavBar.startIndex] when it changes.
  @override
  void didUpdateWidget(covariant BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.startIndex;
    if (index != null && index != oldWidget.startIndex && index != pageIndex) {
      pageIndex = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labels = BottomNavBar.labels();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(BottomNavBar.icons.length, (index) {
              final selected = pageIndex == index;
              return Expanded(
                child: Tooltip(
                  message: labels[index],
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: labels[index],
                    excludeSemantics: true,
                    child: NavItemContainer(
                      isSelected: selected,
                      activeColor: cs.primary,
                      pillColor: BottomNavBar.pillColor(cs),
                      onTap: () => _onPageChange(index),
                      child: AnimatedScale(
                        scale: selected ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        curve: const Cubic(0.23, 1, 0.32, 1),
                        child: IconTheme(
                          data: IconThemeData(
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                            size: BottomNavBar.iconSize,
                          ),
                          child: BottomNavBar.icons[index],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _onPageChange(int index) {
    if (pageIndex == index) return;
    setState(() => pageIndex = index);
    widget.onChanged?.call(index);
  }
}
