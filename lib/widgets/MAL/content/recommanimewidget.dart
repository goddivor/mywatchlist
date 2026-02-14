import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';

class RecommendedAnimeWidget extends StatelessWidget {
  final List<Recommendation> recommAnime;
  final String category;
  final double horizPadding;
  const RecommendedAnimeWidget(
      {super.key,
      required this.recommAnime,
      this.category = "anime",
      required this.horizPadding});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
      builder: (context, homePreferencesState) {
        final preferences = homePreferencesState.preferences;
        final tileSize = getTileSizeValues(preferences.tileSize);
        final double cardWidth = tileSize.containerHeight * (2 / 3);
        final double cardHeight = tileSize.containerHeight;
        return ContentListWidget(
          category: category,
          padding: EdgeInsets.symmetric(horizontal: horizPadding + 5.0),
          items: recommAnime
              .map((recommendation) => recommendation.animenode)
              .toList(),
          height: cardHeight,
          tileWidth: cardWidth,
          tileHeight: cardHeight,
        );
      },
    );
  }
}
