import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/review_reactions.dart';
import 'package:mywatchlist/widgets/MAL/review/user_link.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/common/score_reveal.dart';

/// The star and the score of a review, coloured by value. A hidden score (preference) is
/// replaced by an eye that reveals it on tap.
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
              color: value > 0 ? reviewScoreColor(value) : Theme.of(context).colorScheme.onSurfaceVariant,
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
              AvatarWidget(height: avatarSize, width: avatarSize, url: review.user?.images?.jpg?.imageUrl),
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

/// One review in the horizontal list: reviewer, score, tags, the start of the text, the
/// top reactions and the date. A tap on the card opens the full review; a tap on the
/// reviewer opens their profile.
class ReviewItem extends StatelessWidget {
  final AnimeReview review;
  final VoidCallback onTap;

  const ReviewItem({super.key, required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = formatReviewDate(review.date, locale);
    final tags = review.tags?.take(2).toList() ?? const <String>[];
    final reactions = sortedReactions(review.reactions).take(4).toList();

    return Card(
      margin: const EdgeInsetsDirectional.only(end: 12, bottom: 4, top: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ReviewScoreBadge(score: review.score),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in tags)
                              Text(
                                tag,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                ),
                              ),
                            if (review.isPreliminary == true)
                              ReviewTag(text: S.current.Social_Review_Preliminary, color: theme.colorScheme.primary),
                            if (review.isSpoiler == true)
                              ReviewTag(text: S.current.Social_Review_Spoiler, color: theme.colorScheme.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ReviewerChip(review: review),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  review.review?.trim() ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 9,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        for (final (kind, count) in reactions)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(kind.icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Text(
                                '$count',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
