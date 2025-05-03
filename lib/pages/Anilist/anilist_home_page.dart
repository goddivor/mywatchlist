import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/homeappbar.dart';

class AnilistHomePage extends StatelessWidget {
  const AnilistHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarHome(),
      body: Center(
        child: Text("Anilist Home Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
