import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/main.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/widgets/homeappbar.dart';

class MalHomePage extends StatefulWidget {
  const MalHomePage({super.key});
  @override
  _MalHomePageState createState() => _MalHomePageState();
}

class _MalHomePageState extends State<MalHomePage> {
  bool hasOpened = false;
  double height = 50;
  final MalApi malApi = MalApi();
  ScrollController scrollController = ScrollController();
  ScrollController bodyHeaderController = ScrollController();
  bool transition = false;
  var topHeaders = <String, dynamic>{};
  late String refKey;

  @override
  void initState() {
    super.initState();
    hasOpened = false;
    startOpeningAnimation();

    Future.delayed(Duration.zero).then((value) {
      initLangs();
      usermal.addListener(() {
        if (mounted) setState(() {});
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _loadData();
    });
  }

  initLangs() {
    topHeaders = {
      S.of(context).Categories: SizedBox(),
      // AllRankingWidget(
      //   category: 'anime',
      //   fullScreen: true,
      // ),
      S.of(context).Genres: SizedBox(),
      // _showGenresModal,
      S.of(context).top_anime: SizedBox(),
      // GeneralSearchScreen(
      //   searchQuery: "#all",
      //   autoFocus: false,
      //   showBackButton: true,
      // ),
      S.of(context).top_mange: SizedBox(),
      // GeneralSearchScreen(
      //   searchQuery: "#all@manga",
      //   autoFocus: false,
      //   showBackButton: true,
      // ),
      S.of(context).top_airing: SizedBox(),
      // GeneralSearchScreen(
      //   searchQuery: "#airing",
      //   autoFocus: false,
      //   showBackButton: true,
      // ),
      S.of(context).popular_anime: SizedBox(),
      // GeneralSearchScreen(
      //   searchQuery: "#bypopularity",
      //   autoFocus: false,
      //   showBackButton: true,
      // ),
      S.of(context).popular_manga: SizedBox(),
      // GeneralSearchScreen(
      //   searchQuery: "#bypopularity@manga",
      //   autoFocus: false,
      //   showBackButton: true,
      // )
    };
  }

  startOpeningAnimation() async {
    Future.delayed(Duration.zero).then((value) {
      if (mounted) {
        setState(() {
          hasOpened = true;
          height = 0;
        });
      }
    });
  }

  _showGenresModal() => showBottomSheet(
      context: context,
      builder: (_) => Material(
            child: SizedBox(
              height: 260.0,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(S.of(context).Genres),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        )
                      ],
                    ),
                  ),
                  SizedBox(),
                  // AllGenreWidget(
                  //   category: 'anime',
                  // ),
                ],
              ),
            ),
          ));

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

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const SectionTitle({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
