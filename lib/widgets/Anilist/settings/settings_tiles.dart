import 'package:flutter/material.dart';

/// A titled block of settings rows.
class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const SettingsGroup({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// A row that picks one value out of [options] in a bottom sheet.
class ChoiceRow<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> options;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool enabled;

  const ChoiceRow({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      title: Text(title),
      subtitle: Text(label(value)),
      onTap: () async {
        final picked = await showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheet) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final o = options[i];
                  final selected = o == value;
                  return ListTile(
                    title: Text(label(o)),
                    trailing: selected
                        ? Icon(Icons.check_rounded, color: Theme.of(sheet).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(sheet, o),
                  );
                },
              ),
            ),
          ),
        );
        if (picked != null && picked != value) onChanged(picked);
      },
    );
  }
}

/// A switch row.
class SwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const SwitchRow({super.key, required this.title, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) =>
      SwitchListTile(title: Text(title), value: value, onChanged: onChanged);
}
