import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_comment_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_links.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_thread_composer.dart'
    show anilistCategoryName;
import 'package:mywatchlist/widgets/forum/forum_common.dart'
    show ForumMessage, ForumSkeleton, ForumStatChip;

/// Opens the AniList forum thread [id]; [commentId] (links to
/// `/forum/thread/<id>/comment/<commentId>`) is highlighted once its page is loaded (AniList
/// cannot fetch one comment by id).
Future<void> openAnilistThread(BuildContext context, int id, {int? commentId}) =>
    AppRoutes.push<void>(context, AnilistThreadPage(threadId: id, commentId: commentId));

/// A forum thread: categories and titles, author, body, likes and counts, then the comments
/// as a tree (oldest first, loaded page by page; a reply chain folds). Signed in: like,
/// subscribe, reply to the thread or to a comment, edit and delete one's own comments.
class AnilistThreadPage extends StatefulWidget {
  const AnilistThreadPage({super.key, required this.threadId, this.commentId, this.service});

  final int threadId;
  final int? commentId;
  final AnilistSocialService? service;

  @override
  State<AnilistThreadPage> createState() => _AnilistThreadPageState();
}

class _AnilistThreadPageState extends State<AnilistThreadPage> {
  AnilistThreadDetail? _thread;
  List<AnilistComment> _comments = [];
  final Set<int> _folded = {};
  int _page = 0;
  bool _hasNext = true;
  bool _loadingMore = false;
  Object? _error;
  Object? _moreError;
  int? _viewerId;
  int _generation = 0;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  void initState() {
    super.initState();
    _service.viewerId().then((id) {
      if (mounted) setState(() => _viewerId = id);
    });
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _error = null);
    try {
      final (thread, page) = await _service.thread(widget.threadId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _thread = thread;
        _comments = page.items;
        _page = 1;
        _hasNext = page.hasNext && page.items.isNotEmpty;
        _moreError = null;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext || _thread == null) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final page = await _service.comments(widget.threadId, page: _page + 1);
      if (!mounted || generation != _generation) return;
      final known = {for (final c in _comments) c.id};
      setState(() {
        _page++;
        _comments = [..._comments, ...page.items.where((c) => !known.contains(c.id))];
        _hasNext = page.hasNext && page.items.isNotEmpty;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _moreError = e;
        _loadingMore = false;
      });
    }
  }

  /// Visible rows: the tree depth first, without the replies of a folded comment.
  List<(AnilistComment, int)> get _rows {
    final rows = <(AnilistComment, int)>[];
    void walk(AnilistComment c, int depth) {
      rows.add((c, depth));
      if (_folded.contains(c.id)) return;
      for (final child in c.children) {
        walk(child, depth + 1);
      }
    }

    for (final c in _comments) {
      walk(c, 0);
    }
    return rows;
  }

  void _updateComment(int id, AnilistComment? Function(AnilistComment) update) {
    setState(() => _comments = AnilistComment.updateTree(_comments, id, update));
  }

  Future<void> _reply({AnilistComment? parent}) async {
    final thread = _thread;
    if (thread == null) return;
    final s = S.of(context);
    await showAnilistComposer(
      context,
      title: parent == null ? s.Als_Reply : s.Als_Reply_To(parent.user?.name ?? ''),
      sendLabel: s.Als_Reply,
      service: _service,
      submit: (markdown) async {
        final saved = await _service.saveComment(
          threadId: thread.id,
          markdown: markdown,
          parentId: parent?.id,
        );
        if (!mounted) return true;
        if (parent == null) {
          setState(() {
            _comments = [..._comments, saved];
            _thread = _thread?.copyWith(replyCount: thread.replyCount + 1);
          });
        } else {
          _folded.remove(parent.id);
          _updateComment(parent.id, (c) => c.copyWith(children: [...c.children, saved]));
        }
        return true;
      },
    );
  }

  Future<void> _edit(AnilistComment comment) async {
    final s = S.of(context);
    // A record, so "not found" (null inside) differs from a failed call (null record).
    final found = await runAnilistWrite(
      context,
      () async => (await _service.commentSource(widget.threadId, comment.id),),
      service: _service,
    );
    if (found == null || !mounted) return;
    final source = found.$1;
    if (source == null) {
      // Not reachable through the API (a reply under someone else's comment): edit on the site.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(s.Al_Load_Failed),
        action: SnackBarAction(
          label: s.Open_In_Browser,
          onPressed: () => openLink(context,
              'https://anilist.co/forum/thread/${widget.threadId}/comment/${comment.id}',
              confirm: false),
        ),
      ));
      return;
    }
    await showAnilistComposer(
      context,
      title: s.Edit,
      sendLabel: s.Save,
      initialText: source,
      service: _service,
      submit: (markdown) async {
        final saved = await _service.saveComment(
            threadId: widget.threadId, markdown: markdown, id: comment.id);
        if (mounted) _updateComment(comment.id, (c) => c.copyWith(html: saved.html));
        return true;
      },
    );
  }

  Future<void> _delete(AnilistComment comment) async {
    if (!await confirmAnilistDelete(context, S.of(context).Als_Delete_Comment)) return;
    if (!mounted) return;
    final done = await runAnilistWrite(context, () async {
      await _service.deleteComment(comment.id);
      return true;
    }, service: _service);
    if (done == true) _updateComment(comment.id, (_) => null);
  }

  Future<void> _toggleSubscription() async {
    final thread = _thread;
    if (thread == null) return;
    final subscribed = await runAnilistWrite(
      context,
      () => _service.setThreadSubscription(thread.id, !thread.isSubscribed),
      service: _service,
    );
    if (subscribed != null && mounted) {
      setState(() => _thread = _thread?.copyWith(isSubscribed: subscribed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final thread = _thread;
    final url = 'https://anilist.co/forum/thread/${widget.threadId}';
    final canReply = thread != null && !thread.isLocked;
    return Scaffold(
      appBar: AppBar(
        title: Text(thread?.title ?? s.Als_Thread, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (thread != null && _service.signedIn)
            IconButton(
              tooltip: thread.isSubscribed ? s.Als_Unsubscribe : s.Als_Subscribe,
              isSelected: thread.isSubscribed,
              onPressed: _toggleSubscription,
              icon: const Icon(Icons.notifications_none),
              selectedIcon: const Icon(Icons.notifications_active),
            ),
          IconButton(
            tooltip: s.Open_In_Browser,
            icon: const Icon(Icons.open_in_browser),
            onPressed: () => openLink(context, url, confirm: false),
          ),
        ],
      ),
      bottomNavigationBar: canReply ? AnilistReplyBar(onTap: () => _reply()) : null,
      body: thread == null
          ? (_error != null
              ? ForumMessage(
                  icon: Icons.cloud_off_outlined,
                  title: anilistErrorText(_error!),
                  onRetry: _load,
                )
              : const ForumSkeleton(count: 6, round: true, rowHeight: 88))
          : _content(context, thread, canReply),
    );
  }

  Widget _content(BuildContext context, AnilistThreadDetail thread, bool canReply) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final rows = _rows;
    final number = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 800) _loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thread.categories.isNotEmpty || thread.media.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in thread.categories) AnilistTag(label: anilistCategoryName(c)),
                          for (final m in thread.media)
                            AnilistTag(
                              label: m.title,
                              leading: Icon(
                                m.category == 'manga' ? Icons.menu_book_outlined : Icons.tv,
                                size: 12,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                              onTap: () =>
                                  openAnilistTitle(context, category: m.category, id: m.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    SelectableText(thread.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    AnilistAuthorLine(user: thread.user, time: thread.createdAt),
                    const SizedBox(height: 12),
                    AnilistHtml(thread.bodyHtml),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ForumStatChip(
                          icon: Icons.visibility_outlined,
                          label: number.format(thread.viewCount),
                        ),
                        const SizedBox(width: 6),
                        ForumStatChip(
                          icon: Icons.mode_comment_outlined,
                          label: number.format(thread.replyCount),
                        ),
                        if (thread.isLocked) ...[
                          const SizedBox(width: 6),
                          ForumStatChip(icon: Icons.lock_outline, label: s.Als_Locked),
                        ],
                        const Spacer(),
                        AnilistLikeButton(
                          isLiked: thread.isLiked,
                          count: thread.likeCount,
                          type: AnilistLikeable.thread,
                          id: thread.id,
                          onToggle: () => toggleAnilistLike(
                            context,
                            type: AnilistLikeable.thread,
                            id: thread.id,
                            isLiked: thread.isLiked,
                            count: thread.likeCount,
                            service: _service,
                            apply: (liked, count) => setState(() =>
                                _thread = _thread?.copyWith(isLiked: liked, likeCount: count)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 24)),
            if (rows.isEmpty && !_hasNext)
              SliverToBoxAdapter(
                child: ForumMessage(
                  icon: Icons.forum_outlined,
                  title: s.Als_No_Comments,
                  scrollable: false,
                ),
              )
            else
              SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final (comment, depth) = rows[i];
                  return AnilistCommentTile(
                    key: ValueKey(comment.id),
                    comment: comment,
                    depth: depth,
                    highlighted: comment.id == widget.commentId,
                    folded: _folded.contains(comment.id),
                    mine: _viewerId != null && comment.user?.id == _viewerId,
                    canReply: canReply && !comment.isLocked,
                    service: _service,
                    onToggleFold: () => setState(() {
                      if (!_folded.remove(comment.id)) _folded.add(comment.id);
                    }),
                    onLike: (liked, count) => _updateComment(
                        comment.id, (c) => c.copyWith(isLiked: liked, likeCount: count)),
                    onReply: () => _reply(parent: comment),
                    onEdit: () => _edit(comment),
                    onDelete: () => _delete(comment),
                  );
                },
              ),
            SliverToBoxAdapter(
              child: AnilistPageFooter(
                loading: _loadingMore,
                failed: _moreError != null,
                onRetry: _loadMore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
