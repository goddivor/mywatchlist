import 'package:flutter/material.dart';

class KitsuUserProfilePage extends StatelessWidget {
  final bool isSelf;
  const KitsuUserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Kitsu User Profile Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
