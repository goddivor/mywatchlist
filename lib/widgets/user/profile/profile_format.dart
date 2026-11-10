import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart' show mediaTypeLabel;

/// Number formatting and labels of the profile screens, in the app language (`S.load` sets
/// `Intl.defaultLocale`, so 8.9 reads "8,90" in French and 1234 "1 234").

/// [value] with the locale's grouping and decimal separator, and exactly [digits] decimals.
String profileNumber(num value, {int digits = 0}) {
  final format = NumberFormat.decimalPattern()
    ..minimumFractionDigits = digits
    ..maximumFractionDigits = digits;
  return format.format(value);
}

/// A mean score (two decimals), or a dash when there is none.
String profileMean(double? mean) =>
    (mean ?? 0) > 0 ? profileNumber(mean!, digits: 2) : S.current.Pp_No_Value;

/// MyAnimeList's gender ("Male", "Female", "Non-Binary") in the app language; any other
/// value is shown as MAL gives it.
String profileGenderLabel(String gender) =>
    switch (gender.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      'male' => S.current.Pp_Gender_Male,
      'female' => S.current.Pp_Gender_Female,
      'nonbinary' => S.current.Pp_Gender_Non_Binary,
      _ => gender,
    };

/// A media type of a list row (`tv`, `light_novel`…), translated.
String profileMediaTypeLabel(String type) => mediaTypeLabel(type.toLowerCase());

/// An anime source (`light_novel`, `4_koma_manga`…), translated; unknown values are made
/// readable ("some_value" → "Some value").
String profileSourceLabel(String source) => switch (source.toLowerCase()) {
      'original' => S.current.Mi_Source_Original,
      'manga' => S.current.Mi_Source_Manga,
      '4_koma_manga' => S.current.Mi_Source_Four_Koma,
      'web_manga' => S.current.Mi_Source_Web_Manga,
      'digital_manga' => S.current.Mi_Source_Digital_Manga,
      'novel' => S.current.Mi_Source_Novel,
      'light_novel' => S.current.Mi_Source_Light_Novel,
      'visual_novel' => S.current.Mi_Source_Visual_Novel,
      'game' => S.current.Mi_Source_Game,
      'card_game' => S.current.Mi_Source_Card_Game,
      'book' => S.current.Mi_Source_Book,
      'picture_book' => S.current.Mi_Source_Picture_Book,
      'radio' => S.current.Mi_Source_Radio,
      'music' => S.current.Mi_Source_Music,
      'web_novel' => S.current.Mi_Source_Web_Novel,
      'mixed_media' => S.current.Mi_Source_Mixed_Media,
      'other' => S.current.Mi_Source_Other,
      _ => _readable(source),
    };

String _readable(String raw) {
  final text = raw.replaceAll('_', ' ').trim();
  return text.isEmpty ? raw : '${text[0].toUpperCase()}${text.substring(1)}';
}
