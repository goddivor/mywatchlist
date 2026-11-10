import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/content_preferences.dart';
import 'package:mywatchlist/widgets/calendar/calendar_logic.dart';
import 'package:mywatchlist/widgets/calendar/calendar_models.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Seconds since the epoch, updated once a second by the calendar screen; the
/// countdowns of the visible rows listen to it.
typedef SecondsClock = ValueListenable<int>;

/// "in 2 d 4 h", "in 3 h 12 min" or "in 4 min 05 s" until [airingAt]; "Aired"
/// once it has passed.
String countdownText(DateTime airingAt, DateTime now) {
  final delta = airingAt.difference(now);
  if (delta.isNegative || delta == Duration.zero) return S.current.Cal_Aired;
  final p = splitDuration(delta);
  if (p.days > 0) return S.current.Cal_In_Days_Hours(p.days, p.hours);
  if (p.hours > 0) return S.current.Cal_In_Hours_Minutes(p.hours, p.minutes);
  return S.current.Cal_In_Minutes_Seconds(p.minutes, p.seconds);
}

/// A countdown label that follows [clock].
class CountdownLabel extends StatelessWidget {
  final DateTime airingAt;
  final SecondsClock clock;
  final TextStyle? style;

  const CountdownLabel({super.key, required this.airingAt, required this.clock, this.style});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: clock,
      builder: (_, seconds, __) => Text(
        countdownText(airingAt, DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Label of a MAL list status (`watching`...), from the shared kit strings.
String? statusLabel(String? status) => switch (status) {
      'watching' => S.current.Kit_Status_Watching,
      'plan_to_watch' => S.current.Kit_Status_Plan_To_Watch,
      'completed' => S.current.Kit_Status_Completed,
      'on_hold' => S.current.Kit_Status_On_Hold,
      'dropped' => S.current.Kit_Status_Dropped,
      _ => null,
    };

/// One episode of the week, laid out like DailyAL's calendar row: round cover
/// with the air time under it, the title, the episode and its countdown, the
/// user's list status and an add-to-calendar button (hidden once aired).
class EpisodeTile extends StatelessWidget {
  final CalendarEntry entry;
  final TimezonePref timezone;
  final SecondsClock clock;
  final bool showStatus;
  final VoidCallback onOpen;

  /// Null hides the button (an episode that already aired).
  final VoidCallback? onAddToCalendar;

  const EpisodeTile({
    super.key,
    required this.entry,
    required this.timezone,
    required this.clock,
    required this.showStatus,
    required this.onOpen,
    this.onAddToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = inTimezone(entry.airingAt, timezone);
    final time = '${DateFormat('HH:mm').format(shown)} ${timezoneLabel(timezone)}';
    final label = showStatus ? statusLabel(entry.listStatus) : null;
    final episode = entry.numEpisodes == null
        ? S.current.Cal_Episode_Short(entry.episode)
        : S.current.Cal_Episode_Of_Total(entry.episode, entry.numEpisodes!);
    final small = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppImage(
                    url: entry.imageUrl,
                    width: 60,
                    height: 60,
                    borderRadius: BorderRadius.circular(30),
                    placeholderColor: scheme.surfaceContainerHighest,
                    semanticLabel: entry.title,
                  ),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          time,
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(episode, style: small),
                      CountdownLabel(
                        airingAt: entry.airingAt,
                        clock: clock,
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                      ),
                      if (label != null) _StatusBadge(label: label),
                    ],
                  ),
                ],
              ),
            ),
            if (onAddToCalendar != null)
              IconButton(
                tooltip: S.current.Cal_Add_Title,
                icon: const Icon(Icons.add_alert_outlined),
                onPressed: onAddToCalendar,
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Header of one day of the week (DailyAL's accordion title): an arrow, the
/// weekday and the number of episodes shown. Tapping it folds the day.
class DayHeader extends StatelessWidget {
  final DateTime date;
  final int count;
  final bool open;
  final VoidCallback onToggle;

  const DayHeader({
    super.key,
    required this.date,
    required this.count,
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final weekday = toBeginningOfSentenceCase(DateFormat.EEEE(locale).format(date), locale);
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text('$weekday ($count)', style: theme.textTheme.titleMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "now" line of today's list: the current time of the chosen zone on a rule.
/// Tapping it calls [onTap] (the screen announces the next show).
class NowDivider extends StatelessWidget {
  final DateTime now;
  final TimezonePref timezone;
  final VoidCallback? onTap;

  const NowDivider({super.key, required this.now, required this.timezone, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = inTimezone(now, timezone);
    final text = '${DateFormat('HH:mm').format(shown)} ${timezoneLabel(timezone)}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Row(children: [
          Expanded(child: Divider(color: scheme.primary, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(child: Divider(color: scheme.primary, thickness: 1.5)),
        ]),
      ),
    );
  }
}

/// The seven days as a row of chips (weekday, day of the month, episode count).
class DayStrip extends StatelessWidget {
  final List<CalendarDay> days;
  final int selected;
  final ValueChanged<int> onSelected;

  const DayStrip({super.key, required this.days, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _DayChip(
                  day: days[i],
                  isToday: i == 0,
                  isSelected: i == selected,
                  scheme: scheme,
                  textTheme: theme.textTheme,
                  onTap: () => onSelected(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final CalendarDay day;
  final bool isToday;
  final bool isSelected;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fg = isSelected ? scheme.onPrimary : scheme.onSurface;
    final muted = isSelected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final count = day.entries.length;
    return Semantics(
      selected: isSelected,
      button: true,
      label: '${DateFormat.EEEE(locale).format(day.date)} ${day.date.day}, $count',
      child: Material(
        type: isSelected ? MaterialType.canvas : MaterialType.transparency,
        color: isSelected ? scheme.primary : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isToday && !isSelected ? BorderSide(color: scheme.primary) : BorderSide.none,
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Long day names ("Aujourd'hui", "Donnerstag") shrink to the
                // pill's width instead of being cut.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isToday ? S.current.Cal_Today : DateFormat.E(locale).format(day.date),
                      style: textTheme.labelSmall?.copyWith(color: muted),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('${day.date.day}', style: textTheme.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: textTheme.labelSmall?.copyWith(
                    color: count == 0 ? muted.withValues(alpha: 0.5) : muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
