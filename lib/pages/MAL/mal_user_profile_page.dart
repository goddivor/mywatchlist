import 'package:flutter/material.dart';

class MalUserProfilePage extends StatelessWidget {
  final bool isSelf;
  const MalUserProfilePage({super.key, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Mal User Profile Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
