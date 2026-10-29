import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';

/// Words and numbers of the Kitsu title page. Kitsu's enums (`FINISHED`, `SIDE_STORY`, `MOVIE`)
/// become translated labels; a value the app does not know is shown as Kitsu wrote it.
abstract final class KitsuMediaFormat {
  /// Kitsu's average rating is a percentage ("Community Approval"), shown as Kitsu does (`89%`).
  static String score(double averageRating) => '${averageRating.round()}%';

  static String count(int value) => NumberFormat.decimalPattern().format(value);

  static String users(int n) => S.current.Kmp_Users(n, count(n));
  static String favorites(int n) => S.current.Kmp_Favorites(n, count(n));
  static String likes(int n) => S.current.Kmp_Likes(n, count(n));
  static String comments(int n) => S.current.Kmp_Comments(n, count(n));
  static String ratings(int n) => S.current.Kmp_Ratings_Total(n, count(n));

  static String _words(String raw) {
    final text = raw.replaceAll('_', ' ').trim().toLowerCase();
    return text.isEmpty ? raw : text[0].toUpperCase() + text.substring(1);
  }

  static String status(String? raw, KitsuMediaKind kind) {
    if (raw == null) return '';
    return switch (raw.toUpperCase()) {
      'CURRENT' => kind == KitsuMediaKind.anime ? S.current.Kmp_Status_Airing : S.current.Kmp_Status_Publishing,
      'FINISHED' => S.current.Kmp_Status_Finished,
      'UPCOMING' || 'UNRELEASED' => S.current.Kmp_Status_Upcoming,
      'TBA' => S.current.Kmp_Status_Tba,
      _ => _words(raw),
    };
  }

  /// `TV`, `OVA`, `ONA` stay as they are; the others are translated.
  static String subtype(String? raw) {
    if (raw == null) return '';
    return switch (raw.toUpperCase()) {
      'MOVIE' => S.current.Kmp_Type_Movie,
      'SPECIAL' => S.current.Kmp_Type_Special,
      'MUSIC' => S.current.Kmp_Type_Music,
      'MANGA' => S.current.Kmp_Type_Manga,
      'NOVEL' => S.current.Kmp_Type_Novel,
      'ONESHOT' => S.current.Kmp_Type_Oneshot,
      'DOUJIN' => S.current.Kmp_Type_Doujin,
      'MANHWA' => S.current.Kmp_Type_Manhwa,
      'MANHUA' => S.current.Kmp_Type_Manhua,
      'TV' || 'OVA' || 'ONA' || 'OEL' => raw.toUpperCase(),
      _ => _words(raw),
    };
  }

  static String season(String? raw, DateTime? start) {
    if (raw == null) return '';
    final name = switch (raw.toUpperCase()) {
      'WINTER' => S.current.Kmp_Season_Winter,
      'SPRING' => S.current.Kmp_Season_Spring,
      'SUMMER' => S.current.Kmp_Season_Summer,
      'FALL' => S.current.Kmp_Season_Fall,
      _ => _words(raw),
    };
    return start == null ? name : '$name ${start.year}';
  }

  static String relation(String kind) => switch (kind.toUpperCase()) {
        'SEQUEL' => S.current.Kmp_Rel_Sequel,
        'PREQUEL' => S.current.Kmp_Rel_Prequel,
        'ALTERNATIVE_SETTING' => S.current.Kmp_Rel_Alt_Setting,
        'ALTERNATIVE_VERSION' => S.current.Kmp_Rel_Alt_Version,
        'SIDE_STORY' => S.current.Kmp_Rel_Side_Story,
        'PARENT_STORY' => S.current.Kmp_Rel_Parent_Story,
        'SUMMARY' => S.current.Kmp_Rel_Summary,
        'FULL_STORY' => S.current.Kmp_Rel_Full_Story,
        'SPIN_OFF' => S.current.Kmp_Rel_Spin_Off,
        'ADAPTATION' => S.current.Kmp_Rel_Adaptation,
        'CHARACTER' => S.current.Kmp_Rel_Character,
        'OTHER' => S.current.Kmp_Rel_Other,
        _ => _words(kind),
      };

  static String role(String raw) => switch (raw.toUpperCase()) {
        'MAIN' => S.current.Kmp_Role_Main,
        'RECURRING' => S.current.Kmp_Role_Recurring,
        'BACKGROUND' => S.current.Kmp_Role_Background,
        'CAMEO' => S.current.Kmp_Role_Cameo,
        _ => _words(raw),
      };

  /// `Episode 3` or `Chapter 3` (a volume when [volume]).
  static String unitName(KitsuMediaKind kind, int number, {bool volume = false}) {
    if (volume) return S.current.Kmp_Volume_N(number);
    return kind == KitsuMediaKind.anime ? S.current.Kmp_Episode_N(number) : S.current.Kmp_Chapter_N(number);
  }

  /// Minutes as `24 min` or `2 h 5 min`.
  static String minutes(int total) {
    if (total < 60) return S.current.Kmp_Minutes(total);
    return S.current.Kmp_Duration_Hm(total ~/ 60, total % 60);
  }

  static String date(DateTime? d) => d == null ? '' : DateFormat.yMMMd().format(d.toLocal());

  /// `Sep 29, 2023 – Mar 22, 2024` (just the start when the end is unknown or the same).
  static String span(DateTime? start, DateTime? end) {
    if (start == null) return '';
    if (end == null || end == start) return date(start);
    return '${date(start)} – ${date(end)}';
  }

  /// Site name and URL of an external id Kitsu maps, or null when the app has no web page for it.
  static ({String name, String? url}) externalSite(KitsuMapping m) {
    final id = m.externalId;
    switch (m.site) {
      case 'MYANIMELIST_ANIME':
        return (name: 'MyAnimeList', url: 'https://myanimelist.net/anime/$id');
      case 'MYANIMELIST_MANGA':
        return (name: 'MyAnimeList', url: 'https://myanimelist.net/manga/$id');
      case 'ANILIST_ANIME':
        return (name: 'AniList', url: 'https://anilist.co/anime/$id');
      case 'ANILIST_MANGA':
        return (name: 'AniList', url: 'https://anilist.co/manga/$id');
      case 'ANIDB':
        return (name: 'AniDB', url: 'https://anidb.net/anime/$id');
      case 'ANIMENEWSNETWORK':
        return (name: 'Anime News Network', url: 'https://www.animenewsnetwork.com/encyclopedia/anime.php?id=$id');
      default:
        final words = m.site.split('_').where((w) => w.isNotEmpty).map((w) => w[0] + w.substring(1).toLowerCase());
        return (name: words.where((w) => w != 'Anime' && w != 'Manga').join(' '), url: null);
    }
  }

  /// The Kitsu web page of a title.
  static String pageUrl(KitsuMediaKind kind, String slugOrId) => 'https://kitsu.app/${kind.path}/$slugOrId';
}
