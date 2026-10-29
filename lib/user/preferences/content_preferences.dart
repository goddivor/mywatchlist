import 'package:equatable/equatable.dart';
import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/user/preferences/json_read.dart';

/// Time zone used to display airing times (DAL `TimezonePref`).
enum TimezonePref { utc, jst, local }

/// One section of the anime/manga detail page: its place is its index in the list.
class DetailTabPreference extends Equatable {
  final TabType tabType;
  final bool visible;

  const DetailTabPreference(this.tabType, {this.visible = true});

  DetailTabPreference copyWith({bool? visible}) =>
      DetailTabPreference(tabType, visible: visible ?? this.visible);

  Map<String, dynamic> toJson() => {'tabType': tabType.name, 'visibility': visible};

  /// Null when the saved tab no longer exists.
  static DetailTabPreference? tryFromJson(Map<String, dynamic> json) {
    final name = json['tabType'];
    for (final type in TabType.values) {
      if (type.name == name) {
        return DetailTabPreference(type, visible: readBool(json, 'visibility', true));
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [tabType, visible];
}

/// Default section order of the anime detail page (DAL order, plus MWL's Staff and
/// Episodes sections).
final List<TabType> defaultAnimeTabOrder = List.unmodifiable(
    ContentPreferences.defaultAnimeTabs.map((tab) => tab.tabType));

/// Default section order of the manga detail page (no Media, Staff nor score stats).
final List<TabType> defaultMangaTabOrder = List.unmodifiable(
    ContentPreferences.defaultMangaTabs.map((tab) => tab.tabType));

/// Anime/manga page preferences (DAL "Anime/Manga settings", `AnimeMangaPagePreferences`
/// and the detail-page flags of DAL `UserPreferences`).
class ContentPreferences extends Equatable {
  /// Countdown to the next episode on the detail page (DAL `showCountDownInDetailed`).
  final bool showCountdownOnDetail;

  /// Blurred cover behind the detail page (DAL `showAnimeMangaBg`).
  final bool showDetailBackground;
  final bool showPrivateNotes;

  /// Hide the user's score everywhere it is shown.
  final bool hideScore;

  /// The seasonal page applies the same filter to every season.
  final bool globalSeasonalFilter;
  final TimezonePref timezone;

  /// Status given to an entry added from a detail page, as a MAL list status
  /// (`watching`, `plan_to_watch`, `reading`, `plan_to_read`…); other trackers map it.
  final String defaultAnimeAddStatus;
  final String defaultMangaAddStatus;

  /// Order and visibility of the detail page sections.
  final List<DetailTabPreference> animeTabs;
  final List<DetailTabPreference> mangaTabs;

  const ContentPreferences({
    this.showCountdownOnDetail = true,
    this.showDetailBackground = true,
    this.showPrivateNotes = false,
    this.hideScore = false,
    this.globalSeasonalFilter = false,
    this.timezone = TimezonePref.local,
    this.defaultAnimeAddStatus = 'watching',
    this.defaultMangaAddStatus = 'reading',
    this.animeTabs = defaultAnimeTabs,
    this.mangaTabs = defaultMangaTabs,
  });

  static const List<DetailTabPreference> defaultAnimeTabs = [
    DetailTabPreference(TabType.Synopsis),
    DetailTabPreference(TabType.Media),
    DetailTabPreference(TabType.Related),
    DetailTabPreference(TabType.Episodes),
    DetailTabPreference(TabType.Adaptations),
    DetailTabPreference(TabType.Reviews),
    DetailTabPreference(TabType.Recommendations),
    DetailTabPreference(TabType.Interest_Stacks),
    DetailTabPreference(TabType.Characters),
    DetailTabPreference(TabType.Staff),
    DetailTabPreference(TabType.Forums),
    DetailTabPreference(TabType.Pictures),
    DetailTabPreference(TabType.News),
    DetailTabPreference(TabType.Featured_Articles),
    DetailTabPreference(TabType.User_Updates),
    DetailTabPreference(TabType.Stats),
    DetailTabPreference(TabType.ScoreStats),
    DetailTabPreference(TabType.More_Info),
  ];
  static const List<DetailTabPreference> defaultMangaTabs = [
    DetailTabPreference(TabType.Synopsis),
    DetailTabPreference(TabType.Related),
    DetailTabPreference(TabType.Adaptations),
    DetailTabPreference(TabType.Reviews),
    DetailTabPreference(TabType.Recommendations),
    DetailTabPreference(TabType.Interest_Stacks),
    DetailTabPreference(TabType.Characters),
    DetailTabPreference(TabType.Pictures),
    DetailTabPreference(TabType.Related_Anime),
    DetailTabPreference(TabType.Forums),
    DetailTabPreference(TabType.News),
    DetailTabPreference(TabType.Featured_Articles),
    DetailTabPreference(TabType.User_Updates),
    DetailTabPreference(TabType.More_Info),
  ];

  /// Visible sections of the anime (or manga) detail page, in the user's order.
  List<TabType> visibleTabs({required bool manga}) => [
        for (final tab in manga ? mangaTabs : animeTabs)
          if (tab.visible) tab.tabType,
      ];

  ContentPreferences copyWith({
    bool? showCountdownOnDetail,
    bool? showDetailBackground,
    bool? showPrivateNotes,
    bool? hideScore,
    bool? globalSeasonalFilter,
    TimezonePref? timezone,
    String? defaultAnimeAddStatus,
    String? defaultMangaAddStatus,
    List<DetailTabPreference>? animeTabs,
    List<DetailTabPreference>? mangaTabs,
  }) {
    return ContentPreferences(
      showCountdownOnDetail: showCountdownOnDetail ?? this.showCountdownOnDetail,
      showDetailBackground: showDetailBackground ?? this.showDetailBackground,
      showPrivateNotes: showPrivateNotes ?? this.showPrivateNotes,
      hideScore: hideScore ?? this.hideScore,
      globalSeasonalFilter: globalSeasonalFilter ?? this.globalSeasonalFilter,
      timezone: timezone ?? this.timezone,
      defaultAnimeAddStatus: defaultAnimeAddStatus ?? this.defaultAnimeAddStatus,
      defaultMangaAddStatus: defaultMangaAddStatus ?? this.defaultMangaAddStatus,
      animeTabs: animeTabs != null
          ? List.unmodifiable(completeTabs(animeTabs, defaultAnimeTabOrder))
          : this.animeTabs,
      mangaTabs: mangaTabs != null
          ? List.unmodifiable(completeTabs(mangaTabs, defaultMangaTabOrder))
          : this.mangaTabs,
    );
  }

  Map<String, dynamic> toJson() => {
        'showCountdownOnDetail': showCountdownOnDetail,
        'showDetailBackground': showDetailBackground,
        'showPrivateNotes': showPrivateNotes,
        'hideScore': hideScore,
        'globalSeasonalFilter': globalSeasonalFilter,
        'timezone': timezone.name,
        'defaultAnimeAddStatus': defaultAnimeAddStatus,
        'defaultMangaAddStatus': defaultMangaAddStatus,
        'animeTabs': animeTabs.map((e) => e.toJson()).toList(),
        'mangaTabs': mangaTabs.map((e) => e.toJson()).toList(),
      };

  factory ContentPreferences.fromJson(Map<String, dynamic> json) {
    const d = ContentPreferences();
    List<DetailTabPreference> tabs(String key, List<TabType> defaults) {
      if (json[key] is! List) {
        return identical(defaults, defaultMangaTabOrder) ? d.mangaTabs : d.animeTabs;
      }
      final saved = readMapList(json, key)
          .map(DetailTabPreference.tryFromJson)
          .whereType<DetailTabPreference>()
          .toList();
      return List.unmodifiable(completeTabs(saved, defaults));
    }

    return ContentPreferences(
      showCountdownOnDetail: readBool(json, 'showCountdownOnDetail', d.showCountdownOnDetail),
      showDetailBackground: readBool(json, 'showDetailBackground', d.showDetailBackground),
      showPrivateNotes: readBool(json, 'showPrivateNotes', d.showPrivateNotes),
      hideScore: readBool(json, 'hideScore', d.hideScore),
      globalSeasonalFilter: readBool(json, 'globalSeasonalFilter', d.globalSeasonalFilter),
      timezone: readEnum(json, 'timezone', TimezonePref.values, d.timezone),
      defaultAnimeAddStatus: readString(json, 'defaultAnimeAddStatus', d.defaultAnimeAddStatus),
      defaultMangaAddStatus: readString(json, 'defaultMangaAddStatus', d.defaultMangaAddStatus),
      animeTabs: tabs('animeTabs', defaultAnimeTabOrder),
      mangaTabs: tabs('mangaTabs', defaultMangaTabOrder),
    );
  }

  /// Keeps the saved order, drops duplicates and appends every default section the saved
  /// list does not know yet (a section added by a later version shows up, visible). A new
  /// `ScoreStats` section goes right after `Stats`, as in DailyAL, and a new `Episodes`
  /// section right after `Related`.
  static const Map<TabType, TabType> _insertAfter = {
    TabType.ScoreStats: TabType.Stats,
    TabType.Episodes: TabType.Related,
  };

  static List<DetailTabPreference> completeTabs(
      List<DetailTabPreference> saved, List<TabType> defaults) {
    final result = <DetailTabPreference>[];
    final seen = <TabType>{};
    for (final tab in saved) {
      if (seen.add(tab.tabType)) result.add(tab);
    }
    for (final type in defaults) {
      if (seen.contains(type)) continue;
      seen.add(type);
      final anchor = _insertAfter[type];
      final anchorIndex =
          anchor == null ? -1 : result.indexWhere((t) => t.tabType == anchor);
      if (anchorIndex != -1) {
        result.insert(anchorIndex + 1, DetailTabPreference(type));
      } else {
        result.add(DetailTabPreference(type));
      }
    }
    return result;
  }

  @override
  List<Object?> get props => [
        showCountdownOnDetail,
        showDetailBackground,
        showPrivateNotes,
        hideScore,
        globalSeasonalFilter,
        timezone,
        defaultAnimeAddStatus,
        defaultMangaAddStatus,
        animeTabs,
        mangaTabs,
      ];
}
