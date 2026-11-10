import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/user/edit/edit_labels.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';

/// Small spinner used in place of a field while it saves.
class SmallSpinner extends StatelessWidget {
  final Color? color;
  const SmallSpinner({super.key, this.color});

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
}

/// Caption above a field, with an optional trailing action. [hint] is accepted for the
/// callers that still pass it but is never drawn (DailyAL has no such caption).
class FieldCaption extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget? action;
  const FieldCaption(this.label, {super.key, this.hint, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge,
            ),
          ),
          if (action != null) ...[const Spacer(), action!],
        ],
      ),
    );
  }
}

/// Button showing the list status; opens the status picker.
class StatusButton extends StatelessWidget {
  final String? status;
  final bool busy;
  final bool isAnime;
  final ValueChanged<String> onChanged;

  const StatusButton({
    super.key,
    required this.status,
    required this.isAnime,
    required this.onChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(context, status);
    return SizedBox(
      height: 48,
      width: double.infinity,
      // Tonal, regular weight, like DailyAL's status button.
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: busy ? null : () => _pick(context),
        child: busy
            ? const SmallSpinner()
            : Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusLabel(status),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 20),
                ],
              ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final statuses = isAnime ? animeStatuses : mangaStatuses;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(S.current.Status,
                    style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final value in statuses)
                ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: statusColor(ctx, value), shape: BoxShape.circle),
                  ),
                  title: Text(statusLabel(value)),
                  selected: value == status,
                  trailing: value == status ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(ctx, value),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != status) onChanged(picked);
  }
}

/// `−  [ 12 ]  +` stepper: the field submits on done, the buttons step by one.
class ProgressStepper extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final ValueChanged<int> onSubmitted;
  final String? semanticLabel;

  const ProgressStepper({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.busy = false,
    this.semanticLabel,
  });

  int get _value => int.tryParse(controller.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: S.current.Edit_Decrease,
            onPressed: busy ? null : () => onSubmitted(_value - 1),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: busy
                ? const Center(child: SmallSpinner())
                : Semantics(
                    label: semanticLabel,
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      textInputAction: TextInputAction.done,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (v) => onSubmitted(int.tryParse(v) ?? 0),
                    ),
                  ),
          ),
          IconButton(
            tooltip: S.current.Edit_Increase,
            onPressed: busy ? null : () => onSubmitted(_value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Small `−  3  +` counter for the rewatch / reread count.
class CountStepper extends StatelessWidget {
  final int value;
  final bool busy;
  final ValueChanged<int> onChanged;

  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: S.current.Edit_Decrease,
          visualDensity: VisualDensity.compact,
          onPressed: busy || value <= 0 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove, size: 20),
        ),
        SizedBox(
          width: 32,
          child: Center(
            child: busy
                ? const SmallSpinner()
                : Text('$value',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        IconButton(
          tooltip: S.current.Edit_Increase,
          visualDensity: VisualDensity.compact,
          onPressed: busy ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add, size: 20),
        ),
      ],
    );
  }
}
