import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_social.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_post_page.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_paged_tab.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart';

/// The "Posts" tab: the user's pinned post (when there is one) then their posts, newest first.
class KitsuPostsTab extends StatelessWidget {
  final String slug;

  /// The pinned post, from the profile header; may be `null` or fail to load.
  final Future<KitsuPost?> Function()? pinned;
  final KitsuSocial? social;

  const KitsuPostsTab({super.key, required this.slug, this.pinned, this.social});

  @override
  Widget build(BuildContext context) {
    final api = social ?? KitsuSocial.instance;
    final load = pinned;
    return KitsuPagedList<KitsuPost>(
      storageKey: 'kitsu_posts_$slug',
      createPager: () => KitsuPager((page) => api.posts(slug, page)),
      emptyText: S.of(context).Kitsu_Posts_Empty,
      header: [
        if (load != null) SliverToBoxAdapter(child: _Pinned(load: load)),
      ],
      itemBuilder: (context, post) => KitsuPostCard(key: ValueKey(post.id), post: post),
    );
  }
}

class _Pinned extends StatefulWidget {
  final Future<KitsuPost?> Function() load;

  const _Pinned({required this.load});

  @override
  State<_Pinned> createState() => _PinnedState();
}

class _PinnedState extends State<_Pinned> {
  late final Future<KitsuPost?> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KitsuPost?>(
      future: _future,
      builder: (context, snapshot) {
        final post = snapshot.data;
        if (post == null) return const SizedBox.shrink();
        return KitsuPostCard(post: post, pinned: true);
      },
    );
  }
}

/// One post: a pinned/media header line, its text (behind a tap when it is a spoiler or NSFW),
/// and its like and comment counts. Opens the post on Kitsu.
class KitsuPostCard extends StatefulWidget {
  final KitsuPost post;
  final bool pinned;

  const KitsuPostCard({super.key, required this.post, this.pinned = false});

  @override
  State<KitsuPostCard> createState() => _KitsuPostCardState();
}

class _KitsuPostCardState extends State<KitsuPostCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final post = widget.post;
    final hidden = (post.isSpoiler || post.isNsfw) && !_revealed;
    final head = [
      if (widget.pinned) s.Kitsu_Post_Pinned,
      if (post.media != null) post.media!.titles.display,
      kitsuTimeAgo(post.createdAt),
    ].where((e) => e.isNotEmpty).join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => KitsuPostPage(postId: post.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (head.isNotEmpty)
                Text(head,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              if (hidden)
                TextButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: Text(post.isNsfw ? s.Kitsu_Post_Show_Nsfw : s.Show_Spoiler),
                )
              else
                Text(post.content, maxLines: 12, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.favorite_border_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${post.likes}', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${post.comments}', style: theme.textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
