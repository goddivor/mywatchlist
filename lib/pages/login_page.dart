// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/user_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();

    // Listen to UserManager changes to update tracker status
    UserManager.instance.addListener(_onUserManagerChanged);

    // Initialize tracker states from UserManager
    _updateTrackerStates();
  }

  void _onUserManagerChanged() {
    if (mounted) {
      setState(() {
        _updateTrackerStates();
      });
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _updateTrackerStates() {
    final userManager = UserManager.instance;

    for (int i = 0; i < trackers.length; i++) {
      switch (trackers[i].name) {
        case 'MyAnimeList':
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.myanimelist);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.mal.username;
            trackers[i].profileImage = userManager.mal.profileImage;
          }
          break;
        case 'Anilist':
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.anilist);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.anilist.username;
            trackers[i].profileImage = userManager.anilist.profileImage;
          }
          break;
        case 'Kitsu':
          trackers[i].isActive = userManager.isAuthenticated(AccountType.kitsu);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.kitsu.username;
            trackers[i].profileImage = userManager.kitsu.profileImage;
          }
          break;
        case 'Simkl':
          trackers[i].isActive = userManager.isAuthenticated(AccountType.simkl);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.simkl.username;
            trackers[i].profileImage = userManager.simkl.profileImage;
          }
          break;
      }
    }
  }

  @override
  void dispose() {
    UserManager.instance.removeListener(_onUserManagerChanged);
    _animationController.dispose();
    super.dispose();
  }

  AccountType _trackerToAccountType(String name) {
    switch (name) {
      case 'MyAnimeList':
        return AccountType.myanimelist;
      case 'Anilist':
        return AccountType.anilist;
      case 'Kitsu':
        return AccountType.kitsu;
      case 'Simkl':
        return AccountType.simkl;
      default:
        return AccountType.none;
    }
  }

  void _handleTrackerTap(int index) async {
    await trackerFunctions[trackers[index].name]!(
      context,
      index,
      () {
        setState(() {});
      },
    );
  }

  void _handleSelectAccount(int index, Tracker tracker) {
    if (tracker.isActive) {
      final accountType = _trackerToAccountType(tracker.name);
      context.read<AccountBloc>().add(ChangeAccountEvent(accountType));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: BlocBuilder<AccountBloc, AccountState>(
            builder: (context, state) {
              AccountType currentAccountType = AccountType.none;

              if (state is AccountLoaded) {
                currentAccountType = state.selectedAccountType;
              }

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Header section
                    Column(
                      children: [
                        Text(
                          'Choose Your Account',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Connect a service and select it as your active account',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Tracker list
                    Expanded(
                      child: ListView.separated(
                        itemCount: trackers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildTrackerCard(
                            context,
                            trackers[index],
                            index,
                            currentAccountType,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Continue button
                    FilledButton(
                      onPressed: currentAccountType == AccountType.none
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HomeScreen(),
                                ),
                              );
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 22),
                          SizedBox(width: 8),
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
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTrackerCard(
    BuildContext context,
    Tracker tracker,
    int index,
    AccountType currentAccountType,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected =
        _trackerToAccountType(tracker.name) == currentAccountType;

    return Card(
      elevation: tracker.isActive ? 2 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : tracker.isActive
                  ? tracker.primaryColor.withValues(alpha: 0.5)
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : tracker.isActive
              ? tracker.primaryColor.withValues(alpha: 0.05)
              : colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: tracker.isActive
            ? () => _handleSelectAccount(index, tracker)
            : () => _handleTrackerTap(index),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo or Profile Image with status badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tracker.isActive
                          ? tracker.primaryColor.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest,
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: tracker.primaryColor.withValues(alpha: 0.15),
                      backgroundImage:
                          tracker.isActive && tracker.profileImage != null
                              ? NetworkImage(tracker.profileImage!)
                              : AssetImage(tracker.imageUrl) as ImageProvider,
                    ),
                  ),
                  // Connected badge
                  if (tracker.isActive)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: colorScheme.onPrimary,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 16),

              // Info section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tracker.isActive && tracker.username != null
                          ? tracker.username!
                          : tracker.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tracker.isActive && tracker.username != null
                          ? tracker.name
                          : tracker.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Action area
              if (!tracker.isActive)
                FilledButton(
                  onPressed: () => _handleTrackerTap(index),
                  style: FilledButton.styleFrom(
                    backgroundColor: tracker.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Connect'),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select as primary radio
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: colorScheme.onPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: tracker.primaryColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Select',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: tracker.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Disconnect button
                    IconButton(
                      onPressed: () => _handleTrackerTap(index),
                      icon: Icon(
                        Icons.link_off_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                      ),
                      tooltip: 'Disconnect',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
