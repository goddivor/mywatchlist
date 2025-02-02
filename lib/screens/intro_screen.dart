// ignore_for_file: library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/theme_settings.dart';
import 'package:mywatchlist/widgets/background.dart';
import 'package:mywatchlist/widgets/signin_widget.dart'; // Assurez-vous que cette classe existe
// import 'package:mywatchlist/screens/home_screen.dart';

class IntroScreen extends StatefulWidget {
  final int index;
  final Function(bool)? onRtlChange;
  const IntroScreen({this.onRtlChange, super.key, this.index = 0});

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  int pageLength = 4;
  int pageIndex = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageIndex = widget.index;
    pageController = PageController(initialPage: pageIndex);
  }

  void changePage(int index) {
    pageController.animateToPage(index,
        duration: const Duration(milliseconds: 500), curve: Curves.linear);
    if (mounted) {
      setState(() {
        pageIndex = index;
      });
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  bool get _showPageNavigator => !lastPage;
  bool get lastPage => pageIndex == (pageLength - 1);
  bool get isLoginPage => pageIndex == 1;
  String get _nextButtonText => isLoginPage ? "Skip" : "Next";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: pageController,
            onPageChanged: (value) {
              if (mounted) {
                setState(() {
                  pageIndex = value;
                });
              }
            },
            children: [
              _page(),
              _loginPage(),
              _langPage(),
              ThemeSettings(isIntroPage: true)
            ],
          ),
          if (_showPageNavigator) _pageNavigator(),
        ],
      ),
    );
  }

  Widget _loginPage() {
    return const Center(
      child: SigninWidget(),
    );
  }

  Widget _langPage() {
    return const Center(
      child: Text("Language Page", style: TextStyle(fontSize: 24)),
    );
  }

  Widget _page() {
    return Stack(
      children: [
        Background(isNetworkImage: false, context: context, forceBg: true),
        Container(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(top: MediaQuery.of(context).size.height / 4),
          child: Column(
            children: [
              const CircleAvatar(
                backgroundImage: AssetImage('assets/images/dal-black-bg.png'),
                radius: 48.0,
              ),
              const SizedBox(height: 30),
              const Text("MyWatchList",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(
          alignment: Alignment.topCenter,
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).size.height / 2, left: 15, right: 15),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                SizedBox(height: 80),
                Text(
                  "The Unofficial Multi API App",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 30),
                Text("Keep track of your favorite anime/manga/shows",
                    textAlign: TextAlign.center),
                Text("- or -", textAlign: TextAlign.center),
                Text("Surf through the forums to your hearts content.",
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pageNavigator() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Material(
        borderRadius: BorderRadius.circular(32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _dots(),
            if (pageIndex == 0)
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5, right: 15),
                child: IconButton(
                  onPressed: () {
                    changePage(1);
                  },
                  icon: const Icon(Icons.arrow_forward_ios),
                ),
              ),
            if (pageIndex != 0)
              Expanded(
                child: ButtonBar(
                  buttonPadding: const EdgeInsets.fromLTRB(5, 0, 5, 5),
                  children: [
                    TextButton(
                      onPressed: pageIndex == 0
                          ? null
                          : () => changePage(pageIndex - 1),
                      child: const Text("Previous"),
                    ),
                    TextButton(
                      onPressed:
                          lastPage ? null : () => changePage(pageIndex + 1),
                      child: Text(_nextButtonText),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 0),
          child: Opacity(
            opacity: 1,
            child: Container(
              height: 20,
              width: 100,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(23),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  for (int index = 0; index < pageLength; ++index) dot(index),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget dot(int index) {
    return AnimatedContainer(
      curve: Curves.easeIn,
      duration: const Duration(milliseconds: 200),
      width: pageIndex == index ? 10 : 5,
      height: pageIndex == index ? 10 : 5,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        shape: BoxShape.circle,
      ),
    );
  }
}