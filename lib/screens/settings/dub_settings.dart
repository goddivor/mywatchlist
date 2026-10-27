import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/cache/dub_info.dart';
import 'package:mywatchlist/constants/constants.dart' show launchURLWithConfirmation;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/dub_icon.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

/// Settings page "Dub settings": the dub icon on cards, its language, the number of sources
/// MyDubList needs, the icon style and links to report or support the project
/// (DailyAL `DubSettingsPage`). Values live in `PreferencesBloc`; the data in [DubInfo].
class DubSettingsPage extends StatefulWidget {
  const DubSettingsPage({super.key});

  @override
  State<DubSettingsPage> createState() => _DubSettingsPageState();
}

class _DubSettingsPageState extends State<DubSettingsPage> {
  @override
  void initState() {
    super.initState();
    DubInfo.instance.attach();
    unawaited(DubIcons.ensureFont());
  }

  static String languageName(String value) {
    final s = S.current;
    return switch (value) {
      'english' => s.Dub_Lang_English,
      'spanish' => s.Dub_Lang_Spanish,
      'german' => s.Dub_Lang_German,
      'french' => s.Dub_Lang_French,
      'italian' => s.Dub_Lang_Italian,
      'portuguese' => s.Dub_Lang_Portuguese,
      'korean' => s.Dub_Lang_Korean,
      'tagalog' => s.Dub_Lang_Tagalog,
      'chinese' => s.Dub_Lang_Chinese,
      'arabic' => s.Dub_Lang_Arabic,
      'polish' => s.Dub_Lang_Polish,
      'hungarian' => s.Dub_Lang_Hungarian,
      'swedish' => s.Dub_Lang_Swedish,
      'norwegian' => s.Dub_Lang_Norwegian,
      'hebrew' => s.Dub_Lang_Hebrew,
      'dutch' => s.Dub_Lang_Dutch,
      'russian' => s.Dub_Lang_Russian,
      'indonesian' => s.Dub_Lang_Indonesian,
      'danish' => s.Dub_Lang_Danish,
      'thai' => s.Dub_Lang_Thai,
      'hindi' => s.Dub_Lang_Hindi,
      'finnish' => s.Dub_Lang_Finnish,
      'turkish' => s.Dub_Lang_Turkish,
      'catalan' => s.Dub_Lang_Catalan,
      'vietnamese' => s.Dub_Lang_Vietnamese,
      'lithuanian' => s.Dub_Lang_Lithuanian,
      _ => value,
    };
  }

  static List<SelectOption<String>> _languageOptions() {
    final options = [
      for (final l in dubLanguages) SelectOption(l, languageName(l)),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  static List<SelectOption<int>> _sourceOptions() => [
        for (var n = 1; n <= 4; n++) SelectOption(n, S.current.Dub_Sources(n)),
      ];

  static void _reset(PreferencesBloc bloc) {
    const d = GeneralPreferences();
    bloc.add(GeneralPreferencesChanged((p) => p.copyWith(
          showDubStatus: d.showDubStatus,
          dubLanguage: d.dubLanguage,
          dubIconStyle: d.dubIconStyle,
          dubMinSourceCount: d.dubMinSourceCount,
        )));
  }

  Future<void> _pickLanguage(BuildContext context, String selected) async {
    final bloc = context.read<PreferencesBloc>();
    final picked = await showSearchableSelect<String>(
      context,
      options: _languageOptions(),
      selected: selected,
      title: S.current.Dub_Language,
    );
    if (picked != null && picked != selected) {
      bloc.add(GeneralPreferencesChanged((p) => p.copyWith(dubLanguage: picked)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final enabled = context.select((PreferencesBloc b) => b.state.general.showDubStatus);
    final language = context.select((PreferencesBloc b) => b.state.general.dubLanguage);
    return PrefsPage(
      title: s.Dub_Settings,
      onReset: _reset,
      children: [
        PrefGroup(
          title: s.Dub_Sec_Display,
          description: s.Dub_Source_Credit,
          children: [
            PrefSwitchTile(
              icon: Icons.record_voice_over_outlined,
              title: s.Dub_Show_Icon,
              subtitle: s.Dub_Show_Icon_Desc,
              read: (p) => p.general.showDubStatus,
              toEvent: (v) => GeneralPreferencesChanged((p) => p.copyWith(showDubStatus: v)),
            ),
            if (enabled) ...[
              ListTile(
                contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
                leading: const PrefIcon(Icons.language),
                title: Text(s.Dub_Language),
                subtitle: Text(s.Dub_Language_Desc),
                trailing: Text(
                  languageName(language),
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                onTap: () => _pickLanguage(context, language),
              ),
              PrefSelectTile<int>(
                icon: Icons.fact_check_outlined,
                title: s.Dub_Confidence,
                subtitle: s.Dub_Confidence_Desc,
                options: _sourceOptions(),
                read: (p) => p.general.dubMinSourceCount.clamp(1, 4),
                toEvent: (v) =>
                    GeneralPreferencesChanged((p) => p.copyWith(dubMinSourceCount: v)),
              ),
              const _IconStylePicker(),
              const _DataStatusTile(),
            ],
          ],
        ),
        PrefGroup(
          title: s.Dub_Sec_Links,
          children: [
            _LinkTile(
              icon: Icons.bug_report_outlined,
              title: s.Dub_Report,
              url: DubInfo.reportUrl,
            ),
            _LinkTile(
              icon: Icons.favorite_border,
              title: s.Dub_Support,
              url: DubInfo.supportUrl,
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String url;
  const _LinkTile({required this.icon, required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
      leading: PrefIcon(icon),
      title: Text(title),
      trailing: Icon(Icons.open_in_new, size: 20, color: Theme.of(context).colorScheme.outline),
      onTap: () => launchURLWithConfirmation(url, context: context),
    );
  }
}

/// Four selectable cards, each previewing the "dubbed" and "partially dubbed" icons.
class _IconStylePicker extends StatelessWidget {
  const _IconStylePicker();

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = context.select(
        (PreferencesBloc b) => DubIcons.clampStyle(b.state.general.dubIconStyle));
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PrefIcon(Icons.palette_outlined),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.Dub_Icon_Style, style: theme.textTheme.bodyLarge),
                    Text(
                      s.Dub_Icon_Style_Desc,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < DubIcons.styleCount; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _StyleCard(index: i, selected: i == style)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  final int index;
  final bool selected;
  const _StyleCard({required this.index, required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fg = selected ? colors.onSecondaryContainer : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: S.current.Dub_Style_N(index + 1),
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.secondaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context
              .read<PreferencesBloc>()
              .add(GeneralPreferencesChanged((p) => p.copyWith(dubIconStyle: index))),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: selected ? Border.all(color: colors.primary, width: 2) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DubGlyph(status: DubStatus.dubbed, style: index, size: 22, color: fg),
                const SizedBox(width: 8),
                DubGlyph(status: DubStatus.partial, style: index, size: 22, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Load state of the dub file with a Retry when the network failed.
class _DataStatusTile extends StatelessWidget {
  const _DataStatusTile();

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final colors = Theme.of(context).colorScheme;
    final info = DubInfo.instance;
    return ListenableBuilder(
      listenable: info,
      builder: (context, _) {
        final state = info.state;
        final failed = state == DubLoadState.failed;
        final text = switch (state) {
          DubLoadState.loading => s.Dub_Data_Loading,
          DubLoadState.ready => s.Dub_Data_Ready(info.data.total),
          DubLoadState.failed => s.Dub_Data_Failed,
          DubLoadState.idle => s.Dub_Data_Idle,
        };
        return ListTile(
          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
          leading: PrefIcon(failed ? Icons.cloud_off_outlined : Icons.cloud_done_outlined),
          title: Text(s.Dub_Sec_Data),
          subtitle: Text(text, style: TextStyle(color: failed ? colors.error : null)),
          isThreeLine: failed,
          trailing: state == DubLoadState.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: () => unawaited(info.ensureLoaded(force: true)),
                  child: Text(s.Dub_Retry),
                ),
        );
      },
    );
  }
}
