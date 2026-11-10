// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:mywatchlist/screens/settings/language_settings.dart';
import 'package:mywatchlist/screens/onboarding_trackers.dart';
import 'package:mywatchlist/screens/settings/theme_settings.dart';

/// Intro screen with multiple setup pages
class IntroScreen extends StatefulWidget {
  final int index; // start page index
  final Function(bool)? onRtlChange; // callback for RTL change
  final VoidCallback? onDone;
  const IntroScreen({this.onRtlChange, this.onDone, super.key, this.index = 0});

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

/// State for handling page navigation and UI
class _IntroScreenState extends State<IntroScreen> with TickerProviderStateMixin {
  int pageLength = 4; // total pages count
  int pageIndex = 0; // current page index
  late PageController pageController; // controls page transitions
  late PageController featurePageController; // controls feature carousel
  int currentFeatureIndex = 0;
  Timer? _featureTimer;
  late AnimationController _logoAnimationController;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _logoScaleAnimation;

  final List<Map<String, dynamic>> features = [
    {
      'icon': Icons.playlist_add_check_rounded,
      'title': 'Track Everything',
      'description': 'Manage your anime, manga, and shows in one place',
      'color': 0,
    },
    {
      'icon': Icons.explore_rounded,
      'title': 'Discover & Explore',
      'description': 'Find your next favorite with smart recommendations',
      'color': 1,
    },
    {
      'icon': Icons.sync_rounded,
      'title': 'Multi-Platform Sync',
      'description': 'Connect MAL, AniList, Kitsu & Simkl accounts',
      'color': 2,
    },
  ];

  @override
  void initState() {
    super.initState();
    pageIndex = widget.index;
    pageController = PageController(initialPage: pageIndex);
    featurePageController = PageController();

    // Logo animation
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _logoRotateAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Auto carousel for features - change every 4 seconds
    _featureTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (pageIndex == 0 && mounted) {
        final nextIndex = (currentFeatureIndex + 1) % features.length;
        setState(() {
          currentFeatureIndex = nextIndex;
        });
        featurePageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  /// Animate to given page index
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
    featurePageController.dispose();
    _featureTimer?.cancel();
    _logoAnimationController.dispose();
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
          // main pages
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
              ThemeSettings(isIntroPage: true, onDone: widget.onDone)
            ],
          ),
          // page navigation controls
          if (_showPageNavigator) _pageNavigator(),
        ],
      ),
    );
  }

  /// First welcome page with animated features carousel
  Widget _welcomePage() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.3),
            colorScheme.surface,
            colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Animated logo
              AnimatedBuilder(
                animation: _logoAnimationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _logoRotateAnimation.value,
                    child: Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primaryContainer,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
                          backgroundImage:
                              AssetImage('assets/images/mwl-black-bg.png'),
                          radius: 56.0,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // App title with animated subtitle
              Column(
                children: [
                  Text(
                    "MyWatchList",
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 60,
                    child: DefaultTextStyle(
                      style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ) ??
                          const TextStyle(),
                      child: AnimatedTextKit(
                        animatedTexts: [
                          TypewriterAnimatedText(
                            'Your Ultimate Anime Companion',
                            speed: const Duration(milliseconds: 80),
                          ),
                          TypewriterAnimatedText(
                            'Track. Discover. Enjoy.',
                            speed: const Duration(milliseconds: 100),
                          ),
                        ],
                        repeatForever: true,
                        pause: const Duration(milliseconds: 2000),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Feature carousel with page indicator
              SizedBox(
                height: 220,
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: featurePageController,
                        onPageChanged: (index) {
                          setState(() {
                            currentFeatureIndex = index;
                          });
                        },
                        itemCount: features.length,
                        itemBuilder: (context, index) {
                          return _buildFeatureCard(features[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Page indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        features.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: currentFeatureIndex == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: currentFeatureIndex == index
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  /// Animated feature card
  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<Color> getGradientColors(int colorIndex) {
      switch (colorIndex) {
        case 0:
          return [
            colorScheme.primaryContainer,
            colorScheme.primaryContainer.withValues(alpha: 0.6),
          ];
        case 1:
          return [
            colorScheme.secondaryContainer,
            colorScheme.secondaryContainer.withValues(alpha: 0.6),
          ];
        case 2:
          return [
            colorScheme.tertiaryContainer,
            colorScheme.tertiaryContainer.withValues(alpha: 0.6),
          ];
        default:
          return [colorScheme.primaryContainer, colorScheme.primaryContainer];
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(30 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: getGradientColors(feature['color']),
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                feature['icon'],
                color: colorScheme.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle(
                    style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ) ??
                        const TextStyle(),
                    child: AnimatedTextKit(
                      key: ValueKey(feature['title']),
                      animatedTexts: [
                        TypewriterAnimatedText(
                          feature['title'],
                          speed: const Duration(milliseconds: 60),
                        ),
                      ],
                      isRepeatingAnimation: false,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feature['description'],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Page navigator - Material Design 3
  Widget _pageNavigator() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _dots(),
            const SizedBox(width: 16),
            if (pageIndex == 0)
              FilledButton.icon(
                onPressed: () => changePage(1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: const Text('Get Started'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            if (pageIndex != 0)
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: pageIndex == 0
                        ? null
                        : () => changePage(pageIndex - 1),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed:
                        lastPage ? null : () => changePage(pageIndex + 1),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(_nextButtonText),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Dots indicator row
  Widget _dots() {
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

  /// Single dot widget - Material Design 3
  Widget _dot(int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = pageIndex == index;

    return AnimatedContainer(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 8,
      width: isActive ? 32 : 8,
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary : colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
