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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scoreColor,
                    width: 2,
                  ),
                ),
                child: Text(
                  '$score/10',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Tags
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (review.isPreliminary == true)
                _buildTag('Preliminary', theme.colorScheme.primary),
                
              if (review.isSpoiler == true)
                _buildTag('Spoiler', Colors.red),
                
              // Add reaction tags if present
              if ((review.reactions?.funny ?? 0) > 0)
                _buildTag('Funny (${review.reactions!.funny})', Colors.orange),
                
              if ((review.reactions?.informative ?? 0) > 0)
                _buildTag('Informative (${review.reactions!.informative})', Colors.blue),
                
              if ((review.reactions?.wellWritten ?? 0) > 0)
                _buildTag('Well-written (${review.reactions!.wellWritten})', Colors.deepPurple),
                
              if ((review.reactions?.creative ?? 0) > 0)
                _buildTag('Creative (${review.reactions!.creative})', Colors.teal),
                
              if ((review.reactions?.overall ?? 0) > 0)
                _buildTag('Overall (${review.reactions!.overall})', Colors.grey),
            ],
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
  
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}