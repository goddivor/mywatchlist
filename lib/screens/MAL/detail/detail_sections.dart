/// Ordered registry of the detail page sections.
///
/// One [DetailSectionBuilder] per [TabType]; each lives in its own file under
/// `sections/`. [DetailSections.build] walks the user's order (the
/// `ContentPreferences.animeTabs` / `mangaTabs` contract, hidden tabs dropped)
/// and keeps the sections that have data.
///
/// Extension points:
/// - a new section = a new `TabType` (contract unit) + a builder file in
///   `sections/` + one line in [DetailSections.registry];
/// - reordering / hiding = writing the contract pref (`ContentPreferencesChanged`);
///   the open screen listens to the bloc and rebuilds its sections.
library;

import 'package:flutter/widgets.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/adaptations_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/characters_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/featured_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/forums_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/interest_stacks_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/media_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/more_info_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/news_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/pictures_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/recommendations_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/related_anime_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/related_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/reviews_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/score_stats_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/staff_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/stats_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/synopsis_section.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/user_updates_section.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// Horizontal padding shared by every section body.
const double detailHorizPadding = 15.0;

/// One visible section of the detail page.
@immutable
class DetailSection {
  final TabType type;

  /// Section body (already wrapped by nothing: the screen adds the title row).
  final Widget child;

  /// Listed in the tab bar (false: shown in the page only).
  final bool isTab;

  /// Hides the title row above [child].
  final bool skipTitle;

  /// Arrow button of the title row ("view all").
  final void Function(BuildContext context)? onViewAll;

  /// Extra widget of the title row, left of the arrow.
  final Widget? trailing;

  const DetailSection(
    this.type,
    this.child, {
    this.isTab = true,
    this.skipTitle = false,
    this.onViewAll,
    this.trailing,
  });

  /// Read on every build so a language change applies at once.
  String get title => detailTabLabel(type);
}

/// Builds the section for one tab, or null when the data has nothing to show.
typedef DetailSectionBuilder = DetailSection? Function(DetailData data);

/// Translated name of a detail section (tab bar, title row, customizer).
String detailTabLabel(TabType type) {
  final s = S.current;
  return switch (type) {
    TabType.Synopsis => s.Synopsis,
    TabType.Media => s.Media,
    TabType.Related => s.Related,
    TabType.Adaptations => s.Adaptations,
    TabType.Reviews => s.Reviews,
    TabType.Recommendations => s.Recommendations,
    TabType.Interest_Stacks => s.Interest_Stacks,
    TabType.Characters => s.Characters,
    TabType.Staff => s.Staff,
    TabType.Forums => s.Forums,
    TabType.Pictures => s.Pictures,
    TabType.Related_Anime => s.Related_Anime,
    TabType.News => s.News,
    TabType.Featured_Articles => s.Featured_Articles,
    TabType.User_Updates => s.User_Updates,
    TabType.Stats => s.Stats,
    TabType.ScoreStats => s.Score_Stats,
    TabType.More_Info => s.More_Info,
  };
}

abstract final class DetailSections {
  /// Every known section. A tab missing here is simply skipped.
  static final Map<TabType, DetailSectionBuilder> registry = {
    TabType.Synopsis: synopsisSection,
    TabType.Media: mediaSection,
    TabType.Related: relatedSection,
    TabType.Adaptations: adaptationsSection,
    TabType.Reviews: reviewsSection,
    TabType.Recommendations: recommendationsSection,
    TabType.Interest_Stacks: interestStacksSection,
    TabType.Characters: charactersSection,
    TabType.Staff: staffSection,
    TabType.Forums: forumsSection,
    TabType.Pictures: picturesSection,
    TabType.Related_Anime: relatedAnimeSection,
    TabType.News: newsSection,
    TabType.Featured_Articles: featuredSection,
    TabType.User_Updates: userUpdatesSection,
    TabType.Stats: statsSection,
    TabType.ScoreStats: scoreStatsSection,
    TabType.More_Info: moreInfoSection,
  };

  /// The user's visible section order for this category (contract pref).
  static List<TabType> order(DetailData data, [ContentPreferences? prefs]) =>
      (prefs ?? Preferences.content).visibleTabs(manga: data.isManga);

  /// Sections to show, in order. [order] defaults to the saved preference.
  static List<DetailSection> build(DetailData data, {List<TabType>? order}) {
    final result = <DetailSection>[];
    for (final type in order ?? DetailSections.order(data)) {
      final section = registry[type]?.call(data);
      if (section != null) result.add(section);
    }
    return result;
  }
}
