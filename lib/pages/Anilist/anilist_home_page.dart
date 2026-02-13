import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';

class AnilistHomePage extends StatelessWidget {
  const AnilistHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarHome(
        showSearch: false,
        showBookmarks: false,
        showCalendar: false,
      ),
      body: Center(
        child: Text("Anilist Home Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
