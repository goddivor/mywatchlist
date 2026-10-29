import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Kitsu/kitsu_post_page.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_list.dart';

/// The posts about one Kitsu title. The Kitsu title page opens it from its "posts" link:
/// `gotoPage(context: context, newPage: KitsuMediaDiscussionPage(kind: kind, mediaId: id, title: t))`.
class KitsuMediaDiscussionPage extends StatefulWidget {
  final KitsuMediaKind kind;
  final String mediaId;
  final String title;
  final KitsuFeed? feed;
  const KitsuMediaDiscussionPage({
    super.key,
    required this.kind,
    required this.mediaId,
    required this.title,
    this.feed,
  });

  @override
  State<KitsuMediaDiscussionPage> createState() => _KitsuMediaDiscussionPageState();
}

class _KitsuMediaDiscussionPageState extends State<KitsuMediaDiscussionPage> {
  late final KitsuFeedController _controller =
      (widget.feed ?? KitsuFeed()).media(widget.kind, widget.mediaId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.Discussion),
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: KitsuFeedList(
        controller: _controller,
        emptyLabel: s.Kc_Discussion_Empty,
        onOpenPost: (post) =>
            gotoPage(context: context, newPage: KitsuPostPage(postId: post.id, feed: widget.feed)),
      ),
    );
  }
}
