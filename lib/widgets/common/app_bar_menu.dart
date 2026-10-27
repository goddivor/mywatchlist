import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// One entry of an [AppBarMenu]: an already translated [label], an [icon] and
/// what to do on tap. The menu holds no feature logic; screens pass callbacks.
@immutable
class AppBarMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const AppBarMenuItem({required this.label, required this.icon, required this.onTap});

  /// "Share" (open [showShareBuilder] from [onTap]).
  factory AppBarMenuItem.share(VoidCallback onTap) =>
      AppBarMenuItem(label: S.current.Share, icon: Icons.share_outlined, onTap: onTap);

  /// "Open in browser" (call `openLink` from [onTap]).
  factory AppBarMenuItem.openInBrowser(VoidCallback onTap) =>
      AppBarMenuItem(label: S.current.Open_In_Browser, icon: Icons.open_in_browser, onTap: onTap);

  /// "Bookmark" / "Remove bookmark" depending on [bookmarked].
  factory AppBarMenuItem.bookmark(VoidCallback onTap, {bool bookmarked = false}) => AppBarMenuItem(
        label: bookmarked ? S.current.Kit_Remove_Bookmark : S.current.Kit_Bookmark,
        icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
        onTap: onTap,
      );
}

/// The overflow (⋮) button of an app bar. Lists the standard slots whose
/// callback is given ([onShare], [onOpenInBrowser], [onBookmark], in that
/// order), then [items]. A slot without callback is left out, and with no
/// entry at all the menu renders nothing, so there is never a dead button.
///
/// ```dart
/// AppBar(actions: [
///   AppBarMenu(
///     onShare: () => showShareBuilder(context, fields: fields, subject: title),
///     onOpenInBrowser: () => openLink(context, url),
///     onBookmark: () => bookmarks.toggle(node),
///     bookmarked: isBookmarked,
///   ),
/// ])
/// ```
class AppBarMenu extends StatelessWidget {
  final VoidCallback? onShare;
  final VoidCallback? onOpenInBrowser;
  final VoidCallback? onBookmark;
  final bool bookmarked;
  final List<AppBarMenuItem> items;

  /// Replaces the default ⋮ icon.
  final Widget? icon;

  const AppBarMenu({
    super.key,
    this.onShare,
    this.onOpenInBrowser,
    this.onBookmark,
    this.bookmarked = false,
    this.items = const [],
    this.icon,
  });

  /// Every entry in display order.
  List<AppBarMenuItem> get entries => [
        if (onShare != null) AppBarMenuItem.share(onShare!),
        if (onOpenInBrowser != null) AppBarMenuItem.openInBrowser(onOpenInBrowser!),
        if (onBookmark != null) AppBarMenuItem.bookmark(onBookmark!, bookmarked: bookmarked),
        ...items,
      ];

  @override
  Widget build(BuildContext context) {
    final all = entries;
    if (all.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<int>(
      tooltip: S.current.Show_Menu,
      icon: icon ?? const Icon(Icons.more_vert),
      position: PopupMenuPosition.under,
      onSelected: (index) => all[index].onTap(),
      itemBuilder: (_) => [
        for (var i = 0; i < all.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(all[i].icon, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(all[i].label, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
    );
  }
}
