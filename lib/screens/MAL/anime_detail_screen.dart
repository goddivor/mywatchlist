import 'package:flutter/material.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
// import 'package:mywatchlist/user/theme/theme_bloc.dart';
// import 'package:mywatchlist/user/theme/theme_state.dart';
// import 'package:mywatchlist/widgets/animecardbar.dart';
// import 'package:mywatchlist/widgets/home/section_header.dart';
// import 'package:intl/intl.dart';

class AnimeDetailScreen extends StatefulWidget {
  final Anime anime;

  const AnimeDetailScreen({
    super.key,
    required this.anime,
  });

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;
  // bool _isExpanded = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scrollController = ScrollController();

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("anime detailed screen", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
