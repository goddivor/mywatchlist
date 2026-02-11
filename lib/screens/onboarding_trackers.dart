import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/common/background.dart';

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
  final UserPreference userPref = UserPreference();

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
    }
  }

  void _updateTrackerStates() {
    final userManager = UserManager.instance;

    // Update tracker isActive states based on authentication status
    for (int i = 0; i < trackers.length; i++) {
      switch (trackers[i].name) {
        case 'MyAnimeList':
          trackers[i].isActive = userManager.isAuthenticated(AccountType.myanimelist);
          if (trackers[i].isActive) {
            trackers[i].username = userManager.mal.username;
            trackers[i].profileImage = userManager.mal.profileImage;
          }
          break;
        case 'Anilist':
          trackers[i].isActive = userManager.isAuthenticated(AccountType.anilist);
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
                // Back button
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

                const SizedBox(height: 24),

                // Header section - Material Design 3
                Column(
                  children: [
                    Text(
                      'Connect Your Accounts',
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
                        color: colorScheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Link your tracking services to sync your lists',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Tracker services list - Material Design 3 (scrollable)
                Expanded(
                  child: ListView.separated(
                    itemCount: trackers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _m3TrackerListCard(
                        context,
                        trackers[index],
                        () => _handleTrackerTap(index),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Skip button - Material Design 3
                if (widget.fromIntro)
                  FilledButton.tonal(
                    onPressed: () {
                      userPref.setFirstTimeFalse();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Skip for now'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Material Design 3 tracker card - Horizontal list version
  Widget _m3TrackerListCard(
      BuildContext context, Tracker tracker, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: tracker.isActive ? 2 : 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: tracker.isActive
              ? tracker.primaryColor.withOpacity(0.5)
              : colorScheme.outlineVariant.withOpacity(0.5),
          width: tracker.isActive ? 2 : 1,
        ),
      ),
      color: tracker.isActive
          ? tracker.primaryColor.withOpacity(0.05)
          : colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
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
                    padding: tracker.isActive && tracker.profileImage != null
                        ? EdgeInsets.zero
                        : const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tracker.isActive
                          ? tracker.primaryColor.withOpacity(0.15)
                          : colorScheme.surfaceContainerHighest,
                    ),
                    child: tracker.isActive && tracker.profileImage != null
                        ? CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(tracker.profileImage!),
                            backgroundColor: tracker.primaryColor.withOpacity(0.15),
                          )
                        : Image.asset(
                            tracker.imageUrl,
                            width: 48,
                            height: 48,
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
                              color: colorScheme.primary.withOpacity(0.3),
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
                    // Service name or Username
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
                    // Description or Service name when connected
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

              // Action button
              if (!tracker.isActive)
                FilledButton(
                  onPressed: onTap,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: tracker.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: tracker.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Connected',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: tracker.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
