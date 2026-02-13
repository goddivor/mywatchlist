import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';

class KitsuHomePage extends StatelessWidget {
  const KitsuHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarHome(
        showSearch: false,
        showBookmarks: false,
        showCalendar: false,
      ),
      body: Center(
        child: Text("Kitsu Home Page", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
