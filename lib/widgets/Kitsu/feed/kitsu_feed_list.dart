import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_parts.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_post_card.dart';

/// The posts of a [KitsuFeedController] as an endless list: loads on first build, more near the
/// end, pull to refresh, retry on error. Tapping a post calls [onOpenPost].
class KitsuFeedList extends StatefulWidget {
  final KitsuFeedController controller;
  final void Function(KitsuFeedPost post) onOpenPost;

  /// Shown above the posts (a group header).
  final Widget? header;
  final String? emptyLabel;
  const KitsuFeedList({
    super.key,
    required this.controller,
    required this.onOpenPost,
    this.header,
    this.emptyLabel,
  });

  @override
  State<KitsuFeedList> createState() => _KitsuFeedListState();
}

class _KitsuFeedListState extends State<KitsuFeedList> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isLoaded && !widget.controller.isLoading) widget.controller.loadMore();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 600) widget.controller.loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final hasHeader = widget.header != null;
        if (c.error != null) {
          return Column(children: [
            if (hasHeader) widget.header!,
            Expanded(
              child: KitsuStateMessage(
                icon: Icons.cloud_off_outlined,
                title: s.Kc_Error_Title,
                actionLabel: s.Kc_Retry,
                onAction: c.reload,
              ),
            ),
          ]);
        }
        if (c.isFirstLoad || (!c.isLoaded && c.length == 0)) {
          return Column(children: [
            if (hasHeader) widget.header!,
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ]);
        }
        if (c.length == 0) {
          return Column(children: [
            if (hasHeader) widget.header!,
            Expanded(
              child: KitsuStateMessage(
                icon: Icons.forum_outlined,
                title: widget.emptyLabel ?? s.Kc_Empty,
              ),
            ),
          ]);
        }
        final head = hasHeader ? 1 : 0;
        return RefreshIndicator(
          onRefresh: c.reload,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: head + c.length + 1,
              itemBuilder: (context, i) {
                if (hasHeader && i == 0) return widget.header!;
                final index = i - head;
                if (index == c.length) {
                  return KitsuListFooter(
                    loading: c.isLoading,
                    failed: c.loadMoreFailed,
                    onRetry: c.loadMore,
                  );
                }
                final post = c[index];
                return KitsuPostCard(post: post, onTap: () => widget.onOpenPost(post));
              },
            ),
          ),
        );
      },
    );
  }
}
