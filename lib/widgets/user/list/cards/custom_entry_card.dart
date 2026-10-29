import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';

/// A list row drawn from a custom card layout ([ContentCardProps], DailyAL
/// `CustomizableFieldWidget`): each visible field at its saved position.
///
/// In the editor ([onFieldTap] / [onFieldDrag] set) fields can be selected and
/// dragged; [selected] gets an outline.
class CustomEntryCard extends StatelessWidget {
  final ContentCardProps props;
  final ListEntryView entry;
  final EntryActions? actions;
  final DateTime now;
  final String locale;

  /// Fields in drawing order (later = on top); defaults to [props] fields.
  final List<CustomizableField>? fields;
  final CustomizableFieldType? selected;
  final ValueChanged<CustomizableFieldType>? onFieldTap;
  final void Function(CustomizableFieldType type, Offset delta)? onFieldDrag;

  const CustomEntryCard({
    super.key,
    required this.props,
    required this.entry,
    required this.now,
    required this.locale,
    this.actions,
    this.fields,
    this.selected,
    this.onFieldTap,
    this.onFieldDrag,
  });

  bool get _editing => onFieldTap != null;

  /// The layout prints the watched count ("4 / 12 ep." or the watched field).
  bool get _showsProgress => (fields ?? props.fields).any((f) =>
      !f.hidden &&
      (f.type == CustomizableFieldType.edit_and_watched_button ||
          f.type == CustomizableFieldType.watched_eps));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(10);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: SizedBox(
        height: props.height,
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _editing || actions == null ? null : () => actions!.onOpen(entry),
            onLongPress: _editing || actions?.onEdit == null ? null : () => actions!.onEdit!(entry),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final field in fields ?? props.fields)
                    if (!field.hidden || _editing) _positioned(context, field, constraints.maxWidth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _positioned(BuildContext context, CustomizableField field, double width) {
    final p = field.position;
    final maxWidth = (width - (p.left ?? 0) - (p.right ?? 0) - 8).clamp(24.0, width);
    Widget child = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: _field(context, field.type),
    );
    if (_editing) {
      final isSelected = selected == field.type;
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onFieldTap!(field.type),
        onPanUpdate: isSelected ? (d) => onFieldDrag?.call(field.type, d.delta) : null,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 0.5,
            ),
          ),
          // Hidden fields stay visible in the editor, faded by a lighter colour scheme.
          child: field.hidden
              ? ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0x99FFFFFF), BlendMode.modulate),
                  child: child,
                )
              : child,
        ),
      );
    }
    return Positioned(top: p.top, left: p.left, right: p.right, bottom: p.bottom, child: child);
  }

  Widget _field(BuildContext context, CustomizableFieldType type) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final airing = entry.releaseState == ReleaseState.releasing ? entry.broadcast : null;
    switch (type) {
      case CustomizableFieldType.title:
        return Text(entry.title,
            maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall);
      case CustomizableFieldType.image:
        return EntryCover(entry: entry, width: 86, height: (props.height - 10).clamp(40.0, 400.0));
      case CustomizableFieldType.media_type:
        return Text(entry.mediaType == null ? '' : mediaTypeLabel(entry.mediaType!),
            style: theme.textTheme.labelMedium);
      case CustomizableFieldType.mean_score:
        return MeanScore(entry: entry);
      case CustomizableFieldType.num_list_users:
        final members = entry.members;
        return Text(members == null ? '' : NumberFormat.compact(locale: locale).format(members),
            style: muted);
      case CustomizableFieldType.list_status:
        return StatusPill(entry: entry);
      case CustomizableFieldType.list_score:
        return MyScore(entry: entry);
      case CustomizableFieldType.edit_and_watched_button:
        final actions = this.actions;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Text(progressText(entry), style: theme.textTheme.labelMedium),
          const SizedBox(width: 6),
          if (actions != null && !_editing)
            EntryStepper(entry: entry, actions: actions)
          else
            const Icon(Icons.edit_rounded, size: 18),
        ]);
      case CustomizableFieldType.next_episode_counter:
        if (airing == null) return const SizedBox.shrink();
        return Text(_shortCountdown(airing.nextAiring(now).difference(now.toUtc())),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary));
      case CustomizableFieldType.un_seen_episodes:
        // Both badges unless the layout already prints the progress (DailyAL's rule).
        return EntryEpisodeBadges(entry: entry, now: now, showReleased: !_showsProgress);
      case CustomizableFieldType.watched_eps:
        return Text('${entry.progress}', style: theme.textTheme.labelLarge);
      case CustomizableFieldType.total_eps:
        return Text(entry.total > 0 ? '${entry.total}' : '?', style: theme.textTheme.labelLarge);
      case CustomizableFieldType.genre:
        return Text(entry.genres.join(', '),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: muted);
      case CustomizableFieldType.edit_btn:
        final onEdit = actions?.onEdit;
        return IconButton.filledTonal(
          onPressed: onEdit == null || _editing ? null : () => onEdit(entry),
          tooltip: S.current.UserList_Edit_Entry,
          icon: const Icon(Icons.edit_rounded, size: 18),
          visualDensity: VisualDensity.compact,
        );
      case CustomizableFieldType.airing_date:
        if (airing == null) return const SizedBox.shrink();
        final next = airing.nextAiring(now);
        final shown = switch (Preferences.content.timezone) {
          TimezonePref.utc => next,
          TimezonePref.jst => next.add(const Duration(hours: 9)),
          TimezonePref.local => next.toLocal(),
        };
        return Text(DateFormat('E d MMM HH:mm', locale).format(shown), style: muted);
      case CustomizableFieldType.next_episode_full_counter:
        final text = airingText(entry, now, locale);
        if (text == null) return const SizedBox.shrink();
        return Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary));
      case CustomizableFieldType.time_left:
        final left = entry.timeLeft;
        if (left == null || left == Duration.zero) return const SizedBox.shrink();
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.hourglass_bottom_rounded, size: 13, color: muted?.color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(S.current.Ltf_Time_Left_Value(formatListDuration(left)),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
          ),
        ]);
    }
  }

  static String _shortCountdown(Duration d) => d.inDays > 0
      ? S.current.UserList_Short_Days_Hours(d.inDays, d.inHours % 24)
      : S.current.UserList_Short_Hours_Minutes(d.inHours, d.inMinutes % 60);
}
