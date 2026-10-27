import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';
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
        type: style.cardBackground ? MaterialType.canvas : MaterialType.transparency,
        color: style.cardBackground ? scheme.surfaceContainerLow : null,
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
                            color: entry.status?.colors(context).color, shape: BoxShape.circle),
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
          // The row prints the progress: only the red "+N" badge.
          EntryEpisodeBadges(entry: entry, now: now, showReleased: false),
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
                // The row prints the progress: only the red "+N" badge.
                PositionedDirectional(
                  bottom: 4,
                  end: 4,
                  child: EntryEpisodeBadges(entry: entry, now: now, showReleased: false),
                ),
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

/// Corner radius of grid cards (DailyAL `AnimeGridCard.borderRadius`).
const double gridCardRadius = 6;

/// Height of the score / status bar under a grid cover (DailyAL `smallHeight`).
const double gridCardBarHeight = 30;

/// Text scale allowed in grid cards: past it the cover would shrink too much.
const double _gridMaxTextScale = 1.3;

/// Height of the text block under the bar of a comfortable grid card (title
/// and genres, one line each), so every card of a row has the same height.
double gridCardTextBlockHeight(TextScaler scaler) {
  final s = scaler.clamp(maxScaleFactor: _gridMaxTextScale);
  return 10 + s.scale(14) * _gridLineHeight + 5 + s.scale(9) * _gridLineHeight + 5;
}

const double _gridLineHeight = 1.3;

/// One cell of the grid layout, DailyAL's grid card ([DisplaySubType.comfortable],
/// the default), its compact card (title over the cover) or the cover alone.
///
/// The cell has the fixed extent of the grid; the cover takes what the fixed
/// bar and text block leave, so a long title never changes a card's height.
/// None of these cards print the progress, so the cover carries both episode
/// badges (released and not seen).
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

  void _edit() => actions.onEdit?.call(entry);

  @override
  Widget build(BuildContext context) {
    final card = switch (subType) {
      DisplaySubType.compact => _compact(context),
      DisplaySubType.cover_only_grid => _cover(context, rounded: BorderRadius.circular(gridCardRadius)),
      _ => _comfortable(context),
    };
    return Semantics(
      button: true,
      label: entry.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => actions.onOpen(entry),
        onLongPress: actions.onEdit == null ? null : _edit,
        child: MediaQuery.withClampedTextScaling(maxScaleFactor: _gridMaxTextScale, child: card),
      ),
    );
  }

  /// Cover with the episode badges, the airing band and the priority flag.
  Widget _cover(BuildContext context, {required BorderRadius rounded, List<Widget> extra = const []}) {
    final airing = style.showAiringInfo ? airingText(entry, now, Localizations.localeOf(context).toString()) : null;
    final tokens = AppColors.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        EntryCover(entry: entry, borderRadius: rounded, large: true),
        ...extra,
        if (airing != null)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.imageScrim,
                borderRadius: BorderRadius.vertical(top: rounded.topLeft),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Text(
                  airing,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, height: 1.2, color: tokens.onImageScrim),
                ),
              ),
            ),
          ),
        PositionedDirectional(
          top: airing != null ? 22 : 7,
          end: 3,
          child: EntryEpisodeBadges(entry: entry, now: now),
        ),
        if (style.showPriority && entry.priority > 0)
          PositionedDirectional(bottom: 5, start: 5, child: PriorityPill(priority: entry.priority)),
      ],
    );
  }

  /// DailyAL's grid card: clean cover, score / status bar, one-line title, one-line genres.
  Widget _comfortable(BuildContext context) {
    final theme = Theme.of(context);
    const top = BorderRadius.vertical(top: Radius.circular(gridCardRadius));
    final genres = entry.genres.take(3).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _cover(context, rounded: top)),
        GridCardBar(entry: entry, onEdit: actions.onEdit == null ? null : _edit),
        SizedBox(
          height: gridCardTextBlockHeight(MediaQuery.textScalerOf(context)),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, height: _gridLineHeight),
                ),
                const SizedBox(height: 5),
                Text(
                  genres,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 9, height: _gridLineHeight, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// DailyAL's compact grid card: the title on a scrim at the bottom of the
  /// cover, the edit button in the status colour, watch progress on top and
  /// mean score / members at the top start.
  Widget _compact(BuildContext context) {
    final tokens = AppColors.of(context);
    final radius = BorderRadius.circular(gridCardRadius);
    final mean = entry.meanScore;
    final members = entry.members;
    final hasMean = mean != null && mean > 0;
    final hasMembers = members != null && members > 0;
    final format = NumberFormat.compact(locale: Intl.getCurrentLocale());
    final meanText = [
      if (hasMean) mean.toStringAsFixed(2),
      if (hasMembers) format.format(members),
    ].join(' | ');
    final onEdit = actions.onEdit == null ? null : _edit;
    return _cover(context, rounded: radius, extra: [
      // Static scrim (no blur) under the title, as DailyAL's fading effect.
      PositionedDirectional(
        start: 0,
        end: 0,
        bottom: 0,
        height: 80,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: radius.bottomLeft),
            gradient: tokens.bottomScrimGradient,
          ),
        ),
      ),
      PositionedDirectional(
        start: 0,
        end: 0,
        bottom: 0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(5, 0, 5, 8),
                child: Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 1.2, color: tokens.onImageScrim),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GridEditButton(entry: entry, onEdit: onEdit),
          ],
        ),
      ),
      if (entry.status != null && progressRatio(entry) != null)
        PositionedDirectional(
          top: 0,
          start: 1.5,
          end: 1.5,
          child: EntryProgressBar(entry: entry, height: 2.5),
        ),
      if (meanText.isNotEmpty)
        PositionedDirectional(
          top: 7,
          start: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.imageScrim, borderRadius: radius),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ScoreReveal(
                iconSize: 11,
                iconColor: tokens.onImageScrim,
                hidden: hasMean ? null : false,
                child: Text(
                  meanText,
                  style: TextStyle(fontSize: 9, height: 1.2, color: tokens.onImageScrim),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// The bar under a grid cover (DailyAL `AnimeCardBar`): ★ mean score at the
/// start ("-" when unknown, tap to reveal when scores are hidden), the status
/// chip with the edit pencil at the end. Tapping the bar opens the edit sheet.
class GridCardBar extends StatelessWidget {
  final ListEntryView entry;
  final VoidCallback? onEdit;

  const GridCardBar({super.key, required this.entry, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.vertical(bottom: Radius.circular(gridCardRadius));
    final status = entry.status;
    final role = status?.colors(context);
    final chipForeground = role?.onColor ?? scheme.onSurface;
    return SizedBox(
      height: gridCardBarHeight,
      child: Material(
        // Flat surface instead of DailyAL's elevation 5: no blurred shadow per card.
        color: scheme.surfaceContainerHigh,
        borderRadius: radius,
        child: InkWell(
          onTap: onEdit,
          borderRadius: radius,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MeanScore(entry: entry, fontSize: 11.5, dashWhenUnknown: true),
                ),
              ),
              const SizedBox(width: 5),
              Semantics(
                button: onEdit != null,
                label: status == null
                    ? S.current.UserList_Edit_Entry
                    : '${status.label(isAnime: entry.isAnime)}, ${S.current.UserList_Edit_Entry}',
                excludeSemantics: true,
                child: Container(
                  height: gridCardBarHeight,
                  decoration: BoxDecoration(
                    color: role?.color ?? scheme.surfaceContainerHighest,
                    borderRadius: const BorderRadiusDirectional.only(
                      bottomEnd: Radius.circular(gridCardRadius),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status != null) ...[
                        Text(
                          status.shortLabel(isAnime: entry.isAnime),
                          maxLines: 1,
                          style: TextStyle(fontSize: 12, height: 1.2, color: chipForeground),
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (onEdit != null) Icon(Icons.edit, size: 16, color: chipForeground),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit button of the compact grid card (DailyAL `editIconButton`): in the
/// status colour, the user's score with a star when scored, else a pencil.
class GridEditButton extends StatelessWidget {
  final ListEntryView entry;
  final VoidCallback? onEdit;

  const GridEditButton({super.key, required this.entry, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = entry.status?.colors(context);
    final background = role?.color ?? scheme.surfaceContainerHighest;
    final foreground = role?.onColor ?? scheme.onSurface;
    final scored = entry.status != null && entry.score > 0;
    final hidden = scoreHiddenOf(context);
    final Widget child = scored && !hidden
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star, size: 16, color: foreground),
              Text('${entry.score}',
                  style: TextStyle(fontSize: 12, color: foreground)),
            ],
          )
        : Icon(Icons.edit, size: 16, color: foreground);
    const shape = BorderRadiusDirectional.only(
      topStart: Radius.circular(gridCardRadius * 2),
      bottomEnd: Radius.circular(gridCardRadius),
    );
    return Semantics(
      button: true,
      label: S.current.UserList_Edit_Entry,
      excludeSemantics: true,
      child: SizedBox(
        width: scored && !hidden ? 40 : 30,
        height: 30,
        child: Material(
          color: background,
          borderRadius: shape,
          child: InkWell(
            onTap: onEdit,
            borderRadius: shape.resolve(Directionality.of(context)),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
