import 'package:flutter/material.dart';

class UserProfilePage extends StatelessWidget {
  final bool isSelf;
  const UserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("User Profile Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
