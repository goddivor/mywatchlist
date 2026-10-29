import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_review_page.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// "73 %" of the voters found it helpful; empty without votes.
String anilistHelpfulText(AnilistReview review) => review.ratingAmount <= 0
    ? ''
    : S.current.Als_Review_Helpful_Short((review.rating * 100 / review.ratingAmount).round());

/// A review in a feed: cover, title, summary, reviewer, score and helpful share. A tap
/// opens the whole review; [showMedia] false (a title's own reviews) drops the cover.
class AnilistReviewTile extends StatelessWidget {
  const AnilistReviewTile({
    super.key,
    required this.review,
    this.showMedia = true,
    this.onChanged,
  });

  final AnilistReview review;
  final bool showMedia;

  /// Called with the review as the page left it (votes).
  final ValueChanged<AnilistReview>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final media = review.media;
    final helpful = anilistHelpfulText(review);
    final meta = [
      review.user?.name ?? '',
      formatAnilistTime(review.createdAt),
      if (helpful.isNotEmpty) helpful,
    ].where((t) => t.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () async {
        final updated = await openAnilistReview(context, review.id, initial: review);
        if (updated != null) onChanged?.call(updated);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showMedia) ...[
              AppImage(
                url: media?.coverUrl,
                width: 54,
                height: 78,
                borderRadius: BorderRadius.circular(6),
                placeholderColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showMedia && media != null)
                    Text(
                      media.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  Text(
                    review.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: showMedia ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      if (review.isPrivate)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Icon(Icons.lock_outline,
                              size: 14, semanticLabel: s.Als_Private, color: scheme.onSurfaceVariant),
                        ),
                      AnilistScorePill(score: review.score),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
