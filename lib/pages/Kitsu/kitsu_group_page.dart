import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_post_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_list.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// One Kitsu group: its header and the feed of its posts.
class KitsuGroupScreen extends StatefulWidget {
  final KitsuGroup group;
  final KitsuFeed? feed;
  const KitsuGroupScreen({super.key, required this.group, this.feed});

  @override
  State<KitsuGroupScreen> createState() => _KitsuGroupScreenState();
}

class _KitsuGroupScreenState extends State<KitsuGroupScreen> {
  late final KitsuFeed _feed = widget.feed ?? KitsuFeed();
  late final KitsuFeedController _controller = _feed.group(widget.group.id);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final g = widget.group;
    final tagline = g.tagline?.trim() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: KitsuFeedList(
        controller: _controller,
        emptyLabel: s.Kc_Group_Posts_Empty,
        onOpenPost: (post) =>
            gotoPage(context: context, newPage: KitsuPostPage(postId: post.id, feed: widget.feed)),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              AppImage(
                url: g.avatarUrl,
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(12),
                placeholderColor: theme.colorScheme.surfaceContainerHighest,
                errorWidget: (_) => Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.groups_outlined, color: theme.colorScheme.onSecondaryContainer),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.Kc_Member_Count(g.membersCount), style: theme.textTheme.titleSmall),
                    if (tagline.isNotEmpty)
                      Text(tagline,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
