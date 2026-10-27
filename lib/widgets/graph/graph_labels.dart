import 'package:mywatchlist/generated/l10n.dart';

/// Translated text for the values the graph backend and MAL send as English words.
/// Read at each call so a language change applies; unknown values fall back to a readable form
/// of the raw word instead of hiding it.
class GraphLabels {
  const GraphLabels._();

  /// "alternative_setting" -> "Alternative setting".
  static String humanize(String word) {
    final spaced = word.replaceAll('_', ' ').trim();
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  /// The relation of a MAL `relation_type` word (`sequel`, `side_story`, `adaptation`…);
  /// [fallback] (MAL's own formatted text) when the word is unknown.
  static String relation(String word, {String? fallback}) {
    final s = S.current;
    switch (word) {
      case 'sequel':
        return s.Rg_Rel_Sequel;
      case 'prequel':
        return s.Rg_Rel_Prequel;
      case 'alternative_setting':
        return s.Rg_Rel_Alternative_Setting;
      case 'alternative_version':
        return s.Rg_Rel_Alternative_Version;
      case 'side_story':
        return s.Rg_Rel_Side_Story;
      case 'parent_story':
        return s.Rg_Rel_Parent_Story;
      case 'summary':
        return s.Rg_Rel_Summary;
      case 'full_story':
        return s.Rg_Rel_Full_Story;
      case 'spin_off':
        return s.Rg_Rel_Spin_Off;
      case 'character':
        return s.Rg_Rel_Character;
      case 'other':
        return s.Rg_Rel_Other;
      case 'adaptation':
        return s.Rg_Rel_Adaptation;
    }
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return humanize(word);
  }

  /// `tv`, `ova`, `movie`… ; short acronyms stay upper case.
  static String mediaType(String? word) {
    if (word == null || word.isEmpty) return '';
    final s = S.current;
    switch (word) {
      case 'movie':
        return s.Rg_Type_Movie;
      case 'special':
        return s.Rg_Type_Special;
      case 'music':
        return s.Rg_Type_Music;
      case 'manga':
        return s.Rg_Type_Manga;
      case 'novel':
        return s.Rg_Type_Novel;
      case 'light_novel':
        return s.Rg_Type_Light_Novel;
      case 'one_shot':
        return s.Rg_Type_One_Shot;
    }
    return word.length <= 4 ? word.toUpperCase() : humanize(word);
  }

  /// The airing status (`finished_airing`, `currently_airing`, `not_yet_aired`).
  static String airing(String? word) {
    if (word == null || word.isEmpty) return '';
    final s = S.current;
    switch (word) {
      case 'finished_airing':
        return s.Rg_Airing_Finished;
      case 'currently_airing':
        return s.Rg_Airing_Current;
      case 'not_yet_aired':
        return s.Rg_Airing_Upcoming;
    }
    return humanize(word);
  }

  /// "Winter 2019"; just the year or the season when the other one is missing, '' when both are.
  static String season(String? season, int? year) {
    final s = S.current;
    final name = switch (season) {
      'winter' => s.Rg_Season_Winter,
      'spring' => s.Rg_Season_Spring,
      'summer' => s.Rg_Season_Summer,
      'fall' => s.Rg_Season_Fall,
      _ => '',
    };
    if (name.isEmpty) return year?.toString() ?? '';
    return year == null ? name : '$name $year';
  }
}
