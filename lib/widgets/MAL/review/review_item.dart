// lib/widgets/review/review_item.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';

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
    
    // Calculate score color
    final score = review.score ?? 0;
    final Color scoreColor = score >= 8 
        ? Colors.green 
        : (score >= 5 ? Colors.amber : Colors.red);
    
    // Format date
    final dateStr = review.date != null 
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(review.date!))
        : 'Date inconnue';
    
    return Card(
      margin: const EdgeInsets.only(right: 16, bottom: 8, top: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // User Avatar
                  if (review.user?.images?.jpg?.imageUrl != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(
                        review.user!.images!.jpg!.imageUrl!,
                      ),
                    )
                  else
                    const CircleAvatar(
                      radius: 20,
                      child: Icon(Icons.person),
                    ),
                  
                  const SizedBox(width: 12),
                  
                  // Username & Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.user?.username ?? 'Utilisateur inconnu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  
                  // Score
                  Row(
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        'assets/images/star.png',
                        height: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tags
            if (review.isPreliminary == true || review.isSpoiler == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    if (review.isPreliminary == true)
                      _buildTag('Preliminary', theme.colorScheme.primary, Icons.hourglass_empty),
                      
                    if (review.isSpoiler == true)
                      _buildTag('Spoiler', Colors.red, Icons.warning),
                  ],
                ),
              ),
            
            // Review excerpt
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  review.review != null 
                      ? review.review!.substring(0, review.review!.length > 300 ? 300 : review.review!.length) +
                        (review.review!.length > 300 ? '...' : '')
                      : 'Aucun contenu',
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
            
            // Bottom reaction icons
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if ((review.reactions?.nice ?? 0) > 0)
                      _buildReactionCount(Icons.thumb_up, 'Nice', review.reactions!.nice!, theme),
                      
                    if ((review.reactions?.loveIt ?? 0) > 0)
                      _buildReactionCount(Icons.favorite, 'Love it', review.reactions!.loveIt!, theme),
                      
                    if ((review.reactions?.funny ?? 0) > 0)
                      _buildReactionCount(Icons.mood, 'Funny', review.reactions!.funny!, theme),
                      
                    if ((review.reactions?.confusing ?? 0) > 0)
                      _buildReactionCount(Icons.question_mark, 'Confusing', review.reactions!.confusing!, theme),
                      
                    if ((review.reactions?.informative ?? 0) > 0)
                      _buildReactionCount(Icons.info, 'Informative', review.reactions!.informative!, theme),
                      
                    if ((review.reactions?.wellWritten ?? 0) > 0)
                      _buildReactionCount(Icons.edit, 'Well-written', review.reactions!.wellWritten!, theme),
                      
                    if ((review.reactions?.creative ?? 0) > 0)
                      _buildReactionCount(Icons.auto_awesome, 'Creative', review.reactions!.creative!, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTag(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReactionCount(IconData icon, String label, int count, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}