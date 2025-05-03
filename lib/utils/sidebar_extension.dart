import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/side_bar.dart';
// import 'package:mywatchlist/widgets/side.dart';

/// Helper class to build custom sidebar implementations
class SidebarBuilder {
  /// Build a sidebar with additional menu items
  static Widget buildWithItems({
    required BuildContext context,
    VoidCallback? onClose,
    required List<SidebarMenuItem> menuItems,
  }) {
    // Use the base AppSidebar but inject custom items
    return _ExtendedSidebar(
      onClose: onClose,
      menuItems: menuItems,
    );
  }
}

/// Menu item data for sidebar
class SidebarMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isActive;
  final bool showDividerAfter;

  const SidebarMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.isActive = false,
    this.showDividerAfter = false,
  });
}

/// Extended sidebar with custom menu items
class _ExtendedSidebar extends StatefulWidget {
  final VoidCallback? onClose;
  final List<SidebarMenuItem> menuItems;

  const _ExtendedSidebar({
    required this.menuItems,
    this.onClose,
  });

  @override
  _ExtendedSidebarState createState() => _ExtendedSidebarState();
}

class _ExtendedSidebarState extends State<_ExtendedSidebar> {
  @override
  Widget build(BuildContext context) {
    return AppSidebar(
      onClose: widget.onClose,
    );
  }
}

/// Example usage:
///
/// ```dart
/// Scaffold(
///   key: _scaffoldKey,
///   endDrawer: SidebarBuilder.buildWithItems(
///     context: context,
///     onClose: () {
///       if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
///         Navigator.pop(context);
///       }
///     },
///     menuItems: [
///       SidebarMenuItem(
///         icon: Icons.home,
///         title: 'Home',
///         onTap: () {
///           Navigator.pop(context);
///           // Navigate to home
///         },
///       ),
///       SidebarMenuItem(
///         icon: Icons.list,
///         title: 'My Anime List',
///         onTap: () {
///           Navigator.pop(context);
///           // Navigate to anime list
///         },
///       ),
///       SidebarMenuItem(
///         icon: Icons.book,
///         title: 'My Manga List',
///         onTap: () {
///           Navigator.pop(context);
///           // Navigate to manga list
///         },
///         showDividerAfter: true, // Add divider after this item
///       ),
///       SidebarMenuItem(
///         icon: Icons.settings,
///         title: 'Settings',
///         onTap: () {
///           Navigator.pop(context);
///           // Navigate to settings
///         },
///       ),
///     ],
///   ),
///   body: YourMainContent(),
/// )
/// ```
void exampleUsage() {
  // This is just a placeholder to document usage
  // See the comment above for actual implementation
}
