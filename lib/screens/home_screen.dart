// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, deprecated_member_use, unused_field

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
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
import 'package:mywatchlist/pages/side_bar.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/utils/page_transitions.dart';
import 'package:mywatchlist/widgets/common/background.dart';
import 'package:mywatchlist/widgets/common/bottomnavbar.dart';

class HomeScreen extends StatefulWidget {
  final int? pageIndex;

  const HomeScreen({super.key, this.pageIndex});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int pageIndex = 0;
  int previousPageIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final List<int> backImagePages = [0]; // HomePage a un background
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Map<int, Widget> homeWidgets = {};

  @override
  void initState() {
    super.initState();
    pageIndex = widget.pageIndex ?? 0;
    previousPageIndex = pageIndex;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
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

          // Si aucun compte n'est connecté, rediriger vers la page de connexion
          if (currentAccountType == AccountType.none) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(context, '/login');
            });
            return const SizedBox(); // Évite d'afficher un écran avant la redirection
          }

          homeWidgets = _getHomeWidgets(currentAccountType);

          return Scaffold(
            key: _scaffoldKey,
            endDrawer: AppSidebar(
              onClose: () {
                if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
                  Navigator.pop(context);
                }
              },
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            // BottomNavBar modernisée
            bottomNavigationBar: BottomNavBar(
              startIndex: pageIndex,
              onChanged: (value) {
                setState(() {
                  previousPageIndex = pageIndex;
                  pageIndex = value;
                });

                // Animer le changement de page
                _animationController.reset();
                _animationController.forward();
              },
            ),
            body: WillPopScope(
              onWillPop: () async => true,
              child: Stack(
                children: [
                  // Arrière-plan pour certaines pages
                  if (backImagePages.contains(pageIndex))
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Background(
                        context: context,
                        height: size.height / 2,
                        showLocalFile: false,
                        isNetworkImage: false,
                        url: _getBackgroundImageForTheme(theme),
                      ),
                    ),

                  // Page principale avec animation
                  AnimatedPageSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionType: previousPageIndex < pageIndex
                        ? PageTransitionType.slideLeft
                        : PageTransitionType.slideRight,
                    child: homeWidgets[pageIndex] ?? const SizedBox(),
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
                      color: theme.colorScheme.primary.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/dal-black-bg.png',
                        width: 70,
                        height: 70,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Spinner
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary),
                    strokeWidth: 3,
                  ),
                ),

                const SizedBox(height: 20),

                // Message
                Text(
                  'Loading your anime world...',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onBackground,
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

  // Méthode pour retourner les pages en fonction du type de compte
  Map<int, Widget> _getHomeWidgets(AccountType accountType) {
    if (accountType == AccountType.myanimelist) {
      return {
        0: MalHomePage(),
        1: MalForumPage(),
        2: MalUserPage(),
        3: MalUserProfilePage(isSelf: true),
        4: MalExplorePage(),
      };
    } else if (accountType == AccountType.anilist) {
      return {
        0: AnilistHomePage(),
        1: AnilistForumPage(),
        2: AnilistUserPage(),
        3: AnilistUserProfilePage(isSelf: true),
        4: AnilistExplorePage(),
      };
    } else if (accountType == AccountType.kitsu) {
      return {
        0: KitsuHomePage(),
        1: KitsuForumPage(),
        2: KitsuUserPage(),
        3: KitsuUserProfilePage(isSelf: true),
        4: KitsuExplorePage(),
      };
    } else if (accountType == AccountType.simkl) {
      return {
        0: SimklHomePage(),
        1: SimklForumPage(),
        2: SimklUserPage(),
        3: SimklUserProfilePage(isSelf: true),
        4: SimklExplorePage(),
      };
    }

    // Par défaut, renvoie les pages MAL
    return {
      0: MalHomePage(),
      1: MalForumPage(),
      2: MalUserPage(),
      3: MalUserProfilePage(isSelf: true),
      4: MalExplorePage(),
    };
  }
}
