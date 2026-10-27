import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage, nullOrEmpty;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/pages/full_recommendations_page.dart';
import 'package:mywatchlist/widgets/MAL/content/recommanimewidget.dart';

/// Recommendations; arrow opens the page with the users' comments.
DetailSection? recommendationsSection(DetailData data) {
  final recommendations = data.content?.recommendations;
  if (nullOrEmpty(recommendations)) return null;
  return DetailSection(
    TabType.Recommendations,
    RecommendedAnimeWidget(
      category: data.category,
      horizPadding: detailHorizPadding,
      recommAnime: recommendations!,
    ),
    onViewAll: (context) => gotoPage(
      context: context,
      newPage: Scaffold(
        appBar: AppBar(title: Text(S.current.Recommendations)),
        body: ContentFullRecommendation(id: data.id, category: data.category),
      ),
    ),
  );
}
