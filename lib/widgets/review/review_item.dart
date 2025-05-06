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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User & Score Row
              Row(
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scoreColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$score/10',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Tags row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (review.isPreliminary == true)
                    _buildTag('Preliminary', theme.colorScheme.primary),
                    
                  if (review.isSpoiler == true)
                    _buildTag('Spoiler', Colors.red),
                    
                  // Add reaction tags if present and have at least one vote
                  if ((review.reactions?.funny ?? 0) > 0)
                    _buildTag('Funny (${review.reactions!.funny})', Colors.orange),
                    
                  if ((review.reactions?.informative ?? 0) > 0)
                    _buildTag('Informative (${review.reactions!.informative})', Colors.blue),
                    
                  if ((review.reactions?.wellWritten ?? 0) > 0)
                    _buildTag('Well-written (${review.reactions!.wellWritten})', Colors.deepPurple),
                    
                  if ((review.reactions?.creative ?? 0) > 0)
                    _buildTag('Creative (${review.reactions!.creative})', Colors.teal),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Review excerpt
              Text(
                review.review != null 
                    ? '${review.review!.substring(0, review.review!.length > 150 ? 150 : review.review!.length)}${review.review!.length > 150 ? '...' : ''}'
                    : 'Aucun contenu',
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Read more button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onTap,
                  child: const Text('Lire plus'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}