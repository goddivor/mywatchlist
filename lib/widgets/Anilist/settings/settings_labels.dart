import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';

/// Translated names of AniList's enums, kept out of the page.
class AnilistSettingsLabels {
  const AnilistSettingsLabels._();

  static String titleLanguage(AnilistTitleLanguage v) => switch (v) {
        AnilistTitleLanguage.romaji => S.current.Als_Tl_Romaji,
        AnilistTitleLanguage.english => S.current.Als_Tl_English,
        AnilistTitleLanguage.native => S.current.Als_Tl_Native,
        AnilistTitleLanguage.romajiStylised => S.current.Als_Tl_Romaji_Styl,
        AnilistTitleLanguage.englishStylised => S.current.Als_Tl_English_Styl,
        AnilistTitleLanguage.nativeStylised => S.current.Als_Tl_Native_Styl,
      };

  static String staffLanguage(AnilistStaffNameLanguage v) => switch (v) {
        AnilistStaffNameLanguage.romajiWestern => S.current.Als_Sl_Western,
        AnilistStaffNameLanguage.romaji => S.current.Als_Sl_Romaji,
        AnilistStaffNameLanguage.native => S.current.Als_Sl_Native,
      };

  static String scoreFormat(AnilistScoreFormat v) => switch (v) {
        AnilistScoreFormat.point100 => S.current.Als_Sf_100,
        AnilistScoreFormat.point10Decimal => S.current.Als_Sf_10_Decimal,
        AnilistScoreFormat.point10 => S.current.Als_Sf_10,
        AnilistScoreFormat.point5 => S.current.Als_Sf_5,
        AnilistScoreFormat.point3 => S.current.Als_Sf_3,
      };

  /// `score`, `title`, `updatedAt`, `id`.
  static const List<String> rowOrders = ['score', 'title', 'updatedAt', 'id'];

  static String rowOrder(String v) => switch (v) {
        'score' => S.current.Als_Ro_Score,
        'updatedAt' => S.current.Als_Ro_Updated,
        'id' => S.current.Als_Ro_Id,
        _ => S.current.Als_Ro_Title,
      };

  static const List<String> profileColors = [
    'blue', 'purple', 'pink', 'orange', 'red', 'green', 'gray',
  ];

  static String profileColor(String v) => switch (v) {
        'blue' => S.current.Als_Color_blue,
        'purple' => S.current.Als_Color_purple,
        'pink' => S.current.Als_Color_pink,
        'orange' => S.current.Als_Color_orange,
        'red' => S.current.Als_Color_red,
        'green' => S.current.Als_Color_green,
        'gray' => S.current.Als_Color_gray,
        _ => v,
      };

  /// Activity merge choices in minutes (0 never, 29160 always), as the site offers them.
  static const List<int> mergeTimes = [0, 30, 60, 120, 180, 360, 720, 1440, 2880, 4320, 10080, 20160, 29160];

  static String mergeTime(int minutes) {
    if (minutes == 0) return S.current.Als_Mt_Never;
    if (minutes >= 29160) return S.current.Als_Mt_Always;
    if (minutes < 60) return S.current.Als_Mt_Minutes(minutes);
    if (minutes < 1440) return S.current.Als_Mt_Hours(minutes ~/ 60);
    if (minutes < 10080) return S.current.Als_Mt_Days(minutes ~/ 1440);
    return S.current.Als_Mt_Weeks(minutes ~/ 10080);
  }

  /// Offsets from -12:00 to +14:00 (hours, plus the usual half hours).
  static final List<String> timezones = () {
    String fmt(int mins) {
      final sign = mins < 0 ? '-' : '+';
      final a = mins.abs();
      return '$sign${(a ~/ 60).toString().padLeft(2, '0')}:${(a % 60).toString().padLeft(2, '0')}';
    }

    final all = <int>{for (var h = -12; h <= 14; h++) h * 60, 210, 270, 330, 345, 570, 630, -210, -570}.toList()
      ..sort();
    return [for (final m in all) fmt(m)];
  }();

  static String timezone(String v) => v.isEmpty ? S.current.Als_Timezone_None : 'UTC$v';

  static String notification(String type) => switch (type) {
        'AIRING' => S.current.Als_Nt_AIRING,
        'FOLLOWING' => S.current.Als_Nt_FOLLOWING,
        'ACTIVITY_MESSAGE' => S.current.Als_Nt_ACTIVITY_MESSAGE,
        'ACTIVITY_REPLY' => S.current.Als_Nt_ACTIVITY_REPLY,
        'ACTIVITY_REPLY_SUBSCRIBED' => S.current.Als_Nt_ACTIVITY_REPLY_SUBSCRIBED,
        'ACTIVITY_MENTION' => S.current.Als_Nt_ACTIVITY_MENTION,
        'ACTIVITY_LIKE' => S.current.Als_Nt_ACTIVITY_LIKE,
        'ACTIVITY_REPLY_LIKE' => S.current.Als_Nt_ACTIVITY_REPLY_LIKE,
        'THREAD_COMMENT_MENTION' => S.current.Als_Nt_THREAD_COMMENT_MENTION,
        'THREAD_COMMENT_REPLY' => S.current.Als_Nt_THREAD_COMMENT_REPLY,
        'THREAD_SUBSCRIBED' => S.current.Als_Nt_THREAD_SUBSCRIBED,
        'THREAD_LIKE' => S.current.Als_Nt_THREAD_LIKE,
        'THREAD_COMMENT_LIKE' => S.current.Als_Nt_THREAD_COMMENT_LIKE,
        'RELATED_MEDIA_ADDITION' => S.current.Als_Nt_RELATED_MEDIA_ADDITION,
        'MEDIA_DATA_CHANGE' => S.current.Als_Nt_MEDIA_DATA_CHANGE,
        'MEDIA_MERGE' => S.current.Als_Nt_MEDIA_MERGE,
        'MEDIA_DELETION' => S.current.Als_Nt_MEDIA_DELETION,
        'MEDIA_SUBMISSION_UPDATE' => S.current.Als_Nt_MEDIA_SUBMISSION_UPDATE,
        'STAFF_SUBMISSION_UPDATE' => S.current.Als_Nt_STAFF_SUBMISSION_UPDATE,
        'CHARACTER_SUBMISSION_UPDATE' => S.current.Als_Nt_CHARACTER_SUBMISSION_UPDATE,
        _ => type,
      };

  static String activityStatus(String status) => switch (status) {
        'CURRENT' => S.current.Als_St_CURRENT,
        'PLANNING' => S.current.Als_St_PLANNING,
        'COMPLETED' => S.current.Als_St_COMPLETED,
        'DROPPED' => S.current.Als_St_DROPPED,
        'PAUSED' => S.current.Als_St_PAUSED,
        _ => S.current.Als_St_REPEATING,
      };
}
