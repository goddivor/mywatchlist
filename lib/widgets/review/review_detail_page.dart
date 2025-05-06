// lib/widgets/review/review_detail_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';

class ReviewDetailPage extends StatelessWidget {
  final AnimeReview review;
  
  const ReviewDetailPage({
    super.key,
    required this.review,
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
    
    return Container(
      color: theme.scaffoldBackgroundColor,
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Critique',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          
          const Divider(),
          
          // User & Score Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User Avatar
              if (review.user?.images?.jpg?.imageUrl != null)
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(
                    review.user!.images!.jpg!.imageUrl!,
                  ),
                )
              else
                const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person),
                ),
              
              const SizedBox(width: 16),
              
              // Username & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.user?.username ?? 'Utilisateur inconnu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodyMedium,
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
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Image.asset(
                    'assets/images/star.png',
                    height: 24,
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Tags
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (review.isPreliminary == true)
                  _buildTag('Preliminary', theme.colorScheme.primary, Icons.hourglass_empty),
                  
                if (review.isSpoiler == true)
                  _buildTag('Spoiler', Colors.red, Icons.warning),
                  
                // Add reaction tags if present
                if ((review.reactions?.nice ?? 0) > 0)
                  _buildTag('Nice', Colors.blue, Icons.thumb_up, review.reactions!.nice!),
                  
                if ((review.reactions?.loveIt ?? 0) > 0)
                  _buildTag('Love it', Colors.pink, Icons.favorite, review.reactions!.loveIt!),
                  
                if ((review.reactions?.funny ?? 0) > 0)
                  _buildTag('Funny', Colors.orange, Icons.mood, review.reactions!.funny!),
                  
                if ((review.reactions?.confusing ?? 0) > 0)
                  _buildTag('Confusing', Colors.purple, Icons.question_mark, review.reactions!.confusing!),
                  
                if ((review.reactions?.informative ?? 0) > 0)
                  _buildTag('Informative', Colors.blue, Icons.info, review.reactions!.informative!),
                  
                if ((review.reactions?.wellWritten ?? 0) > 0)
                  _buildTag('Well-written', Colors.deepPurple, Icons.edit, review.reactions!.wellWritten!),
                  
                if ((review.reactions?.creative ?? 0) > 0)
                  _buildTag('Creative', Colors.teal, Icons.auto_awesome, review.reactions!.creative!),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          
          // Review content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  review.review ?? 'Aucun contenu de critique',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          
          // Additional Info
          if (review.episodesWatched != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.visibility),
                  const SizedBox(width: 8),
                  Text(
                    'Épisodes regardés: ${review.episodesWatched}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildTag(String text, Color color, IconData icon, [int? count]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}