import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/list_query.dart';

/// What a card can do with its entry; built once per list, shared by every card.
@immutable
class EntryActions {
  final void Function(ListEntryView entry) onOpen;
  final void Function(ListEntryView entry)? onEdit;

  /// +1 / -1 episode (chapter); null hides the buttons.
  final void Function(ListEntryView entry, int delta)? onStep;
  final bool Function(ListEntryView entry) canStep;

  /// Ids with a write in progress (their buttons show a spinner).
  final ValueListenable<Set<int>> busy;

  const EntryActions({
    required this.onOpen,
    required this.onEdit,
    required this.onStep,
    required this.canStep,
    required this.busy,
  });
}

/// List-wide card options, read once per list from the preferences.
@immutable
class EntryCardStyle {
  /// The status badge is shown (the "All" tab; a status tab already says it).
  final bool showStatus;
  final bool showPriority;
  final bool showAiringInfo;

  /// Cards drawn on a surface card (DAL `showAnimeMangaCard`).
  final bool cardBackground;

  const EntryCardStyle({
    this.showStatus = true,
    this.showPriority = false,
    this.showAiringInfo = false,
    this.cardBackground = false,
  });

  factory EntryCardStyle.fromPreferences(GeneralPreferences general, {required bool showStatus}) =>
      EntryCardStyle(
        showStatus: showStatus,
        showPriority: general.showPriority,
        showAiringInfo: general.showAiringInfo,
        cardBackground: general.showAnimeMangaCard,
      );
}

/// Cover of [entry] decoded at the slot size.
class EntryCover extends StatelessWidget {
  final ListEntryView entry;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool large;

  const EntryCover({
    super.key,
    required this.entry,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppImage(
      url: large ? (entry.largeImageUrl ?? entry.imageUrl) : (entry.imageUrl ?? entry.largeImageUrl),
      width: width,
      height: height,
      borderRadius: borderRadius,
      placeholderColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      semanticLabel: entry.title,
    );
  }
}

/// Small rounded label.
class EntryPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const EntryPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: foreground),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 10.5, height: 1.2, fontWeight: FontWeight.w600, color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// The entry's list status as a coloured pill.
class StatusPill extends StatelessWidget {
  final ListEntryView entry;
  const StatusPill({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final status = entry.status;
    if (status == null) return const SizedBox.shrink();
    return EntryPill(
      label: entry.repeating
          ? (entry.isAnime ? S.current.Edit_Rewatching : S.current.Edit_Rereading)
          : status.label(isAnime: entry.isAnime),
      icon: entry.repeating ? Icons.replay_rounded : null,
      background: status.color.withValues(alpha: 0.16),
      foreground: _readable(status.color, Theme.of(context).brightness),
    );
  }
}

/// A brighter hue on dark backgrounds so the label stays readable.
Color _readable(Color color, Brightness brightness) => brightness == Brightness.dark
    ? Color.lerp(color, Colors.white, 0.45)!
    : Color.lerp(color, Colors.black, 0.1)!;

/// "High" / "Medium" priority pill (nothing for low).
class PriorityPill extends StatelessWidget {
  final int priority;
  const PriorityPill({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    if (priority <= 0) return const SizedBox.shrink();
    final color = priority >= 2 ? const Color(0xFFD9363E) : const Color(0xFFE08A00);
    return EntryPill(
      label: priorityLabel(priority),
      icon: Icons.flag_rounded,
      background: color.withValues(alpha: 0.16),
      foreground: _readable(color, Theme.of(context).brightness),
    );
  }
}

/// Unseen episodes pill (aired but not watched).
class UnseenPill extends StatelessWidget {
  final int count;
  const UnseenPill({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: S.current.UserList_Unseen_Count(count),
      excludeSemantics: true,
      child: EntryPill(
        label: '+${NumberFormat.compact().format(count)}',
        background: scheme.error,
        foreground: scheme.onError,
      ),
    );
  }
}

/// Star + mean score of every user (hidden behind [ScoreReveal] when the
/// "Hide score" preference is on, as in DailyAL).
class MeanScore extends StatelessWidget {
  final ListEntryView entry;
  final double fontSize;
  final bool showMembers;

  const MeanScore({super.key, required this.entry, this.fontSize = 12, this.showMembers = false});

  @override
  Widget build(BuildContext context) {
    final mean = entry.meanScore;
    if (mean == null || mean <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final members = entry.members;
    return ScoreReveal(
      iconSize: fontSize + 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: fontSize + 3, color: const Color(0xFFF5B301)),
          const SizedBox(width: 2),
          Text(mean.toStringAsFixed(2),
              style: theme.textTheme.labelMedium?.copyWith(fontSize: fontSize)),
          if (showMembers && members != null && members > 0) ...[
            const SizedBox(width: 4),
            Text('(${NumberFormat.compact().format(members)})',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// The user's own score ("—" when not scored).
class MyScore extends StatelessWidget {
  final ListEntryView entry;
  final double fontSize;

  /// Text and icon colour (default: theme).
  final Color? color;
  const MyScore({super.key, required this.entry, this.fontSize = 13, this.color});

  @override
  Widget build(BuildContext context) {
    if (entry.status == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scored = entry.score > 0;
    return Semantics(
      label: scored ? S.current.UserList_My_Score_Value(entry.score) : S.current.UserList_Not_Scored,
      excludeSemantics: true,
      child: ScoreReveal(
        iconSize: fontSize + 1,
        iconColor: color,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, size: fontSize + 1, color: color ?? theme.colorScheme.primary),
            const SizedBox(width: 2),
            Text(scored ? '${entry.score}' : '–',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontSize: fontSize, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

/// "12 / 24 ep." or "34 / ? ch. · 3 vol."
String progressText(ListEntryView e) {
  final total = e.total > 0 ? '${e.total}' : '?';
  if (e.isAnime) return S.current.UserList_Progress_Episodes('${e.progress}', total);
  final chapters = S.current.UserList_Progress_Chapters('${e.progress}', total);
  if (e.progressVolumes <= 0) return chapters;
  return '$chapters · ${S.current.UserList_Progress_Volumes('${e.progressVolumes}')}';
}

/// "TV · 24 ep. · 2024" style line: media type and size.
String mediaLine(ListEntryView e) {
  final parts = <String>[
    if (e.mediaType != null) mediaTypeLabel(e.mediaType!),
    if (e.total > 0)
      e.isAnime
          ? S.current.UserList_Episode_Count(e.total)
          : (e.totalVolumes > 0
              ? S.current.UserList_Volume_Count(e.totalVolumes)
              : S.current.UserList_Chapter_Count(e.total)),
    if ((e.releaseStart?.length ?? 0) >= 4) e.releaseStart!.substring(0, 4),
  ];
  return parts.join(' · ');
}

/// Progress of [e] from 0 to 1, or null when the total is unknown.
double? progressRatio(ListEntryView e) {
  if (e.total <= 0) return null;
  return (e.progress / e.total).clamp(0.0, 1.0);
}

/// Next episode of an airing anime: "Ep. 8 · Sat 23:30 · in 2 d 4 h".
String? airingText(ListEntryView e, DateTime now, String locale) {
  if (!e.isAnime || e.releaseState != ReleaseState.releasing) return null;
  final slot = e.broadcast;
  if (slot == null) return null;
  final next = slot.nextAiring(now);
  final shown = _inTimezone(next, now);
  final when = DateFormat('E HH:mm', locale).format(shown);
  final released = e.releasedCount(now);
  final wait = next.difference(now.toUtc());
  final countdown = wait.inDays > 0
      ? S.current.UserList_In_Days_Hours(wait.inDays, wait.inHours % 24)
      : wait.inHours > 0
          ? S.current.UserList_In_Hours_Minutes(wait.inHours, wait.inMinutes % 60)
          : S.current.UserList_In_Minutes(wait.inMinutes < 1 ? 1 : wait.inMinutes);
  final episode = released == null ? null : released + 1;
  final head = episode != null && (e.total <= 0 || episode <= e.total)
      ? '${S.current.UserList_Episode_Short(episode)} · '
      : '';
  return '$head$when · $countdown';
}

/// [utc] shown in the time zone of the preferences (local, JST or UTC).
DateTime _inTimezone(DateTime utc, DateTime now) => switch (Preferences.content.timezone) {
      TimezonePref.utc => utc.toUtc(),
      TimezonePref.jst => utc.toUtc().add(const Duration(hours: 9)),
      TimezonePref.local => utc.toLocal(),
    };

/// Thin determinate progress bar (no animation).
class EntryProgressBar extends StatelessWidget {
  final ListEntryView entry;
  final double height;
  const EntryProgressBar({super.key, required this.entry, this.height = 3});

  @override
  Widget build(BuildContext context) {
    final ratio = progressRatio(entry);
    if (ratio == null || entry.status == null) return SizedBox(height: height);
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          color: entry.status?.color ?? scheme.primary,
        ),
      ),
    );
  }
}

/// [-] [edit] [+] buttons of an entry (only edit when it cannot step).
class EntryStepper extends StatelessWidget {
  final ListEntryView entry;
  final EntryActions actions;
  final bool compact;

  const EntryStepper({super.key, required this.entry, required this.actions, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onStep = actions.onStep;
    final canStep = onStep != null && actions.canStep(entry);
    final atEnd = entry.total > 0 && entry.progress >= entry.total;
    return ValueListenableBuilder<Set<int>>(
      valueListenable: actions.busy,
      builder: (context, busy, _) {
        final isBusy = busy.contains(entry.id);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canStep && !compact)
                _StepButton(
                  icon: Icons.remove_rounded,
                  tooltip: S.current.UserList_Minus_One,
                  onPressed: isBusy || entry.progress <= 0 ? null : () => onStep(entry, -1),
                ),
              if (actions.onEdit != null)
                isBusy
                    ? const SizedBox(
                        width: 36,
                        height: 32,
                        child: Center(
                            child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    : _StepButton(
                        icon: Icons.edit_rounded,
                        tooltip: S.current.UserList_Edit_Entry,
                        onPressed: () => actions.onEdit!(entry),
                      ),
              if (canStep)
                _StepButton(
                  icon: Icons.add_rounded,
                  tooltip: S.current.UserList_Plus_One,
                  onPressed: isBusy || atEnd ? null : () => onStep(entry, 1),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}
