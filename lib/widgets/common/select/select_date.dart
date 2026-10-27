import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Formats [date] the way the tracker APIs expect it (`2024-04-07`), whatever
/// the app language.
String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// [date] as shown to the user: `Apr 7, 2024` in English, `7 avr. 2024` in
/// French (falls back to the numeric Material format if the locale has no
/// date symbols loaded).
String formatDisplayDate(BuildContext context, DateTime date) {
  try {
    return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
  } catch (_) {
    return MaterialLocalizations.of(context).formatCompactDate(date);
  }
}

/// A date field: shows [date] in the user's locale (or [hint], default
/// "Pick a date") and opens the Material date picker on tap. Give [onClear] to
/// show a clear button once a date is set. Controlled: the caller keeps [date].
///
/// The picker spans [firstDate] (default 1917, the oldest anime) to [lastDate]
/// (default ten years from now). Use [formatApiDate] to send the value.
///
/// ```dart
/// SelectDate(
///   label: S.current.Start_Date,
///   date: entry.startDate,
///   onChanged: (d) => setState(() => entry = entry.copyWith(startDate: d)),
///   onClear: () => setState(() => entry = entry.copyWith(startDate: null)),
/// )
/// ```
class SelectDate extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onClear;
  final String? label;
  final String? hint;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const SelectDate({
    super.key,
    required this.date,
    required this.onChanged,
    this.onClear,
    this.label,
    this.hint,
    this.firstDate,
    this.lastDate,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(1917);
    final last = lastDate ?? DateTime(now.year + 10, 12, 31);
    var initial = date ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: label,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = date == null ? (hint ?? S.current.Kit_Pick_Date) : formatDisplayDate(context, date!);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _pick(context),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12, 8, onClear != null && date != null ? 0 : 12, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (label != null)
                        Text(label!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: date == null ? scheme.onSurfaceVariant : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClear != null && date != null)
                  IconButton(
                    tooltip: S.current.Clear,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
