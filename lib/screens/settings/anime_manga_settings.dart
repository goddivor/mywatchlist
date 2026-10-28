import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/constants/constants.dart' show TitleLang;
import 'package:mywatchlist/screens/settings/prefs/detail_tabs_editor.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

/// Settings page "Anime/Manga page settings" (DailyAL `AnimeMangaSettings`): detail page
/// switches, time zone, status of added entries and the order of the page sections. UI only:
/// every value lives in `PreferencesBloc`.
class AnimeMangaSettingsPage extends StatelessWidget {
  const AnimeMangaSettingsPage({super.key});

  static List<SelectOption<TimezonePref>> _timezoneOptions() => [
        SelectOption(TimezonePref.local, S.current.Prefs_Timezone_Local),
        SelectOption(TimezonePref.jst, S.current.Prefs_Timezone_Jst),
        SelectOption(TimezonePref.utc, S.current.Prefs_Timezone_Utc),
      ];

  static List<SelectOption<TitleLang>> _titleOptions() => [
        SelectOption(TitleLang.ro, S.current.Prefs_Title_Romaji),
        SelectOption(TitleLang.en, S.current.Prefs_Title_English),
        SelectOption(TitleLang.ja, S.current.Prefs_Title_Japanese),
      ];

  /// Puts back the defaults of this page (the title language is shared with the user
  /// preferences page and stays as it is).
  static void _reset(PreferencesBloc bloc) {
    const d = ContentPreferences();
    bloc.add(ContentPreferencesChanged((p) => p.copyWith(
          showCountdownOnDetail: d.showCountdownOnDetail,
          showDetailBackground: d.showDetailBackground,
          showPrivateNotes: d.showPrivateNotes,
          hideScore: d.hideScore,
          globalSeasonalFilter: d.globalSeasonalFilter,
          timezone: d.timezone,
          defaultAnimeAddStatus: d.defaultAnimeAddStatus,
          defaultMangaAddStatus: d.defaultMangaAddStatus,
          animeTabs: d.animeTabs,
          mangaTabs: d.mangaTabs,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return PrefsPage(
      title: s.Anime_Manga_settings,
      onReset: _reset,
      trailingSlivers: const [DetailTabsEditor()],
      children: [
        PrefGroup(
          title: s.Prefs_Sec_Detail_Page,
          children: [
            PrefSwitchTile(
              icon: Icons.timer_outlined,
              title: s.Prefs_Countdown,
              subtitle: s.Prefs_Countdown_Desc,
              read: (p) => p.content.showCountdownOnDetail,
              toEvent: (v) =>
                  ContentPreferencesChanged((p) => p.copyWith(showCountdownOnDetail: v)),
            ),
            PrefSwitchTile(
              icon: Icons.wallpaper_outlined,
              title: s.Prefs_Detail_Bg,
              subtitle: s.Prefs_Detail_Bg_Desc,
              read: (p) => p.content.showDetailBackground,
              toEvent: (v) =>
                  ContentPreferencesChanged((p) => p.copyWith(showDetailBackground: v)),
            ),
            PrefSwitchTile(
              icon: Icons.notes_rounded,
              title: s.Prefs_Private_Notes,
              malOnly: true,
              subtitle: s.Prefs_Private_Notes_Desc,
              read: (p) => p.content.showPrivateNotes,
              toEvent: (v) => ContentPreferencesChanged((p) => p.copyWith(showPrivateNotes: v)),
            ),
            PrefSwitchTile(
              icon: Icons.star_border_rounded,
              title: s.Prefs_Hide_Score,
              subtitle: s.Prefs_Hide_Score_Desc,
              read: (p) => p.content.hideScore,
              toEvent: (v) => ContentPreferencesChanged((p) => p.copyWith(hideScore: v)),
            ),
            PrefSwitchTile(
              icon: Icons.filter_alt_outlined,
              title: s.Prefs_Global_Seasonal,
              subtitle: s.Prefs_Global_Seasonal_Desc,
              read: (p) => p.content.globalSeasonalFilter,
              toEvent: (v) =>
                  ContentPreferencesChanged((p) => p.copyWith(globalSeasonalFilter: v)),
            ),
          ],
        ),
        PrefGroup(
          title: s.Prefs_Sec_Titles_Time,
          children: [
            PrefSelectTile<TitleLang>(
              icon: Icons.title,
              title: s.Prefs_Title_Lang,
              subtitle: s.Prefs_Title_Lang_Desc,
              options: _titleOptions(),
              read: (p) => p.general.preferredTitle,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(preferredTitle: v)),
            ),
            PrefSelectTile<TimezonePref>(
              icon: Icons.schedule,
              title: s.Prefs_Timezone,
              subtitle: s.Prefs_Timezone_Desc,
              options: _timezoneOptions(),
              read: (p) => p.content.timezone,
              toEvent: (v) => ContentPreferencesChanged((p) => p.copyWith(timezone: v)),
            ),
          ],
        ),
        PrefGroup(
          title: s.Prefs_Sec_Adding,
          children: [
            PrefSelectTile<String>(
              icon: Icons.playlist_add_check,
              title: s.Prefs_Add_Anime,
              malOnly: true,
              subtitle: s.Prefs_Add_Anime_Desc,
              options: PrefStatusLabels.options(PrefStatusLabels.animeAdd),
              read: (p) => p.content.defaultAnimeAddStatus,
              toEvent: (v) =>
                  ContentPreferencesChanged((p) => p.copyWith(defaultAnimeAddStatus: v)),
            ),
            PrefSelectTile<String>(
              icon: Icons.playlist_add_check,
              title: s.Prefs_Add_Manga,
              malOnly: true,
              subtitle: s.Prefs_Add_Manga_Desc,
              options: PrefStatusLabels.options(PrefStatusLabels.mangaAdd),
              read: (p) => p.content.defaultMangaAddStatus,
              toEvent: (v) =>
                  ContentPreferencesChanged((p) => p.copyWith(defaultMangaAddStatus: v)),
            ),
          ],
        ),
      ],
    );
  }
}
