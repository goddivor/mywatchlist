// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/main.dart';

class ThemeSettings extends StatelessWidget {
  final bool isIntroPage;
  const ThemeSettings({super.key, required this.isIntroPage});

  void save(BuildContext context) async {
    if (isIntroPage) {
      final userPref = UserPreference();
      await userPref.setFirstTimeFalse();
    }
    restartApp(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Désactiver le retour arrière
      child: Scaffold(
        floatingActionButtonLocation:
            FloatingActionButtonLocation.miniCenterFloat,
        floatingActionButton: FloatingActionButton(
          onPressed: () => save(context),
          child: const Icon(Icons.check),
        ),
        body: const Center(
          child: Text("Theme Settings Page", style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }
}
