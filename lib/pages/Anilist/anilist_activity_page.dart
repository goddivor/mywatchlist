import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_composer.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// Opens the AniList activity [id] with its replies. [initial] (the row tapped in a feed)
/// shows at once while the replies load. Completes with the activity as it was when the
/// page closed (likes, replies), null when it never loaded or was deleted.
Future<AnilistActivity?> openAnilistActivity(
  BuildContext context,
  int id, {
  AnilistActivity? initial,
}) =>
    AppRoutes.push<AnilistActivity>(
      context,
      AnilistActivityPage(activityId: id, initial: initial),
    );

/// One activity (status, list update or message) and its replies, with like, reply,
/// subscribe; the user's own replies can be edited and deleted.
class AnilistActivityPage extends StatefulWidget {
  const AnilistActivityPage({super.key, required this.activityId, this.initial, this.service});

  final int activityId;
  final AnilistActivity? initial;
  final AnilistSocialService? service;

  @override
  State<AnilistActivityPage> createState() => _AnilistActivityPageState();
}

class _AnilistActivityPageState extends State<AnilistActivityPage> {
  AnilistActivity? _activity;
  bool _repliesLoaded = false;
  bool _deleted = false;
  Object? _error;
  int? _viewerId;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  void initState() {
    super.initState();
    _activity = widget.initial;
    _service.viewerId().then((id) {
      if (mounted) setState(() => _viewerId = id);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final activity = await _service.activity(widget.activityId);
      if (!mounted) return;
      setState(() {
        _activity = activity;
        _repliesLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _update(AnilistActivity a) => setState(() => _activity = a.copyWith(replies: _activity?.replies));

  void _setReplies(List<AnilistActivityReply> replies) {
    final a = _activity;
    if (a == null) return;
    setState(() => _activity = a.copyWith(replies: replies, replyCount: replies.length));
  }

  Future<void> _reply() async {
    final a = _activity;
    if (a == null) return;
    await showAnilistComposer(
      context,
      title: S.of(context).Als_Reply,
      sendLabel: S.of(context).Als_Reply,
      service: _service,
      submit: (markdown) async {
        final reply = await _service.saveReply(activityId: a.id, markdown: markdown);
        if (mounted) _setReplies([...?_activity?.replies, reply]);
        return true;
      },
    );
  }

  Future<void> _editReply(AnilistActivityReply reply) async {
    final s = S.of(context);
    final source = await runAnilistWrite(context, () => _service.replySource(reply.id), service: _service);
    if (source == null || !mounted) return;
    await showAnilistComposer(
      context,
      title: s.Edit,
      sendLabel: s.Save,
      initialText: source,
      service: _service,
      submit: (markdown) async {
        final saved = await _service.saveReply(
            activityId: widget.activityId, markdown: markdown, id: reply.id);
        if (mounted) {
          _setReplies([
            for (final r in _activity?.replies ?? const <AnilistActivityReply>[])
              r.id == reply.id ? r.copyWith(html: saved.html) : r,
          ]);
        }
        return true;
      },
    );
  }

  Future<void> _deleteReply(AnilistActivityReply reply) async {
    if (!await confirmAnilistDelete(context, S.of(context).Als_Delete_Reply)) return;
    if (!mounted) return;
    final done = await runAnilistWrite(context, () async {
      await _service.deleteReply(reply.id);
      return true;
    }, service: _service);
    if (done == true) {
      _setReplies([...?_activity?.replies.where((r) => r.id != reply.id)]);
    }
  }

  void _close() => Navigator.of(context).pop(_deleted ? null : _activity);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final a = _activity;
    return PopScope<AnilistActivity>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.Als_Activity),
          actions: [
            IconButton(
              tooltip: s.Open_In_Browser,
              icon: const Icon(Icons.open_in_browser),
              onPressed: () => openLink(
                  context, 'https://anilist.co/activity/${widget.activityId}',
                  confirm: false),
            ),
          ],
        ),
        bottomNavigationBar: a == null ? null : AnilistReplyBar(onTap: _reply),
        body: a == null
            ? (_error != null
                ? ForumMessage(
                    icon: Icons.cloud_off_outlined,
                    title: anilistErrorText(_error!),
                    onRetry: _load,
                  )
                : const ForumSkeleton(count: 4, round: true, rowHeight: 88))
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: AnilistActivityTile(
                        activity: a,
                        viewerId: _viewerId,
                        openable: false,
                        service: _service,
                        onChanged: _update,
                        onDeleted: () {
                          _deleted = true;
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 1)),
                    if (!_repliesLoaded)
                      SliverToBoxAdapter(
                        child: _error != null
                            ? ForumMessage(
                                icon: Icons.cloud_off_outlined,
                                title: anilistErrorText(_error!),
                                onRetry: _load,
                                scrollable: false,
                              )
                            : const ForumSkeleton(count: 3, round: true),
                      )
                    else if (a.replies.isEmpty)
                      SliverToBoxAdapter(
                        child: ForumMessage(
                          icon: Icons.mode_comment_outlined,
                          title: s.Als_No_Replies,
                          scrollable: false,
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: a.replies.length,
                        itemBuilder: (context, i) {
                          final r = a.replies[i];
                          return _ReplyTile(
                            key: ValueKey(r.id),
                            reply: r,
                            mine: _viewerId != null && r.user?.id == _viewerId,
                            service: _service,
                            onChanged: (updated) => _setReplies([
                              for (final x in a.replies) x.id == updated.id ? updated : x,
                            ]),
                            onEdit: () => _editReply(r),
                            onDelete: () => _deleteReply(r),
                          );
                        },
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    super.key,
    required this.reply,
    required this.mine,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
    required this.service,
  });

  final AnilistActivityReply reply;
  final bool mine;
  final ValueChanged<AnilistActivityReply> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final AnilistSocialService service;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnilistAuthorLine(
            user: reply.user,
            time: reply.createdAt,
            size: 32,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnilistLikeButton(
                  isLiked: reply.isLiked,
                  count: reply.likeCount,
                  type: AnilistLikeable.activityReply,
                  id: reply.id,
                  onToggle: () => toggleAnilistLike(
                    context,
                    type: AnilistLikeable.activityReply,
                    id: reply.id,
                    isLiked: reply.isLiked,
                    count: reply.likeCount,
                    service: service,
                    apply: (liked, count) =>
                        onChanged(reply.copyWith(isLiked: liked, likeCount: count)),
                  ),
                ),
                if (mine)
                  PopupMenuButton<int>(
                    icon: Icon(Icons.more_vert, size: 20, color: scheme.onSurfaceVariant),
                    onSelected: (v) => v == 0 ? onEdit() : onDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 0, child: Text(s.Edit)),
                      PopupMenuItem(value: 1, child: Text(s.Delete)),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(42, 4, 12, 8),
            child: AnilistHtml(reply.html, maxImageWidth: MediaQuery.sizeOf(context).width - 74),
          ),
        ],
      ),
    );
  }
}
