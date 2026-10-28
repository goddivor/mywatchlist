import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart';
import 'package:mywatchlist/widgets/Simkl/media/simkl_media_format.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Horizontal padding of the page's sections (DailyAL's detail page uses the same).
const double simklPagePadding = 15;

/// Title row of a section, DailyAL's layout: the name at 22 and, when the section has more,
/// an arrow button that opens the full list.
class SimklSectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;

  const SimklSectionTitle(this.title, {super.key, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final view = onViewAll;
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding + 10, 25, simklPagePadding, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          if (view != null)
            IconButton(
              tooltip: S.current.Smp_View_All,
              onPressed: view,
              icon: const Icon(Icons.arrow_forward),
            ),
        ],
      ),
    );
  }
}

/// A section: its title row then its body.
class SimklSection extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  final Widget child;

  const SimklSection({super.key, required this.title, required this.child, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SimklSectionTitle(title, onViewAll: onViewAll), child],
    );
  }
}

/// Text folded to [maxLines] with Show more / Show less.
class SimklExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;

  const SimklExpandableText(this.text, {super.key, this.maxLines = 5, this.style});

  @override
  State<SimklExpandableText> createState() => _SimklExpandableTextState();
}

class _SimklExpandableTextState extends State<SimklExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.style ?? theme.textTheme.bodyMedium;
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: style,
            maxLines: _open ? null : widget.maxLines,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          if (overflows || _open)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? S.current.Smp_Show_Less : S.current.Smp_Show_More),
            ),
        ],
      );
    });
  }
}

/// Wrapped tonal chips; tappable when [onTap] is given.
class SimklChips extends StatelessWidget {
  final List<String> labels;
  final void Function(int index)? onTap;
  final int? limit;

  const SimklChips(this.labels, {super.key, this.onTap, this.limit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = limit == null || labels.length <= limit! ? labels : labels.sublist(0, limit);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < shown.length; i++)
          if (onTap == null)
            Chip(
              label: Text(shown[i]),
              labelStyle: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
              backgroundColor: scheme.secondaryContainer,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            )
          else
            ActionChip(
              label: Text(shown[i]),
              labelStyle: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
              backgroundColor: scheme.secondaryContainer,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              onPressed: () => onTap!(i),
            ),
      ],
    );
  }
}

/// Watchers by status (C1): one bar per status in the list status colours, then the total.
class SimklWatchersView extends StatelessWidget {
  final SimklWatchers watchers;

  const SimklWatchersView(this.watchers, {super.key});

  static ListStatusTone _tone(SimklWatcherStatus s) => switch (s) {
        SimklWatcherStatus.watching => ListStatusTone.watching,
        SimklWatcherStatus.planToWatch => ListStatusTone.planned,
        SimklWatcherStatus.completed => ListStatusTone.completed,
        SimklWatcherStatus.onHold => ListStatusTone.onHold,
        SimklWatcherStatus.dropped => ListStatusTone.dropped,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final total = watchers.total ?? watchers.sum;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: simklPagePadding + 10),
      child: Column(
        children: [
          for (final b in watchers.buckets)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(SimklFormat.watcherStatus(b.status), style: theme.textTheme.bodyMedium)),
                      Text(
                        b.percent == null
                            ? SimklFormat.count(b.users)
                            : '${SimklFormat.count(b.users)} · ${SimklFormat.percent(b.percent!)}',
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total <= 0 ? 0 : (b.users / total).clamp(0.0, 1.0),
                      minHeight: 6,
                      color: colors.status(_tone(b.status)).color,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          if (total > 0)
            Row(
              children: [
                Expanded(child: Text(S.current.Smp_Total, style: theme.textTheme.titleSmall)),
                Text(SimklFormat.count(total), style: theme.textTheme.titleSmall),
              ],
            ),
        ],
      ),
    );
  }
}

/// One counter of the reactions bar (C7).
class SimklCounter {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const SimklCounter(this.icon, this.label, [this.onTap]);
}

/// The counters as a row of tonal pills (reactions, reviews, comments, memos).
class SimklCountersRow extends StatelessWidget {
  final List<SimklCounter> counters;

  const SimklCountersRow(this.counters, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding, 4, simklPagePadding, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in counters)
            Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: c.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(c.label, style: TextStyle(color: scheme.onSurface, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A horizontal strip built lazily.
class SimklStrip extends StatelessWidget {
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;

  const SimklStrip({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: simklPagePadding),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// A 16:9 picture with a centred play mark (trailers).
class SimklTrailerCard extends StatelessWidget {
  final SimklTrailer trailer;
  final VoidCallback onTap;
  static const double width = 220;

  const SimklTrailerCard({super.key, required this.trailer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: trailer.name ?? S.current.Smp_Trailers,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AppImage(
              url: trailer.thumbnail,
              width: width,
              height: width * 9 / 16,
              borderRadius: BorderRadius.circular(12),
              placeholderColor: scheme.surfaceContainerHighest,
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: colors.imageScrim, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.play_arrow_rounded, size: 32, color: colors.onImageScrim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An episode card of the strip: still, "Episode N", its title and air date.
class SimklEpisodeCard extends StatelessWidget {
  final SimklEpisode episode;
  final VoidCallback? onTap;
  static const double width = 200;
  static double heightFor(BuildContext context) =>
      width * 9 / 16 + 8 + MediaQuery.textScalerOf(context).scale(56);

  const SimklEpisodeCard({super.key, required this.episode, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heading = episode.number != null && !episode.isSpecial
        ? S.current.Smp_Episode_Number(episode.number!)
        : S.current.Smp_Specials;
    final date = episode.date;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              url: episode.imageUrl,
              width: width,
              height: width * 9 / 16,
              borderRadius: BorderRadius.circular(12),
              placeholderColor: scheme.surfaceContainerHighest,
              errorWidget: (_) => DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant)),
              ),
            ),
            const SizedBox(height: 8),
            Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
            Text(
              episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            Text(
              !episode.aired
                  ? S.current.Smp_Not_Aired
                  : date == null
                      ? ''
                      : SimklFormat.episodeDate(date),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A poster card of the related / recommended rows, with a line under the title (relation
/// type, share of users).
class SimklLinkedCard extends StatelessWidget {
  final SimklLinkedTitle item;
  final String? caption;
  final VoidCallback onTap;
  static const double width = 112;
  static double heightFor(BuildContext context) =>
      width * 1.5 + 6 + MediaQuery.textScalerOf(context).scale(56);

  const SimklLinkedCard({super.key, required this.item, required this.onTap, this.caption});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: item.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImage(
                url: item.posterUrl,
                width: width,
                height: width * 1.5,
                borderRadius: BorderRadius.circular(10),
                placeholderColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 6),
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round avatar with the initial when the member has no picture.
class SimklAvatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;

  const SimklAvatar({super.key, required this.url, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.secondaryContainer,
      child: Text(initial, style: TextStyle(color: scheme.onSecondaryContainer)),
    );
    if (url == null) return fallback;
    return AppImage(
      url: url,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      placeholderColor: scheme.surfaceContainerHighest,
      errorWidget: (_) => fallback,
    );
  }
}

/// Reviews summary (C3): share of positive reviews and the three counts.
class SimklReviewSummaryRow extends StatelessWidget {
  final SimklReviewSummary summary;

  const SimklReviewSummaryRow(this.summary, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final scheme = theme.colorScheme;
    Widget count(String label, int value, Color color) => Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 5),
            Text('${SimklFormat.count(value)} $label', style: theme.textTheme.labelMedium),
          ]),
        );
    final share = summary.positivePercent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(simklPagePadding + 10, 0, simklPagePadding, 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        children: [
          if (share != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                S.current.Smp_Positive_Share(SimklFormat.percent(share)),
                style: theme.textTheme.titleSmall?.copyWith(color: colors.success.color),
              ),
            ),
          count(S.current.Smp_Positive, summary.positive, colors.success.color),
          count(S.current.Smp_Neutral, summary.neutral, scheme.onSurfaceVariant),
          count(S.current.Smp_Negative, summary.negative, colors.danger.color),
        ],
      ),
    );
  }
}

/// A review card (C3): author, date, overall score, the five sub-scores and the excerpt.
/// [compact] = DailyAL's fixed-width card of the strip (excerpt folded); otherwise full width.
class SimklReviewCard extends StatelessWidget {
  final SimklReview review;
  final bool compact;
  final VoidCallback? onOpen;
  static const double width = 320;

  const SimklReviewCard({super.key, required this.review, this.compact = true, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = AppColors.of(context);
    final toneColor = switch (review.tone) {
      SimklReviewTone.positive => colors.success.color,
      SimklReviewTone.negative => colors.danger.color,
      _ => scheme.onSurfaceVariant,
    };
    final date = SimklFormat.siteDate(review.date) ?? review.date;
    final overall = review.overall;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SimklAvatar(url: review.avatarUrl, name: review.author),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  if (date != null)
                    Text(date, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (overall != null)
              Tooltip(
                message: S.current.Smp_Overall,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.star_rounded, size: 20, color: colors.score.color),
                  const SizedBox(width: 2),
                  Text('$overall', style: theme.textTheme.titleMedium?.copyWith(color: toneColor)),
                ]),
              ),
          ],
        ),
        if (review.title != null) ...[
          const SizedBox(height: 10),
          Text(
            review.title!,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: theme.textTheme.titleSmall,
          ),
        ],
        if (review.scores.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              for (final e in review.scores.entries)
                Text(
                  '${SimklFormat.aspect(e.key)} ${e.value}',
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (compact)
          Expanded(
            child: Text(
              review.text,
              overflow: TextOverflow.fade,
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          Text(review.text, style: theme.textTheme.bodyMedium),
        if (!compact && (review.helpful != null || (review.truncated && onOpen != null))) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (review.helpful != null && review.helpfulTotal != null)
                Expanded(
                  child: Text(
                    S.current.Smp_Helpful(review.helpful!, review.helpfulTotal!),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                )
              else
                const Spacer(),
              if (review.truncated && onOpen != null)
                TextButton(onPressed: onOpen, child: Text(S.current.Smp_Read_Full_Review)),
            ],
          ),
        ],
      ],
    );
    final card = Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(padding: const EdgeInsets.all(14), child: body),
      ),
    );
    return compact ? SizedBox(width: width, child: card) : card;
  }
}

/// A comment (C4): avatar, name, VIP badge, date, likes and the text; a spoiler stays folded
/// until tapped. Replies are indented.
class SimklCommentTile extends StatefulWidget {
  final SimklComment comment;

  const SimklCommentTile(this.comment, {super.key});

  @override
  State<SimklCommentTile> createState() => _SimklCommentTileState();
}

class _SimklCommentTileState extends State<SimklCommentTile> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final when = SimklFormat.siteDate(c.exactTime);
    final hidden = c.spoiler && !_revealed;
    return Padding(
      padding: EdgeInsets.fromLTRB(simklPagePadding + 10 + c.depth.clamp(0, 4) * 24.0, 8, simklPagePadding + 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SimklAvatar(url: c.avatarUrl, name: c.author),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    ),
                    if (c.vip) ...[
                      const SizedBox(width: 6),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          child: Text(
                            S.current.Smp_Vip,
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onTertiaryContainer),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (c.likes > 0) ...[
                      Icon(Icons.favorite, size: 14, color: scheme.primary),
                      const SizedBox(width: 3),
                      Text(SimklFormat.count(c.likes), style: theme.textTheme.labelSmall),
                    ],
                  ],
                ),
                if (when != null)
                  Text(when, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                if (hidden)
                  InkWell(
                    onTap: () => setState(() => _revealed = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        S.current.Smp_Spoiler,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary),
                      ),
                    ),
                  )
                else
                  SelectableText(c.text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A memo (C5): member, likes and the one-line note.
class SimklMemoTile extends StatelessWidget {
  final SimklMemo memo;

  const SimklMemoTile(this.memo, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: simklPagePadding + 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(children: [
              Icon(Icons.thumb_up_alt_outlined, size: 16, color: scheme.onSurfaceVariant),
              Text(SimklFormat.count(memo.likes), style: theme.textTheme.labelSmall),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: memo.author, style: theme.textTheme.titleSmall),
                const TextSpan(text: '  '),
                TextSpan(text: memo.text, style: theme.textTheme.bodyMedium),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the information table: label on the left, value on the right.
class SimklInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const SimklInfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: simklPagePadding + 10, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Placeholder block while a section loads (shared shimmer ticker).
class SimklBlockSkeleton extends StatelessWidget {
  final double height;

  const SimklBlockSkeleton({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(context).shimmerBase;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: simklPagePadding, vertical: 8),
      child: ShimmerColor(
        DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: SizedBox(height: height, width: double.infinity),
        ),
      ),
    );
  }
}
