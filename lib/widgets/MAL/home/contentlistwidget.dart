// import 'package:flutter/material.dart';
// import 'package:mywatchlist/constants/constants.dart';
// import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
// import 'package:mywatchlist/widgets/animegridcard.dart';

// // Classe ContentListWidget
// class ContentListWidget extends StatelessWidget {
//   final String category;
//   final List<Anime> items;
//   final double? height;
//   final bool showTime;
//   final EdgeInsetsGeometry? padding;

//   const ContentListWidget({
//     super.key,
//     required this.category,
//     required this.items,
//     this.height,
//     this.showTime = false,
//     this.padding,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return horizontalList(
//       category: category,
//       items: items,
//       height: height,
//       showTime: showTime,
//       padding: padding,
//     );
//   }

//   Widget horizontalList({
//     required String category,
//     required List<Anime> items,
//     double? height,
//     bool showTime = false,
//     EdgeInsetsGeometry? padding,
//   }) {
//     return Container(
//       height: height ?? 220, // Hauteur par défaut si non spécifiée
//       padding: padding ?? const EdgeInsets.all(8.0),
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         itemCount: items.length,
//         itemBuilder: (context, index) {
//           final item = items[index];
//           return Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 2),
//             child: AnimeGridCard(
//               node: item,
//               showMemberCount: true,
//               showCardBar: true,
//               width: 170,
//               height: height!,
//               displaySubType: DisplaySubType.compact,
//               onTap: (){
//                 // gotoPage(context: context, newPage: AnimeDetails(animeId: item.id));
//                 // gotoPage(context: context, newPage: ContentDetailedScreen(node: item, id: item.id, category: "anime",)); //will have to add categorie next time
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }

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
  final bool enableAnimation;
  final Duration animationDuration;
  final Curve animationCurve;

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
    this.enableAnimation = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
  });

  @override
  Widget build(BuildContext context) {
    return horizontalList(
      context: context,
      category: category,
      items: items,
      height: height,
      tileWidth: tileWidth,
      tileHeight: tileHeight,
      showTime: showTime,
      padding: padding,
      showCardBar: showCardBar,
      displaySubType: displaySubType,
    );
  }

  Widget horizontalList({
    required BuildContext context,
    required String category,
    required List<Anime> items,
    double? height,
    double? tileWidth,
    double? tileHeight,
    bool showTime = false,
    EdgeInsetsGeometry? padding,
    bool showCardBar = true,
    DisplaySubType displaySubType = DisplaySubType.compact,
  }) {
    final theme = Theme.of(context);
    final double effectiveHeight = height ?? 220;
    final double effectiveWidth = tileWidth ?? 120;
    final double effectiveContentHeight = tileHeight ?? 160;
    
    final Widget container = Container(
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
                  index,
                );
              },
            ),
    );
    
    // Apply animation conditionally
    if (enableAnimation) {
      return AnimatedContainer(
        duration: animationDuration,
        curve: animationCurve,
        height: effectiveHeight,
        child: container,
      );
    } else {
      return container;
    }
  }
  
  Widget _buildAnimeCard(
    BuildContext context,
    Anime anime,
    double width,
    double height,
    bool showCardBar,
    DisplaySubType displaySubType,
    bool showTime,
    int index,
  ) {
    // Add staggered animation for each card
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: GestureDetector(
          onTap: () {
            // Navigate to anime details screen
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ContentDetailedScreen(node: anime),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
              // Navigate to anime details
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContentDetailedScreen(node: anime),
                ),
              );
            },
          ),
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
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'No $category available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
