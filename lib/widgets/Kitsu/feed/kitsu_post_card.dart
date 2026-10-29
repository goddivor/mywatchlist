import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_parts.dart';

/// A post in a feed: author, time, a few lines of text (behind a tap when it is a spoiler or
/// sensitive), counts. The whole card opens the post.
class KitsuPostCard extends StatelessWidget {
  final KitsuFeedPost post;
  final VoidCallback onTap;
  const KitsuPostCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = post.user;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KitsuByline(
                name: user?.name ?? '?',
                avatarUrl: user?.avatarUrl,
                at: post.createdAt,
                nsfw: post.isNsfw,
              ),
              const SizedBox(height: 10),
              KitsuGuardedBody(
                text: post.content,
                isSpoiler: post.isSpoiler,
                isNsfw: post.isNsfw,
                maxLines: 6,
              ),
              const SizedBox(height: 10),
              KitsuCounts(likes: post.likesCount, comments: post.commentsCount),
            ],
          ),
        ),
      ),
    );
  }
}
