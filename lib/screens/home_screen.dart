// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, deprecated_member_use, unused_field

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
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
import 'package:mywatchlist/pages/Simkl/simkl_explore_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_forum_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_home_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_page.dart';
import 'package:mywatchlist/pages/Simkl/simkl_user_profile_page.dart';
import 'package:mywatchlist/pages/MAL/mal_user_page.dart';
import 'package:mywatchlist/pages/MAL/mal_user_profile_page.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/widgets/common/background.dart';
import 'package:mywatchlist/widgets/common/bottomnavbar.dart';

class OpacityAnima extends AnimatedWidget {
  final Widget? child;
  const OpacityAnima({super.key, required Animation<double> animation, this.child})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    return Opacity(opacity: animation.value, child: child);
  }
}

class HomeScreen extends StatefulWidget {
  final int? pageIndex;

  const HomeScreen({super.key, this.pageIndex});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int pageIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;
  final List<int> backImagePages = [0];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<int, Widget> homeWidgets = {};
  AccountType? _lastAccountType;

  @override
  void initState() {
    super.initState();
    pageIndex = widget.pageIndex ?? 0;

    _animationController = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 250),
    );
    _animation = Tween(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        if (state is AccountLoaded) {
          AccountType currentAccountType = state.selectedAccountType;

          if (currentAccountType == AccountType.none) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/login');
            });
            return const SizedBox();
          }

          // Only rebuild widgets when account type changes
          if (_lastAccountType != currentAccountType) {
            _lastAccountType = currentAccountType;
            homeWidgets = _getHomeWidgets(currentAccountType);
          }

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: theme.scaffoldBackgroundColor,
            bottomNavigationBar: BottomNavBar(
              startIndex: pageIndex,
              onChanged: (value) {
                _animationController.reset();
                _animationController.forward();
                setState(() {
                  pageIndex = value;
                });
              },
            ),
            body: PopScope(
              canPop: true,
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: backImagePages.contains(pageIndex) ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Background(
                      context: context,
                      height: size.height / 2,
                      showLocalFile: false,
                      isNetworkImage: false,
                      url: _getBackgroundImageForTheme(theme),
                    ),
                  ),
                  IndexedStack(
                    index: pageIndex,
                    children: homeWidgets.values.toList(),
                  ),
                ],
              ),
            ),
          );
        }

        // Écran de chargement avec animation
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animé
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/mwl-black-bg.png',
                        width: 70,
                        height: 70,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Shimmer loading bars
                ShimmerColor(
                  Column(
                    children: [
                      Container(
                        height: 12,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 12,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Obtenir l'image de fond selon le thème
  String _getBackgroundImageForTheme(ThemeData theme) {
    final brightness = theme.brightness;

    // En fonction de la saison ou du thème
    if (brightness == Brightness.dark) {
      return "assets/images/fall.jpg"; // Automne pour le mode sombre
    } else {
      return "assets/images/spring.jpg"; // Printemps pour le mode clair
    }
  }

  Map<int, Widget> _getHomeWidgets(AccountType accountType) {
    Widget wrap(Widget child) =>
        OpacityAnima(animation: _animation, child: child);

    if (accountType == AccountType.myanimelist) {
      return {
        0: wrap(const MalHomePage()),
        1: wrap(MalForumPage()),
        2: wrap(MalUserPage()),
        3: wrap(MalUserProfilePage(isSelf: true)),
        4: wrap(MalExplorePage()),
      };
    } else if (accountType == AccountType.anilist) {
      return {
        0: wrap(AnilistHomePage()),
        1: wrap(AnilistForumPage()),
        2: wrap(AnilistUserPage()),
        3: wrap(AnilistUserProfilePage(isSelf: true)),
        4: wrap(AnilistExplorePage()),
      };
    } else if (accountType == AccountType.kitsu) {
      return {
        0: wrap(KitsuHomePage()),
        1: wrap(KitsuForumPage()),
        2: wrap(KitsuUserPage()),
        3: wrap(KitsuUserProfilePage(isSelf: true)),
        4: wrap(KitsuExplorePage()),
      };
    } else if (accountType == AccountType.simkl) {
      return {
        0: wrap(SimklHomePage()),
        1: wrap(SimklForumPage()),
        2: wrap(SimklUserPage()),
        3: wrap(SimklUserProfilePage(isSelf: true)),
        4: wrap(SimklExplorePage()),
      };
    }

    return {
      0: wrap(const MalHomePage()),
      1: wrap(MalForumPage()),
      2: wrap(MalUserPage()),
      3: wrap(MalUserProfilePage(isSelf: true)),
      4: wrap(MalExplorePage()),
    };
  }
}
