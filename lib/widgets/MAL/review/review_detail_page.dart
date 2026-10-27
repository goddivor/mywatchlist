import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/review_reactions.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

/// A whole review: reviewer (tap = quick user sheet), score, tags, reactions, the
/// selectable text, the date and the progress of the reviewer. Share and "open on
/// MyAnimeList" sit in the header. The text scrolls inside the page; the page itself never
/// sits in another scroll view.
class ReviewDetailPage extends StatelessWidget {
  final AnimeReview review;
  final String category;

  const ReviewDetailPage({super.key, required this.review, this.category = 'anime'});

  void _share(BuildContext context) {
    showShareBuilder(
      context,
      fields: reviewShareFields(review),
      subject: review.user?.username,
      title: S.current.Social_Review_Share,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final date = formatReviewDate(review.date, locale);
    final url = review.url;
    final progress = review.episodesWatched;
    final reactions = sortedReactions(review.reactions);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (reviewShareFields(review).isNotEmpty)
                IconButton(
                  tooltip: S.current.Social_Review_Share,
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () => _share(context),
                ),
              if (url != null && url.isNotEmpty)
                IconButton(
                  tooltip: S.current.Social_Review_Open_Web,
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: () => openLink(context, url),
                ),
              IconButton(
                tooltip: S.current.Social_Close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReviewScoreBadge(score: review.score, size: 28),
                    const SizedBox(height: 8),
                    for (final tag in review.tags ?? const <String>[])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          tag,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (review.isPreliminary == true)
                          ReviewTag(
                            text: S.current.Social_Review_Preliminary,
                            color: theme.colorScheme.primary,
                            large: true,
                          ),
                        if (review.isSpoiler == true)
                          ReviewTag(
                            text: S.current.Social_Review_Spoiler,
                            color: theme.colorScheme.error,
                            large: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              ReviewerChip(review: review, avatarSize: 52, nameWidth: 96),
            ],
          ),
          if (reactions.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: reactions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (kind, count) = reactions[i];
                  return Tooltip(
                    message: kind.label,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kind.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kind.color.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(kind.icon, size: 16, color: kind.color),
                            const SizedBox(width: 5),
                            Text(
                              '$count',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: kind.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 20),
              child: SelectableText(
                review.review?.trim() ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (progress != null)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              category == 'manga'
                                  ? S.current.Social_Review_Chapters_Read(progress)
                                  : S.current.Social_Review_Episodes_Watched(progress),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
