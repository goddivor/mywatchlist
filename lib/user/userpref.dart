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
