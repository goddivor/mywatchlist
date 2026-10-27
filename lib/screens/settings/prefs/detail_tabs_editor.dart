import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart' show detailTabLabel;
import 'package:mywatchlist/user/preferences/preferences.dart';

/// Order and visibility of the sections of the anime / manga detail page (DAL "Customize
/// tabs"). A switch picks the category; the sections are one reorderable sliver list.
class DetailTabsEditor extends StatefulWidget {
  const DetailTabsEditor({super.key});

  @override
  State<DetailTabsEditor> createState() => _DetailTabsEditorState();
}

class _DetailTabsEditorState extends State<DetailTabsEditor> {
  bool _manga = false;

  List<DetailTabPreference> _tabsOf(ContentPreferences c) => _manga ? c.mangaTabs : c.animeTabs;

  void _save(BuildContext context, List<DetailTabPreference> tabs) {
    final manga = _manga;
    context.read<PreferencesBloc>().add(ContentPreferencesChanged(
        (p) => manga ? p.copyWith(mangaTabs: tabs) : p.copyWith(animeTabs: tabs)));
  }

  void _reorder(BuildContext context, int oldIndex, int newIndex) {
    final tabs = List.of(_tabsOf(context.read<PreferencesBloc>().state.content));
    if (newIndex > oldIndex) newIndex -= 1;
    tabs.insert(newIndex, tabs.removeAt(oldIndex));
    _save(context, tabs);
  }

  void _toggle(BuildContext context, int index) {
    final tabs = List.of(_tabsOf(context.read<PreferencesBloc>().state.content));
    tabs[index] = tabs[index].copyWith(visible: !tabs[index].visible);
    _save(context, tabs);
  }

  void _restoreOrder(BuildContext context) =>
      _save(context, _manga ? ContentPreferences.defaultMangaTabs : ContentPreferences.defaultAnimeTabs);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tabs = context.select((PreferencesBloc b) => _tabsOf(b.state.content));
    final shown = tabs.where((t) => t.visible).length;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      S.current.Prefs_Sec_Sections,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: false, label: Text(S.current.Prefs_Anime)),
                      ButtonSegment(value: true, label: Text(S.current.Prefs_Manga)),
                    ],
                    selected: {_manga},
                    onSelectionChanged: (value) => setState(() => _manga = value.first),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 8),
                  child: Text(
                    '${S.current.Prefs_Tabs_Hint} ${S.current.Prefs_Tabs_Count(shown, tabs.length)}.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverReorderableList(
            itemCount: tabs.length,
            onReorder: (oldIndex, newIndex) => _reorder(context, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final tab = tabs[index];
              return _TabTile(
                key: ValueKey('${_manga ? 'manga' : 'anime'}-${tab.tabType.name}'),
                index: index,
                tab: tab,
                onToggle: () => _toggle(context, index),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _restoreOrder(context),
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(S.current.Prefs_Tabs_Reset),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabTile extends StatelessWidget {
  final int index;
  final DetailTabPreference tab;
  final VoidCallback onToggle;

  const _TabTile({super.key, required this.index, required this.tab, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = detailTabLabel(tab.tabType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 0),
          leading: ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: S.current.Prefs_Tabs_Drag,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.drag_indicator),
              ),
            ),
          ),
          title: Text(
            name,
            style: TextStyle(
              color: tab.visible ? colors.onSurface : colors.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: IconButton(
            tooltip: tab.visible
                ? S.current.Prefs_Tabs_Hide(name)
                : S.current.Prefs_Tabs_Show(name),
            icon: Icon(tab.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}
