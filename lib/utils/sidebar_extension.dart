import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/side_bar.dart';

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

