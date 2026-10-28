import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

part 'explore_images_data.dart';

/// The pictures of DailyAL's Explore cards (rankings, genre groups, genres), bundled as app
/// assets under `assets/images/explore/` from DailyAL's `web_assets` (MIT licence, credited
/// through [registerLicense]). Identical pictures are stored once; every lookup returns null
/// when DailyAL has no picture for that card, and the card then keeps its tonal look.
abstract final class ExploreImages {
  static const String folder = 'assets/images/explore';
  static const String licenseAsset = '$folder/DAILYAL_LICENSE.txt';

  /// Every DailyAL picture is 225 px wide: decoding wider would only upscale.
  static const int sourceWidth = 225;

  /// Picture of a ranking card: [ranking] is the MAL ranking word (`all`, `airing`,
  /// `bypopularity`…), [category] `anime` or `manga`.
  static String? ranking(String ranking, String category) => _path('rank_${ranking}_$category');

  /// Picture of a genre group card (`Genres`, `Explicit Genres`, `Themes`, `Demographics`).
  static String? genreGroup(String type, String category) =>
      _path('group_${type.toLowerCase().replaceAll(' ', '_')}_$category');

  /// Picture of one MyAnimeList genre of [category].
  static String? genre(int id, String category) => _path('genre_${id}_$category');

  /// Every file the lookups can return (tests check they are all bundled).
  @visibleForTesting
  static Iterable<String> get allFiles => _exploreFiles.map((k) => '$folder/$k.jpg');

  /// Every alias target, so a test can check none points to a missing file.
  @visibleForTesting
  static Iterable<String> get aliasTargets => _exploreAliases.values;

  @visibleForTesting
  static bool hasFile(String key) => _exploreFiles.contains(key);

  static String? _path(String key) {
    final file = _exploreAliases[key] ?? key;
    return _exploreFiles.contains(file) ? '$folder/$file.jpg' : null;
  }

  static bool _registered = false;

  /// Adds DailyAL's MIT licence to the licences page (About > Licences). Safe to call more than
  /// once; the text is read from the bundled file only when that page is opened.
  static void registerLicense() {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(licenseAsset);
      yield LicenseEntryWithLineBreaks(const ['DailyAL (Explore pictures)'], text);
    });
  }
}
