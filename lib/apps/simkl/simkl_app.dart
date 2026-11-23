import 'package:flutter/material.dart';
import 'package:mywatchlist/apps/simkl/simkl_top_bar.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Simkl/simkl_explore_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_home_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_profile_page.dart';
import 'package:mywatchlist/screens/home_screen.dart' show ShellBackScope;
import 'package:mywatchlist/services/api/SimKl/simkl_kind.dart';
import 'package:mywatchlist/widgets/Simkl/calendar/simkl_calendar.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_catalogue.dart';

/// The Simkl app: what MyWatchList is while a Simkl account is active. Built like Simkl's own
/// "Simkl Lists" app, its bottom bar carries the catalogues (TV shows, Anime, Movies), then the
/// calendar and the profile. Simkl has no forum, so there is none. Every page has the Simkl app
/// bar: its search (in the catalogue of the page), the Simkl settings and the account switcher.
class SimklApp extends StatefulWidget {
  const SimklApp({super.key});

  static const int tabs = 5;
  static const int calendarTab = 3;
  static const int profileTab = 4;

  @override
  State<SimklApp> createState() => _SimklAppState();
}

class _SimklAppState extends State<SimklApp> {
  /// Opens on the catalogue last picked (TV shows by default, like Simkl).
  late int _index = SimklKind.values.indexOf(SimklCatalogue.instance.value);
  final Map<int, Widget> _built = {};
  final ValueNotifier<bool> _noSidebar = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    SimklCatalogue.instance.ensureLoaded().then((_) {
      if (!mounted || _built.isNotEmpty && _index != 0) return;
      setState(() => _index = SimklKind.values.indexOf(SimklCatalogue.instance.value));
    });
  }

  @override
  void dispose() {
    _noSidebar.dispose();
    super.dispose();
  }

  Widget _page(int i) => switch (i) {
        < 3 => SimklCatalogueTab(kind: SimklKind.values[i]),
        SimklApp.calendarTab => const SimklCalendarTab(),
        _ => const SimklProfileTab(),
      };

  void _select(int i) {
    if (i < 3) SimklCatalogue.instance.pick(SimklKind.values[i]);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Tabs are built the first time they are opened, then kept.
    _built.putIfAbsent(_index, () => _page(_index));
    final home = SimklKind.values.indexOf(SimklCatalogue.instance.value);
    return ShellBackScope(
      sidebarOpen: _noSidebar,
      closeSidebar: () {},
      // Back from the calendar or the profile returns to the catalogue in use.
      onHomeTab: _index < 3,
      goHome: () => setState(() => _index = home),
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [for (var i = 0; i < SimklApp.tabs; i++) _built[i] ?? const SizedBox.shrink()],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final k in SimklKind.values)
              NavigationDestination(icon: Icon(simklKindIcon(k)), label: simklKindLabel(k)),
            NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), label: s.Skr_Calendar),
            NavigationDestination(icon: const Icon(Icons.person_outline_rounded), label: s.Skm_Profile),
          ],
        ),
      ),
    );
  }
}

/// One catalogue of the Simkl app: "Up next" (the user's next episodes and Simkl's lists of
/// the catalogue; "Discover" for movies) and "My list", under the Simkl app bar whose search
/// looks in this catalogue.
class SimklCatalogueTab extends StatelessWidget {
  const SimklCatalogueTab({super.key, required this.kind});

  final SimklKind kind;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: SimklTopBar(
          title: simklKindLabel(kind),
          onSearch: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => SimklExplorePage(kind: kind)),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: kind == SimklKind.movie ? s.Skm_Tab_Discover : s.Skr_Up_Next),
              Tab(text: s.Skm_Tab_My_List),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SimklHomePage(kind: kind, embedded: true),
            SimklUserPage(kind: kind),
          ],
        ),
      ),
    );
  }
}

/// The calendar of the Simkl app: the episodes of the coming days for shows and anime, the
/// releases for movies.
class SimklCalendarTab extends StatefulWidget {
  const SimklCalendarTab({super.key});

  @override
  State<SimklCalendarTab> createState() => _SimklCalendarTabState();
}

class _SimklCalendarTabState extends State<SimklCalendarTab> {
  late SimklKind _kind = SimklCatalogue.instance.value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SimklTopBar(title: S.of(context).Skr_Calendar),
      body: Column(
        children: [
          SimklKindSwitch(value: _kind, onChanged: (k) => setState(() => _kind = k)),
          Expanded(child: SimklCalendarPage(key: ValueKey(_kind), kind: _kind, showAppBar: false)),
        ],
      ),
    );
  }
}

/// The profile of the Simkl app (its own TV shows / Anime / Movies switch inside).
class SimklProfileTab extends StatelessWidget {
  const SimklProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SimklTopBar(title: S.of(context).Skm_Profile),
      body: const SimklUserProfilePage(isSelf: true),
    );
  }
}
