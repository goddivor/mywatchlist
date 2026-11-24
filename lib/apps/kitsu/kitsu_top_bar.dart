import 'package:flutter/material.dart';
import 'package:mywatchlist/apps/common/tracker_app_avatar.dart';
import 'package:mywatchlist/apps/kitsu/kitsu_app_settings_page.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// The buttons of the Kitsu app bar: the Kitsu settings and the account avatar (a long press
/// opens the account switcher). The search is a tab of its own.
class KitsuBarActions extends StatelessWidget {
  const KitsuBarActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: S.of(context).Settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const KitsuAppSettingsPage()),
            ),
          ),
          const TrackerAppAvatar(),
          const SizedBox(width: 8),
        ],
      );
}

/// The app bar of a Kitsu app page: its title, then [KitsuBarActions].
class KitsuTopBar extends StatelessWidget implements PreferredSizeWidget {
  const KitsuTopBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: Text(title),
        actions: const [KitsuBarActions()],
      );
}

/// The title row of a Kitsu page whose own app bar stays (search, quick update, library).
class KitsuTitleRow extends StatelessWidget {
  const KitsuTitleRow({super.key, this.title, this.leading});

  final String? title;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const SizedBox(width: 16),
          if (leading != null) leading!,
          if (title != null) Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleLarge)),
          if (title == null) const Spacer(),
          const KitsuBarActions(),
        ],
      );
}
