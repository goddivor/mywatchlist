import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';
import 'package:mywatchlist/widgets/common/select/select_sheet.dart';
import 'package:mywatchlist/widgets/common/select/top_sheet.dart';

/// Where [SelectButton] shows its options.
enum SelectMode {
  /// Bottom sheet ([showSelectSheet]; searchable above 15 options).
  sheet,

  /// Chips sliding from the top ([showTopSheet] + [TopSelectSheet]).
  top,

  /// Popup menu anchored on the button.
  menu,
}

/// A compact button showing the current choice; tapping it opens the [options]
/// ([mode]) and reports the pick through [onChanged]. It is controlled: the
/// caller keeps [selected] and rebuilds with the new value.
///
/// By default it is a tonal pill "label ▾" ("Select" when nothing is picked).
/// Give [icon] for an icon-only button (its tooltip is [title]), or [child] for
/// any custom face.
///
/// ```dart
/// SelectButton<String>(
///   title: S.current.Sort,
///   options: sorts,
///   selected: state.sort,
///   onChanged: (sort) => bloc.add(SortChanged(sort)),
/// )
/// ```
class SelectButton<T> extends StatelessWidget {
  final List<SelectOption<T>> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final String? title;
  final SelectMode mode;
  final IconData? icon;
  final Widget? child;

  const SelectButton({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.title,
    this.mode = SelectMode.sheet,
    this.icon,
    this.child,
  });

  Future<void> _open(BuildContext context) async {
    final T? picked = switch (mode) {
      SelectMode.sheet => await showSelectSheet<T>(context, options: options, selected: selected, title: title),
      SelectMode.top => await showTopSheet<T>(
          context: context,
          child: TopSelectSheet<T>(options: options, selected: selected, title: title),
        ),
      SelectMode.menu => null,
    };
    if (picked != null && picked != selected) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (mode == SelectMode.menu) return _menu(context);
    if (icon != null) {
      return IconButton(tooltip: title, icon: Icon(icon), onPressed: () => _open(context));
    }
    if (child != null) {
      return InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _open(context), child: child);
    }
    return _Pill(label: labelOf(options, selected) ?? S.current.Select, onTap: () => _open(context));
  }

  Widget _menu(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: title ?? S.current.Show_Menu,
      initialValue: selected,
      onSelected: (value) {
        if (value != selected) onChanged(value);
      },
      itemBuilder: (_) => [
        for (final option in options)
          CheckedPopupMenuItem<T>(
            value: option.value,
            checked: option.value == selected,
            child: Text(option.label),
          ),
      ],
      icon: icon == null ? null : Icon(icon),
      child: icon != null
          ? null
          : child ?? _Pill(label: labelOf(options, selected) ?? S.current.Select),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _Pill({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final face = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
          Icon(Icons.arrow_drop_down, color: scheme.onSecondaryContainer),
        ],
      ),
    );
    return Material(
      color: scheme.secondaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      // In menu mode the PopupMenuButton handles the tap.
      child: onTap == null ? face : InkWell(onTap: onTap, child: face),
    );
  }
}
