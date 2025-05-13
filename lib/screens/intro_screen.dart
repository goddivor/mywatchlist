// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/settings/language_settings.dart';
import 'package:mywatchlist/screens/onboarding_trackers.dart';
import 'package:mywatchlist/screens/settings/theme_settings.dart';
import 'package:mywatchlist/widgets/common/background.dart';

class IntroScreen extends StatefulWidget {
  final int index;
  final Function(bool)? onRtlChange;
  const IntroScreen({this.onRtlChange, super.key, this.index = 0});

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  int pageLength = 4;
  int pageIndex = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageIndex = widget.index;
    pageController = PageController(initialPage: pageIndex);
  }

  void changePage(int index) {
    pageController.animateToPage(index,
        duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    if (mounted) {
      setState(() {
        pageIndex = index;
      });
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  bool get _showPageNavigator => !lastPage;
  bool get lastPage => pageIndex == (pageLength - 1);
  bool get isLoginPage => pageIndex == 1;
  String get _nextButtonText => isLoginPage ? "Skip" : "Next";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: pageController,
            onPageChanged: (value) {
              if (mounted) {
                setState(() {
                  pageIndex = value;
                });
              }
            },
            children: [
              _welcomePage(),
              const OnboardingTrackers(fromIntro: true),
              const LanguageSettings(isIntroPage: true),
              const ThemeSettings(isIntroPage: true)
            ],
          ),
          if (_showPageNavigator) _pageNavigator(),
        ],
      ),
    );
  }

  Widget _welcomePage() {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Background(isNetworkImage: false, context: context, forceBg: true),
        Container(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height / 6),
          child: Column(
            children: [
              // App logo
              Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  backgroundImage: AssetImage('assets/images/mwl-black-bg.png'),
                  radius: 48.0,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // App title with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  "MyWatchList",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onBackground,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Content
        Container(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height / 2.5, left: 24, right: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Delayed animated content
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      // Title
                      Text(
                        "The Ultimate Anime, Manga & TV Shows Tracker",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Features in a card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _featureItem(
                              icon: Icons.trending_up_rounded,
                              title: "Track Your Anime & Manga",
                              description: "Keep up with all your favorites across multiple services",
                            ),
                            
                            const SizedBox(height: 16),
                            
                            _featureItem(
                              icon: Icons.explore_rounded,
                              title: "Discover New Content",
                              description: "Find new anime and manga based on your preferences",
                            ),
                            
                            const SizedBox(height: 16),
                            
                            _featureItem(
                              icon: Icons.forum_rounded,
                              title: "Join the Community",
                              description: "Discuss your favorites in dedicated forums",
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Get started button
                      // SizedBox(
                      //   width: double.infinity,
                      //   child: ElevatedButton(
                      //     onPressed: () => changePage(1),
                      //     style: ElevatedButton.styleFrom(
                      //       backgroundColor: theme.colorScheme.primary,
                      //       foregroundColor: theme.colorScheme.onPrimary,
                      //       padding: const EdgeInsets.symmetric(vertical: 16),
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(12),
                      //       ),
                      //       elevation: 4,
                      //     ),
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.center,
                      //       children: const [
                      //         Text(
                      //           "Get Started",
                      //           style: TextStyle(
                      //             fontSize: 18,
                      //             fontWeight: FontWeight.bold,
                      //           ),
                      //         ),
                      //         SizedBox(width: 8),
                      //         Icon(Icons.arrow_forward_rounded),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageNavigator() {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Material(
        borderRadius: BorderRadius.circular(32),
        elevation: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _dots(),
              if (pageIndex == 0)
                IconButton(
                  onPressed: () => changePage(1),
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: theme.colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              if (pageIndex != 0)
                Row(
                  children: [
                    TextButton(
                      onPressed: pageIndex == 0
                          ? null
                          : () => changePage(pageIndex - 1),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Previous",
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: lastPage ? null : () => changePage(pageIndex + 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(_nextButtonText),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int index = 0; index < pageLength; ++index) _dot(index),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(int index) {
    final theme = Theme.of(context);
    final isActive = pageIndex == index;
    
    return AnimatedContainer(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      duration: const Duration(milliseconds: 200),
      height: isActive ? 10 : 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive 
            ? theme.colorScheme.primary 
            : theme.colorScheme.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}