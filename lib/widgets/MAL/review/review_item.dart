import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

class ReviewItem extends StatelessWidget {
  final AnimeReview review;
  final VoidCallback onTap;

  const ReviewItem({
    super.key,
    required this.review,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = review.score ?? 0;
    final Color scoreColor =
        score >= 8 ? Colors.green : (score >= 5 ? Colors.amber : Colors.red);
    final dateStr = review.date != null
        ? DateFormat('MMM d, yyyy').format(DateTime.parse(review.date!))
        : '';

    return Card(
      margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Score + Tags | User avatar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score + Tags column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/star.png',
                              height: 22,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Tags row (inline, not stacked)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (review.tags != null && review.tags!.isNotEmpty)
                              ...review.tags!.take(2).map(
                                    (tag) => Text(
                                      tag,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                            if (review.isPreliminary == true)
                              _buildSmallTag(context, 'Preliminary',
                                  theme.colorScheme.primary),
                            if (review.isSpoiler == true)
                              _buildSmallTag(context, 'Spoiler', Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // User avatar + name
                  Column(
                    children: [
                      AvatarWidget(
                        height: 42,
                        width: 42,
                        url: review.user?.images?.jpg?.imageUrl,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          review.user?.username ?? '?',
                          style: theme.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Review text
              Expanded(
                child: Text(
                  review.review ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),

              const SizedBox(height: 8),

              // Bottom: Reactions + Date
              Row(
                children: [
                  // Reactions
                  Expanded(
                    child: _buildReactionBar(context),
                  ),
                  // Date
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
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

  Widget _buildSmallTag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildReactionBar(BuildContext context) {
    final reactions = review.reactions;
    if (reactions == null) return const SizedBox();

    final reactionList = <_ReactionData>[
      if ((reactions.nice ?? 0) > 0)
        _ReactionData(Icons.thumb_up, reactions.nice!),
      if ((reactions.loveIt ?? 0) > 0)
        _ReactionData(Icons.favorite, reactions.loveIt!),
      if ((reactions.funny ?? 0) > 0)
        _ReactionData(Icons.mood, reactions.funny!),
      if ((reactions.confusing ?? 0) > 0)
        _ReactionData(Icons.help_outline, reactions.confusing!),
      if ((reactions.informative ?? 0) > 0)
        _ReactionData(Icons.psychology, reactions.informative!),
      if ((reactions.wellWritten ?? 0) > 0)
        _ReactionData(Icons.description, reactions.wellWritten!),
      if ((reactions.creative ?? 0) > 0)
        _ReactionData(Icons.lightbulb_outline, reactions.creative!),
    ];

    reactionList.sort((a, b) => b.count.compareTo(a.count));

    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: reactionList.take(4).map((r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(r.icon,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 3),
            Text(
              '${r.count}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _ReactionData {
  final IconData icon;
  final int count;
  _ReactionData(this.icon, this.count);
}
