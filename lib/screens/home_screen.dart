import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_explore_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_forum_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_home_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_user_page.dart';
import 'package:mywatchlist/pages/Anilist/anilist_user_profile_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_explore_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_forum_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_home_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_page.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_user_profile_page.dart';
import 'package:mywatchlist/pages/MAL/mal_explore_page.dart';
import 'package:mywatchlist/pages/MAL/mal_forum_page.dart';
import 'package:mywatchlist/pages/MAL/mal_home_page.dart';
import 'package:mywatchlist/pages/MAL/mal_user_page.dart';
import 'package:mywatchlist/pages/MAL/mal_user_profile_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_explore_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_forum_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_home_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_profile_page.dart';
import 'package:mywatchlist/pages/side_bar.dart';
import 'package:mywatchlist/screens/open_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/background.dart';
import 'package:mywatchlist/widgets/common/bottomnavbar.dart';

/// Tabs of the bottom bar, in [BottomNavBar] order.
abstract final class HomeTab {
  static const int home = 0;
  static const int forum = 1;
  static const int userList = 2;
  static const int profile = 3;
  static const int explore = 4;
  static const int count = 5;
}

/// Lets any page inside the home shell reach the shell (e.g. open the sidebar) without a
/// global key; read it through `AppRoutes.openSidebar`.
class HomeShell extends InheritedWidget {
  /// Opens the shell's sidebar (end drawer).
  final VoidCallback openSidebar;

  const HomeShell({super.key, required this.openSidebar, required super.child});

  static HomeShell? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<HomeShell>();

  @override
  bool updateShouldNotify(HomeShell oldWidget) => false;
}

/// The home shell: bottom bar, the five tabs of the active tracker, the sidebar, the
/// startup page, the notification hook and the "session expired" prompt.
class HomeScreen extends StatefulWidget {
  /// Tab to open; null = the startup page preference.
  final int? pageIndex;

  /// Payload of the notification that opened the app (see `NotificationRoute`).
  final String? notificationPayload;

  const HomeScreen({super.key, this.pageIndex, this.notificationPayload});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late int _pageIndex;

  /// Tabs already built for [_pagesFor] (only used when pages are kept in memory).
  final Map<int, Widget> _pages = {};
  AccountType? _pagesFor;

  /// Trackers whose "session expired" prompt was already shown.
  final Set<AccountType> _reLoginPrompted = {};
  bool _redirectingToLogin = false;

  @override
  void initState() {
    super.initState();
    final startup = Preferences.general.startupPage;
    _pageIndex = (widget.pageIndex ?? _tabForStartup(startup))
        .clamp(0, HomeTab.count - 1);
    UserManager.instance.addListener(_onUsersChanged);
    MalApi.sessionExpired.addListener(_onUsersChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.notificationPayload != null) {
        AppRoutes.openFromNotification(context, widget.notificationPayload);
      } else if (widget.pageIndex == null) {
        // Startup pages that are not tabs open on top of the home tab.
        if (startup == StartupPage.calendar) AppRoutes.openCalendar(context);
        if (startup == StartupPage.search) AppRoutes.openSearch(context);
      }
      _onUsersChanged();
    });
  }

  @override
  void dispose() {
    UserManager.instance.removeListener(_onUsersChanged);
    MalApi.sessionExpired.removeListener(_onUsersChanged);
    super.dispose();
  }

  static int _tabForStartup(StartupPage page) {
    switch (page) {
      case StartupPage.forum:
        return HomeTab.forum;
      case StartupPage.userList:
        return HomeTab.userList;
      case StartupPage.profile:
        return HomeTab.profile;
      case StartupPage.explore:
        return HomeTab.explore;
      case StartupPage.home:
      case StartupPage.calendar:
      case StartupPage.search:
        return HomeTab.home;
    }
  }

  /// Trackers whose session died: `needsReLogin` of every tracker, plus MAL's single
  /// signal from the API layer ([MalApi.sessionExpired]).
  static Set<AccountType> expiredTrackers() => {
        ...UserManager.instance.trackersNeedingReLogin,
        if (MalApi.sessionExpired.value) AccountType.myanimelist,
      };

  /// Shows one non-blocking prompt per tracker whose session died (any tracker, not only
  /// MAL); forgets the tracker once it is signed in again.
  void _onUsersChanged() {
    if (!mounted) return;
    final expired = expiredTrackers();
    _reLoginPrompted.removeWhere((t) => !expired.contains(t));
    for (final tracker in expired) {
      if (_reLoginPrompted.add(tracker)) {
        // Listeners may fire during a build: show the snackbar right after it.
        scheduleMicrotask(() => _showSessionExpired(tracker));
      }
    }
  }

  void _showSessionExpired(AccountType tracker) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        showCloseIcon: true,
        content: Text(
          S.current.Shell_Session_Expired(AppRoutes.trackerLabel(tracker)),
        ),
        action: SnackBarAction(
          label: S.current.Shell_Sign_In_Again,
          onPressed: () {
            if (mounted) AppRoutes.signInAgain(context, tracker);
          },
        ),
      ),
    );
  }

  void _redirectToLogin() {
    if (_redirectingToLogin) return;
    _redirectingToLogin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  void _onTabSelected(int index) {
    if (index == _pageIndex) return;
    setState(() => _pageIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the shell only when the selected tracker changes (not on avatar or account
    // list updates); null while the accounts are loading.
    return BlocSelector<AccountBloc, AccountState, AccountType?>(
      selector: (state) =>
          state is AccountLoaded ? state.selectedAccountType : null,
      builder: (context, tracker) {
        if (tracker == null) return const AppStartupLoader();
        if (tracker == AccountType.none) {
          _redirectToLogin();
          return const AppStartupLoader();
        }
        _redirectingToLogin = false;
        return _buildShell(context, tracker);
      },
    );
  }

  Widget _buildShell(BuildContext context, AccountType tracker) {
    final keepInMemory = context.select<PreferencesBloc, bool>(
        (bloc) => bloc.state.general.keepPagesInMemory);
    if (_pagesFor != tracker || !keepInMemory) {
      _pages.clear();
      _pagesFor = tracker;
    }

    final Widget body;
    if (keepInMemory) {
      // Tabs are built the first time they are opened, then kept alive.
      _pages.putIfAbsent(_pageIndex, () => _createTab(tracker, _pageIndex));
      body = IndexedStack(
        index: _pageIndex,
        children: [
          for (var i = 0; i < HomeTab.count; i++)
            _pages[i] ?? const SizedBox.shrink(),
        ],
      );
    } else {
      // Only the current tab exists, so the other tabs fire no request (DAL behaviour).
      body = KeyedSubtree(
        key: ValueKey((tracker, _pageIndex)),
        child: _createTab(tracker, _pageIndex),
      );
    }

    return HomeShell(
      openSidebar: () => _scaffoldKey.currentState?.openEndDrawer(),
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: const AppSidebar(),
        // Wider than the 20 dp default so a swipe from the end edge still reaches the
        // drawer next to Android's gesture-navigation back zone.
        drawerEdgeDragWidth: 40,
        bottomNavigationBar: BottomNavBar(
          startIndex: _pageIndex,
          onChanged: _onTabSelected,
        ),
        body: Stack(
          children: [
            _HomeBackground(visible: _pageIndex == HomeTab.home),
            body,
          ],
        ),
      ),
    );
  }

  static Widget _createTab(AccountType tracker, int index) {
    switch (tracker) {
      case AccountType.anilist:
        return switch (index) {
          HomeTab.forum => AnilistForumPage(),
          HomeTab.userList => AnilistUserPage(),
          HomeTab.profile => const AnilistUserProfilePage(isSelf: true),
          HomeTab.explore => AnilistExplorePage(),
          _ => AnilistHomePage(),
        };
      case AccountType.kitsu:
        return switch (index) {
          HomeTab.forum => KitsuForumPage(),
          HomeTab.userList => KitsuUserPage(),
          HomeTab.profile => const KitsuUserProfilePage(isSelf: true),
          HomeTab.explore => KitsuExplorePage(),
          _ => KitsuHomePage(),
        };
      case AccountType.simkl:
        return switch (index) {
          HomeTab.forum => SimklForumPage(),
          HomeTab.userList => SimklUserPage(),
          HomeTab.profile => const SimklUserProfilePage(isSelf: true),
          HomeTab.explore => SimklExplorePage(),
          _ => SimklHomePage(),
        };
      case AccountType.myanimelist:
      case AccountType.none:
        return switch (index) {
          HomeTab.forum => MalForumPage(),
          HomeTab.userList => MalUserPage(),
          HomeTab.profile => const MalUserProfilePage(isSelf: true),
          HomeTab.explore => MalExplorePage(),
          _ => const MalHomePage(),
        };
    }
  }
}

/// Home tab background picture; rebuilds only when the background settings change.
class _HomeBackground extends StatelessWidget {
  final bool visible;
  const _HomeBackground({required this.visible});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      buildWhen: (previous, current) =>
          previous.showBackground != current.showBackground ||
          previous.backgroundImagePath != current.backgroundImagePath,
      builder: (context, themeState) {
        final show = visible && themeState.showBackground;
        final path = themeState.backgroundImagePath;
        final dark = Theme.of(context).brightness == Brightness.dark;
        // Fades only the picture (never the tab) and stops painting it once hidden.
        return AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: const Cubic(0.23, 1, 0.32, 1),
          child: Background(
            context: context,
            height: MediaQuery.sizeOf(context).height / 2,
            showLocalFile: path != null && path.startsWith('/'),
            isNetworkImage: false,
            url: path ??
                (dark ? 'assets/images/fall.jpg' : 'assets/images/spring.jpg'),
          ),
        );
      },
    );
  }
}
