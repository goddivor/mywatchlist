import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart' show detailTabLabel;
import 'package:mywatchlist/user/preferences/preferences.dart';

/// Opens the "Customize sections" sheet of the detail page (DAL "Customize
/// tabs"): reorder with the handle, show or hide with the switch. Every
/// change is saved at once in the contract preference (`animeTabs` /
/// `mangaTabs`), which the open detail screen listens to, so the page
/// follows while the sheet is open. [manga] picks which list is edited.
Future<void> showTabsCustomizer(BuildContext context, {required bool manga}) {
  final bloc = Preferences.bloc ?? context.read<PreferencesBloc>();
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: TabsCustomizer(manga: manga),
    ),
  );
}

/// Body of [showTabsCustomizer].
class TabsCustomizer extends StatefulWidget {
  final bool manga;

  const TabsCustomizer({super.key, required this.manga});

  @override
  State<TabsCustomizer> createState() => _TabsCustomizerState();
}

class _TabsCustomizerState extends State<TabsCustomizer> {
  // Local copy: the list reorders at once while the bloc saves in the background.
  late List<DetailTabPreference> _tabs = List.of(_saved(context));

  List<DetailTabPreference> _saved(BuildContext context) {
    final content = context.read<PreferencesBloc>().state.content;
    return widget.manga ? content.mangaTabs : content.animeTabs;
  }

  void _save(List<DetailTabPreference> tabs) {
    setState(() => _tabs = tabs);
    final manga = widget.manga;
    context.read<PreferencesBloc>().add(ContentPreferencesChanged(
        (p) => manga ? p.copyWith(mangaTabs: tabs) : p.copyWith(animeTabs: tabs)));
  }

  void _reorder(int oldIndex, int newIndex) {
    final tabs = List.of(_tabs);
    if (newIndex > oldIndex) newIndex -= 1;
    tabs.insert(newIndex, tabs.removeAt(oldIndex));
    _save(tabs);
  }

  void _toggle(int index, bool visible) {
    final tabs = List.of(_tabs);
    tabs[index] = tabs[index].copyWith(visible: visible);
    _save(tabs);
  }

  void _restore() => _save(List.of(
      widget.manga ? ContentPreferences.defaultMangaTabs : ContentPreferences.defaultAnimeTabs));

  @override
  Widget build(BuildContext context) {
    final s = S.current;
    final theme = Theme.of(context);
    final shown = _tabs.where((t) => t.visible).length;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 12, 4),
            child: Row(
              children: [
                Expanded(child: Text(s.Dh_Customize, style: theme.textTheme.titleLarge)),
                TextButton(onPressed: _restore, child: Text(s.Dh_Customize_Reset)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
            child: Text(
              '${s.Dh_Customize_Hint}\n${s.Dh_Customize_Count(shown, _tabs.length)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _tabs.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                return SwitchListTile(
                  key: ValueKey(tab.tabType),
                  value: tab.visible,
                  onChanged: (value) => _toggle(index, value),
                  title: Text(detailTabLabel(tab.tabType)),
                  secondary: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.Dh_Done),
            ),
          ),
        ],
      ),
    );
  }
}
