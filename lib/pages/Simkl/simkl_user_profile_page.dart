import 'package:flutter/material.dart';

class SimklUserProfilePage extends StatelessWidget {
  final bool isSelf;
  const SimklUserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Simkl User Profile Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
