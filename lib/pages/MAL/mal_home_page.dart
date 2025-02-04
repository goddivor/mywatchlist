import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/homeappbar.dart';

class MalHomePage extends StatelessWidget {
  const MalHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarHome(),
      body: Center(
        child: Text("Mal Home Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
