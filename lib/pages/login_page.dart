// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_user.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_user_prof.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_user.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_user_prof.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/trackers/widgets/tracker_item.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:mywatchlist/widgets/background.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  int? selectedIndex;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkAuthStatus() async {
    // Check MyAnimeList
    if (UserMal.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[0].isActive = true;
      });
      _checkAndFetchMalUserProfile();
    }

    // Check Anilist
    if (UserAnilist.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[1].isActive = true;
      });
      _checkAndFetchAnilistUserProfile();
    }

    // Check Kitsu
    if (UserKitsu.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[2].isActive = true;
      });
      _checkAndFetchKitsuUserProfile();
    }

    // Check Simkl
    if (UserSimkl.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[3].isActive = true;
      });
      _checkAndFetchSimklUserProfile();
    }
  }

  void handleTrackerTap(BuildContext context, int index) async {
    await trackerFunctions[trackers[index].name]!(context, index, () async {
      setState(() {});

      // Handle MyAnimeList
      if (trackers[index].isActive && trackers[index].name == 'MyAnimeList') {
        _checkAndFetchMalUserProfile();
      }

      // Handle Anilist
      if (trackers[index].isActive && trackers[index].name == 'Anilist') {
        _checkAndFetchAnilistUserProfile();
      }

      // Handle Kitsu
      if (trackers[index].isActive && trackers[index].name == 'Kitsu') {
        _checkAndFetchKitsuUserProfile();
      }

      // Handle Simkl
      if (trackers[index].isActive && trackers[index].name == 'Simkl') {
        _checkAndFetchSimklUserProfile();
      }
    });
  }

  void handleTrackerSelected(
      BuildContext context, int index, Tracker tracker) async {
    setState(() {
      selectedIndex = index;
    });

    if (tracker.isActive) {
      if (tracker.name == "MyAnimeList") {
        context
            .read<AccountBloc>()
            .add(ChangeAccountEvent(AccountType.myanimelist));
      } else if (tracker.name == "Anilist") {
        context
            .read<AccountBloc>()
            .add(ChangeAccountEvent(AccountType.anilist));
      } else if (tracker.name == "Kitsu") {
        context.read<AccountBloc>().add(ChangeAccountEvent(AccountType.kitsu));
      } else if (tracker.name == "Simkl") {
        context.read<AccountBloc>().add(ChangeAccountEvent(AccountType.simkl));
      }
    }
  }

  void _checkAndFetchSimklUserProfile() async {
    if (UserSimkl.instance.username == null ||
        UserSimkl.instance.profileImage == null) {
      UserProfSimkl userProfile = await SimklUser().getUserInfo();
      UserSimkl.instance.setUserInfo(userProfile.name, userProfile.avatar);
      setState(() {});
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _checkAndFetchKitsuUserProfile() async {
    if (UserKitsu.instance.username == null ||
        UserKitsu.instance.profileImage == null) {
      KitsuUserProf userProfile = await KitsuUser().getUserInfo();
      UserKitsu.instance.setUserInfo(userProfile.name, userProfile.avatar);
      setState(() {});
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _checkAndFetchAnilistUserProfile() async {
    if (UserAnilist.instance.username == null ||
        UserAnilist.instance.profileImage == null) {
      AnilistUserProf userProfile = await AnilistUser().getUserInfo();
      UserAnilist.instance.setUserInfo(userProfile.name, userProfile.avatarUrl);
      setState(() {});
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _checkAndFetchMalUserProfile() async {
    if (UserMal.instance.username == null ||
        UserMal.instance.profileImage == null) {
      List<String> fields = ['name', 'picture'];
      MalUserProf userProfile = await MalUser().getUserInfo(fields: fields);
      UserMal.instance.setUserInfo(userProfile.name, userProfile.picture);
      setState(() {});
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background with theme-aware image
          Background(
            context: context,
            forceBg: true,
            isNetworkImage: false,
            height: size.height,
            url:
                "assets/images/${theme.brightness == Brightness.dark ? 'fall' : 'spring'}.jpg",
          ),

          // Background overlay for better readability
          Container(
            width: double.infinity,
            height: double.infinity,
            color: theme.scaffoldBackgroundColor.withOpacity(0.8),
          ),

          // Main content
          BlocBuilder<AccountBloc, AccountState>(
            builder: (context, state) {
              String? profileImageUrl;
              AccountType currentAccountType = AccountType.none;
              List<Account> accounts = [];

              if (state is AccountLoaded) {
                currentAccountType = state.selectedAccountType;
                profileImageUrl = state.profileImageUrl;
                accounts = state.availableAccounts;
              }

              // Get the currently selected account
              Account selectedAccount = accounts.firstWhere(
                (account) => account.typeAcc == currentAccountType,
                orElse: () => Account(
                  name: 'Select an account',
                  typeAcc: AccountType.none,
                  imageUrl:
                      'https://cdn-icons-png.flaticon.com/512/4140/4140037.png',
                ),
              );

              return FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // App logo and title
                        const CircleAvatar(
                          backgroundImage:
                              AssetImage('assets/images/mwl-black-bg.png'),
                          radius: 48.0,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MyWatchList',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                        Text(
                          'Multi-API Anime & Manga Tracker',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                theme.colorScheme.onBackground.withOpacity(0.8),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Profile section
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Profile image
                              Hero(
                                tag: 'profile_image',
                                child: Container(
                                  height: 70,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(35),
                                    child: profileImageUrl != null
                                        ? Image.network(
                                            profileImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Image.network(
                                                selectedAccount.imageUrl,
                                                fit: BoxFit.cover,
                                              );
                                            },
                                          )
                                        : Image.network(
                                            selectedAccount.imageUrl,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedAccount.name,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      currentAccountType == AccountType.none
                                          ? 'No account selected'
                                          : 'Active account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Active indicator
                              if (currentAccountType != AccountType.none)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Services title with animation
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Icon(
                                Icons.connecting_airports_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Available Services',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onBackground,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Tap to select',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onBackground
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Service tracker list
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            physics: const BouncingScrollPhysics(),
                            itemCount: trackers.length,
                            itemBuilder: (context, index) {
                              final tracker = trackers[index];
                              return TrackerItem(
                                tracker: tracker,
                                isSelected: selectedIndex == index,
                                onTap: () => handleTrackerSelected(
                                    context, index, tracker),
                                onDoubleTap: () =>
                                    handleTrackerTap(context, index),
                              );
                            },
                          ),
                        ),

                        // Bottom button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: ElevatedButton(
                            onPressed: currentAccountType == AccountType.none
                                ? null
                                : () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const HomeScreen(),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              disabledBackgroundColor:
                                  theme.colorScheme.onSurface.withOpacity(0.12),
                              disabledForegroundColor:
                                  theme.colorScheme.onSurface.withOpacity(0.38),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  size: 22,
                                  color: currentAccountType == AccountType.none
                                      ? theme.colorScheme.onSurface
                                          .withOpacity(0.38)
                                      : theme.colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Continue to App',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
