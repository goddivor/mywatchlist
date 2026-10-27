import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/select/select.dart';

/// Building blocks shared by the three preference pages: a large-title scaffold with a
/// "restore defaults" menu, grouped rounded surfaces, and tiles that read one field of the
/// preferences contract and write it back through its group event (UI only, no storage).

/// Settings page: large collapsing title, a lazy list of [children] and a menu to restore
/// the defaults of the page ([onReset] receives the bloc to dispatch its events on).
class PrefsPage extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// Slivers shown after [children] (a reorderable list, for instance).
  final List<Widget> trailingSlivers;
  final void Function(PreferencesBloc bloc) onReset;

  const PrefsPage({
    super.key,
    required this.title,
    required this.children,
    this.trailingSlivers = const [],
    required this.onReset,
  });

  Future<void> _confirmReset(BuildContext context) async {
    final bloc = context.read<PreferencesBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restart_alt_rounded),
        title: Text(S.current.Prefs_Reset_Title),
        content: Text(S.current.Prefs_Reset_Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.current.Prefs_Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.Prefs_Reset_Confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    onReset(bloc);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.current.Prefs_Reset_Done)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(title),
            actions: [
              PopupMenuButton<void>(
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                itemBuilder: (_) => [
                  PopupMenuItem<void>(
                    onTap: () => _confirmReset(context),
                    child: Text(S.current.Prefs_Reset_Menu),
                  ),
                ],
              ),
            ],
          ),
          SliverList.list(children: children),
          ...trailingSlivers,
          SliverToBoxAdapter(
            child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }
}

/// A titled rounded surface holding a few tiles separated by inset dividers.
class PrefGroup extends StatelessWidget {
  final String title;
  final String? description;
  final List<Widget> children;

  const PrefGroup({super.key, required this.title, this.description, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(28, 20, 16, 8),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(28, 0, 16, 8),
            child: Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 72,
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded icon badge used by every tile (same look as the settings hub).
class PrefIcon extends StatelessWidget {
  final IconData icon;
  const PrefIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: colors.onPrimaryContainer),
    );
  }
}

const EdgeInsetsGeometry _tilePadding = EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4);

/// Switch bound to one boolean of the contract. Only this tile rebuilds when it changes.
class PrefSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool Function(AppPreferences prefs) read;
  final PreferencesEvent Function(bool value) toEvent;

  const PrefSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.read,
    required this.toEvent,
  });

  @override
  Widget build(BuildContext context) {
    final value = context.select((PreferencesBloc b) => read(b.state));
    return SwitchListTile(
      contentPadding: _tilePadding,
      secondary: PrefIcon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      isThreeLine: (subtitle?.length ?? 0) > 70,
      value: value,
      onChanged: (next) => context.read<PreferencesBloc>().add(toEvent(next)),
    );
  }
}

/// Row that opens the shared select sheet for one value of the contract and shows the
/// current choice on its right.
class PrefSelectTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<SelectOption<T>> options;
  final T Function(AppPreferences prefs) read;
  final PreferencesEvent Function(T value) toEvent;

  /// Label shown when the stored value is not among [options].
  final String? fallbackLabel;

  const PrefSelectTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.options,
    required this.read,
    required this.toEvent,
    this.fallbackLabel,
  });

  Future<void> _open(BuildContext context, T selected) async {
    final bloc = context.read<PreferencesBloc>();
    final picked =
        await showSelectSheet<T>(context, options: options, selected: selected, title: title);
    if (picked != null && picked != selected) bloc.add(toEvent(picked));
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.select((PreferencesBloc b) => read(b.state));
    final theme = Theme.of(context);
    final label = labelOf(options, selected) ?? fallbackLabel ?? '';
    return ListTile(
      contentPadding: _tilePadding,
      leading: PrefIcon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      isThreeLine: (subtitle?.length ?? 0) > 70,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
          ],
        ),
      ),
      onTap: () => _open(context, selected),
    );
  }
}

/// MAL list statuses with their translated names, for the pickers of the pages.
abstract final class PrefStatusLabels {
  static String of(String status) {
    final s = S.current;
    return switch (status) {
      'watching' => s.Prefs_Status_Watching,
      'reading' => s.Prefs_Status_Reading,
      'completed' => s.Prefs_Status_Completed,
      'on_hold' => s.Prefs_Status_On_Hold,
      'dropped' => s.Prefs_Status_Dropped,
      'plan_to_watch' => s.Prefs_Status_Plan_Watch,
      'plan_to_read' => s.Prefs_Status_Plan_Read,
      'all' => s.Prefs_Status_All,
      _ => status,
    };
  }

  static List<SelectOption<String>> options(Iterable<String> statuses) =>
      [for (final status in statuses) SelectOption(status, of(status))];

  static const List<String> animeAdd = [
    'watching',
    'completed',
    'on_hold',
    'dropped',
    'plan_to_watch',
  ];
  static const List<String> mangaAdd = [
    'reading',
    'completed',
    'on_hold',
    'dropped',
    'plan_to_read',
  ];
}
