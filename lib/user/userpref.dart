// ignore_for_file: no_leading_underscores_for_local_identifiers

// import 'dart:ui';

// import 'package:mywatchlist/constants/constants.dart';
// import 'package:mywatchlist/user/anime_manga_pref.dart';
// import 'package:mywatchlist/user/hompagepref.dart';

// class UserPreferences {
//   List<int> cacheUpdateFrequency;
//   bool firstTime;
//   bool showBg;
//   bool showCountDownInDetailed;
//   bool detailsExpanded;
//   bool nsfw;
//   bool keepPagesInMemory;
//   bool showPriority;
//   bool showOnlyLastQuote;
//   bool autoTranslateSynopsis;
//   bool autoAddStartEndDate;
//   bool showAiringInfo;
//   bool showAnimeMangaCard;
//   NotifPref notifPref;
//   List<HomePageApiPref> hpApiPrefList;
//   List<int> userchart;
//   int homePageItemsPerCategory;
//   String userLanguage;
//   Brightness brightness;
//   bool isRtl;
//   String? bgPath;
//   bool showAnimeMangaBg;
//   DisplayType defaultDisplayType;
//   FirstTimePref firstTimePref;
//   String userPageAnimeSortType;
//   String userPageMangaSortType;
//   HomePageTileSize homePageTileSize;
//   TitleLang preferredAnimeTitle;
//   AnimeMangaPagePreferences animeMangaPagePreferences;
//   int startUpPage;
//   LinkType preferredLinkType;
//   bool allowYoutubePlayer;
//   UserPreferences({
//     required this.firstTime,
//     required this.homePageTileSize,
//     required this.showCountDownInDetailed,
//     required this.cacheUpdateFrequency,
//     required this.homePageItemsPerCategory,
//     required this.showBg,
//     required this.detailsExpanded,
//     required this.keepPagesInMemory,
//     required this.nsfw,
//     required this.showPriority,
//     required this.userchart,
//     required this.userLanguage,
//     required this.showAiringInfo,
//     required this.isRtl,
//     required this.brightness,
//     required this.showAnimeMangaBg,
//     required this.bgPath,
//     required this.hpApiPrefList,
//     required this.autoTranslateSynopsis,
//     required this.showOnlyLastQuote,
//     required this.autoAddStartEndDate,
//     required this.defaultDisplayType,
//     required this.notifPref,
//     required this.userPageAnimeSortType,
//     required this.userPageMangaSortType,
//     required this.firstTimePref,
//     required this.preferredAnimeTitle,
//     required this.animeMangaPagePreferences,
//     required this.startUpPage,
//     required this.showAnimeMangaCard,
//     required this.preferredLinkType,
//     required this.allowYoutubePlayer,
//   });

//   factory UserPreferences.fromJson(Map<String, dynamic>? json) {
//     List<int>? _cacheUpdateFrequency;
//     List<HomePageApiPref>? _hpApiPrefList;
//     List<int>? _userchart;
//     int? _homePageItemsPerCategory;
//     NotifPref _notifPref = NotifPref();
//     bool _detailsExpanded = true,
//         _nsfw = false,
//         _keepPagesInMemory = false,
//         _showOnlyLastQuote = true,
//         _autoAddStartEndDate = true,
//         _showAiringInfo = false;
//     Brightness _brightness = Brightness.dark;
//     bool _showPriority = false,
//         _autoTranslateSynopsis = false,
//         _isRtl = false,
//         showAnimeMangaBg = true,
//         _showBg = true;
//     String? _userLanguage, _bgPath;
//     AnimeMangaPagePreferences? _animeMangaPagePreferences;
//     if (json != null) {
//       _cacheUpdateFrequency ??= List.from(json["cacheUpdateFrequency"] ?? [])
//           .map((e) => int.parse(e.toString()))
//           .toList();

//       if (json.containsKey("show_bg")) {
//         _showBg = json["show_bg"] ?? true;
//       }

//       if (json.containsKey("notifPref")) {
//         _notifPref = NotifPref.fromJson(json["notifPref"]);
//       }

//       if (json.containsKey("detailsExpanded")) {
//         _detailsExpanded = json["detailsExpanded"] ?? true;
//       }

//       if (json.containsKey("nsfw")) {
//         _nsfw = json["nsfw"] ?? false;
//       }

//       if (json.containsKey("keepPagesInMemory")) {
//         _keepPagesInMemory = json["keepPagesInMemory"] ?? true;
//       }

//       if (json.containsKey("hpApiPrefList_v6")) {
//         _hpApiPrefList = List.from(json["hpApiPrefList_v6"])
//             .map((e) => HomePageApiPref.fromJson(e))
//             .toList();
//       }

//       if (json.containsKey("userChart")) {
//         _userchart = json["userChart"] != null
//             ? List<int>.from(json["userChart"])
//             : [-1, -1, -1, -1, -1];
//       }

//       if (json.containsKey("homePageItemsPerCategory")) {
//         _homePageItemsPerCategory = json["homePageItemsPerCategory"] ?? 14;
//       }

//       if (json.containsKey("showPriority")) {
//         _showPriority = json["showPriority"] ?? false;
//       }
//       if (json.containsKey("userLanguage")) {
//         _userLanguage = json["userLanguage"] as String?;
//       }

//       if (json.containsKey("autoTranslateSynopsis")) {
//         _autoTranslateSynopsis = json["autoTranslateSynopsis"] ?? false;
//       }
//       if (json.containsKey("isRtl")) {
//         _isRtl = json["isRtl"] ?? false;
//       }
//       if (json.containsKey("showOnlyLastQuote")) {
//         _showOnlyLastQuote = json["showOnlyLastQuote"] ?? true;
//       }
//       if (json.containsKey("brightness")) {
//         _brightness =
//             (json["brightness"] ?? false) ? Brightness.light : Brightness.dark;
//       }
//       if (json.containsKey("bgPath")) {
//         _bgPath = json["bgPath"] as String?;
//       }
//       if (json.containsKey("autoAddStartEndDate")) {
//         _autoAddStartEndDate = json["autoAddStartEndDate"] ?? true;
//       }
//       if (json.containsKey("showAiringInfo_v2")) {
//         _showAiringInfo = json["showAiringInfo_v2"] ?? false;
//       }
//       if (json.containsKey("showAnimeMangaBg")) {
//         showAnimeMangaBg = json['showAnimeMangaBg'] ?? showAnimeMangaBg;
//       }
//       if (json.containsKey('animeMangaPagePreferences')) {
//         try {
//           _animeMangaPagePreferences = AnimeMangaPagePreferences.fromJson(
//               json['animeMangaPagePreferences']);
//         } catch (e) {
//           // logDal(e);
//         }
//       }
//     }
//     return json != null
//         ? UserPreferences(
//             showCountDownInDetailed: json['showCountDownInDetailed'] ?? true,
//             firstTime: json["first_time"] ?? true,
//             cacheUpdateFrequency: _cacheUpdateFrequency ?? [8, 2, 1],
//             showBg: _showBg,
//             detailsExpanded: _detailsExpanded,
//             nsfw: _nsfw,
//             userLanguage: _userLanguage ?? "en_US",
//             showPriority: _showPriority,
//             userchart: _userchart ?? [-1, -1, -1, -1, -1],
//             keepPagesInMemory: _keepPagesInMemory,
//             homePageItemsPerCategory: _homePageItemsPerCategory ?? 14,
//             hpApiPrefList: _hpApiPrefList ?? [],
//             autoTranslateSynopsis: _autoTranslateSynopsis,
//             isRtl: _isRtl,
//             showOnlyLastQuote: _showOnlyLastQuote,
//             bgPath: _bgPath,
//             autoAddStartEndDate: _autoAddStartEndDate,
//             brightness: _brightness,
//             notifPref: _notifPref,
//             showAiringInfo: _showAiringInfo,
//             showAnimeMangaBg: showAnimeMangaBg,
//             userPageAnimeSortType:
//                 json['userPageAnimeSortType'] ?? 'list_updated_at',
//             userPageMangaSortType:
//                 json['userPageMangaSortType'] ?? 'list_updated_at',
//             defaultDisplayType:
//                 DisplayType.values.elementAt(json['defaultDisplayType'] ?? 0),
//             homePageTileSize: json['homePageTileSize'] != null
//                 ? HomePageTileSize.values.elementAt(json['homePageTileSize'])
//                 : HomePageTileSize.l,
//             firstTimePref: FirstTimePref.fromJson(json['firstTimePref']),
//             preferredAnimeTitle: TitleLang.values
//                 .elementAt(json['preferredAnimeTitle'] ?? TitleLang.ro.index),
//             startUpPage: json['startUpPage'] ?? 0,
//             preferredLinkType: LinkType.values.firstWhere(
//               (e) => e.name == json['preferredLinkType'],
//               orElse: () => LinkType.streaming,
//             ),
//             allowYoutubePlayer: json['allowYoutubePlayer'] ?? false,
//             showAnimeMangaCard: json['showAnimeMangaCard'] ?? false,
//             animeMangaPagePreferences: _animeMangaPagePreferences ??
//                 AnimeMangaPagePreferences.defaultObject())
//         : UserPreferences(
//             showCountDownInDetailed: true,
//             firstTime: true,
//             cacheUpdateFrequency: [8, 2, 1],
//             notifPref: NotifPref.fromJson(null),
//             nsfw: _nsfw,
//             brightness: _brightness,
//             userLanguage: _userLanguage ?? "en_US",
//             showPriority: _showPriority,
//             bgPath: _bgPath,
//             homePageItemsPerCategory: _homePageItemsPerCategory ?? 14,
//             userchart: _userchart ?? [-1, -1, -1, -1, -1],
//             hpApiPrefList: _hpApiPrefList ?? [],
//             keepPagesInMemory: _keepPagesInMemory,
//             isRtl: false,
//             autoAddStartEndDate: _autoAddStartEndDate,
//             showOnlyLastQuote: _showOnlyLastQuote,
//             detailsExpanded: _detailsExpanded,
//             autoTranslateSynopsis: _autoTranslateSynopsis,
//             showBg: _showBg,
//             showAiringInfo: _showAiringInfo,
//             defaultDisplayType: DisplayType.list_vert,
//             showAnimeMangaBg: showAnimeMangaBg,
//             userPageAnimeSortType: 'list_updated_at',
//             userPageMangaSortType: 'list_updated_at',
//             firstTimePref: FirstTimePref(),
//             homePageTileSize: HomePageTileSize.l,
//             preferredAnimeTitle: TitleLang.ro,
//             startUpPage: 0,
//             preferredLinkType: LinkType.streaming,
//             showAnimeMangaCard: false,
//             allowYoutubePlayer: false,
//             animeMangaPagePreferences:
//                 AnimeMangaPagePreferences.defaultObject(),
//           );
//   }
//   Map<String, dynamic> toJson() {
//     return {
//       'showCountDownInDetailed': showCountDownInDetailed,
//       'userPageMangaSortType': userPageMangaSortType,
//       'userPageAnimeSortType': userPageAnimeSortType,
//       "homePageItemsPerCategory": homePageItemsPerCategory,
//       "userChart": userchart,
//       "hpApiPrefList_v6": hpApiPrefList,
//       "first_time": firstTime,
//       "cacheUpdateFrequency": cacheUpdateFrequency,
//       "show_bg": showBg,
//       "notifPref": notifPref.toJson(),
//       "keepPagesInMemory": keepPagesInMemory,
//       "nsfw": nsfw,
//       "showPriority": showPriority,
//       "isRtl": isRtl,
//       "detailsExpanded": detailsExpanded,
//       "userLanguage": userLanguage,
//       "autoTranslateSynopsis": autoTranslateSynopsis,
//       "showOnlyLastQuote": showOnlyLastQuote,
//       "bgPath": bgPath,
//       "showAiringInfo_v2": showAiringInfo,
//       "autoAddStartEndDate": autoAddStartEndDate,
//       "defaultDisplayType": defaultDisplayType.index,
//       'showAnimeMangaBg': showAnimeMangaBg,
//       "firstTimePref": firstTimePref.toJson(),
//       "brightness": (brightness) != Brightness.dark,
//       'homePageTileSize': homePageTileSize.index,
//       'preferredAnimeTitle': preferredAnimeTitle.index,
//       'animeMangaPagePreferences': animeMangaPagePreferences,
//       'showAnimeMangaCard': showAnimeMangaCard,
//       'startUpPage': startUpPage,
//       'allowYoutubePlayer': allowYoutubePlayer,
//       'preferredLinkType': preferredLinkType.name,
//     };
//   }
// }

// class NotifPref {
//   DateTime? daySubscribed;
//   bool onDailyAnimeReleases;
//   bool onWatchingListUpdated;
//   bool onPTWGoesToWatching;
//   bool preferLargeImage;

//   NotifPref(
//       {this.daySubscribed,
//       this.onDailyAnimeReleases = true,
//       this.onPTWGoesToWatching = true,
//       this.onWatchingListUpdated = true,
//       this.preferLargeImage = true});

//   factory NotifPref.fromJson(Map<String, dynamic>? json) {
//     dynamic _daySubscribed,
//         _onDailyAnimeReleases,
//         _onWatchingListUpdated,
//         _onPTWGoesToWatching,
//         _preferLargeImage;

//     if (json != null) {
//       if (json.containsKey("day_subscribed")) {
//         _daySubscribed = DateTime.tryParse(json["day_subscribed"] ?? "");
//       }

//       if (json.containsKey("onDailyAnimeReleases")) {
//         _onDailyAnimeReleases = (json["onDailyAnimeReleases"]) ?? true;
//       }

//       if (json.containsKey("onPTWGoesToWatching")) {
//         _onPTWGoesToWatching = (json["onPTWGoesToWatching"]) ?? true;
//       }

//       if (json.containsKey("onWatchingListUpdated")) {
//         _onWatchingListUpdated = (json["onWatchingListUpdated"]) ?? true;
//       }
//       if (json.containsKey("preferLargeImage")) {
//         _preferLargeImage = (json["preferLargeImage"]) ?? true;
//       }
//     }

//     return json == null
//         ? NotifPref()
//         : NotifPref(
//             daySubscribed: _daySubscribed,
//             onDailyAnimeReleases: _onDailyAnimeReleases ?? true,
//             onPTWGoesToWatching: _onPTWGoesToWatching ?? true,
//             onWatchingListUpdated: _onWatchingListUpdated ?? true,
//             preferLargeImage: _preferLargeImage ?? true,
//           );
//   }

//   Map<String, dynamic> toJson() => {
//         "day_subscribed": daySubscribed?.toString(),
//         'preferLargeImage': preferLargeImage,
//         "onDailyAnimeReleases": onDailyAnimeReleases,
//         "onWatchingListUpdated": onWatchingListUpdated,
//         "onPTWGoesToWatching": onPTWGoesToWatching,
//       };
// }

// class FirstTimePref {
//   bool bg;
//   bool news;
//   bool themeV3;
//   bool homePageSize;
//   bool prefferedTitle;
//   bool startUpPage;

//   FirstTimePref({
//     this.bg = true,
//     this.news = true,
//     this.homePageSize = true,
//     this.prefferedTitle = true,
//     this.themeV3 = true,
//     this.startUpPage = true,
//   });

//   factory FirstTimePref.fromJson(Map<String, dynamic>? json) {
//     return json == null
//         ? FirstTimePref()
//         : FirstTimePref(
//             bg: json['bg'] ?? true,
//             news: json['news'] ?? true,
//             homePageSize: json['homePageSize'] ?? true,
//             prefferedTitle: json['prefferedTitle'] ?? true,
//             themeV3: json['themeV3'] ?? true,
//             startUpPage: json['startUpPage'] ?? true,
//           );
//   }

//   Map<String, dynamic> toJson() => {
//         "bg": bg,
//         "news": news,
//         "homePageSize": homePageSize,
//         'prefferedTitle': prefferedTitle,
//         'themeV3': themeV3,
//         'startUpPage': startUpPage,
//       };
// }

// import 'package:flutter/material.dart';
// import 'package:mywatchlist/generated/l10n.dart';
// import 'package:mywatchlist/utils/homepageutils.dart';

// First time preferences model that tracks which features have been introduced
class FirstTimePref {
  bool bg;
  bool news;
  bool themeV3;

  FirstTimePref({
    this.bg = true,
    this.news = true,
    this.themeV3 = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'bg': bg,
      'news': news,
      'themeV3': themeV3,
    };
  }

  factory FirstTimePref.fromJson(Map<String, dynamic> json) {
    return FirstTimePref(
      bg: json['bg'] ?? true,
      news: json['news'] ?? true,
      themeV3: json['themeV3'] ?? true,
    );
  }
}

// Home page API preferences model
class HomePagePref {
  String title;
  String api;
  bool useApi;

  HomePagePref({
    required this.title,
    required this.api,
    required this.useApi,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'api': api,
      'useApi': useApi,
    };
  }

  factory HomePagePref.fromJson(Map<String, dynamic> json) {
    return HomePagePref(
      title: json['title'] ?? '',
      api: json['api'] ?? '',
      useApi: json['useApi'] ?? true,
    );
  }
}

// Main user preferences class with extensive customization options
class UserPreferences {
  // App settings
  bool firstTime;
  FirstTimePref firstTimePref;
  String userLanguage;
  bool showBg;
  String? bgImagePath; // Background image path for user customization
  bool useDarkTheme;

  // API and service preferences
  List<HomePagePref> hpApiPrefList;

  // User interface settings
  bool showAllStatus;
  bool showMatureContent;
  bool twoColumnView;
  bool useImageFromDb;
  bool showDate;
  double? fontSize;
  String theme;
  bool useMaterial3;

  // Extension settings
  bool animeExtensionEnabled;
  bool mangaExtensionEnabled;

  UserPreferences({
    this.firstTime = true,
    required this.firstTimePref,
    this.userLanguage = 'en',
    this.showBg = true,
    this.bgImagePath,
    this.useDarkTheme = true,
    required this.hpApiPrefList,
    this.showAllStatus = false,
    this.showMatureContent = false,
    this.twoColumnView = false,
    this.useImageFromDb = false,
    this.showDate = true,
    this.fontSize,
    this.theme = 'autumn',
    this.useMaterial3 = true,
    this.animeExtensionEnabled = true,
    this.mangaExtensionEnabled = true,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'firstTime': firstTime,
      'firstTimePref': firstTimePref.toJson(),
      'userLanguage': userLanguage,
      'showBg': showBg,
      'bgImagePath': bgImagePath,
      'useDarkTheme': useDarkTheme,
      'hpApiPrefList': hpApiPrefList.map((e) => e.toJson()).toList(),
      'showAllStatus': showAllStatus,
      'showMatureContent': showMatureContent,
      'twoColumnView': twoColumnView,
      'useImageFromDb': useImageFromDb,
      'showDate': showDate,
      'fontSize': fontSize,
      'theme': theme,
      'useMaterial3': useMaterial3,
      'animeExtensionEnabled': animeExtensionEnabled,
      'mangaExtensionEnabled': mangaExtensionEnabled,
    };
  }

  // Create from JSON when loading
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      firstTime: json['firstTime'] ?? true,
      firstTimePref: json['firstTimePref'] != null
          ? FirstTimePref.fromJson(json['firstTimePref'])
          : FirstTimePref(),
      userLanguage: json['userLanguage'] ?? 'en',
      showBg: json['showBg'] ?? true,
      bgImagePath: json['bgImagePath'],
      useDarkTheme: json['useDarkTheme'] ?? true,
      hpApiPrefList: json['hpApiPrefList'] != null
          ? List<HomePagePref>.from(
              json['hpApiPrefList'].map((x) => HomePagePref.fromJson(x)))
          : [],
      showAllStatus: json['showAllStatus'] ?? false,
      showMatureContent: json['showMatureContent'] ?? false,
      twoColumnView: json['twoColumnView'] ?? false,
      useImageFromDb: json['useImageFromDb'] ?? false,
      showDate: json['showDate'] ?? true,
      fontSize: json['fontSize']?.toDouble(),
      theme: json['theme'] ?? 'autumn',
      useMaterial3: json['useMaterial3'] ?? true,
      animeExtensionEnabled: json['animeExtensionEnabled'] ?? true,
      mangaExtensionEnabled: json['mangaExtensionEnabled'] ?? true,
    );
  }
}
