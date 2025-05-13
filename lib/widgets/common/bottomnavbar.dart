// // ignore_for_file: prefer_typing_uninitialized_variables, library_private_types_in_public_api, deprecated_member_use

// import 'package:flutter/material.dart';
// import 'package:line_icons/line_icon.dart';

// class BottomNavBar extends StatefulWidget {
//   final startIndex;
//   final ValueChanged<int>? onChanged;
//   const BottomNavBar({super.key, this.onChanged, this.startIndex = 0});
//   @override
//   _BottomNavBarState createState() => _BottomNavBarState();
// }

// class _BottomNavBarState extends State<BottomNavBar> {
//   int pageIndex = 0;
//   double iconSize = 20.0;

//   Map<int, Icon> lineIconMap = {
//     0: LineIcon.home(),
//     1: LineIcon.comments(),
//     2: LineIcon.list(),
//     3: LineIcon.user(),
//     4: LineIcon.globe(),
//   };

//   @override
//   void initState() {
//     super.initState();
//     pageIndex = widget.startIndex ?? 0;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return BottomNavigationBar(
//         unselectedItemColor: theme.iconTheme.color?.withOpacity(.5),
//         selectedItemColor: theme.iconTheme.color,
//         showSelectedLabels: false,
//         showUnselectedLabels: false,
//         currentIndex: pageIndex,
//         enableFeedback: true,
//         type: BottomNavigationBarType.shifting,
//         onTap: (index) => _onPageChange(index),
//         items: List.generate(
//             lineIconMap.length,
//             (index) => BottomNavigationBarItem(
//                   label: '$index',
//                   icon: lineIconMap[index]!,
//                 )));
//   }

//   void _onPageChange(int index) {
//     if (pageIndex != index) {
//       widget.onChanged!(index);
//       pageIndex = index;
//     }
//   }
// }

// ignore_for_file: prefer_typing_uninitialized_variables, library_private_types_in_public_api, deprecated_member_use

// ignore_for_file: prefer_typing_uninitialized_variables, library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:line_icons/line_icon.dart';
// import 'package:line_icons/line_icons.dart';
import 'package:mywatchlist/widgets/common/nav_indicator.dart';

class BottomNavBar extends StatefulWidget {
  final startIndex;
  final ValueChanged<int>? onChanged;
  final bool forceBackground;

  const BottomNavBar({
    super.key,
    this.onChanged,
    this.startIndex = 0,
    this.forceBackground = false,
  });

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with SingleTickerProviderStateMixin {
  int pageIndex = 0;
  double iconSize = 24.0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Utilisation de LineIcon selon votre demande
  final Map<int, Widget> lineIconMap = {
    0: const LineIcon.home(size: 24),
    1: const LineIcon.comments(size: 24),
    2: const LineIcon.list(size: 24),
    3: const LineIcon.user(size: 24),
    4: const LineIcon.globe(size: 24),
  };

  // Titres des pages pour l'accessibilité et les tooltips
  final Map<int, String> pageTitles = {
    0: 'Home',
    1: 'Forum',
    2: 'My List',
    3: 'Profile',
    4: 'Explore',
  };

  @override
  void initState() {
    super.initState();
    pageIndex = widget.startIndex ?? 0;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Créer un effet d'élévation subtil
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      // Barre de navigation arrondie dans les coins supérieurs
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: FadeTransition(
          opacity: _animation,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface
                  : theme.colorScheme.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(
                    lineIconMap.length,
                    (index) => _buildNavItem(index, theme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, ThemeData theme) {
    final bool isSelected = pageIndex == index;
    final Color activeColor = theme.colorScheme.primary;
    final Color inactiveColor = theme.colorScheme.onSurface.withOpacity(0.5);

    return Expanded(
      child: Tooltip(
        message: pageTitles[index] ?? 'Tab $index',
        child: NavItemContainer(
          isSelected: isSelected,
          activeColor: activeColor,
          backgroundColor: theme.colorScheme.surface,
          onTap: () => _onPageChange(index),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône avec coloration adaptative
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isSelected ? activeColor : inactiveColor,
                  fontSize: iconSize,
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: IconTheme(
                    data: IconThemeData(
                      color: isSelected ? activeColor : inactiveColor,
                      size: iconSize,
                    ),
                    child: lineIconMap[index] ?? const Icon(Icons.circle),
                  ),
                ),
              ),

              // Indicateur
              NavIndicator(
                isActive: isSelected,
                color: activeColor,
                width: 24,
                height: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPageChange(int index) {
    if (pageIndex != index) {
      setState(() {
        pageIndex = index;
      });
      widget.onChanged?.call(index);

      // Animation pour l'élément sélectionné
      _animationController.reset();
      _animationController.forward();
    }
  }
}
