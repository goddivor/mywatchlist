import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'dart:async';

import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

// Classe ShowAnimeNews qui affiche les news avec pagination et défilement infini
class ShowAnimeNews extends StatefulWidget {
  final int animeId;

  const ShowAnimeNews({super.key, required this.animeId});

  @override
  // ignore: library_private_types_in_public_api
  _ShowAnimeNewsState createState() => _ShowAnimeNewsState();
}

class _ShowAnimeNewsState extends State<ShowAnimeNews> {
  List<AnimeNews>? newsList;
  List newsFullList = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(scrollController);
    _fetchNews();
  }

  Future<void> scrollController() async {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {});
      await _fetchNews();
      setState(() {});
    }
  }

  Future<void> _fetchNews() async {
    if (_hasNextPage) {
      final response =
          await JikanApi().getAnimeNews(widget.animeId, page: _currentPage);
      setState(() {
        newsList = response.data;
        newsFullList.addAll(newsList!);
        _currentPage++;
        _hasNextPage = response.pagination.hasNextPage ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 15.0),
      child: SizedBox(
        height: 270,
        child: GridView.builder(
          controller: _scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisSpacing: 0,
            crossAxisCount: 1,
            mainAxisSpacing: 0,
            childAspectRatio: .9,
          ),
          itemCount: newsFullList.length + (_hasNextPage ? 1 : 0),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            if (index < newsFullList.length) {
              final news = newsFullList[index];
              return Card(
                child: InkWell(
                  onTap: () {
                    // Action lorsqu'on appuie sur la carte (par exemple ouvrir un lien)
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _titleWidget(news),
                      const SizedBox(height: 10),
                      _summaryWidget(news),
                      const SizedBox(height: 10),
                      _bottomWidget(news),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  Widget _titleWidget(AnimeNews news) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AvatarWidget(
              height: 40,
              width: 40,
              url: news.images?.jpg?.imageUrl,
              userRoundBorderforLoading: false,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: title(news.title ?? '', textOverflow: TextOverflow.fade),
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryWidget(AnimeNews news) {
    return Expanded(
      flex: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: title(news.excerpt ?? ''),
      ),
    );
  }

  Widget _bottomWidget(AnimeNews news) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          title(news.authorUsername ?? '', selectable: true),
          iconAndText(Icons.comment, news.comments.toString())
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
