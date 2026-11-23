import 'package:flutter/material.dart';
import 'package:mywatchlist/apps/common/tracker_app_avatar.dart';
import 'package:mywatchlist/apps/simkl/simkl_settings_page.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// The app bar of the Simkl app: the page title, then the Simkl search of the page (when it has
/// one), the Simkl settings and the account avatar: a long press opens the account switcher, as
/// on every tracker; a tap too (Simkl has no sidebar).
class SimklTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SimklTopBar({super.key, required this.title, this.onSearch, this.bottom});

  final String title;

  /// Null = no search on this page.
  final VoidCallback? onSearch;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      title: Text(title),
      bottom: bottom,
      actions: [
        if (onSearch != null)
          IconButton(tooltip: s.Search, icon: const Icon(Icons.search_rounded), onPressed: onSearch),
        IconButton(
          tooltip: s.Settings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SimklSettingsPage())),
        ),
        const TrackerAppAvatar(),
        const SizedBox(width: 8),
      ],
    );
  }
}
