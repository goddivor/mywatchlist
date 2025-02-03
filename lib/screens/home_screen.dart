// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/pages/explore_page.dart';
import 'package:mywatchlist/pages/forum_page.dart';
import 'package:mywatchlist/pages/home_page.dart';
import 'package:mywatchlist/pages/side_bar.dart';
import 'package:mywatchlist/pages/user_page.dart';
import 'package:mywatchlist/pages/user_profile_page.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/widgets/background.dart';
import 'package:mywatchlist/widgets/bottomnavbar.dart';

class OpacityAnima extends AnimatedWidget {
  final Widget? child;

  const OpacityAnima(
      {super.key, required Animation<double> animation, this.child})
      : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    Animation<double> animation = listenable as Animation<double>;
    return Opacity(
      opacity: animation.value,
      child: child,
    );
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
  late Animation<double> animation;
  final List<int> backImagePages = [0]; // HomePage a un background

  Map<int, Widget> homeWidgets = {};

  @override
  void initState() {
    super.initState();
    pageIndex = widget.pageIndex ?? 0;

    _animationController = AnimationController(
      vsync: this,
      value: 1.0,
      duration: const Duration(milliseconds: 250),
    );
    animation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

    // homeWidgets = {
    //   0: OpacityAnima(animation: animation, child: HomePage()),
    //   1: OpacityAnima(animation: animation, child: ForumPage()),
    //   2: OpacityAnima(animation: animation, child: UserPage()),
    //   3: OpacityAnima(
    //       animation: animation, child: UserProfilePage(isSelf: true)),
    //   4: OpacityAnima(animation: animation, child: ExplorePage()),
    // };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            endDrawer: AppSideBar(),
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
            body: WillPopScope(
              onWillPop: () async => true,
              child: Stack(
                children: [
                  if (backImagePages.contains(pageIndex))
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Background(
                        context: context,
                        height: MediaQuery.of(context).size.height / 2,
                        showLocalFile: false,
                        url: "assets/images/fall.jpg",
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
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  // Méthode pour retourner les pages en fonction du type de compte
  Map<int, Widget> _getHomeWidgets(AccountType accountType) {
    if (accountType == AccountType.myanimelist) {
      return {
        0: OpacityAnima(animation: animation, child: HomePage()),
        1: OpacityAnima(animation: animation, child: ForumPage()),
        2: OpacityAnima(animation: animation, child: UserPage()),
        3: OpacityAnima(
            animation: animation, child: UserProfilePage(isSelf: true)),
        4: OpacityAnima(animation: animation, child: ExplorePage()),
      };
    } else if (accountType == AccountType.anilist) {
      return {
        0: OpacityAnima(animation: animation, child: HomePage()),
        1: OpacityAnima(animation: animation, child: ForumPage()),
        2: OpacityAnima(animation: animation, child: UserPage()),
        3: OpacityAnima(
            animation: animation, child: UserProfilePage(isSelf: true)),
        4: OpacityAnima(animation: animation, child: ExplorePage()),
      };
    } else if (accountType == AccountType.kitsu) {
      return {
        0: OpacityAnima(animation: animation, child: HomePage()),
        1: OpacityAnima(animation: animation, child: ForumPage()),
        2: OpacityAnima(animation: animation, child: UserPage()),
        3: OpacityAnima(
            animation: animation, child: UserProfilePage(isSelf: true)),
        4: OpacityAnima(animation: animation, child: ExplorePage()),
      };
    } else if (accountType == AccountType.simkl) {
      return {
        0: OpacityAnima(animation: animation, child: HomePage()),
        1: OpacityAnima(animation: animation, child: ForumPage()),
        2: OpacityAnima(animation: animation, child: UserPage()),
        3: OpacityAnima(
            animation: animation, child: UserProfilePage(isSelf: true)),
        4: OpacityAnima(animation: animation, child: ExplorePage()),
      };
    }

    // Par défaut, affiche toutes les pages
    return {
      0: OpacityAnima(animation: animation, child: HomePage()),
      1: OpacityAnima(animation: animation, child: ForumPage()),
      2: OpacityAnima(animation: animation, child: UserPage()),
      3: OpacityAnima(
          animation: animation, child: UserProfilePage(isSelf: true)),
      4: OpacityAnima(animation: animation, child: ExplorePage()),
    };
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     endDrawer: AppSideBar(),
  //     bottomNavigationBar: BottomNavBar(
  //       startIndex: pageIndex,
  //       onChanged: (value) {
  //         _animationController.reset();
  //         _animationController.forward();
  //         setState(() {
  //           pageIndex = value;
  //         });
  //       },
  //     ),
  //     body: WillPopScope(
  //       onWillPop: () async => true, // Gérer le retour si nécessaire
  //       child: Stack(
  //         children: [
  //           if (backImagePages.contains(pageIndex))
  //             AnimatedOpacity(
  //               opacity: 1.0,
  //               duration: const Duration(milliseconds: 300),
  //               child: Background(
  //                 context: context,
  //                 height: MediaQuery.of(context).size.height / 2,
  //                 showLocalFile: false,
  //                 url: "assets/images/fall.jpg",
  //               ),
  //             ),
  //           IndexedStack(
  //             index: pageIndex,
  //             children: homeWidgets.values.toList(),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
