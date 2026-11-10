import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';

/// The bar under a comfortable card: mean score and members on the start side,
/// the status button (status colour, short status, your score or a pencil) on
/// the end side. Only the button is tappable (it opens the edit sheet).
///
/// Flat surface, no elevation: the bar repeats in every list.
class AnimeCardBar extends StatelessWidget {
  final NodeStatusValue? nsv;
  final double smallHeight;
  final double smallWidth;
  final double radius;
  final Anime? node;
  final bool showMemberCount;
  final bool showNsv;
  final VoidCallback? onTap;
  final bool showEdit;
  final bool showSelfScoreInsteadOfStatus;
  final MyListStatus? myListStatus;

  /// The user's entry for the title (cache first); falls back to [myListStatus].
  final CardListEntry? entry;

  const AnimeCardBar({
    super.key,
    this.nsv,
    this.radius = 6,
    this.smallHeight = 30,
    this.smallWidth = 30,
    this.onTap,
    this.showMemberCount = true,
    this.showNsv = true,
    this.showEdit = true,
    this.node,
    this.showSelfScoreInsteadOfStatus = false,
    this.myListStatus,
    this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = node?.score ?? 0;
    final members = node?.members ?? 0;
    final userScore = entry?.score ?? myListStatus?.score ?? 0;
    final showButton = showNsv && showEdit;

    return SizedBox(
      width: smallWidth,
      height: smallHeight,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
                child: _stats(context, score, members),
              ),
            ),
            if (showButton)
              _StatusButton(
                nsv: nsv,
                radius: radius,
                score: showSelfScoreInsteadOfStatus ? userScore : 0,
                onTap: onTap,
              ),
          ],
        ),
      ),
    );
  }

  /// Score and members as separate widgets: digits stay in order in
  /// right-to-left languages.
  Widget _stats(BuildContext context, double score, int members) {
    final scheme = Theme.of(context).colorScheme;
    final hasMembers = showMemberCount && members > 0;
    return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreReveal(
              iconSize: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: 15, color: AppColors.of(context).score.color),
                  const SizedBox(width: 3),
                  Text(
                    score > 0 ? ratingFormat.format(score) : '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
            if (hasMembers) ...[
              const SizedBox(width: 6),
              Icon(Icons.people_alt_outlined,
                  size: 11, color: scheme.onSurfaceVariant),
              const SizedBox(width: 2),
              Text(
                userCountFormat.format(members),
                maxLines: 1,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ));
  }
}

class _StatusButton extends StatelessWidget {
  final NodeStatusValue? nsv;
  final double radius;
  final int score;
  final VoidCallback? onTap;

  const _StatusButton({
    required this.nsv,
    required this.radius,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = nsv?.role(context);
    final background = role?.container ?? scheme.surfaceContainerHighest;
    final foreground = role?.onContainer ?? scheme.onSurfaceVariant;
    final hasScore = score > 0 && !scoreHiddenOf(context);
    final label = nsv?.fullLabel;
    return Semantics(
      button: true,
      label: label == null
          ? S.current.Card_Edit
          : S.current.Card_Edit_Status(label),
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.only(
            bottomEnd: Radius.circular(radius),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: double.infinity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasScore) ...[
                    Icon(Icons.star_rounded, size: 13, color: foreground),
                    Text('$score ',
                        style: TextStyle(fontSize: 12, color: foreground)),
                  ],
                  if (nsv?.status != null)
                    Text(
                      nsv!.status!,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit, size: 14, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill with the short status ("CW", "CMP"), used by the user-updates
/// list.
class StatusBadge extends StatelessWidget {
  final double height;
  final double width;
  final NodeStatusValue nsv;
  const StatusBadge(this.nsv,
      {this.height = 30.0, this.width = 40.0, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = nsv.role(context);
    final color = role?.container ?? scheme.surfaceContainerHighest;
    final foreground = role?.onContainer ?? scheme.onSurfaceVariant;
    return Semantics(
      label: nsv.fullLabel,
      excludeSemantics: nsv.fullLabel != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          height: height,
          width: width,
          child: Center(
            child: Text(
              nsv.status ?? '',
              maxLines: 1,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
