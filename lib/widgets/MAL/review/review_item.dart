import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/review_reactions.dart';
import 'package:mywatchlist/widgets/MAL/review/user_link.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart' show RoundAvatar;
import 'package:mywatchlist/widgets/common/score_reveal.dart';

/// The star and the score of a review (DailyAL: plain text beside the star). A hidden score
/// (preference) is replaced by an eye that reveals it on tap.
class ReviewScoreBadge extends StatelessWidget {
  final int? score;
  final double size;

  const ReviewScoreBadge({super.key, required this.score, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final value = score ?? 0;
    return ScoreReveal(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/star.png', height: size * 0.92),
          const SizedBox(width: 6),
          Text(
            value > 0 ? '$value' : '-',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.bold,
              color: value > 0 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small coloured label ("Spoiler", "Preliminary").
class ReviewTag extends StatelessWidget {
  final String text;
  final Color color;
  final bool large;

  const ReviewTag({super.key, required this.text, required this.color, this.large = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(large ? 6 : 4),
        border: large ? Border.all(color: color.withValues(alpha: 0.3)) : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: large ? 8 : 6, vertical: large ? 3 : 2),
        child: Text(
          text,
          style: TextStyle(fontSize: large ? 11 : 10, color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Avatar and name of a reviewer; a tap opens the quick user sheet.
class ReviewerChip extends StatelessWidget {
  final AnimeReview review;
  final double avatarSize;
  final double nameWidth;

  const ReviewerChip({super.key, required this.review, this.avatarSize = 42, this.nameWidth = 64});

  @override
  Widget build(BuildContext context) {
    final username = review.user?.username;
    final name = (username == null || username.isEmpty) ? S.current.Social_Review_Anonymous : username;
    final linkable = isLinkableUser(username);
    return Semantics(
      button: linkable,
      label: linkable ? S.current.Social_Open_Profile(name) : name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: linkable ? () => openMalUser(context, username) : null,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoundAvatar(url: review.user?.images?.jpg?.imageUrl, size: avatarSize),
              const SizedBox(height: 4),
              SizedBox(
                width: nameWidth,
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One review card, laid out like DailyAL's: score (star) and tags on the
/// left, the reviewer (round picture, name) on the right, the start of the
/// text, the reactions in one row, then "Show more…" and the date. A tap on
/// the card or on "Show more…" opens the full review; a tap on the reviewer
/// opens their profile. The parent gives the size (320 dp wide in the detail
/// row, the whole width in the "view all" list).
class ReviewItem extends StatelessWidget {
  final AnimeReview review;
  final VoidCallback onTap;

  const ReviewItem({super.key, required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final date = formatReviewDate(review.date, locale);
    final tags = review.tags ?? const <String>[];
    final reactions = sortedReactions(review.reactions);
    final faded = scheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsetsDirectional.only(end: 10, bottom: 4, top: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ReviewScoreBadge(score: review.score),
                        const SizedBox(height: 10),
                        for (final tag in tags.take(3))
                          Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(color: faded),
                          ),
                        if (review.isPreliminary == true || review.isSpoiler == true) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (review.isPreliminary == true)
                                ReviewTag(text: S.current.Social_Review_Preliminary, color: scheme.primary),
                              if (review.isSpoiler == true)
                                ReviewTag(text: S.current.Social_Review_Spoiler, color: scheme.error),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  ReviewerChip(review: review, avatarSize: 40),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                child: Text(
                  review.review?.trim() ?? '',
                  overflow: TextOverflow.fade,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ),
            if (reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: SizedBox(
                  height: 20,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: reactions.length,
                    itemBuilder: (_, i) {
                      final (kind, count) = reactions[i];
                      return Tooltip(
                        message: kind.label,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(kind.icon, size: 14, color: faded),
                              const SizedBox(width: 3),
                              Text('$count', style: theme.textTheme.labelSmall?.copyWith(color: faded)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 5, 15, 10),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: S.current.Dp_Open_Review,
                    excludeSemantics: true,
                    child: Text(S.current.Dp_Show_More, style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
                  ),
                  const Spacer(),
                  if (date.isNotEmpty) Text(date, style: theme.textTheme.labelSmall?.copyWith(color: faded)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
