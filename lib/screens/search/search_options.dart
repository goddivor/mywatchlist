import 'package:mywatchlist/enums.dart' show ForumConstants;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_filters.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

/// The choices of the search filters: API value + translated label. Built at each call, so a
/// language change applies at once.
abstract final class SearchOptions {
  static String categoryLabel(String category) {
    switch (category) {
      case SearchCategory.anime:
        return S.current.Srch_Cat_Anime;
      case SearchCategory.manga:
        return S.current.Srch_Cat_Manga;
      case SearchCategory.character:
        return S.current.Srch_Cat_Character;
      case SearchCategory.person:
        return S.current.Srch_Cat_Person;
      case SearchCategory.user:
        return S.current.Srch_Cat_User;
      case SearchCategory.forum:
        return S.current.Srch_Cat_Forum;
      case SearchCategory.featured:
        return S.current.Srch_Cat_Featured;
      case SearchCategory.news:
        return S.current.Srch_Cat_News;
      case SearchCategory.club:
        return S.current.Srch_Cat_Club;
      case SearchCategory.interestStack:
        return S.current.Srch_Cat_Stack;
      default:
        return S.current.Srch_Cat_All;
    }
  }

  static List<SelectOption<String>> categories() => [
        for (final category in SearchCategory.values)
          SelectOption(category, categoryLabel(category)),
      ];

  static List<SelectOption<String>> animeTypes() => [
        SelectOption('tv', S.current.Srch_Type_Tv),
        SelectOption('movie', S.current.Srch_Type_Movie),
        SelectOption('ova', S.current.Srch_Type_Ova),
        SelectOption('special', S.current.Srch_Type_Special),
        SelectOption('ona', S.current.Srch_Type_Ona),
        SelectOption('music', S.current.Srch_Type_Music),
      ];

  static List<SelectOption<String>> mangaTypes() => [
        SelectOption('manga', S.current.Srch_MType_Manga),
        SelectOption('novel', S.current.Srch_MType_Novel),
        SelectOption('lightnovel', S.current.Srch_MType_LightNovel),
        SelectOption('oneshot', S.current.Srch_MType_Oneshot),
        SelectOption('doujin', S.current.Srch_MType_Doujin),
        SelectOption('manhwa', S.current.Srch_MType_Manhwa),
        SelectOption('manhua', S.current.Srch_MType_Manhua),
      ];

  static List<SelectOption<String>> animeStatuses() => [
        SelectOption('airing', S.current.Srch_Status_Airing),
        SelectOption('complete', S.current.Srch_Status_Finished),
        SelectOption('upcoming', S.current.Srch_Status_Upcoming),
      ];

  static List<SelectOption<String>> mangaStatuses() => [
        SelectOption('publishing', S.current.Srch_Status_Publishing),
        SelectOption('complete', S.current.Srch_Status_Finished),
        SelectOption('hiatus', S.current.Srch_Status_Hiatus),
        SelectOption('discontinued', S.current.Srch_Status_Discontinued),
        SelectOption('upcoming', S.current.Srch_Status_Upcoming),
      ];

  static List<SelectOption<String>> ratings() => [
        SelectOption('g', S.current.Srch_Rated_G),
        SelectOption('pg', S.current.Srch_Rated_Pg),
        SelectOption('pg13', S.current.Srch_Rated_Pg13),
        SelectOption('r17', S.current.Srch_Rated_R17),
        SelectOption('r', S.current.Srch_Rated_R),
        SelectOption('rx', S.current.Srch_Rated_Rx),
      ];

  static List<SelectOption<String>> animeOrders() => [
        SelectOption('title', S.current.Srch_Order_Title),
        SelectOption('start_date', S.current.Srch_Order_Start),
        SelectOption('end_date', S.current.Srch_Order_End),
        SelectOption('episodes', S.current.Srch_Order_Episodes),
        SelectOption('score', S.current.Srch_Order_Score),
        SelectOption('scored_by', S.current.Srch_Order_ScoredBy),
        SelectOption('rank', S.current.Srch_Order_Rank),
        SelectOption('popularity', S.current.Srch_Order_Popularity),
        SelectOption('members', S.current.Srch_Order_Members),
        SelectOption('favorites', S.current.Srch_Order_Favorites),
      ];

  static List<SelectOption<String>> mangaOrders() => [
        SelectOption('title', S.current.Srch_Order_Title),
        SelectOption('start_date', S.current.Srch_Order_Start),
        SelectOption('end_date', S.current.Srch_Order_End),
        SelectOption('chapters', S.current.Srch_Order_Chapters),
        SelectOption('volumes', S.current.Srch_Order_Volumes),
        SelectOption('score', S.current.Srch_Order_Score),
        SelectOption('scored_by', S.current.Srch_Order_ScoredBy),
        SelectOption('rank', S.current.Srch_Order_Rank),
        SelectOption('popularity', S.current.Srch_Order_Popularity),
        SelectOption('members', S.current.Srch_Order_Members),
        SelectOption('favorites', S.current.Srch_Order_Favorites),
      ];

  static List<SelectOption<String>> sorts() => [
        SelectOption('desc', S.current.Srch_Sort_Desc),
        SelectOption('asc', S.current.Srch_Sort_Asc),
      ];

  /// Minimum scores: 9+ down to 1+.
  static List<SelectOption<int>> scores() => [
        for (var score = 9; score >= 1; score--) SelectOption(score, '$score+'),
      ];

  static List<SelectOption<String>> letters() => [
        for (var i = 0; i < 26; i++)
          SelectOption(String.fromCharCode(65 + i), String.fromCharCode(65 + i)),
      ];

  static List<SelectOption<int>> genders() => [
        SelectOption(0, S.current.Srch_Gender_Any),
        SelectOption(1, S.current.Srch_Gender_Male),
        SelectOption(2, S.current.Srch_Gender_Female),
        SelectOption(3, S.current.Srch_Gender_NonBinary),
      ];

  static List<SelectOption<String>> stackTypes() => [
        SelectOption('anime', S.current.Srch_Cat_Anime),
        SelectOption('manga', S.current.Srch_Cat_Manga),
        SelectOption('myanimelist', S.current.Srch_Stack_Mal),
      ];

  static List<SelectOption<int>> boards() => [
        for (final entry in ForumConstants.boards.entries) SelectOption(entry.key, entry.value),
      ];

  static List<SelectOption<int>> subBoards() => [
        for (final entry in ForumConstants.subBoards.entries) SelectOption(entry.key, entry.value),
      ];

  /// Featured article tags (the first, "All", is left out: no tag is the same thing).
  static List<SelectOption<String>> featuredTags() => [
        for (final entry in ForumConstants.tags.entries)
          if (entry.key != 'All') SelectOption(entry.key, entry.value),
      ];

  /// News tags, every group flattened.
  static List<SelectOption<String>> newsTags() => [
        for (final group in ForumConstants.newsTags.values)
          for (final entry in group.entries)
            if (entry.key != 'All') SelectOption(entry.key, entry.value),
      ];

  /// Label of a tag key, searched in both lists.
  static String? tagLabel(String key) {
    final featured = ForumConstants.tags[key];
    if (featured != null) return featured;
    for (final group in ForumConstants.newsTags.values) {
      final label = group[key];
      if (label != null) return label;
    }
    return null;
  }
}
