import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

/// The horizontal row of news (or featured) articles of the home: a card per article with its
/// picture, title, start of the text and tags.
///
/// The picture also fills the card behind the text, washed out by a flat surface-coloured layer
/// (no `Opacity`, no clip per item: both force an offscreen layer on every scrolled frame).
class HomePageNewsWidget extends StatelessWidget {
  final List<Map<String, String>> featuredList;
  final String category;
  const HomePageNewsWidget(this.featuredList, {super.key, this.category = 'news'});

  static const double _radius = 12;
  static const double _cardWidth = 320;
  static const double _height = 250;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 12, right: 15),
        itemCount: featuredList.length,
        scrollDirection: Axis.horizontal,
        itemExtent: _cardWidth,
        itemBuilder: (context, index) => _NewsCard(
          node: featuredList[index],
          category: category,
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, String> node;
  final String category;

  const _NewsCard({required this.node, required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = node['imageUrl'] ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final id = int.tryParse(node['id'] ?? '');
          if (id != null) {
            gotoPage(
              context: context,
              newPage: FeaturedScreen(
                id: id,
                featureTitle: node['title'],
                imgUrl: imageUrl.isEmpty ? null : imageUrl,
                category: category,
              ),
            );
          }
        },
        child: Stack(
          children: [
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: AppImage(
                  url: imageUrl,
                  width: HomePageNewsWidget._cardWidth,
                  height: HomePageNewsWidget._height,
                  fit: BoxFit.cover,
                ),
              ),
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: ColoredBox(color: theme.cardColor.withValues(alpha: 0.9)),
              ),
            _NewsTile(node: node, imageUrl: imageUrl),
          ],
        ),
      ),
    );
  }
}

class _NewsTile extends StatelessWidget {
  final Map<String, String> node;
  final String imageUrl;

  const _NewsTile({required this.node, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        if (imageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
            child: AvatarWidget(
              height: 220,
              width: 120,
              url: imageUrl,
              onTap: () => zoomInImage(context, imageUrl),
              radius: BorderRadius.circular(HomePageNewsWidget._radius),
              userRoundBorderforLoading: false,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node['title'] ?? '',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 5,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    node['text'] ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
                    overflow: TextOverflow.fade,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  node['tags'] ?? '',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
