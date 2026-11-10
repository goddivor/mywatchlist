import 'package:flutter/widgets.dart';

/// One choice of a select widget: the [value] handed back to the caller and the
/// already translated [label] shown to the user (pass an `S.current.*` string).
///
/// ```dart
/// final sorts = [
///   SelectOption('score', S.current.Score),
///   SelectOption('title', S.current.Title, icon: Icons.sort_by_alpha),
/// ];
/// ```
@immutable
class SelectOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const SelectOption(this.value, this.label, {this.icon});

  @override
  bool operator ==(Object other) =>
      other is SelectOption<T> && other.value == value && other.label == label && other.icon == icon;

  @override
  int get hashCode => Object.hash(value, label, icon);
}

/// The label of the option holding [value], or null when no option holds it.
String? labelOf<T>(List<SelectOption<T>> options, T? value) {
  if (value == null) return null;
  for (final option in options) {
    if (option.value == value) return option.label;
  }
  return null;
}
