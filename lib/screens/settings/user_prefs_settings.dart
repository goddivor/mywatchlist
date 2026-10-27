import 'package:flutter/material.dart';
import 'package:mwl_commons/mwl_commons.dart' show LinkType;
import 'package:mywatchlist/constants/constants.dart' show DisplayType, TitleLang;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/screens/settings/prefs/stats_chart_colors.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

/// Settings page "User preferences": how titles, lists and pages behave across the app
/// (DailyAL `UserPrefSettings`). UI only: every value lives in `PreferencesBloc`.
///
/// Language, theme, home layout and the dub options have their own settings pages.
class UserPrefSettingsPage extends StatelessWidget {
  const UserPrefSettingsPage({super.key});

  static List<SelectOption<TitleLang>> _titleOptions() => [
        SelectOption(TitleLang.ro, S.current.Prefs_Title_Romaji),
        SelectOption(TitleLang.en, S.current.Prefs_Title_English),
        SelectOption(TitleLang.ja, S.current.Prefs_Title_Japanese),
      ];

  static List<SelectOption<StartupPage>> _startupOptions() => [
        SelectOption(StartupPage.home, S.current.Prefs_Startup_Home, icon: Icons.home_outlined),
        SelectOption(StartupPage.explore, S.current.Prefs_Startup_Explore,
            icon: Icons.explore_outlined),
        SelectOption(StartupPage.userList, S.current.Prefs_Startup_List,
            icon: Icons.view_list_outlined),
        SelectOption(StartupPage.forum, S.current.Prefs_Startup_Forums,
            icon: Icons.forum_outlined),
        SelectOption(StartupPage.profile, S.current.Prefs_Startup_Profile,
            icon: Icons.person_outline),
        SelectOption(StartupPage.calendar, S.current.Prefs_Startup_Calendar,
            icon: Icons.calendar_month_outlined),
        SelectOption(StartupPage.search, S.current.Prefs_Startup_Search, icon: Icons.search),
      ];

  static List<SelectOption<DisplayType>> _displayOptions() => [
        SelectOption(DisplayType.list_vert, S.current.Prefs_Display_List,
            icon: Icons.view_agenda_outlined),
        SelectOption(DisplayType.grid, S.current.Prefs_Display_Grid, icon: Icons.grid_view),
        SelectOption(DisplayType.list_horiz, S.current.Prefs_Display_Horizontal,
            icon: Icons.view_carousel_outlined),
      ];

  static List<SelectOption<LinkType>> _linkOptions() => [
        SelectOption(LinkType.streaming, S.current.Prefs_Link_Streaming),
        SelectOption(LinkType.availableAt, S.current.Prefs_Link_Available_At),
        SelectOption(LinkType.resources, S.current.Prefs_Link_Resources),
        SelectOption(LinkType.otherLists, S.current.Prefs_Link_Other_Lists),
      ];

  /// Puts back the defaults of the options shown here only (dub options keep their values).
  static void _reset(PreferencesBloc bloc) {
    const d = GeneralPreferences();
    bloc.add(GeneralPreferencesChanged((p) => p.copyWith(
          preferredTitle: d.preferredTitle,
          startupPage: d.startupPage,
          defaultDisplayType: d.defaultDisplayType,
          nsfw: d.nsfw,
          showAnimeMangaCard: d.showAnimeMangaCard,
          allowYoutubePlayer: d.allowYoutubePlayer,
          keepPagesInMemory: d.keepPagesInMemory,
          showPriority: d.showPriority,
          autoTranslateSynopsis: d.autoTranslateSynopsis,
          showOnlyLastQuote: d.showOnlyLastQuote,
          autoAddStartEndDate: d.autoAddStartEndDate,
          showAiringInfo: d.showAiringInfo,
          statsChartColors: d.statsChartColors,
          preferredLinkType: d.preferredLinkType,
          detailsExpanded: d.detailsExpanded,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return PrefsPage(
      title: s.User_Preferences,
      onReset: _reset,
      children: [
        PrefGroup(
          title: s.Prefs_Sec_Display,
          children: [
            PrefSelectTile<TitleLang>(
              icon: Icons.title,
              title: s.Prefs_Title_Lang,
              subtitle: s.Prefs_Title_Lang_Desc,
              options: _titleOptions(),
              read: (p) => p.general.preferredTitle,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(preferredTitle: v)),
            ),
            PrefSelectTile<StartupPage>(
              icon: Icons.rocket_launch_outlined,
              title: s.Prefs_Startup,
              subtitle: s.Prefs_Startup_Desc,
              options: _startupOptions(),
              read: (p) => p.general.startupPage,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(startupPage: v)),
            ),
            PrefSelectTile<DisplayType>(
              icon: Icons.dashboard_customize_outlined,
              title: s.Prefs_Display_Default,
              subtitle: s.Prefs_Display_Default_Desc,
              options: _displayOptions(),
              read: (p) => p.general.defaultDisplayType,
              toEvent: (v) =>
                  GeneralPreferencesChanged((p) => p.copyWith(defaultDisplayType: v)),
            ),
            PrefSwitchTile(
              icon: Icons.indeterminate_check_box_outlined,
              title: s.Prefs_Content_Card,
              subtitle: s.Prefs_Content_Card_Desc,
              read: (p) => p.general.showAnimeMangaCard,
              toEvent: (v) =>
                  GeneralPreferencesChanged((p) => p.copyWith(showAnimeMangaCard: v)),
            ),
          ],
        ),
        PrefGroup(
          title: s.Prefs_Sec_Content,
          children: [
            PrefSwitchTile(
              icon: Icons.work_off_outlined,
              title: s.Prefs_Nsfw,
              subtitle: s.Prefs_Nsfw_Desc,
              read: (p) => p.general.nsfw,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(nsfw: v)),
            ),
            PrefSwitchTile(
              icon: Icons.translate,
              title: s.Prefs_Auto_Translate,
              subtitle: s.Prefs_Auto_Translate_Desc,
              read: (p) => p.general.autoTranslateSynopsis,
              toEvent: (v) =>
                  GeneralPreferencesChanged((p) => p.copyWith(autoTranslateSynopsis: v)),
            ),
            PrefSwitchTile(
              icon: Icons.unfold_more_rounded,
              title: s.Prefs_Details_Expanded,
              subtitle: s.Prefs_Details_Expanded_Desc,
              read: (p) => p.general.detailsExpanded,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(detailsExpanded: v)),
            ),
            PrefSelectTile<LinkType>(
              icon: Icons.link,
              title: s.Prefs_Link_Type,
              subtitle: s.Prefs_Link_Type_Desc,
              options: _linkOptions(),
              read: (p) => p.general.preferredLinkType,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(preferredLinkType: v)),
            ),
            PrefSwitchTile(
              icon: Icons.smart_display_outlined,
              title: s.Prefs_Youtube,
              subtitle: s.Prefs_Youtube_Desc,
              read: (p) => p.general.allowYoutubePlayer,
              toEvent: (v) =>
                  GeneralPreferencesChanged((p) => p.copyWith(allowYoutubePlayer: v)),
            ),
          ],
        ),
        PrefGroup(
          title: s.Prefs_Sec_Lists,
          children: [
            PrefSwitchTile(
              icon: Icons.priority_high,
              title: s.Prefs_Priority,
              subtitle: s.Prefs_Priority_Desc,
              read: (p) => p.general.showPriority,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(showPriority: v)),
            ),
            PrefSwitchTile(
              icon: Icons.live_tv_rounded,
              title: s.Prefs_Airing_Info,
              subtitle: s.Prefs_Airing_Info_Desc,
              read: (p) => p.general.showAiringInfo,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(showAiringInfo: v)),
            ),
            PrefSwitchTile(
              icon: Icons.date_range,
              title: s.Prefs_Auto_Dates,
              subtitle: s.Prefs_Auto_Dates_Desc,
              read: (p) => p.general.autoAddStartEndDate,
              toEvent: (v) =>
                  GeneralPreferencesChanged((p) => p.copyWith(autoAddStartEndDate: v)),
            ),
          ],
        ),
        PrefGroup(
          title: s.Prefs_Sec_App,
          children: [
            PrefSwitchTile(
              icon: Icons.memory,
              title: s.Prefs_Keep_Pages,
              subtitle: s.Prefs_Keep_Pages_Desc,
              read: (p) => p.general.keepPagesInMemory,
              toEvent: (v) =>
                  GeneralPreferencesChanged((p) => p.copyWith(keepPagesInMemory: v)),
            ),
            PrefSwitchTile(
              icon: Icons.format_quote,
              title: s.Prefs_Last_Quote,
              subtitle: s.Prefs_Last_Quote_Desc,
              read: (p) => p.general.showOnlyLastQuote,
              toEvent: (v) =>
                  GeneralPreferencesChanged((p) => p.copyWith(showOnlyLastQuote: v)),
            ),
          ],
        ),
        PrefGroup(
          title: s.Prefs_Stats_Title,
          description: s.Prefs_Stats_Desc,
          children: [
            for (var i = 0; i < statsChartStatuses.length; i++) StatsChartColorTile(index: i),
          ],
        ),
      ],
    );
  }
}
