
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/screens/intro_screen.dart';
import 'package:mywatchlist/user/user_preference.dart';

class OpenScreen extends StatefulWidget {
  const OpenScreen({super.key});

  @override
  _OpenScreenState createState() => _OpenScreenState();
}

class _OpenScreenState extends State<OpenScreen> {
  final UserPreference userPref = UserPreference();
  bool? isFirstTime;

  @override
  void initState() {
    super.initState();
    checkFirstTime();
  }

  void checkFirstTime() async {
    bool first = await userPref.isFirstTime();
    setState(() {
      isFirstTime = first;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isFirstTime == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return isFirstTime! ? IntroScreen() : HomeScreen();
  }
}
