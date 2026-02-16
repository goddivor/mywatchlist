import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';

class ContentListWidget extends StatelessWidget {
  final String category;
  final List<Anime> items;
  final double? height;
  final double? tileWidth;
  final double? tileHeight;
  final bool showTime;
  final EdgeInsetsGeometry? padding;
  final bool showCardBar;
  final VoidCallback? onViewAll;
  final DisplaySubType displaySubType;

  const ContentListWidget({
    super.key,
    required this.category,
    required this.items,
    this.height,
    this.tileWidth,
    this.tileHeight,
    this.showTime = false,
    this.padding,
    this.showCardBar = true,
    this.onViewAll,
    this.displaySubType = DisplaySubType.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double effectiveHeight = height ?? 220;
    final double effectiveWidth = tileWidth ?? 120;
    final double effectiveContentHeight = tileHeight ?? 160;

    return Container(
      height: effectiveHeight,
      padding: padding ?? const EdgeInsets.all(8.0),
      child: items.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildAnimeCard(
                  context,
                  item,
                  effectiveWidth,
                  effectiveContentHeight,
                  showCardBar,
                  displaySubType,
                  showTime,
                );
              },
            ),
    );
  }

  static const _mangaMediaTypes = {
    'manga', 'light_novel', 'one_shot', 'doujinshi', 'manhwa', 'manhua', 'novel'
  };

  String _categoryForItem(Anime anime) {
    if (anime.mediaType != null && _mangaMediaTypes.contains(anime.mediaType)) {
      return 'manga';
    }
    if (anime.mediaType != null) return 'anime';
    return category;
  }

  Widget _buildAnimeCard(
    BuildContext context,
    Anime anime,
    double width,
    double height,
    bool showCardBar,
    DisplaySubType displaySubType,
    bool showTime,
  ) {
    final itemCategory = _categoryForItem(anime);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ContentDetailedScreen(node: anime, category: itemCategory),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                var begin = const Offset(1.0, 0.0);
                var end = Offset.zero;
                var curve = Curves.easeOutCubic;
                var tween = Tween(begin: begin, end: end).chain(
                  CurveTween(curve: curve),
                );
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            ),
          );
        },
        child: AnimeGridCard(
          node: anime,
          showMemberCount: true,
          showCardBar: showCardBar,
          width: width,
          height: height,
          gridHeight: height,
          displaySubType: displaySubType,
          showTime: showTime,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ContentDetailedScreen(node: anime, category: itemCategory),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_filter_outlined,
            size: 36,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No $category available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
