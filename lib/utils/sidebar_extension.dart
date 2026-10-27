import 'package:flutter/material.dart';
import 'package:mywatchlist/pages/side_bar.dart';

/// Builds the app sidebar with extra entries, for a screen that needs its own shortcuts
/// (they are listed after the "My space" group).
class SidebarBuilder {
  /// The sidebar with [menuItems] appended to its destinations.
  static Widget buildWithItems({
    required BuildContext context,
    required List<SidebarMenuItem> menuItems,
  }) {
    return AppSidebar(extraItems: menuItems);
  }
}

/// One extra destination of the sidebar.
class SidebarMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isActive;

  const SidebarMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.isActive = false,
  });
}
