import 'package:flutter/material.dart';
import 'package:mywatchlist/apps/kitsu/kitsu_top_bar.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_explore_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_forum_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_home_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_profile_page.dart';
import 'package:mywatchlist/screens/home_screen.dart' show ShellBackScope;

/// The Kitsu app: what MyWatchList is while a Kitsu account is active. Laid out like Kitsu's
/// own app: Feed (posts, Kitsu news, groups), Search (the Kitsu catalogue and discovery),
/// Quick update in the middle (the next episode of what is being watched, with the home rows),
/// Library and Profile. Every page has the Kitsu settings and the account switcher.
class KitsuApp extends StatefulWidget {
  const KitsuApp({super.key});

  static const int tabs = 5;

  /// Quick update, the middle tab: where the app opens, like Kitsu's.
  static const int home = 2;

  @override
  State<KitsuApp> createState() => _KitsuAppState();
}

class _KitsuAppState extends State<KitsuApp> {
  int _index = KitsuApp.home;
  final Map<int, Widget> _built = {};
  final ValueNotifier<bool> _noSidebar = ValueNotifier(false);

  @override
  void dispose() {
    _noSidebar.dispose();
    super.dispose();
  }

  static Widget _page(int i) => switch (i) {
        0 => const KitsuFeedTab(),
        1 => const KitsuExplorePage(embedded: true),
        2 => const KitsuHomePage(embedded: true),
        3 => const KitsuUserPage(embedded: true),
        _ => const KitsuProfileTab(),
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Tabs are built the first time they are opened, then kept.
    _built.putIfAbsent(_index, () => _page(_index));
    return ShellBackScope(
      sidebarOpen: _noSidebar,
      closeSidebar: () {},
      onHomeTab: _index == KitsuApp.home,
      goHome: () => setState(() => _index = KitsuApp.home),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [for (var i = 0; i < KitsuApp.tabs; i++) _built[i] ?? const SizedBox.shrink()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(icon: const Icon(Icons.dynamic_feed_outlined), label: s.Kta_Tab_Feed),
            NavigationDestination(icon: const Icon(Icons.search_rounded), label: s.Search),
            NavigationDestination(icon: const Icon(Icons.bolt_rounded), label: s.Kta_Tab_Quick_Update),
            NavigationDestination(icon: const Icon(Icons.local_library_outlined), label: s.Kta_Tab_Library),
            NavigationDestination(icon: const Icon(Icons.person_outline_rounded), label: s.Hw_Tab_Profile),
          ],
        ),
      ),
    );
  }
}

/// The Kitsu feed: the latest posts, the Kitsu news and the groups directory.
class KitsuFeedTab extends StatelessWidget {
  const KitsuFeedTab({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: KitsuTopBar(title: S.of(context).Kta_Tab_Feed),
        body: const KitsuForumPage(showAppBar: false),
      );
}

/// The profile of the Kitsu app.
class KitsuProfileTab extends StatelessWidget {
  const KitsuProfileTab({super.key});

  @override
  // No bar above: the banner covers the top of the screen; the Kitsu buttons are in the
  // profile's own bar, under the header.
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: Colors.transparent,
        body: KitsuUserProfilePage(isSelf: true, barActions: [KitsuBarActions()]),
      );
}
