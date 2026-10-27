// ignore_for_file: constant_identifier_names

import 'package:equatable/equatable.dart';
import 'package:mwl_commons/mwl_commons.dart' show LinkType;
import 'package:mywatchlist/constants/constants.dart' show DisplayType, TitleLang;
import 'package:mywatchlist/user/preferences/json_read.dart';

/// Page shown when the app opens (DAL `startUpPageMobile` / `startUpPageTablet`).
///
/// The app shell maps each value to its own destination and falls back to [home] when a
/// destination does not exist on the current layout or tracker.
enum StartupPage { home, explore, userList, forum, profile, calendar, search }

/// Number of list statuses drawn in the stats chart (watching, completed, on hold, dropped,
/// plan to watch), in that order.
const int statsChartColorCount = 5;

/// A stats chart colour slot left to the theme.
const int themeChartColor = -1;

/// User preferences of DailyAL's "User preferences" page (DAL `UserPreferences`).
///
/// Language, theme, font and background live in `LanguageBloc` / `ThemeBloc`; the home page
/// layout lives in `HomePreferencesBloc`. Everything else DAL keeps in its user preferences is
/// here.
class GeneralPreferences extends Equatable {
  /// Title shown for an anime or a manga everywhere (DAL `preferredAnimeTitle`, default Romaji).
  final TitleLang preferredTitle;
  final StartupPage startupPage;

  /// Show adult (NSFW) entries in search, rankings and seasonal lists.
  final bool nsfw;

  /// Show the anime/manga info card on list and search tiles.
  final bool showAnimeMangaCard;

  /// Play trailers in the embedded YouTube player instead of opening YouTube.
  final bool allowYoutubePlayer;
  final bool keepPagesInMemory;

  /// Show the priority of each entry in the user list.
  final bool showPriority;
  final bool autoTranslateSynopsis;

  /// Home page quote widget shows only the last quote.
  final bool showOnlyLastQuote;

  /// Set the start date when an entry moves to watching/reading and the finish date when it
  /// moves to completed.
  final bool autoAddStartEndDate;

  /// Show the next episode and its countdown in the user list.
  final bool showAiringInfo;

  /// ARGB colour per list status in the stats chart ([statsChartColorCount] slots,
  /// [themeChartColor] = theme colour).
  final List<int> statsChartColors;

  /// Link group opened first in the "Available at" section of a detail page.
  final LinkType preferredLinkType;

  /// Detail page sections start expanded.
  final bool detailsExpanded;

  /// Display used by search and list pages until the user picks another one.
  final DisplayType defaultDisplayType;

  /// Sort field of the user's anime / manga list (MAL API name, e.g. `list_updated_at`).
  final String userListAnimeSort;
  final String userListMangaSort;

  /// Dub information (DAL "Dub" settings).
  final bool showDubStatus;
  final String dubLanguage;
  final int dubIconStyle;
  final int dubMinSourceCount;

  const GeneralPreferences({
    this.preferredTitle = TitleLang.ro,
    this.startupPage = StartupPage.home,
    this.nsfw = false,
    this.showAnimeMangaCard = false,
    this.allowYoutubePlayer = false,
    this.keepPagesInMemory = false,
    this.showPriority = false,
    this.autoTranslateSynopsis = false,
    this.showOnlyLastQuote = true,
    this.autoAddStartEndDate = true,
    this.showAiringInfo = false,
    this.statsChartColors = const [
      themeChartColor,
      themeChartColor,
      themeChartColor,
      themeChartColor,
      themeChartColor,
    ],
    this.preferredLinkType = LinkType.streaming,
    this.detailsExpanded = true,
    this.defaultDisplayType = DisplayType.list_vert,
    this.userListAnimeSort = 'list_updated_at',
    this.userListMangaSort = 'list_updated_at',
    this.showDubStatus = false,
    this.dubLanguage = 'english',
    this.dubIconStyle = 0,
    this.dubMinSourceCount = 1,
  });

  /// Colour of stats chart slot [index], or null when the theme colour applies.
  int? statsChartColor(int index) {
    if (index < 0 || index >= statsChartColors.length) return null;
    final color = statsChartColors[index];
    return color == themeChartColor ? null : color;
  }

  GeneralPreferences copyWith({
    TitleLang? preferredTitle,
    StartupPage? startupPage,
    bool? nsfw,
    bool? showAnimeMangaCard,
    bool? allowYoutubePlayer,
    bool? keepPagesInMemory,
    bool? showPriority,
    bool? autoTranslateSynopsis,
    bool? showOnlyLastQuote,
    bool? autoAddStartEndDate,
    bool? showAiringInfo,
    List<int>? statsChartColors,
    LinkType? preferredLinkType,
    bool? detailsExpanded,
    DisplayType? defaultDisplayType,
    String? userListAnimeSort,
    String? userListMangaSort,
    bool? showDubStatus,
    String? dubLanguage,
    int? dubIconStyle,
    int? dubMinSourceCount,
  }) {
    return GeneralPreferences(
      preferredTitle: preferredTitle ?? this.preferredTitle,
      startupPage: startupPage ?? this.startupPage,
      nsfw: nsfw ?? this.nsfw,
      showAnimeMangaCard: showAnimeMangaCard ?? this.showAnimeMangaCard,
      allowYoutubePlayer: allowYoutubePlayer ?? this.allowYoutubePlayer,
      keepPagesInMemory: keepPagesInMemory ?? this.keepPagesInMemory,
      showPriority: showPriority ?? this.showPriority,
      autoTranslateSynopsis: autoTranslateSynopsis ?? this.autoTranslateSynopsis,
      showOnlyLastQuote: showOnlyLastQuote ?? this.showOnlyLastQuote,
      autoAddStartEndDate: autoAddStartEndDate ?? this.autoAddStartEndDate,
      showAiringInfo: showAiringInfo ?? this.showAiringInfo,
      statsChartColors: statsChartColors != null
          ? List.unmodifiable(_normalizeChartColors(statsChartColors))
          : this.statsChartColors,
      preferredLinkType: preferredLinkType ?? this.preferredLinkType,
      detailsExpanded: detailsExpanded ?? this.detailsExpanded,
      defaultDisplayType: defaultDisplayType ?? this.defaultDisplayType,
      userListAnimeSort: userListAnimeSort ?? this.userListAnimeSort,
      userListMangaSort: userListMangaSort ?? this.userListMangaSort,
      showDubStatus: showDubStatus ?? this.showDubStatus,
      dubLanguage: dubLanguage ?? this.dubLanguage,
      dubIconStyle: dubIconStyle ?? this.dubIconStyle,
      dubMinSourceCount: dubMinSourceCount ?? this.dubMinSourceCount,
    );
  }

  /// Returns a copy with chart slot [index] set to [color] (null = theme colour).
  GeneralPreferences withStatsChartColor(int index, int? color) {
    final colors = List<int>.of(statsChartColors);
    if (index < 0 || index >= colors.length) return this;
    colors[index] = color ?? themeChartColor;
    return copyWith(statsChartColors: colors);
  }

  Map<String, dynamic> toJson() => {
        'preferredTitle': preferredTitle.name,
        'startupPage': startupPage.name,
        'nsfw': nsfw,
        'showAnimeMangaCard': showAnimeMangaCard,
        'allowYoutubePlayer': allowYoutubePlayer,
        'keepPagesInMemory': keepPagesInMemory,
        'showPriority': showPriority,
        'autoTranslateSynopsis': autoTranslateSynopsis,
        'showOnlyLastQuote': showOnlyLastQuote,
        'autoAddStartEndDate': autoAddStartEndDate,
        'showAiringInfo': showAiringInfo,
        'statsChartColors': statsChartColors,
        'preferredLinkType': preferredLinkType.name,
        'detailsExpanded': detailsExpanded,
        'defaultDisplayType': defaultDisplayType.name,
        'userListAnimeSort': userListAnimeSort,
        'userListMangaSort': userListMangaSort,
        'showDubStatus': showDubStatus,
        'dubLanguage': dubLanguage,
        'dubIconStyle': dubIconStyle,
        'dubMinSourceCount': dubMinSourceCount,
      };

  factory GeneralPreferences.fromJson(Map<String, dynamic> json) {
    const d = GeneralPreferences();
    return GeneralPreferences(
      preferredTitle: readEnum(json, 'preferredTitle', TitleLang.values, d.preferredTitle),
      startupPage: readEnum(json, 'startupPage', StartupPage.values, d.startupPage),
      nsfw: readBool(json, 'nsfw', d.nsfw),
      showAnimeMangaCard: readBool(json, 'showAnimeMangaCard', d.showAnimeMangaCard),
      allowYoutubePlayer: readBool(json, 'allowYoutubePlayer', d.allowYoutubePlayer),
      keepPagesInMemory: readBool(json, 'keepPagesInMemory', d.keepPagesInMemory),
      showPriority: readBool(json, 'showPriority', d.showPriority),
      autoTranslateSynopsis: readBool(json, 'autoTranslateSynopsis', d.autoTranslateSynopsis),
      showOnlyLastQuote: readBool(json, 'showOnlyLastQuote', d.showOnlyLastQuote),
      autoAddStartEndDate: readBool(json, 'autoAddStartEndDate', d.autoAddStartEndDate),
      showAiringInfo: readBool(json, 'showAiringInfo', d.showAiringInfo),
      statsChartColors: List.unmodifiable(
          _normalizeChartColors(readIntList(json, 'statsChartColors', d.statsChartColors))),
      preferredLinkType:
          readEnum(json, 'preferredLinkType', LinkType.values, d.preferredLinkType),
      detailsExpanded: readBool(json, 'detailsExpanded', d.detailsExpanded),
      defaultDisplayType:
          readEnum(json, 'defaultDisplayType', DisplayType.values, d.defaultDisplayType),
      userListAnimeSort: readString(json, 'userListAnimeSort', d.userListAnimeSort),
      userListMangaSort: readString(json, 'userListMangaSort', d.userListMangaSort),
      showDubStatus: readBool(json, 'showDubStatus', d.showDubStatus),
      dubLanguage: readString(json, 'dubLanguage', d.dubLanguage),
      dubIconStyle: readInt(json, 'dubIconStyle', d.dubIconStyle),
      dubMinSourceCount: readInt(json, 'dubMinSourceCount', d.dubMinSourceCount),
    );
  }

  /// Exactly [statsChartColorCount] slots: extra ones dropped, missing ones left to the theme.
  static List<int> _normalizeChartColors(List<int> colors) => List.generate(
        statsChartColorCount,
        (i) => i < colors.length ? colors[i] : themeChartColor,
      );

  @override
  List<Object?> get props => [
        preferredTitle,
        startupPage,
        nsfw,
        showAnimeMangaCard,
        allowYoutubePlayer,
        keepPagesInMemory,
        showPriority,
        autoTranslateSynopsis,
        showOnlyLastQuote,
        autoAddStartEndDate,
        showAiringInfo,
        statsChartColors,
        preferredLinkType,
        detailsExpanded,
        defaultDisplayType,
        userListAnimeSort,
        userListMangaSort,
        showDubStatus,
        dubLanguage,
        dubIconStyle,
        dubMinSourceCount,
      ];
}
