import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/calendar_export.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';

/// Opens the "add to calendar" sheet of [entry]: add it to the device calendar
/// (once or every week until the last episode) or export an .ics file.
Future<void> showAddToCalendarSheet(
  BuildContext context, {
  required CalendarEntry entry,
  required TimezonePref timezone,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AddToCalendarSheet(
      entry: entry,
      timezone: timezone,
      onResult: (message) {
        if (message.isEmpty) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
    ),
  );
}

class AddToCalendarSheet extends StatefulWidget {
  final CalendarEntry entry;
  final TimezonePref timezone;

  /// Receives the translated outcome message to show once the sheet is closed.
  final ValueChanged<String> onResult;

  const AddToCalendarSheet({super.key, required this.entry, required this.timezone, required this.onResult});

  @override
  State<AddToCalendarSheet> createState() => _AddToCalendarSheetState();
}

class _AddToCalendarSheetState extends State<AddToCalendarSheet> {
  late final int? _count = recurrenceCount(total: widget.entry.numEpisodes, nextEpisode: widget.entry.episode);
  late bool _recurring = (_count ?? 0) > 1;
  bool _busy = false;

  int? get _recurringCount => _recurring ? _count : null;

  Future<void> _run(Future<bool> Function() action, String success, String failure) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await action();
    widget.onResult(ok ? success : failure);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final shown = inTimezone(entry.airingAt, widget.timezone);
    final when = '${DateFormat.yMMMEd().format(shown)} · ${DateFormat('HH:mm').format(shown)} ${timezoneLabel(widget.timezone)}';
    final canRecurring = (_count ?? 0) > 1;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.event_available_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(S.current.Cal_Add_Title, style: theme.textTheme.titleLarge)),
          ]),
          const SizedBox(height: 16),
          Text(entry.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            '${S.current.Cal_Episode_Short(entry.episode)} · $when',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (canRecurring)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(S.current.Cal_Recurring),
              subtitle: Text(S.current.Cal_Recurring_Desc(_count!)),
              value: _recurring,
              onChanged: _busy ? null : (v) => setState(() => _recurring = v),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                S.current.Cal_Recurring_Unknown,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                      () => CalendarExporter.addToDevice(entry, recurringCount: _recurringCount),
                      S.current.Cal_Event_Added,
                      S.current.Cal_Event_Error,
                    ),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: Text(S.current.Cal_Add_Device),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => CalendarExporter.saveIcs(entry, recurringCount: _recurringCount),
                          S.current.Cal_Ics_Saved,
                          S.current.Cal_Ics_Error,
                        ),
                icon: const Icon(Icons.download_outlined),
                label: Text(S.current.Cal_Save_Ics),
              ),
            ),
            if (!kIsWeb && defaultTargetPlatform != TargetPlatform.linux) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _run(
                            () => CalendarExporter.shareIcs(entry, recurringCount: _recurringCount),
                            '',
                            S.current.Cal_Ics_Error,
                          ),
                  icon: const Icon(Icons.share_outlined),
                  label: Text(S.current.Cal_Share_Ics),
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}
