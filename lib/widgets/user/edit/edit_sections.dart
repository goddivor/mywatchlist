import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/user/edit/edit_fields.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/number_bar.dart';

/// Collapsible section of the advanced editor.
class EditSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  const EditSection({
    super.key,
    required this.title,
    required this.icon,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: editEaseOut,
                  child: const Icon(Icons.expand_more, size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: editEaseOut,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// One labelled row of the advanced editor: label on the left, control on the right.
class EditRow extends StatelessWidget {
  final String label;
  final Widget control;
  const EditRow({super.key, required this.label, required this.control});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          control,
        ],
      ),
    );
  }
}

/// Start or finish date: shows MAL's date exactly (partial dates as is) and
/// opens a date picker.
class DateField extends StatelessWidget {
  final String label;
  final String? date;
  final bool busy;
  final ValueChanged<DateTime> onPicked;

  const DateField({
    super.key,
    required this.label,
    required this.date,
    required this.onPicked,
    this.busy = false,
  });

  /// Full dates in the app language; partial ones (`2024-03`) untouched.
  static String display(BuildContext context, String? date) {
    if (date == null) return S.current.Edit_Not_Set;
    final full = DateTime.tryParse(date);
    if (full == null) return date;
    try {
      return DateFormat.yMMMd(Localizations.localeOf(context).toString())
          .format(full);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = date == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldCaption(label),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              foregroundColor: empty
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
            onPressed: busy ? null : () => _pick(context),
            icon: busy
                ? const SmallSpinner()
                : const Icon(Icons.event_outlined, size: 18),
            label: Text(
              display(context, date),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final lastDate = DateTime(now.year + 1, 12, 31);
    var initial = parseApiDate(date) ?? now;
    if (initial.isAfter(lastDate)) initial = lastDate;
    if (initial.isBefore(DateTime(1900))) initial = DateTime(1900);
    final picked = await showDatePicker(
      context: context,
      helpText: label,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: lastDate,
    );
    if (picked != null) onPicked(picked);
  }
}

/// Read-only preview of a text field (comments, tags); a tap opens the popup
/// editor (DAL ee084b6).
class TextPreviewTile extends StatelessWidget {
  final String label;
  final String text;
  final String emptyText;
  final IconData icon;
  final bool busy;
  final VoidCallback onTap;

  const TextPreviewTile({
    super.key,
    required this.label,
    required this.text,
    required this.emptyText,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldCaption(label),
        Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      empty ? emptyText : text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: empty
                          ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  busy
                      ? const SmallSpinner()
                      : Icon(Icons.edit_outlined,
                          size: 18, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Popup text editor; returns the new text, or null when cancelled.
Future<String?> showTextEditor(
  BuildContext context, {
  required String title,
  required String initial,
  bool multiline = true,
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextEditorDialog(
      title: title,
      initial: initial,
      multiline: multiline,
      hint: hint,
    ),
  );
}

class _TextEditorDialog extends StatefulWidget {
  final String title;
  final String initial;
  final bool multiline;
  final String? hint;

  const _TextEditorDialog({
    required this.title,
    required this.initial,
    required this.multiline,
    this.hint,
  });

  @override
  State<_TextEditorDialog> createState() => _TextEditorDialogState();
}

class _TextEditorDialogState extends State<_TextEditorDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: widget.multiline ? 5 : 1,
          maxLines: widget.multiline ? 12 : 1,
          keyboardType:
              widget.multiline ? TextInputType.multiline : TextInputType.text,
          textInputAction:
              widget.multiline ? TextInputAction.newline : TextInputAction.done,
          onSubmitted: widget.multiline ? null : (_) => _save(),
          decoration: InputDecoration(
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.current.Cancel),
        ),
        FilledButton(onPressed: _save, child: Text(S.current.Edit_Save)),
      ],
    );
  }
}

/// Shape of the editor while the entry loads (shared shimmer, no spinner).
class EditSkeleton extends StatelessWidget {
  const EditSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget box(double height, {double? width, double radius = 14}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    return ShimmerColor(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: box(48)),
                const SizedBox(width: 12),
                Expanded(child: box(48)),
              ],
            ),
            const SizedBox(height: 16),
            box(14, width: 120, radius: 7),
            const SizedBox(height: 10),
            box(44, radius: 22),
          ],
        ),
      ),
    );
  }
}

/// Centred message with an optional main action and retry (load error,
/// expired session…).
class EditMessageView extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EditMessageView({
    super.key,
    required this.icon,
    required this.message,
    this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          if (onRetry != null || onAction != null) const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onAction != null && actionLabel != null)
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              if (onRetry != null)
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(S.current.Edit_Retry),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
