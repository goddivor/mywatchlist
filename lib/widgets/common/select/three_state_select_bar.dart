import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';

/// A chip that cycles through three states on each tap:
/// off → [exclude] → [include] → off. Used by [ThreeStateSelectBar] for
/// filters such as "Not in my list" / "In my list".
@immutable
class CycleOption<T> {
  /// Label shown while the chip is off.
  final String label;

  /// First state (shown with the error container color), e.g. "Not in my list".
  final SelectOption<T> exclude;

  /// Second state (shown with the primary container color), e.g. "In my list".
  final SelectOption<T> include;

  const CycleOption({required this.label, required this.exclude, required this.include});
}

/// A horizontal, lazily built row of single-choice filter chips. Tapping the
/// selected chip clears it (`onChanged(null)`). An optional [cycle] chip comes
/// first and cycles off → exclude → include → off; its two values share the
/// same [selected] slot as the regular [options], so one filter value at most
/// is active at a time (DailyAL behaviour).
///
/// ```dart
/// ThreeStateSelectBar<String>(
///   options: statuses,
///   selected: filter.status,
///   onChanged: (value) => bloc.add(StatusFilterChanged(value)),
///   cycle: CycleOption(
///     label: S.current.Kit_In_List,
///     exclude: SelectOption('not_in_list', S.current.Kit_Not_In_List),
///     include: SelectOption('in_list', S.current.Kit_In_List),
///   ),
/// )
/// ```
class ThreeStateSelectBar<T> extends StatelessWidget {
  final List<SelectOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onChanged;
  final CycleOption<T>? cycle;
  final EdgeInsetsGeometry padding;

  const ThreeStateSelectBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.cycle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// The value after one tap on the [cycle] chip when [current] is selected.
  static T? nextCycleValue<T>(CycleOption<T> cycle, T? current) {
    if (current == cycle.exclude.value) return cycle.include.value;
    if (current == cycle.include.value) return null;
    return cycle.exclude.value;
  }

  @override
  Widget build(BuildContext context) {
    final hasCycle = cycle != null;
    final count = options.length + (hasCycle ? 1 : 0);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (hasCycle && index == 0) return Center(child: _cycleChip(context, cycle!));
          final option = options[index - (hasCycle ? 1 : 0)];
          final isSelected = option.value == selected;
          return Center(
            child: FilterChip(
              avatar: option.icon == null ? null : Icon(option.icon, size: 18),
              label: Text(option.label),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onChanged(isSelected ? null : option.value),
            ),
          );
        },
      ),
    );
  }

  Widget _cycleChip(BuildContext context, CycleOption<T> cycle) {
    final scheme = Theme.of(context).colorScheme;
    final excluded = selected == cycle.exclude.value;
    final included = selected == cycle.include.value;
    final Color? background = excluded
        ? scheme.errorContainer
        : included
            ? scheme.primaryContainer
            : null;
    final Color? foreground = excluded
        ? scheme.onErrorContainer
        : included
            ? scheme.onPrimaryContainer
            : null;
    final label = excluded
        ? cycle.exclude.label
        : included
            ? cycle.include.label
            : cycle.label;
    final icon = excluded
        ? Icons.remove_circle_outline
        : included
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked;
    return FilterChip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      selected: excluded || included,
      selectedColor: background,
      showCheckmark: false,
      onSelected: (_) => onChanged(nextCycleValue(cycle, selected)),
    );
  }
}
