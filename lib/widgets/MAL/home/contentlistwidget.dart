import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';

/// A horizontal row of [AnimeGridCard]s (home sections, related and
/// recommended titles). Lazy, with a fixed item extent so scrolling never
/// measures the cards; a tap opens the detail screen with the card's node.
class ContentListWidget extends StatelessWidget {
  final String category;
  final List<Anime> items;
  final double? height;
  final double? tileWidth;
  final double? tileHeight;
  final bool showTime;
  final EdgeInsetsGeometry? padding;
  final bool showCardBar;

  /// Adds a trailing "View all" tile that calls this.
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

  static const _mangaMediaTypes = {
    'manga', 'light_novel', 'one_shot', 'doujinshi', 'manhwa', 'manhua', 'novel'
  };

  String _categoryForItem(Anime anime) {
    final type = anime.mediaType;
    if (type != null && _mangaMediaTypes.contains(type)) return 'manga';
    if (type != null) return 'anime';
    return category;
  }

  /// Width a card takes in the row: its own width plus the paddings the card
  /// and the row add around it.
  double _extent(double cardWidth) {
    final compact = displaySubType == DisplaySubType.compact ||
        displaySubType == DisplaySubType.cover_only_grid;
    return cardWidth + 10 + (compact ? 12 : 10);
  }

  @override
  Widget build(BuildContext context) {
    final double effectiveHeight = height ?? 220;
    final double effectiveWidth = tileWidth ?? 120;
    final double effectiveContentHeight = tileHeight ?? 160;

    if (items.isEmpty) {
      return Container(
        height: effectiveHeight,
        padding: padding ?? const EdgeInsets.all(8.0),
        child: _EmptyRow(category: category),
      );
    }

    final extent = _extent(effectiveWidth);
    final count = items.length + (onViewAll == null ? 0 : 1);
    return Container(
      height: effectiveHeight,
      padding: padding ?? const EdgeInsets.all(8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        itemExtent: extent,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _ViewAll(onPressed: onViewAll!);
          }
          final item = items[index];
          final itemCategory = _categoryForItem(item);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: AnimeGridCard(
              key: ValueKey('$itemCategory:${item.id}'),
              node: item,
              category: itemCategory,
              showMemberCount: true,
              showCardBar: showCardBar,
              width: effectiveWidth,
              height: effectiveContentHeight,
              gridHeight: effectiveContentHeight,
              displaySubType: displaySubType,
              showTime: showTime,
              onTap: () => AppRoutes.push(
                context,
                ContentDetailedScreen(node: item, category: itemCategory),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String category;
  const _EmptyRow({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = switch (category) {
      'anime' => S.current.Card_Empty_Anime,
      'manga' => S.current.Card_Empty_Manga,
      _ => S.current.Card_Empty,
    };
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
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewAll extends StatelessWidget {
  final VoidCallback onPressed;
  const _ViewAll({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.arrow_forward),
        label: Text(S.current.Card_View_All),
      ),
    );
  }
}
