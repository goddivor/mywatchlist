import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Fixed height of a list row per sub type (lets the list skip layout work).
double listRowExtent(DisplaySubType subType) => switch (subType) {
      DisplaySubType.compact => 64,
      DisplaySubType.spacious => 176,
      _ => 128,
    };

/// One row of the list layout ([DisplaySubType.comfortable], compact or spacious).
class EntryListTile extends StatelessWidget {
  final ListEntryView entry;
  final DisplaySubType subType;
  final EntryActions actions;
  final EntryCardStyle style;
  final DateTime now;
  final String locale;

  const EntryListTile({
    super.key,
    required this.entry,
    required this.subType,
    required this.actions,
    required this.style,
    required this.now,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final body = switch (subType) {
      DisplaySubType.compact => _compact(context),
      DisplaySubType.spacious => _rich(context, spacious: true),
      _ => _rich(context, spacious: false),
    };
    final radius = BorderRadius.circular(12);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: style.cardBackground ? scheme.surfaceContainerLow : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () => actions.onOpen(entry),
          onLongPress: actions.onEdit == null ? null : () => actions.onEdit!(entry),
          child: body,
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          EntryCover(entry: entry, width: 36, height: 48, borderRadius: BorderRadius.circular(6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (style.showStatus) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: entry.status?.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(progressText(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 8),
                    MyScore(entry: entry, fontSize: 11),
                  ],
                ),
              ],
            ),
          ),
          UnseenPill(count: entry.unseenCount(now)),
          const SizedBox(width: 6),
          EntryStepper(entry: entry, actions: actions, compact: true),
        ],
      ),
    );
  }

  Widget _rich(BuildContext context, {required bool spacious}) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final coverW = spacious ? 112.0 : 84.0;
    final coverH = spacious ? 160.0 : 120.0;
    final airing = style.showAiringInfo || spacious ? airingText(entry, now, locale) : null;
    final unseen = entry.unseenCount(now);
    final badges = <Widget>[
      if (style.showStatus) StatusPill(entry: entry),
      if (style.showPriority && entry.priority > 0) PriorityPill(priority: entry.priority),
      MeanScore(entry: entry, showMembers: spacious),
    ];
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: coverW,
            height: coverH,
            child: Stack(
              children: [
                EntryCover(entry: entry, width: coverW, height: coverH, large: spacious),
                if (unseen > 0)
                  PositionedDirectional(bottom: 4, end: 4, child: UnseenPill(count: unseen)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: badges,
                ),
                const SizedBox(height: 4),
                Text(entry.title,
                    maxLines: spacious ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(height: 1.2)),
                const SizedBox(height: 2),
                Text(
                  spacious && entry.genres.isNotEmpty
                      ? '${mediaLine(entry)}\n${entry.genres.take(4).join(', ')}'
                      : mediaLine(entry),
                  maxLines: spacious ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (airing != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(airing,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    MyScore(entry: entry),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(progressText(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium),
                    ),
                    EntryStepper(entry: entry, actions: actions),
                  ],
                ),
                const SizedBox(height: 4),
                EntryProgressBar(entry: entry),
                const SizedBox(height: 2),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// One cell of the grid layout (comfortable, compact or cover only).
class EntryGridCard extends StatelessWidget {
  final ListEntryView entry;
  final DisplaySubType subType;
  final EntryActions actions;
  final EntryCardStyle style;
  final DateTime now;

  const EntryGridCard({
    super.key,
    required this.entry,
    required this.subType,
    required this.actions,
    required this.style,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(10);
    final unseen = entry.unseenCount(now);
    final cover = Stack(
      fit: StackFit.expand,
      children: [
        EntryCover(entry: entry, borderRadius: radius, large: true),
        if (subType == DisplaySubType.comfortable)
          // Static scrim (no blur) so the title stays readable on any cover.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 1],
                colors: [Color(0x00000000), Color(0xD9000000)],
              ),
            ),
          ),
        PositionedDirectional(
          top: 6,
          start: 6,
          end: 6,
          child: Row(
            children: [
              if (style.showStatus && entry.status != null)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: entry.status!.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              const Spacer(),
              UnseenPill(count: unseen),
            ],
          ),
        ),
        if (subType == DisplaySubType.comfortable)
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: Colors.white, height: 1.15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(progressText(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: const Color(0xE6FFFFFF))),
                    ),
                    if (entry.score > 0)
                      MyScore(entry: entry, fontSize: 11, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 4),
                EntryProgressBar(entry: entry),
              ],
            ),
          ),
      ],
    );
    final card = subType == DisplaySubType.compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cover),
              const SizedBox(height: 4),
              EntryProgressBar(entry: entry),
              const SizedBox(height: 4),
              Text(entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(height: 1.15)),
            ],
          )
        : cover;
    return Semantics(
      button: true,
      label: entry.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => actions.onOpen(entry),
        onLongPress: actions.onEdit == null ? null : () => actions.onEdit!(entry),
        child: card,
      ),
    );
  }
}
