import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/select/searchable_select.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';

/// Above this many options [showSelectSheet] opens a [SearchableSelect] instead
/// of a plain list, so long lists (genres, studios, years) stay usable.
const int kSearchableSelectThreshold = 15;

/// Opens a bottom sheet listing [options] (single choice) and completes with
/// the picked value, or null when the sheet is dismissed.
///
/// [selected] is marked as checked. With more than [searchThreshold] options
/// the sheet gets a search field ([showSearchableSelect]).
///
/// ```dart
/// final sort = await showSelectSheet(
///   context,
///   title: S.current.Sort,
///   options: sorts,
///   selected: currentSort,
/// );
/// if (sort != null) bloc.add(SortChanged(sort));
/// ```
Future<T?> showSelectSheet<T>(
  BuildContext context, {
  required List<SelectOption<T>> options,
  T? selected,
  String? title,
  int searchThreshold = kSearchableSelectThreshold,
}) {
  if (options.length > searchThreshold) {
    return showSearchableSelect<T>(context, options: options, selected: selected, title: title);
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SelectSheet<T>(
      options: options,
      selected: selected,
      title: title,
      onSelected: (value) => Navigator.of(sheetContext).pop(value),
    ),
  );
}

/// Body of [showSelectSheet]: an optional [title] above a lazily built list of
/// [options], the [selected] one checked. Tapping an option calls [onSelected];
/// closing the sheet is the caller's job (use [showSelectSheet] for that).
class SelectSheet<T> extends StatelessWidget {
  final List<SelectOption<T>> options;
  final T? selected;
  final String? title;
  final ValueChanged<T> onSelected;

  const SelectSheet({
    super.key,
    required this.options,
    required this.onSelected,
    this.selected,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title!, style: theme.textTheme.titleLarge),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: options.length,
              itemBuilder: (context, index) => SelectOptionTile<T>(
                option: options[index],
                checked: options[index].value == selected,
                onTap: () => onSelected(options[index].value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of a select list: the option's icon (or a radio mark), its label,
/// highlighted with the accent color when [checked].
class SelectOptionTile<T> extends StatelessWidget {
  final SelectOption<T> option;
  final bool checked;
  final VoidCallback onTap;

  const SelectOptionTile({
    super.key,
    required this.option,
    required this.checked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      selected: checked,
      leading: Icon(option.icon ?? (checked ? Icons.radio_button_checked : Icons.radio_button_off)),
      trailing: checked && option.icon != null ? const Icon(Icons.check) : null,
      title: Text(option.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
