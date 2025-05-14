import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';

class SimklHomePage extends StatelessWidget {
  const SimklHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarHome(),
      body: Center(
        child: Text("Simkl Home Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
