import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Kitsu/feed/kitsu_feed_parts.dart';

/// A Kitsu post with its comment thread (each comment with its first replies).
class KitsuPostPage extends StatefulWidget {
  final String postId;

  /// Source of the data; defaults to the shared Kitsu client.
  final KitsuFeed? feed;
  const KitsuPostPage({super.key, required this.postId, this.feed});

  @override
  State<KitsuPostPage> createState() => _KitsuPostPageState();
}

class _KitsuPostPageState extends State<KitsuPostPage> {
  late final KitsuFeed _feed = widget.feed ?? KitsuFeed();
  final _scroll = ScrollController();
  KitsuPost? _post;
  final List<KitsuComment> _comments = [];
  KitsuPageArgs? _next;
  bool _loading = false;
  bool _loaded = false;
  bool _failed = false;
  bool _moreFailed = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(const KitsuPageArgs());
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 600 && _next != null) {
      _load(_next!);
    }
  }

  Future<void> _load(KitsuPageArgs page) async {
    if (_loading) return;
    final first = page.after == null;
    setState(() {
      _loading = true;
      _failed = false;
      _moreFailed = false;
    });
    try {
      final thread = await _feed.thread(widget.postId, page);
      if (!mounted) return;
      if (thread == null) {
        _gone = true;
      } else {
        if (first) {
          _post = thread.post;
          _comments.clear();
        }
        final known = _comments.map((c) => c.id).toSet();
        _comments.addAll(thread.comments.nodes.where((c) => known.add(c.id)));
        _next = thread.comments.nextPage();
      }
      _loaded = true;
    } catch (_) {
      if (!mounted) return;
      if (first) {
        _failed = true;
      } else {
        _moreFailed = true;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _retry() {
    _next = null;
    _load(const KitsuPageArgs());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final Widget body;
    final post = _post;
    if (_failed) {
      body = KitsuStateMessage(
        icon: Icons.cloud_off_outlined,
        title: s.Kc_Error_Title,
        actionLabel: s.Kc_Retry,
        onAction: _retry,
      );
    } else if (_gone) {
      body = KitsuStateMessage(icon: Icons.delete_outline, title: s.Kc_Post_Deleted);
    } else if (!_loaded || post == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          _next = null;
          await _load(const KitsuPageArgs());
        },
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: _comments.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) return _PostHeader(post: post);
            if (i == _comments.length + 1) {
              return KitsuListFooter(
                loading: _loading,
                failed: _moreFailed,
                onRetry: () {
                  if (_next != null) _load(_next!);
                },
              );
            }
            return _CommentTile(comment: _comments[i - 1]);
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.Kc_Post_Title)),
      body: body,
    );
  }
}

class _PostHeader extends StatelessWidget {
  final KitsuPost post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final media = post.media;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitsuByline(
            name: post.author.name,
            avatarUrl: post.author.avatar?.url,
            at: post.createdAt,
            nsfw: post.isNsfw,
            avatarSize: 42,
          ),
          if (media != null) ...[
            const SizedBox(height: 8),
            Text(s.Kc_On_Title(media.titles.display),
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          ],
          const SizedBox(height: 12),
          KitsuGuardedBody(
            text: post.content,
            html: post.contentHtml,
            isSpoiler: post.isSpoiler,
            isNsfw: post.isNsfw,
          ),
          const SizedBox(height: 12),
          KitsuCounts(likes: post.likes, comments: post.comments),
          const Divider(height: 28),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final KitsuComment comment;
  final bool reply;
  const _CommentTile({required this.comment, this.reply = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final hidden = comment.repliesCount - comment.replies.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(reply ? 52 : 16, 6, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitsuByline(
            name: comment.author.name,
            avatarUrl: comment.author.avatar?.url,
            at: comment.createdAt,
            avatarSize: reply ? 28 : 34,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KitsuBody(text: comment.content, html: comment.contentHtml),
                if (comment.likes > 0) ...[
                  const SizedBox(height: 4),
                  Text(s.Kc_Like_Count(comment.likes),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          for (final r in comment.replies) _CommentTile(comment: r, reply: true),
          if (!reply && hidden > 0)
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: TextButton(
                onPressed: () => launchWebView(KitsuFeed.siteUrl, context: context),
                child: Text(s.Kc_More_Replies(hidden)),
              ),
            ),
        ],
      ),
    );
  }
}
