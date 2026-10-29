import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/calendar/airing_schedule.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/dub_icon.dart';
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

/// The dub pill over an anime cover (the "Show dub icon" setting and MyDubList decide, in
/// [DubStatusBadge]). Nothing for manga or an entry without a MyAnimeList id.
class EntryDubBadge extends StatelessWidget {
  final ListEntryView entry;
  final double radius;
  const EntryDubBadge({super.key, required this.entry, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    if (entry.category != 'anime' || entry.malId == null) return const SizedBox.shrink();
    return DubStatusBadge(animeId: entry.malId, radius: radius);
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
      background: status.colors(context).container,
      foreground: status.colors(context).onContainer,
    );
  }
}

/// "High" / "Medium" priority pill (nothing for low).
class PriorityPill extends StatelessWidget {
  final int priority;
  const PriorityPill({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    if (priority <= 0) return const SizedBox.shrink();
    final tokens = AppColors.of(context);
    final role = priority >= 2 ? tokens.danger : tokens.warning;
    return EntryPill(
      label: priorityLabel(priority),
      icon: Icons.flag_rounded,
      background: role.container,
      foreground: role.onContainer,
    );
  }
}

/// "Rewatched ×2" / "Reread ×2" when the user went through the title again
/// ([ListEntryView.timesRewatched] > 0). [short] draws only the replay icon and
/// "×2" (grid covers), with the full text for screen readers.
class RewatchPill extends StatelessWidget {
  final ListEntryView entry;
  final bool short;
  const RewatchPill({super.key, required this.entry, this.short = false});

  @override
  Widget build(BuildContext context) {
    final count = entry.timesRewatched;
    if (count <= 0) return const SizedBox.shrink();
    final text = entry.isAnime ? S.current.Ltf_Rewatched(count) : S.current.Ltf_Reread(count);
    final role = AppColors.of(context).completed;
    final pill = EntryPill(
      label: short ? '×$count' : text,
      icon: Icons.replay_rounded,
      background: role.container,
      foreground: role.onContainer,
    );
    return short ? Semantics(label: text, excludeSemantics: true, child: pill) : pill;
  }
}

/// The episode badges of a cover, DailyAL's rule: a red "+N" badge for the
/// released episodes (chapters) the user has not watched yet and, when
/// [showReleased] is set, a blue badge with the number released so far
/// (hidden when it equals the red one, i.e. nothing watched yet). Nothing when
/// caught up or when the released count is unknown.
///
/// Cards that already print the progress ("4 / 12 ep.") pass
/// `showReleased: false`; the others (grid cards, layouts without the progress
/// field) show both. The released count comes from [ListEntryView.releasedCount]
/// (calendar schedule first, then the weekly estimate, then the total); for an
/// airing anime the badge rebuilds when the schedule loads.
class EntryEpisodeBadges extends StatefulWidget {
  final ListEntryView entry;
  final DateTime now;
  final bool showReleased;

  const EntryEpisodeBadges({
    super.key,
    required this.entry,
    required this.now,
    this.showReleased = true,
  });

  @override
  State<EntryEpisodeBadges> createState() => _EntryEpisodeBadgesState();
}

class _EntryEpisodeBadgesState extends State<EntryEpisodeBadges> {
  bool get _usesSchedule =>
      widget.entry.isAnime &&
      widget.entry.malId != null &&
      widget.entry.releaseState == ReleaseState.releasing;

  @override
  void initState() {
    super.initState();
    if (_usesSchedule) requestAiringSchedule();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entry.status == null) return const SizedBox.shrink();
    if (!_usesSchedule) return _badges(context);
    return ListenableBuilder(
      listenable: AiringSchedule.instance,
      builder: (context, _) => _badges(context),
    );
  }

  Widget _badges(BuildContext context) {
    final e = widget.entry;
    final released = e.releasedCount(widget.now);
    if (released == null) return const SizedBox.shrink();
    final unseen = released - e.progress;
    if (unseen <= 0) return const SizedBox.shrink();
    final tokens = AppColors.of(context);
    final showReleased = widget.showReleased && released != unseen;
    final format = NumberFormat.compact(locale: Intl.getCurrentLocale());
    final label = e.isAnime
        ? S.current.UserList_Unseen_Count(unseen)
        : S.current.Lcd_Unread_Count(unseen);
    return Semantics(
      label: showReleased
          ? '${e.isAnime ? S.current.Lcd_Aired_Count(released) : S.current.Lcd_Released_Chapters(released)}, $label'
          : label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showReleased) ...[
            _EpisodeBadge(
              text: format.format(released),
              // DailyAL's solid blue / red with white bold text, the same in
              // light, dark and black (status chip shades, >= 3:1 bold).
              background: tokens.completed.container,
              foreground: tokens.completed.onContainer,
            ),
            const SizedBox(width: 3),
          ],
          _EpisodeBadge(
            text: '+${format.format(unseen)}',
            background: tokens.dropped.container,
            foreground: tokens.dropped.onContainer,
          ),
        ],
      ),
    );
  }
}

class _EpisodeBadge extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _EpisodeBadge({required this.text, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          text,
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
          style: TextStyle(fontSize: 10, height: 1.1, fontWeight: FontWeight.w700, color: foreground),
        ),
      ),
    );
  }
}

DateTime? _lastScheduleRequest;

/// Asks the calendar's [AiringSchedule] to load (shared request, no-op while
/// fresh); after a failure it is asked again at most every 5 minutes, so a
/// scrolling list never hammers the backend.
void requestAiringSchedule() {
  final schedule = AiringSchedule.instance;
  final now = DateTime.now();
  final last = _lastScheduleRequest;
  if (!schedule.isLoaded && last != null && now.difference(last) < const Duration(minutes: 5)) {
    return;
  }
  _lastScheduleRequest = now;
  schedule.ensureLoaded();
}

/// Star + mean score of every user (hidden behind [ScoreReveal] when the
/// "Hide score" preference is on, as in DailyAL).
class MeanScore extends StatelessWidget {
  final ListEntryView entry;
  final double fontSize;
  final bool showMembers;

  /// Shows "-" when the entry has no mean score instead of nothing (grid bar, as DailyAL).
  final bool dashWhenUnknown;

  const MeanScore({
    super.key,
    required this.entry,
    this.fontSize = 12,
    this.showMembers = false,
    this.dashWhenUnknown = false,
  });

  @override
  Widget build(BuildContext context) {
    final mean = entry.meanScore;
    final known = mean != null && mean > 0;
    if (!known && !dashWhenUnknown) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final members = entry.members;
    return ScoreReveal(
      iconSize: fontSize + 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: fontSize + 3, color: AppColors.of(context).score.color),
          const SizedBox(width: 2),
          Flexible(
            child: Text(known ? mean.toStringAsFixed(2) : '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(fontSize: fontSize)),
          ),
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
    // Rounded by the indicator itself: no clip layer per row.
    return LinearProgressIndicator(
      value: ratio,
      minHeight: height,
      borderRadius: BorderRadius.circular(height),
      backgroundColor: scheme.surfaceContainerHighest,
      color: entry.status?.colors(context).color ?? scheme.primary,
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
