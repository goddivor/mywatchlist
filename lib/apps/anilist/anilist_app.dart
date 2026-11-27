import 'package:flutter/material.dart';
import 'package:mywatchlist/apps/anilist/anilist_top_bar.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_explore_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_forum_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_home_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_user_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_user_profile_page.dart';
import 'package:mywatchlist/screens/home_screen.dart' show ShellBackScope;
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_feed.dart';

/// The AniList app: what MyWatchList is while an AniList account is active. Laid out like
/// anilist.co: Home (the activity feed first, then the overview rows), List (anime and manga),
/// Browse (search and discovery), Forum and Profile. Every page has the AniList app bar: the
/// AniList search, the AniList bell, the AniList settings and the account switcher.
class AnilistApp extends StatefulWidget {
  const AnilistApp({super.key});

  static const int tabs = 5;

  @override
  State<AnilistApp> createState() => _AnilistAppState();
}

class _AnilistAppState extends State<AnilistApp> {
  int _index = 0;
  final Map<int, Widget> _built = {};
  final ValueNotifier<bool> _noSidebar = ValueNotifier(false);

  @override
  void dispose() {
    _noSidebar.dispose();
    super.dispose();
  }

  static Widget _page(int i) => switch (i) {
        0 => const AnilistHomeTab(),
        1 => const AnilistUserPage(embedded: true),
        2 => const AnilistExplorePage(embedded: true),
        3 => const AnilistForumPage(embedded: true),
        _ => const AnilistProfileTab(),
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Tabs are built the first time they are opened, then kept.
    _built.putIfAbsent(_index, () => _page(_index));
    return ShellBackScope(
      sidebarOpen: _noSidebar,
      closeSidebar: () {},
      onHomeTab: _index == 0,
      goHome: () => setState(() => _index = 0),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [for (var i = 0; i < AnilistApp.tabs; i++) _built[i] ?? const SizedBox.shrink()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), label: s.Hw_Tab_Home),
            NavigationDestination(icon: const Icon(Icons.view_list_outlined), label: s.Ala_Tab_List),
            NavigationDestination(icon: const Icon(Icons.explore_outlined), label: s.Ala_Tab_Browse),
            NavigationDestination(icon: const Icon(Icons.forum_outlined), label: s.Hw_Tab_Forum),
            NavigationDestination(icon: const Icon(Icons.person_outline_rounded), label: s.Hw_Tab_Profile),
          ],
        ),
      ),
    );
  }
}

/// Home of the AniList app, like anilist.co: the activity feed (Following / Global, post a
/// status), then the overview (in progress, seasonal, rankings, suggestions, birthdays).
class AnilistHomeTab extends StatelessWidget {
  const AnilistHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AnilistTopBar(
          title: 'AniList',
          bottom: TabBar(tabs: [Tab(text: s.Als_Activity), Tab(text: s.Ala_Tab_Overview)]),
        ),
        body: const TabBarView(
          children: [
            AnilistActivityFeed(),
            AnilistHomePage(embedded: true),
          ],
        ),
      ),
    );
  }
}

/// The profile of the AniList app.
class AnilistProfileTab extends StatelessWidget {
  const AnilistProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    // The profile header is the bar of this page: it carries the AniList buttons.
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: AnilistUserProfilePage(isSelf: true, barActions: [AnilistBarActions()]),
    );
  }
}
