import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';

/// AniList's `UserTitleLanguage`.
enum AnilistTitleLanguage {
  romaji('ROMAJI'),
  english('ENGLISH'),
  native('NATIVE'),
  romajiStylised('ROMAJI_STYLISED'),
  englishStylised('ENGLISH_STYLISED'),
  nativeStylised('NATIVE_STYLISED');

  const AnilistTitleLanguage(this.value);
  final String value;

  static AnilistTitleLanguage parse(Object? raw) => values.firstWhere(
        (v) => v.value == raw,
        orElse: () => AnilistTitleLanguage.romaji,
      );
}

/// AniList's `UserStaffNameLanguage`.
enum AnilistStaffNameLanguage {
  romajiWestern('ROMAJI_WESTERN'),
  romaji('ROMAJI'),
  native('NATIVE');

  const AnilistStaffNameLanguage(this.value);
  final String value;

  static AnilistStaffNameLanguage parse(Object? raw) => values.firstWhere(
        (v) => v.value == raw,
        orElse: () => AnilistStaffNameLanguage.romajiWestern,
      );
}

/// AniList's `ScoreFormat`.
enum AnilistScoreFormat {
  point100('POINT_100'),
  point10Decimal('POINT_10_DECIMAL'),
  point10('POINT_10'),
  point5('POINT_5'),
  point3('POINT_3');

  const AnilistScoreFormat(this.value);
  final String value;

  static AnilistScoreFormat parse(Object? raw) => values.firstWhere(
        (v) => v.value == raw,
        orElse: () => AnilistScoreFormat.point10,
      );
}

/// AniList's `NotificationType`, in the order the site shows them.
const List<String> anilistNotificationTypes = [
  'AIRING',
  'FOLLOWING',
  'ACTIVITY_MESSAGE',
  'ACTIVITY_REPLY',
  'ACTIVITY_REPLY_SUBSCRIBED',
  'ACTIVITY_MENTION',
  'ACTIVITY_LIKE',
  'ACTIVITY_REPLY_LIKE',
  'THREAD_COMMENT_MENTION',
  'THREAD_COMMENT_REPLY',
  'THREAD_SUBSCRIBED',
  'THREAD_LIKE',
  'THREAD_COMMENT_LIKE',
  'RELATED_MEDIA_ADDITION',
  'MEDIA_DATA_CHANGE',
  'MEDIA_MERGE',
  'MEDIA_DELETION',
  'MEDIA_SUBMISSION_UPDATE',
  'STAFF_SUBMISSION_UPDATE',
  'CHARACTER_SUBMISSION_UPDATE',
];

/// The list statuses whose activity can be switched off (`ListActivityOption.type`).
const List<String> anilistActivityStatuses = [
  'CURRENT',
  'PLANNING',
  'COMPLETED',
  'DROPPED',
  'PAUSED',
  'REPEATING',
];

/// The options of one list kind (`MediaListTypeOptions`).
@immutable
class AnilistListTypeOptions {
  final List<String> sectionOrder;
  final bool splitCompletedSectionByFormat;
  final List<String> customLists;
  final List<String> advancedScoring;
  final bool advancedScoringEnabled;

  const AnilistListTypeOptions({
    this.sectionOrder = const [],
    this.splitCompletedSectionByFormat = false,
    this.customLists = const [],
    this.advancedScoring = const [],
    this.advancedScoringEnabled = false,
  });

  factory AnilistListTypeOptions.fromJson(Map<String, dynamic>? json) {
    List<String> strings(Object? raw) =>
        raw is List ? [for (final e in raw) if (e is String) e] : const [];
    if (json == null) return const AnilistListTypeOptions();
    return AnilistListTypeOptions(
      sectionOrder: strings(json['sectionOrder']),
      splitCompletedSectionByFormat: json['splitCompletedSectionByFormat'] == true,
      customLists: strings(json['customLists']),
      advancedScoring: strings(json['advancedScoring']),
      advancedScoringEnabled: json['advancedScoringEnabled'] == true,
    );
  }
}

/// Everything the AniList settings page edits: `Viewer.options`, `Viewer.mediaListOptions`
/// and the profile text.
@immutable
class AnilistSettings {
  final AnilistTitleLanguage titleLanguage;
  final AnilistStaffNameLanguage staffNameLanguage;
  final bool displayAdultContent;
  final bool includeAdultContentInSearch;
  final bool includeAdultContentInQuickSearch;
  final bool displayAdultActivities;
  final bool airingNotifications;

  /// Notification type to enabled (only the types AniList reported).
  final Map<String, bool> notificationOptions;

  /// Offset such as `-05:00`, empty when none is set.
  final String timezone;

  /// Minutes, 0 = never merge, 29160 = always.
  final int activityMergeTime;
  final bool restrictMessagesToFollowing;

  /// List status to "activity disabled".
  final Map<String, bool> disabledListActivity;
  final String profileColor;
  final String about;
  final int donatorTier;
  final String donatorBadge;
  final AnilistScoreFormat scoreFormat;

  /// `score`, `title`, `updatedAt` or `id`.
  final String rowOrder;
  final AnilistListTypeOptions anime;
  final AnilistListTypeOptions manga;

  const AnilistSettings({
    this.titleLanguage = AnilistTitleLanguage.romaji,
    this.staffNameLanguage = AnilistStaffNameLanguage.romajiWestern,
    this.displayAdultContent = false,
    this.includeAdultContentInSearch = false,
    this.includeAdultContentInQuickSearch = false,
    this.displayAdultActivities = false,
    this.airingNotifications = true,
    this.notificationOptions = const {},
    this.timezone = '',
    this.activityMergeTime = 0,
    this.restrictMessagesToFollowing = false,
    this.disabledListActivity = const {},
    this.profileColor = 'blue',
    this.about = '',
    this.donatorTier = 0,
    this.donatorBadge = '',
    this.scoreFormat = AnilistScoreFormat.point10,
    this.rowOrder = 'title',
    this.anime = const AnilistListTypeOptions(),
    this.manga = const AnilistListTypeOptions(),
  });

  /// Reads the `Viewer` object selected by [AnilistSettingsService.selection].
  factory AnilistSettings.fromViewer(Map<String, dynamic> viewer) {
    final options = viewer['options'] as Map<String, dynamic>? ?? const {};
    final lists = viewer['mediaListOptions'] as Map<String, dynamic>? ?? const {};
    Map<String, bool> flags(Object? raw, String flag) => {
          if (raw is List)
            for (final e in raw)
              if (e is Map && e['type'] is String) e['type'] as String: e[flag] == true,
        };
    return AnilistSettings(
      titleLanguage: AnilistTitleLanguage.parse(options['titleLanguage']),
      staffNameLanguage: AnilistStaffNameLanguage.parse(options['staffNameLanguage']),
      displayAdultContent: options['displayAdultContent'] == true,
      includeAdultContentInSearch: options['includeAdultContentInSearch'] == true,
      includeAdultContentInQuickSearch: options['includeAdultContentInQuickSearch'] == true,
      displayAdultActivities: options['displayAdultActivities'] == true,
      airingNotifications: options['airingNotifications'] != false,
      notificationOptions: flags(options['notificationOptions'], 'enabled'),
      timezone: options['timezone'] as String? ?? '',
      activityMergeTime: (options['activityMergeTime'] as num?)?.toInt() ?? 0,
      restrictMessagesToFollowing: options['restrictMessagesToFollowing'] == true,
      disabledListActivity: flags(options['disabledListActivity'], 'disabled'),
      profileColor: options['profileColor'] as String? ?? 'blue',
      about: viewer['about'] as String? ?? '',
      donatorTier: (viewer['donatorTier'] as num?)?.toInt() ?? 0,
      donatorBadge: viewer['donatorBadge'] as String? ?? '',
      scoreFormat: AnilistScoreFormat.parse(lists['scoreFormat']),
      rowOrder: lists['rowOrder'] as String? ?? 'title',
      anime: AnilistListTypeOptions.fromJson(lists['animeList'] as Map<String, dynamic>?),
      manga: AnilistListTypeOptions.fromJson(lists['mangaList'] as Map<String, dynamic>?),
    );
  }
}

/// Reads and writes the signed-in user's AniList settings (`Viewer`, `UpdateUser`,
/// `DeleteCustomList`, `Markdown`). Writes go through [AnilistGraphql.mutate]; nothing here
/// is called with a real account in tests.
class AnilistSettingsService {
  AnilistSettingsService({AnilistGraphql? client}) : _client = client;

  /// The service the settings page uses; tests replace it.
  static AnilistSettingsService instance = AnilistSettingsService();

  final AnilistGraphql? _client;
  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  /// The `Viewer` selection both [load] and [update] ask for.
  static const String selection = '''
about donatorTier donatorBadge
options {
  titleLanguage staffNameLanguage displayAdultContent includeAdultContentInSearch
  includeAdultContentInQuickSearch displayAdultActivities airingNotifications profileColor
  timezone activityMergeTime restrictMessagesToFollowing
  notificationOptions { type enabled }
  disabledListActivity { type disabled }
}
mediaListOptions {
  scoreFormat rowOrder
  animeList { sectionOrder splitCompletedSectionByFormat customLists advancedScoring advancedScoringEnabled }
  mangaList { sectionOrder splitCompletedSectionByFormat customLists advancedScoring advancedScoringEnabled }
}''';

  Future<AnilistSettings> load() async {
    final data = await _gql.query('query { Viewer { $selection } }', auth: true);
    return _read(data['Viewer']);
  }

  /// Sends only the fields given (null = unchanged) in one `UpdateUser` and returns the
  /// settings as AniList now stores them. [animeListOptions] / [mangaListOptions] are
  /// `MediaListOptionsInput` maps; [notificationOptions] / [disabledListActivity] hold the
  /// changed entries only.
  Future<AnilistSettings> update({
    String? about,
    AnilistTitleLanguage? titleLanguage,
    AnilistStaffNameLanguage? staffNameLanguage,
    bool? displayAdultContent,
    bool? includeAdultContentInSearch,
    bool? includeAdultContentInQuickSearch,
    bool? displayAdultActivities,
    bool? airingNotifications,
    AnilistScoreFormat? scoreFormat,
    String? rowOrder,
    String? profileColor,
    String? donatorBadge,
    String? timezone,
    int? activityMergeTime,
    bool? restrictMessagesToFollowing,
    Map<String, bool>? notificationOptions,
    Map<String, bool>? disabledListActivity,
    Map<String, Object?>? animeListOptions,
    Map<String, Object?>? mangaListOptions,
  }) async {
    final vars = <String, GqlVar>{
      if (about != null) 'about': GqlVar('String', about),
      if (titleLanguage != null) 'titleLanguage': GqlVar('UserTitleLanguage', titleLanguage.value),
      if (staffNameLanguage != null)
        'staffNameLanguage': GqlVar('UserStaffNameLanguage', staffNameLanguage.value),
      if (displayAdultContent != null) 'displayAdultContent': GqlVar('Boolean', displayAdultContent),
      if (includeAdultContentInSearch != null)
        'includeAdultContentInSearch': GqlVar('Boolean', includeAdultContentInSearch),
      if (includeAdultContentInQuickSearch != null)
        'includeAdultContentInQuickSearch': GqlVar('Boolean', includeAdultContentInQuickSearch),
      if (displayAdultActivities != null)
        'displayAdultActivities': GqlVar('Boolean', displayAdultActivities),
      if (airingNotifications != null) 'airingNotifications': GqlVar('Boolean', airingNotifications),
      if (scoreFormat != null) 'scoreFormat': GqlVar('ScoreFormat', scoreFormat.value),
      if (rowOrder != null) 'rowOrder': GqlVar('String', rowOrder),
      if (profileColor != null) 'profileColor': GqlVar('String', profileColor),
      if (donatorBadge != null) 'donatorBadge': GqlVar('String', donatorBadge),
      if (timezone != null) 'timezone': GqlVar('String', timezone),
      if (activityMergeTime != null) 'activityMergeTime': GqlVar('Int', activityMergeTime),
      if (restrictMessagesToFollowing != null)
        'restrictMessagesToFollowing': GqlVar('Boolean', restrictMessagesToFollowing),
      if (notificationOptions != null && notificationOptions.isNotEmpty)
        'notificationOptions': GqlVar('[NotificationOptionInput]', [
          for (final e in notificationOptions.entries) {'type': e.key, 'enabled': e.value},
        ]),
      if (disabledListActivity != null && disabledListActivity.isNotEmpty)
        'disabledListActivity': GqlVar('[ListActivityOptionInput]', [
          for (final e in disabledListActivity.entries) {'type': e.key, 'disabled': e.value},
        ]),
      if (animeListOptions != null) 'animeListOptions': GqlVar('MediaListOptionsInput', animeListOptions),
      if (mangaListOptions != null) 'mangaListOptions': GqlVar('MediaListOptionsInput', mangaListOptions),
    };
    if (vars.isEmpty) return load();
    final declared = vars.entries.map((e) => '\$${e.key}: ${e.value.type}').join(', ');
    final passed = vars.keys.map((k) => '$k: \$$k').join(', ');
    final data = await _gql.mutate(
      'mutation ($declared) { UpdateUser($passed) { $selection } }',
      variables: {for (final e in vars.entries) e.key: e.value.value},
    );
    return _read(data['UpdateUser']);
  }

  /// Adds [name] to the custom lists of [anime] (else manga). [current] is the existing
  /// names: `UpdateUser` replaces the whole array.
  Future<AnilistSettings> addCustomList(
    String name, {
    required bool anime,
    required List<String> current,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || current.contains(trimmed)) return load();
    final options = <String, Object?>{'customLists': [...current, trimmed]};
    return update(
      animeListOptions: anime ? options : null,
      mangaListOptions: anime ? null : options,
    );
  }

  /// `DeleteCustomList`: removes the list and every entry's membership of it.
  Future<AnilistSettings> deleteCustomList(String name, {required bool anime}) async {
    await _gql.mutate(
      r'mutation ($customList: String, $type: MediaType) { DeleteCustomList(customList: $customList, type: $type) { deleted } }',
      variables: {'customList': name, 'type': anime ? 'ANIME' : 'MANGA'},
    );
    return load();
  }

  /// Renders AniList-flavoured markdown (spoilers, `img(url)`, `~~~` centring…) to HTML with
  /// AniList's own `Markdown` query, so the preview matches the site.
  Future<String> previewMarkdown(String markdown) async {
    if (markdown.trim().isEmpty) return '';
    final data = await _gql.query(
      r'query ($markdown: String!) { Markdown(markdown: $markdown) { html } }',
      variables: {'markdown': markdown},
    );
    return (data['Markdown'] as Map?)?['html'] as String? ?? '';
  }

  AnilistSettings _read(Object? viewer) {
    if (viewer is! Map<String, dynamic>) throw const AnilistError(404, 'No viewer');
    return AnilistSettings.fromViewer(viewer);
  }
}
