import 'package:flutter/material.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/constants/constants.dart';

class OnboardingTrackers extends StatefulWidget {
  final bool fromIntro;

  const OnboardingTrackers({
    super.key,
    this.fromIntro = true,
  });

  @override
  State<OnboardingTrackers> createState() => _OnboardingTrackersState();
}

class _OnboardingTrackersState extends State<OnboardingTrackers>
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

    UserManager.instance.addListener(_onUserManagerChanged);
    _updateTrackerStates();
  }

  void _onUserManagerChanged() {
    if (mounted) {
      setState(() {
        _updateTrackerStates();
      });
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
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.kitsu);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.kitsu.username;
            trackers[i].profileImage = userManager.kitsu.profileImage;
          }
          break;
        case 'Simkl':
          trackers[i].isActive =
              userManager.isAuthenticated(AccountType.simkl);
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

  void _handleTrackerTap(int index) async {
    await trackerFunctions[trackers[index].name]!(
      context,
      index,
      () {
        setState(() {});
      },
    );
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                if (!widget.fromIntro)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),

                const Spacer(flex: 2),

                // Header
                Text(
                  'Connect Your Accounts',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap a service to connect or disconnect',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // Circular icons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(trackers.length, (index) {
                    final tracker = trackers[index];

                    return GestureDetector(
                      onTap: () => _handleTrackerTap(index),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Circle with logo or profile image
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: tracker.isActive
                                      ? tracker.primaryColor.withAlpha(30)
                                      : colorScheme.surfaceContainerHighest,
                                  border: Border.all(
                                    color: tracker.isActive
                                        ? tracker.primaryColor
                                        : colorScheme.outlineVariant,
                                    width: tracker.isActive ? 2.5 : 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: tracker.isActive &&
                                          tracker.profileImage != null
                                      ? Image.network(
                                          tracker.profileImage!,
                                          fit: BoxFit.cover,
                                          width: 68,
                                          height: 68,
                                        )
                                      : Image.asset(
                                          tracker.imageUrl,
                                          fit: BoxFit.cover,
                                          width: 68,
                                          height: 68,
                                        ),
                                ),
                              ),
                              // Connected badge
                              if (tracker.isActive)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      color: colorScheme.onPrimary,
                                      size: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Service name
                          Text(
                            tracker.name == 'MyAnimeList'
                                ? 'MAL'
                                : tracker.name,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: tracker.isActive
                                  ? tracker.primaryColor
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: tracker.isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
