import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';

class ReviewDetailPage extends StatelessWidget {
  final AnimeReview review;

  const ReviewDetailPage({
    super.key,
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = review.score ?? 0;
    final Color scoreColor =
        score >= 8 ? Colors.green : (score >= 5 ? Colors.amber : Colors.red);
    final dateStr = review.date != null
        ? DateFormat('EEE, MMM d, yyyy').format(DateTime.parse(review.date!))
        : '';

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Score + User section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Score + Tags
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/star.png',
                          height: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Tags from Jikan
                    if (review.tags != null && review.tags!.isNotEmpty)
                      ...review.tags!.map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            tag,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    // Preliminary / Spoiler tags
                    if (review.isPreliminary == true)
                      _buildTag('Preliminary', theme.colorScheme.primary),
                    if (review.isSpoiler == true)
                      _buildTag('Spoiler', Colors.red),
                  ],
                ),
                // Right: User avatar + name
                GestureDetector(
                  onTap: () {
                    // TODO: Navigate to user profile
                  },
                  child: Column(
                    children: [
                      AvatarWidget(
                        height: 48,
                        width: 48,
                        url: review.user?.images?.jpg?.imageUrl,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        review.user?.username ?? '?',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Reactions bar
          _buildReactionsRow(context),

          const SizedBox(height: 12),

          // Review text (selectable, scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: SelectableText(
                  review.review ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),

          // Footer: Date + Episodes watched
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (review.episodesWatched != null)
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${review.episodesWatched} episodes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsRow(BuildContext context) {
    final reactions = review.reactions;
    if (reactions == null) return const SizedBox();

    final theme = Theme.of(context);
    final reactionList = <_ReactionInfo>[
      if ((reactions.nice ?? 0) > 0)
        _ReactionInfo(Icons.thumb_up, 'Nice', reactions.nice!, Colors.blue),
      if ((reactions.loveIt ?? 0) > 0)
        _ReactionInfo(
            Icons.favorite, 'Love it', reactions.loveIt!, Colors.pink),
      if ((reactions.funny ?? 0) > 0)
        _ReactionInfo(Icons.mood, 'Funny', reactions.funny!, Colors.orange),
      if ((reactions.confusing ?? 0) > 0)
        _ReactionInfo(Icons.help_outline, 'Confusing', reactions.confusing!,
            Colors.purple),
      if ((reactions.informative ?? 0) > 0)
        _ReactionInfo(Icons.psychology, 'Informative', reactions.informative!,
            Colors.teal),
      if ((reactions.wellWritten ?? 0) > 0)
        _ReactionInfo(Icons.description, 'Well-written',
            reactions.wellWritten!, Colors.deepPurple),
      if ((reactions.creative ?? 0) > 0)
        _ReactionInfo(Icons.lightbulb_outline, 'Creative', reactions.creative!,
            Colors.amber.shade700),
    ];

    reactionList.sort((a, b) => b.count.compareTo(a.count));

    if (reactionList.isEmpty) return const SizedBox();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: reactionList.map((r) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: r.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: r.color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(r.icon, size: 16, color: r.color),
                const SizedBox(width: 5),
                Text(
                  '${r.count}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: r.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReactionInfo {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  _ReactionInfo(this.icon, this.label, this.count, this.color);
}
