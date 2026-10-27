import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// Statuses of the stats chart, in the order of `GeneralPreferences.statsChartColors`.
const List<String> statsChartStatuses = [
  'watching',
  'completed',
  'on_hold',
  'dropped',
  'plan_to_watch',
];

/// One status of the stats chart: its colour (or "theme colour") with a picker and a clear
/// button. Rebuilds alone when its own slot changes.
class StatsChartColorTile extends StatelessWidget {
  final int index;
  const StatsChartColorTile({super.key, required this.index});

  Future<void> _pick(BuildContext context, Color initial) async {
    final bloc = context.read<PreferencesBloc>();
    var chosen = initial;
    final confirmed = await ColorPicker(
      color: initial,
      onColorChanged: (color) => chosen = color,
      heading: Text(S.current.Prefs_Color_Pick, style: Theme.of(context).textTheme.titleMedium),
      pickersEnabled: const {
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
      pickerTypeLabels: {
        ColorPickerType.primary: S.current.Prefs_Picker_Main,
        ColorPickerType.wheel: S.current.Prefs_Picker_Wheel,
      },
      padding: const EdgeInsets.all(16),
    ).showPickerDialog(context, constraints: const BoxConstraints(minWidth: 280, maxWidth: 360));
    if (confirmed) {
      bloc.add(GeneralPreferencesChanged((p) => p.withStatsChartColor(index, chosen.toARGB32())));
    }
  }

  void _clear(BuildContext context) => context
      .read<PreferencesBloc>()
      .add(GeneralPreferencesChanged((p) => p.withStatsChartColor(index, null)));

  @override
  Widget build(BuildContext context) {
    final argb = context.select((PreferencesBloc b) => b.state.general.statsChartColor(index));
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final label = PrefStatusLabels.of(statsChartStatuses[index]);
    final swatch = argb == null ? null : Color(argb);
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 2, 4, 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: swatch ?? colors.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant, width: 2),
        ),
        child: swatch == null
            ? Icon(Icons.palette_outlined, size: 20, color: colors.onSurfaceVariant)
            : null,
      ),
      title: Text(label),
      subtitle: Text(swatch == null ? S.current.Prefs_Color_Theme : S.current.Prefs_Color_Custom),
      trailing: swatch == null
          ? null
          : IconButton(
              tooltip: S.current.Prefs_Color_Clear,
              icon: const Icon(Icons.layers_clear_outlined),
              onPressed: () => _clear(context),
            ),
      onTap: () => _pick(context, swatch ?? colors.primary),
    );
  }
}
