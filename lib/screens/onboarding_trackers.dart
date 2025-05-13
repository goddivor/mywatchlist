import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/user_preference.dart';
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
  }

  @override
  void dispose() {
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Background(
            context: context,
            forceBg: true,
            isNetworkImage: false,
            height: size.height,
            url:
                'assets/images/${theme.brightness == Brightness.dark ? 'winter' : 'spring'}.jpg',
          ),

          // Background overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            color: theme.scaffoldBackgroundColor.withOpacity(0.85),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    if (!widget.fromIntro)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: theme.colorScheme.onBackground,
                        ),
                      ),

                    // Header
                    Center(
                      child: Column(
                        children: [
                          const CircleAvatar(
                            backgroundImage:
                                AssetImage('assets/images/mwl-black-bg.png'),
                            radius: 48.0,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Connect Your Accounts',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Link your anime and manga tracking services to get started',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onBackground
                                  .withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Tracker services grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: trackers.length,
                        itemBuilder: (context, index) {
                          return _buildTrackerCard(
                            context,
                            trackers[index],
                            () => _handleTrackerTap(index),
                          );
                        },
                      ),
                    ),

                    // Continue button
                    // SizedBox(
                    //   width: double.infinity,
                    //   child: ElevatedButton(
                    //     onPressed: () {
                    //       if (widget.fromIntro) {
                    //         // Set first time to false
                    //         userPref.setFirstTimeFalse();
                    //       }

                    //       // Navigate to home screen
                    //       Navigator.pushReplacement(
                    //         context,
                    //         MaterialPageRoute(
                    //           builder: (context) => const HomeScreen(),
                    //         ),
                    //       );
                    //     },
                    //     style: ElevatedButton.styleFrom(
                    //       padding: const EdgeInsets.symmetric(vertical: 16),
                    //       backgroundColor: theme.colorScheme.primary,
                    //       foregroundColor: theme.colorScheme.onPrimary,
                    //       elevation: 2,
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(16),
                    //       ),
                    //     ),
                    //     child: Row(
                    //       mainAxisAlignment: MainAxisAlignment.center,
                    //       children: [
                    //         Text(
                    //           'Continue to App',
                    //           style: TextStyle(
                    //             fontSize: 18,
                    //             fontWeight: FontWeight.bold,
                    //           ),
                    //         ),
                    //         const SizedBox(width: 8),
                    //         Icon(Icons.arrow_forward_rounded),
                    //       ],
                    //     ),
                    //   ),
                    // ),

                    // Skip text (only for first time users)
                    if (widget.fromIntro)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: TextButton(
                            onPressed: () {
                              userPref.setFirstTimeFalse();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HomeScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Skip for now',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerCard(
      BuildContext context, Tracker tracker, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: tracker.isActive
              ? Border.all(
                  color: tracker.primaryColor,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status indicator with logo
            Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tracker.isActive
                        ? tracker.primaryColor.withOpacity(0.1)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  ),
                ),

                // Service logo
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Image.asset(
                    tracker.imageUrl,
                    width: 60,
                    height: 60,
                  ),
                ),

                // Connection status indicator
                if (tracker.isActive)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? theme.cardColor : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Service name
            Text(
              tracker.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 4),

            // Status text
            Text(
              tracker.isActive ? 'Connected' : 'Tap to connect',
              style: TextStyle(
                fontSize: 12,
                color: tracker.isActive
                    ? tracker.primaryColor
                    : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 8),

            // Connection button
            if (!tracker.isActive)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 36),
                    padding: EdgeInsets.zero,
                    side: BorderSide(
                      color: tracker.primaryColor,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    'Connect',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: tracker.primaryColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
