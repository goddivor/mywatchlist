import 'package:mywatchlist/constants/constants.dart' show TitleLang;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';

/// Title of the page in the chosen language: romaji is MAL's main title;
/// English / Japanese fall back to the main title when MAL has none.
String resolveDetailTitle(DetailData data, TitleLang lang) {
  final content = data.content;
  final main = content?.title ?? data.node?.title;
  if (lang == TitleLang.ro) return main ?? '?';
  final alt = content?.alternativeTitles;
  if (alt == null) return '?';
  final localized = lang == TitleLang.en ? alt.en : alt.ja;
  if (localized == null || localized.isEmpty) {
    return data.node?.title ?? content?.title ?? '?';
  }
  return localized;
}
