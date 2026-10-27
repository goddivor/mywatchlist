import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show HomePageTileSize, TitleLang;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _seenKey = 'home_showcase_seen_v1';

/// The first-run showcase of the home settings: card size, preferred title and startup page, in
/// one bottom sheet shown once (DailyAL's "new features" sheet). Closing it, by any means,
/// marks it as seen.
Future<void> showHomeShowcaseOnce(BuildContext context) async {
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return;
  }
  if (prefs.getBool(_seenKey) ?? false) return;
  if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
  await prefs.setBool(_seenKey, true);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const HomeShowcaseSheet(),
  );
}

class HomeShowcaseSheet extends StatelessWidget {
  const HomeShowcaseSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.current;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(s.Hw_Showcase_Title, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(s.Hw_Showcase_Intro,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          _Label(s.Hw_Showcase_Tile),
          const _TileSizePicker(),
          const SizedBox(height: 20),
          _Label(s.Hw_Showcase_Title_Pref),
          const _TitlePicker(),
          const SizedBox(height: 20),
          _Label(s.Hw_Showcase_Startup),
          const _StartupPicker(),
          const SizedBox(height: 24),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(s.Hw_Showcase_Done),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _TileSizePicker extends StatelessWidget {
  const _TileSizePicker();

  @override
  Widget build(BuildContext context) {
    final current = context.select<HomePreferencesBloc, HomePageTileSize>(
        (bloc) => bloc.state.preferences.tileSize);
    return SegmentedButton<HomePageTileSize>(
      showSelectedIcon: false,
      segments: [
        for (final size in HomePageTileSize.values)
          ButtonSegment(value: size, label: Text(size.name.toUpperCase())),
      ],
      selected: {current},
      onSelectionChanged: (selection) {
        final bloc = context.read<HomePreferencesBloc>();
        final prefs = bloc.state.preferences;
        bloc.add(UpdateHomePreferencesEvent(MalHomePreferences(
          sections: [for (final section in prefs.sections) section.copy()],
          tileSize: selection.first,
        )));
      },
    );
  }
}

class _TitlePicker extends StatelessWidget {
  const _TitlePicker();

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final current = context.select<PreferencesBloc, TitleLang>(
        (bloc) => bloc.state.general.preferredTitle);
    final options = {
      TitleLang.ro: s.Prefs_Title_Romaji,
      TitleLang.en: s.Prefs_Title_English,
      TitleLang.ja: s.Prefs_Title_Japanese,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options.entries)
          ChoiceChip(
            label: Text(option.value),
            selected: option.key == current,
            onSelected: (_) => context.read<PreferencesBloc>().add(
                GeneralPreferencesChanged((p) => p.copyWith(preferredTitle: option.key))),
          ),
      ],
    );
  }
}

class _StartupPicker extends StatelessWidget {
  const _StartupPicker();

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final current = context.select<PreferencesBloc, StartupPage>(
        (bloc) => bloc.state.general.startupPage);
    final options = {
      StartupPage.home: s.Prefs_Startup_Home,
      StartupPage.explore: s.Prefs_Startup_Explore,
      StartupPage.userList: s.Prefs_Startup_List,
      StartupPage.forum: s.Prefs_Startup_Forums,
      StartupPage.profile: s.Prefs_Startup_Profile,
      StartupPage.calendar: s.Prefs_Startup_Calendar,
      StartupPage.search: s.Prefs_Startup_Search,
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options.entries)
          ChoiceChip(
            label: Text(option.value),
            selected: option.key == current,
            onSelected: (_) => context.read<PreferencesBloc>().add(
                GeneralPreferencesChanged((p) => p.copyWith(startupPage: option.key))),
          ),
      ],
    );
  }
}
