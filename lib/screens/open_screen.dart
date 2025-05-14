// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/screens/intro_screen.dart';
import 'package:mywatchlist/user/user_preference.dart';

/// Entry point widget that decides whether to show intro or home
class OpenScreen extends StatefulWidget {
  const OpenScreen({super.key});

  @override
  _OpenScreenState createState() => _OpenScreenState();
}

/// State class handling first-time logic and UI selection
class _OpenScreenState extends State<OpenScreen> {
  // Manages user preferences storage
  final UserPreference userPref = UserPreference();
  // Tracks if this is the user's first app launch
  bool? isFirstTime;

  @override
  void initState() {
    super.initState();
    // Check preference on widget creation
    checkFirstTime();
  }

  /// Retrieves first-time flag asynchronously
  void checkFirstTime() async {
    bool first = await userPref.isFirstTime();
    // Update state with retrieved flag
    setState(() {
      isFirstTime = first;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator until flag is loaded
    if (isFirstTime == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // Show intro on first launch, otherwise go to home
    return isFirstTime! ? IntroScreen() : HomeScreen();
  }
}
