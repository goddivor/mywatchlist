import 'package:flutter/material.dart';

class AnilistUserProfilePage extends StatelessWidget {
  final bool isSelf;
  const AnilistUserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Anilist User Profile Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
