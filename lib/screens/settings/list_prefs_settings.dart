import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/card_profiles_section.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

/// Settings page "List preferences" (DailyAL `ListPreferenceSettings`): which category and
/// status tab the user list opens on, and the saved card layouts. UI only: every value lives
/// in `PreferencesBloc`.
class ListPreferenceSettingsPage extends StatelessWidget {
  const ListPreferenceSettingsPage({super.key});

  static const List<String> _animeTabs = [
    'all',
    'watching',
    'completed',
    'on_hold',
    'dropped',
    'plan_to_watch',
  ];
  static const List<String> _mangaTabs = [
    'all',
    'reading',
    'completed',
    'on_hold',
    'dropped',
    'plan_to_read',
  ];

  static List<SelectOption<ListCategory>> _categoryOptions() => [
        SelectOption(ListCategory.none, S.current.Prefs_List_Last_Used, icon: Icons.history),
        SelectOption(ListCategory.anime, S.current.Prefs_Anime, icon: Icons.live_tv_outlined),
        SelectOption(ListCategory.manga, S.current.Prefs_Manga, icon: Icons.menu_book_outlined),
      ];

  static List<SelectOption<String>> _tabOptions(List<String> statuses) => [
        SelectOption(ListPreferences.noDefaultTab, S.current.Prefs_List_Last_Used,
            icon: Icons.history),
        ...PrefStatusLabels.options(statuses),
      ];

  /// Puts back the defaults of this page (card layouts are kept: they are user content).
  static void _reset(PreferencesBloc bloc) {
    const d = ListPreferences();
    bloc.add(ListPreferencesChanged((p) => p.copyWith(
          defaultCategory: d.defaultCategory,
          defaultAnimeTab: d.defaultAnimeTab,
          defaultMangaTab: d.defaultMangaTab,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    return PrefsPage(
      title: s.List_preferences,
      onReset: _reset,
      children: [
        PrefGroup(
          title: s.Prefs_Sec_List_Opening,
          children: [
            PrefSelectTile<ListCategory>(
              icon: Icons.line_style,
              title: s.Prefs_List_Category,
              subtitle: s.Prefs_List_Category_Desc,
              options: _categoryOptions(),
              read: (p) => p.list.defaultCategory,
              toEvent: (v) => ListPreferencesChanged((p) => p.copyWith(defaultCategory: v)),
            ),
            PrefSelectTile<String>(
              icon: Icons.live_tv_outlined,
              title: s.Prefs_List_Anime_Tab,
              subtitle: s.Prefs_List_Anime_Tab_Desc,
              options: _tabOptions(_animeTabs),
              fallbackLabel: s.Prefs_List_Last_Used,
              read: (p) => p.list.defaultAnimeTab,
              toEvent: (v) => ListPreferencesChanged((p) => p.copyWith(defaultAnimeTab: v)),
            ),
            PrefSelectTile<String>(
              icon: Icons.menu_book_outlined,
              title: s.Prefs_List_Manga_Tab,
              subtitle: s.Prefs_List_Manga_Tab_Desc,
              options: _tabOptions(_mangaTabs),
              fallbackLabel: s.Prefs_List_Last_Used,
              read: (p) => p.list.defaultMangaTab,
              toEvent: (v) => ListPreferencesChanged((p) => p.copyWith(defaultMangaTab: v)),
            ),
          ],
        ),
        const CardProfilesSection(),
      ],
    );
  }
}
