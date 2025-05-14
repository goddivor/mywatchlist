import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_featured.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class ShowAnimeFeatured extends StatefulWidget {
  final int animeId;
  final String animeName;

  const ShowAnimeFeatured({
    super.key,
    required this.animeId,
    required this.animeName,
  });

  @override
  State<ShowAnimeFeatured> createState() => _ShowAnimeFeaturedState();
}

class _ShowAnimeFeaturedState extends State<ShowAnimeFeatured> {
  AnimeFeaturedResult? featuredArticles;
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchFeaturedArticles();
  }

  Future<void> _fetchFeaturedArticles() async {
    try {
      final response = await MalScraper().getAnimeFeaturedArticles(
        widget.animeId,
        widget.animeName,
      );

      if (response != null) {
        setState(() {
          featuredArticles = AnimeFeaturedResult.fromJson(response);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching featured articles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (featuredArticles == null ||
        featuredArticles!.featuredArticles.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 15.0),
      child: SizedBox(
        height: 270,
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: featuredArticles!.featuredArticles.length,
          itemBuilder: (context, index) {
            final article = featuredArticles!.featuredArticles[index];
            return SizedBox(
              width: 300,
              child: Card(
                margin: const EdgeInsets.only(right: 12.0),
                child: InkWell(
                  onTap: () async {
                    if (article.url.isNotEmpty) {
                      // final Uri url = Uri.parse(article.url);
                      // if (await canLaunchUrl(url)) {
                      //   await launchUrl(url);
                      // }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _imageWidget(article),
                      _titleWidget(article),
                      _summaryWidget(article),
                      _authorAndTagsWidget(article),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _imageWidget(AnimeFeatured article) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        child: article.imageUrl.isNotEmpty
            ? AvatarWidget(
                height: 100,
                width: double.infinity,
                url: article.imageUrl,
                radius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                userRoundBorderforLoading: false,
              )
            : Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Center(
                  child: Icon(
                    Icons.article_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _titleWidget(AnimeFeatured article) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        article.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _summaryWidget(AnimeFeatured article) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          article.text,
          style: TextStyle(
            fontSize: 13,
            color:
                Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
          maxLines: 6, // Augmentation du nombre de lignes de 4 à 6
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _authorAndTagsWidget(AnimeFeatured article) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16),
              const SizedBox(width: 4),
              Text(
                article.author,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.visibility, size: 16),
              const SizedBox(width: 4),
              Text(
                article.views.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (article.tags.isNotEmpty) ...[
            const SizedBox(height: 4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: article.tags.map((tag) {
                  // Special handling for "Spoiler" tag
                  final bool isSpoilerTag = tag.toLowerCase() == 'spoiler';

                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSpoilerTag
                            ? Colors.red.withOpacity(0.7)
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSpoilerTag
                              ? Colors.white
                              : Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Loading state widget
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.only(left: 15.0),
      child: SizedBox(
        height: 270,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 3, // Show 3 placeholder cards
          itemBuilder: (context, index) {
            return SizedBox(
              width: 300,
              child: Card(
                margin: const EdgeInsets.only(right: 12.0),
                child: ShimmerColor(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        color: Colors.white,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 20,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Container(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 30,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Empty state when no featured articles are available
  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun article en vedette disponible',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
