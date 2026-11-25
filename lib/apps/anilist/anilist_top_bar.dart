import 'package:flutter/material.dart';
import 'package:mywatchlist/apps/anilist/anilist_app_settings_page.dart';
import 'package:mywatchlist/apps/common/tracker_app_avatar.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/calendar/anilist_calendar_page.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_chips.dart' show openAnilistSearch;
import 'package:mywatchlist/widgets/Anilist/notifications/anilist_notification_bell.dart';

/// The buttons of the AniList app bar: the AniList search (titles, characters, staff,
/// studios, users), the AniList bell with its unread badge, the AniList settings and the
/// account avatar (a long press opens the account switcher).
class AnilistBarActions extends StatelessWidget {
  const AnilistBarActions({super.key, this.showSearch = true});

  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSearch)
          IconButton(
            tooltip: s.Search,
            icon: const Icon(Icons.search_rounded),
            onPressed: () => openAnilistSearch(context),
          ),
        IconButton(
          tooltip: s.Alc_Open_Calendar,
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AnilistCalendarPage()),
          ),
        ),
        IconButton(
          tooltip: s.Bookmarks,
          icon: const Icon(Icons.bookmark_border),
          onPressed: () => AppRoutes.openBookmarks(context),
        ),
        const AnilistNotificationBell(),
        IconButton(
          tooltip: s.Settings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AnilistAppSettingsPage()),
          ),
        ),
        const TrackerAppAvatar(),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// The app bar of an AniList app page: its title, then [AnilistBarActions].
class AnilistTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AnilistTopBar({super.key, required this.title, this.bottom, this.showSearch = true});

  final String title;
  final PreferredSizeWidget? bottom;
  final bool showSearch;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) => AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        centerTitle: false,
        title: Text(title),
        bottom: bottom,
        actions: [AnilistBarActions(showSearch: showSearch)],
      );
}
